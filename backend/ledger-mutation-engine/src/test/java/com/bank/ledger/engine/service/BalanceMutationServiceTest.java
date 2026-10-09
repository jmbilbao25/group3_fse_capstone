package com.bank.ledger.engine.service;

import com.bank.ledger.contracts.dto.CheckerActionRequest;
import com.bank.ledger.contracts.dto.MutationRequest;
import com.bank.ledger.contracts.dto.MutationResponse;
import com.bank.ledger.contracts.dto.T24FundsTransferRequest;
import com.bank.ledger.contracts.dto.T24FundsTransferResponse;
import com.bank.ledger.contracts.dto.T24ReversalRequest;
import com.bank.ledger.contracts.dto.T24ReversalResponse;
import com.bank.ledger.contracts.enums.EventType;
import com.bank.ledger.contracts.enums.MutationType;
import com.bank.ledger.contracts.exception.InsufficientFundsException;
import com.bank.ledger.contracts.exception.SegregationOfDutiesException;
import com.bank.ledger.engine.entity.audit.LedgerMutationAudit;
import com.bank.ledger.engine.entity.master.AccountMaster;
import com.bank.ledger.engine.entity.master.BalanceMaster;
import com.bank.ledger.engine.entity.master.TransactionMaster;
import com.bank.ledger.engine.kafka.KafkaEventPublisher;
import com.bank.ledger.engine.repository.audit.LedgerMutationAuditRepository;
import com.bank.ledger.engine.repository.master.AccountMasterRepository;
import com.bank.ledger.engine.repository.master.BalanceMasterRepository;
import com.bank.ledger.engine.repository.master.TransactionMasterRepository;
import com.bank.ledger.engine.repository.master.UserMasterRepository;
import com.bank.ledger.engine.service.RiskEngineClient;
import com.bank.ledger.engine.entity.master.OutboxEventMaster;
import com.bank.ledger.engine.repository.master.OutboxEventMasterRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Optional;
import java.util.concurrent.CompletableFuture;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class BalanceMutationServiceTest {

    @Mock
    private BalanceMasterRepository balanceRepository;

    @Mock
    private TransactionMasterRepository transactionRepository;

    @Mock
    private AccountMasterRepository accountRepository;

    @Mock
    private UserMasterRepository userMasterRepository;

    @Mock
    private RiskEngineClient riskEngineClient;

    @Mock
    private LedgerMutationAuditRepository auditRepository;

    @Mock
    private KafkaEventPublisher kafkaPublisher;

    @Mock
    private OutboxEventMasterRepository outboxRepository;

    @Mock
    private ObjectMapper objectMapper;

    @InjectMocks
    private BalanceMutationService mutationService;

    private static final String SENDER_ACCOUNT = "acc-2001-sav-001";
    private static final String RECEIVER_ACCOUNT = "acc-2003-sav-002";
    private static final String MAKER_USER = "usr-1001-cst-001";
    private static final String CHECKER_USER = "usr-1003-tel-001";

    private BalanceMaster senderBalance;
    private BalanceMaster receiverBalance;
    private AccountMaster senderAccountMaster;

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(mutationService, "makerCheckerThreshold", new BigDecimal("50000.0000"));

        senderBalance = BalanceMaster.builder()
                .accountId(SENDER_ACCOUNT)
                .balanceAmount(new BigDecimal("100000.0000"))
                .holdAmount(BigDecimal.ZERO)
                .availableBalance(new BigDecimal("100000.0000"))
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();

        receiverBalance = BalanceMaster.builder()
                .accountId(RECEIVER_ACCOUNT)
                .balanceAmount(new BigDecimal("50000.0000"))
                .holdAmount(BigDecimal.ZERO)
                .availableBalance(new BigDecimal("50000.0000"))
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();

        senderAccountMaster = AccountMaster.builder()
                .accountId(SENDER_ACCOUNT)
                .userId(MAKER_USER)
                .accountNumber("100100001234")
                .accountType("SAVINGS")
                .status("ACTIVE")
                .build();

        lenient().when(userMasterRepository.findById(any())).thenReturn(Optional.empty());
        lenient().when(riskEngineClient.evaluateRisk(any())).thenReturn(
                RiskEngineClient.RiskEvaluationResult.builder().decision("ALLOW").fraudScore(0).build()
        );
    }

    @Test
    @DisplayName("Normal transfer (amount <= 50,000) settles immediately with COMMITTED status")
    void testNormalTransferSettlesImmediately() {
        when(balanceRepository.findByAccountIdWithLock(SENDER_ACCOUNT)).thenReturn(Optional.of(senderBalance));
        when(balanceRepository.findByAccountIdWithLock(RECEIVER_ACCOUNT)).thenReturn(Optional.of(receiverBalance));
        when(kafkaPublisher.publishTransactionEvent(any())).thenReturn(CompletableFuture.completedFuture(null));
        when(kafkaPublisher.publishNotificationAlert(any())).thenReturn(CompletableFuture.completedFuture(null));

        MutationRequest request = MutationRequest.builder()
                .transactionId("TX-NORMAL-001")
                .accountId(SENDER_ACCOUNT)
                .targetAccountId(RECEIVER_ACCOUNT)
                .eventType(EventType.TRANSFER)
                .mutationType(MutationType.TRANSFER)
                .mutationAmount(new BigDecimal("20000.0000"))
                .initiatorUserId(MAKER_USER)
                .build();

        MutationResponse response = mutationService.executeTransfer(request);

        assertNotNull(response);
        assertEquals("COMMITTED", response.getStatus());
        assertEquals(0, new BigDecimal("80000.0000").compareTo(response.getBalanceAfter()));
        assertEquals(0, new BigDecimal("80000.0000").compareTo(response.getAvailableBalance()));
        assertEquals(0, new BigDecimal("70000.0000").compareTo(receiverBalance.getBalanceAmount()));

        verify(balanceRepository).save(senderBalance);
        verify(balanceRepository).save(receiverBalance);
        verify(transactionRepository).save(any(TransactionMaster.class));
        verify(auditRepository, times(2)).save(any(LedgerMutationAudit.class));
        verify(kafkaPublisher).publishTransactionEvent(any());
        verify(kafkaPublisher).publishNotificationAlert(any());
    }

    @Test
    @DisplayName("High-value transfer (amount > 50,000) places soft hold and enters PENDING_APPROVAL")
    void testHighValueTransferPlacesSoftHold() {
        when(balanceRepository.findByAccountIdWithLock(SENDER_ACCOUNT)).thenReturn(Optional.of(senderBalance));
        when(balanceRepository.findByAccountIdWithLock(RECEIVER_ACCOUNT)).thenReturn(Optional.of(receiverBalance));
        when(kafkaPublisher.publishNotificationAlert(any())).thenReturn(CompletableFuture.completedFuture(null));

        MutationRequest request = MutationRequest.builder()
                .transactionId("TX-HIGH-001")
                .accountId(SENDER_ACCOUNT)
                .targetAccountId(RECEIVER_ACCOUNT)
                .eventType(EventType.TRANSFER)
                .mutationType(MutationType.TRANSFER)
                .mutationAmount(new BigDecimal("75000.0000"))
                .initiatorUserId(MAKER_USER)
                .build();

        MutationResponse response = mutationService.executeTransfer(request);

        assertNotNull(response);
        assertEquals("PENDING_APPROVAL", response.getStatus());
        // Balance amount unchanged (100,000)
        assertEquals(0, new BigDecimal("100000.0000").compareTo(response.getBalanceAfter()));
        // Available balance deducted (100,000 - 75,000 = 25,000)
        assertEquals(0, new BigDecimal("25000.0000").compareTo(response.getAvailableBalance()));
        // Hold amount set to 75,000
        assertEquals(0, new BigDecimal("75000.0000").compareTo(senderBalance.getHoldAmount()));

        // Receiver untouched
        assertEquals(0, new BigDecimal("50000.0000").compareTo(receiverBalance.getBalanceAmount()));

        ArgumentCaptor<TransactionMaster> txCaptor = ArgumentCaptor.forClass(TransactionMaster.class);
        verify(transactionRepository).save(txCaptor.capture());
        assertEquals("PENDING_APPROVAL", txCaptor.getValue().getStatus());
        assertEquals(1, txCaptor.getValue().getRequiresMakerChecker());
    }

    @Test
    @DisplayName("Transfer rejected when available funds are insufficient")
    void testTransferInsufficientFunds() {
        when(balanceRepository.findByAccountIdWithLock(SENDER_ACCOUNT)).thenReturn(Optional.of(senderBalance));
        when(balanceRepository.findByAccountIdWithLock(RECEIVER_ACCOUNT)).thenReturn(Optional.of(receiverBalance));

        MutationRequest request = MutationRequest.builder()
                .transactionId("TX-INS-001")
                .accountId(SENDER_ACCOUNT)
                .targetAccountId(RECEIVER_ACCOUNT)
                .eventType(EventType.TRANSFER)
                .mutationType(MutationType.TRANSFER)
                .mutationAmount(new BigDecimal("150000.0000"))
                .initiatorUserId(MAKER_USER)
                .build();

        assertThrows(InsufficientFundsException.class, () -> mutationService.executeTransfer(request));
        verify(transactionRepository, never()).save(any());
    }

    @Test
    @DisplayName("Transfer rejected when source and target account are identical")
    void testTransferSameAccountRejected() {
        MutationRequest request = MutationRequest.builder()
                .transactionId("TX-SAME-001")
                .accountId(SENDER_ACCOUNT)
                .targetAccountId(SENDER_ACCOUNT)
                .eventType(EventType.TRANSFER)
                .mutationType(MutationType.TRANSFER)
                .mutationAmount(new BigDecimal("1000.0000"))
                .initiatorUserId(MAKER_USER)
                .build();

        assertThrows(IllegalArgumentException.class, () -> mutationService.executeTransfer(request));
    }

    @Test
    @DisplayName("Teller approval releases soft hold and settles balances atomically")
    void testApproveTransferByDistinctChecker() {
        TransactionMaster pendingTx = TransactionMaster.builder()
                .transactionId("TX-PENDING-001")
                .fromAccountId(SENDER_ACCOUNT)
                .toAccountId(RECEIVER_ACCOUNT)
                .type("TRANSFER")
                .amount(new BigDecimal("60000.0000"))
                .beforeBalance(new BigDecimal("100000.0000"))
                .afterBalance(new BigDecimal("100000.0000"))
                .status("PENDING_APPROVAL")
                .requiresMakerChecker(1)
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();

        // Sender currently has 60,000 on hold
        senderBalance.setHoldAmount(new BigDecimal("60000.0000"));
        senderBalance.setAvailableBalance(new BigDecimal("40000.0000"));

        when(transactionRepository.findById("TX-PENDING-001")).thenReturn(Optional.of(pendingTx));
        when(accountRepository.findById(SENDER_ACCOUNT)).thenReturn(Optional.of(senderAccountMaster));
        when(balanceRepository.findByAccountIdWithLock(SENDER_ACCOUNT)).thenReturn(Optional.of(senderBalance));
        when(balanceRepository.findByAccountIdWithLock(RECEIVER_ACCOUNT)).thenReturn(Optional.of(receiverBalance));
        when(kafkaPublisher.publishTransactionEvent(any())).thenReturn(CompletableFuture.completedFuture(null));
        when(kafkaPublisher.publishNotificationAlert(any())).thenReturn(CompletableFuture.completedFuture(null));

        CheckerActionRequest actionRequest = CheckerActionRequest.builder()
                .checkerUserId(CHECKER_USER)
                .remarks("Approved by compliance officer")
                .build();

        MutationResponse response = mutationService.approveTransfer("TX-PENDING-001", actionRequest);

        assertNotNull(response);
        assertEquals("COMMITTED", response.getStatus());
        // Hold released
        assertEquals(0, BigDecimal.ZERO.compareTo(senderBalance.getHoldAmount()));
        // Balance amount deducted (100,000 - 60,000 = 40,000)
        assertEquals(0, new BigDecimal("40000.0000").compareTo(senderBalance.getBalanceAmount()));
        // Receiver credited (50,000 + 60,000 = 110,000)
        assertEquals(0, new BigDecimal("110000.0000").compareTo(receiverBalance.getBalanceAmount()));

        assertEquals("COMMITTED", pendingTx.getStatus());
        assertEquals(CHECKER_USER, pendingTx.getApprovedByUserId());
    }

    @Test
    @DisplayName("Segregation of duties: Maker cannot approve their own high-value transfer")
    void testMakerCannotApproveOwnTransfer() {
        TransactionMaster pendingTx = TransactionMaster.builder()
                .transactionId("TX-SOD-001")
                .fromAccountId(SENDER_ACCOUNT)
                .toAccountId(RECEIVER_ACCOUNT)
                .type("TRANSFER")
                .amount(new BigDecimal("70000.0000"))
                .status("PENDING_APPROVAL")
                .build();

        when(transactionRepository.findById("TX-SOD-001")).thenReturn(Optional.of(pendingTx));
        when(accountRepository.findById(SENDER_ACCOUNT)).thenReturn(Optional.of(senderAccountMaster));

        CheckerActionRequest selfApproval = CheckerActionRequest.builder()
                .checkerUserId(MAKER_USER) // Same as senderAccountMaster.getUserId()
                .remarks("Self-approving transfer")
                .build();

        assertThrows(SegregationOfDutiesException.class, () ->
                mutationService.approveTransfer("TX-SOD-001", selfApproval));

        verify(balanceRepository, never()).save(any());
    }

    @Test
    @DisplayName("Teller rejection releases soft hold and restores available balance")
    void testRejectTransferByDistinctChecker() {
        TransactionMaster pendingTx = TransactionMaster.builder()
                .transactionId("TX-REJECT-001")
                .fromAccountId(SENDER_ACCOUNT)
                .toAccountId(RECEIVER_ACCOUNT)
                .type("TRANSFER")
                .amount(new BigDecimal("60000.0000"))
                .status("PENDING_APPROVAL")
                .build();

        senderBalance.setHoldAmount(new BigDecimal("60000.0000"));
        senderBalance.setAvailableBalance(new BigDecimal("40000.0000"));

        when(transactionRepository.findById("TX-REJECT-001")).thenReturn(Optional.of(pendingTx));
        when(accountRepository.findById(SENDER_ACCOUNT)).thenReturn(Optional.of(senderAccountMaster));
        when(balanceRepository.findByAccountIdWithLock(SENDER_ACCOUNT)).thenReturn(Optional.of(senderBalance));
        when(kafkaPublisher.publishNotificationAlert(any())).thenReturn(CompletableFuture.completedFuture(null));

        CheckerActionRequest rejection = CheckerActionRequest.builder()
                .checkerUserId(CHECKER_USER)
                .remarks("Fraudulent transaction suspected")
                .build();

        MutationResponse response = mutationService.rejectTransfer("TX-REJECT-001", rejection);

        assertNotNull(response);
        assertEquals("FAILED", response.getStatus());
        // Hold released back to 0
        assertEquals(0, BigDecimal.ZERO.compareTo(senderBalance.getHoldAmount()));
        // Available balance restored (40,000 + 60,000 = 100,000)
        assertEquals(0, new BigDecimal("100000.0000").compareTo(senderBalance.getAvailableBalance()));
        // Balance amount unchanged (100,000)
        assertEquals(0, new BigDecimal("100000.0000").compareTo(senderBalance.getBalanceAmount()));

        assertEquals("FAILED", pendingTx.getStatus());
        assertEquals(CHECKER_USER, pendingTx.getApprovedByUserId());
    }

    @Test
    @DisplayName("Segregation of duties: Maker cannot reject their own high-value transfer as checker")
    void testMakerCannotRejectOwnTransfer() {
        TransactionMaster pendingTx = TransactionMaster.builder()
                .transactionId("TX-SOD-REJ-001")
                .fromAccountId(SENDER_ACCOUNT)
                .toAccountId(RECEIVER_ACCOUNT)
                .type("TRANSFER")
                .amount(new BigDecimal("70000.0000"))
                .status("PENDING_APPROVAL")
                .build();

        when(transactionRepository.findById("TX-SOD-REJ-001")).thenReturn(Optional.of(pendingTx));
        when(accountRepository.findById(SENDER_ACCOUNT)).thenReturn(Optional.of(senderAccountMaster));

        CheckerActionRequest selfRejection = CheckerActionRequest.builder()
                .checkerUserId(MAKER_USER)
                .remarks("Self-cancelling transfer via checker endpoint")
                .build();

        assertThrows(SegregationOfDutiesException.class, () ->
                mutationService.rejectTransfer("TX-SOD-REJ-001", selfRejection));

        verify(balanceRepository, never()).save(any());
    }

    @Test
    @DisplayName("Deterministic lock ordering locks accounts in lexicographical order")
    void testDeterministicLockOrdering() {
        // Here SENDER_ACCOUNT ("acc-2001-sav-001") < RECEIVER_ACCOUNT ("acc-2003-sav-002")
        when(balanceRepository.findByAccountIdWithLock(SENDER_ACCOUNT)).thenReturn(Optional.of(senderBalance));
        when(balanceRepository.findByAccountIdWithLock(RECEIVER_ACCOUNT)).thenReturn(Optional.of(receiverBalance));
        when(kafkaPublisher.publishTransactionEvent(any())).thenReturn(CompletableFuture.completedFuture(null));
        when(kafkaPublisher.publishNotificationAlert(any())).thenReturn(CompletableFuture.completedFuture(null));

        MutationRequest forwardRequest = MutationRequest.builder()
                .transactionId("TX-LOCK-001")
                .accountId(SENDER_ACCOUNT)
                .targetAccountId(RECEIVER_ACCOUNT)
                .eventType(EventType.TRANSFER)
                .mutationType(MutationType.TRANSFER)
                .mutationAmount(new BigDecimal("1000.0000"))
                .initiatorUserId(MAKER_USER)
                .build();

        mutationService.executeTransfer(forwardRequest);

        org.mockito.InOrder inOrder = inOrder(balanceRepository);
        inOrder.verify(balanceRepository).findByAccountIdWithLock(SENDER_ACCOUNT);
        inOrder.verify(balanceRepository).findByAccountIdWithLock(RECEIVER_ACCOUNT);

        // Now reverse: transfer from RECEIVER ("acc-2003") to SENDER ("acc-2001")
        reset(balanceRepository);
        when(balanceRepository.findByAccountIdWithLock(SENDER_ACCOUNT)).thenReturn(Optional.of(senderBalance));
        when(balanceRepository.findByAccountIdWithLock(RECEIVER_ACCOUNT)).thenReturn(Optional.of(receiverBalance));

        MutationRequest reverseRequest = MutationRequest.builder()
                .transactionId("TX-LOCK-002")
                .accountId(RECEIVER_ACCOUNT)
                .targetAccountId(SENDER_ACCOUNT)
                .eventType(EventType.TRANSFER)
                .mutationType(MutationType.TRANSFER)
                .mutationAmount(new BigDecimal("1000.0000"))
                .initiatorUserId("usr-1002")
                .build();

        mutationService.executeTransfer(reverseRequest);

        // Crucial invariant: Still locks SENDER ("acc-2001") FIRST, then RECEIVER ("acc-2003") SECOND!
        org.mockito.InOrder inOrderReverse = inOrder(balanceRepository);
        inOrderReverse.verify(balanceRepository).findByAccountIdWithLock(SENDER_ACCOUNT);
        inOrderReverse.verify(balanceRepository).findByAccountIdWithLock(RECEIVER_ACCOUNT);
    }

    @Test
    @DisplayName("T24 FUNDS.TRANSFER: Successfully executes atomic dual-account transfer")
    void testT24FundsTransferSuccess() {
        when(balanceRepository.findByAccountIdWithLock(SENDER_ACCOUNT)).thenReturn(Optional.of(senderBalance));
        when(balanceRepository.findByAccountIdWithLock(RECEIVER_ACCOUNT)).thenReturn(Optional.of(receiverBalance));
        when(balanceRepository.findByAccountId(SENDER_ACCOUNT)).thenReturn(Optional.of(senderBalance));
        when(balanceRepository.findByAccountId(RECEIVER_ACCOUNT)).thenReturn(Optional.of(receiverBalance));

        T24FundsTransferRequest request = T24FundsTransferRequest.builder()
                .transactionReference("FT261007A111")
                .debitAccountId(SENDER_ACCOUNT)
                .creditAccountId(RECEIVER_ACCOUNT)
                .amount(new BigDecimal("5000.0000"))
                .currency("PHP")
                .paymentDetails("Invoice settlement")
                .customerId("usr-1001")
                .build();

        T24FundsTransferResponse response = mutationService.executeT24FundsTransfer(request);

        assertNotNull(response);
        assertEquals("FT261007A111", response.getT24Reference());
        assertEquals("COMMITTED", response.getStatus());
        assertEquals(SENDER_ACCOUNT, response.getDebitAccountId());
        assertEquals(RECEIVER_ACCOUNT, response.getCreditAccountId());
        assertEquals(new BigDecimal("95000.0000"), response.getDebitBalanceAfter());
        assertTrue(response.getOfsResponse().contains("FT261007A111//1/COMMITTED"));

        verify(balanceRepository).save(senderBalance);
        verify(balanceRepository).save(receiverBalance);
        verify(transactionRepository).save(any(TransactionMaster.class));
    }

    @Test
    @DisplayName("T24 REVERSAL: Successfully executes compensating double-entry reversal")
    void testT24ReversalSuccess() {
        TransactionMaster originalTx = TransactionMaster.builder()
                .transactionId("TX-ORIG-999")
                .fromAccountId(SENDER_ACCOUNT)
                .toAccountId(RECEIVER_ACCOUNT)
                .amount(new BigDecimal("5000.0000"))
                .beforeBalance(new BigDecimal("50000.0000"))
                .afterBalance(new BigDecimal("45000.0000"))
                .status("COMMITTED")
                .requires2FaOtp(0)
                .createdAt(Instant.now().minusSeconds(3600))
                .updatedAt(Instant.now().minusSeconds(3600))
                .build();

        when(transactionRepository.findById("TX-ORIG-999")).thenReturn(Optional.of(originalTx));
        when(balanceRepository.findByAccountIdWithLock(SENDER_ACCOUNT)).thenReturn(Optional.of(senderBalance));
        when(balanceRepository.findByAccountIdWithLock(RECEIVER_ACCOUNT)).thenReturn(Optional.of(receiverBalance));

        T24ReversalRequest reversalRequest = T24ReversalRequest.builder()
                .originalTransactionId("TX-ORIG-999")
                .reversalReason("DUPLICATE_TRANSFER")
                .checkerId("OP-SUPERVISOR")
                .makerId("OP-TELLER")
                .build();

        T24ReversalResponse response = mutationService.executeT24Reversal(reversalRequest);

        assertNotNull(response);
        assertEquals("TX-ORIG-999", response.getOriginalTransactionId());
        assertEquals("REVERSED", response.getStatus());
        assertEquals("DUPLICATE_TRANSFER", response.getReversalReason());
        assertEquals(new BigDecimal("5000.0000"), response.getAmount());
        assertEquals(RECEIVER_ACCOUNT, response.getDebitedAccountId());
        assertEquals(SENDER_ACCOUNT, response.getCreditedAccountId());
        // Receiver debited: 50,000 - 5,000 = 45,000
        assertEquals(new BigDecimal("45000.0000"), response.getDebitedBalanceAfter());
        // Sender credited: 100,000 + 5,000 = 105,000
        assertEquals(new BigDecimal("105000.0000"), response.getCreditedBalanceAfter());
        assertTrue(response.getOfsResponse().contains("TX-ORIG-999//1/REVERSED"));

        // Verify original transaction updated to REVERSED
        assertEquals("REVERSED", originalTx.getStatus());
        verify(transactionRepository).save(originalTx);

        // Verify compensating reversal transaction saved
        ArgumentCaptor<TransactionMaster> txCaptor = ArgumentCaptor.forClass(TransactionMaster.class);
        verify(transactionRepository, atLeastOnce()).save(txCaptor.capture());
        TransactionMaster savedReversal = txCaptor.getAllValues().stream()
                .filter(t -> "REVERSAL".equals(t.getType()))
                .findFirst()
                .orElse(null);
        assertNotNull(savedReversal);
        assertEquals(RECEIVER_ACCOUNT, savedReversal.getFromAccountId());
        assertEquals(SENDER_ACCOUNT, savedReversal.getToAccountId());

        // Verify audit record saved
        verify(auditRepository).save(any(LedgerMutationAudit.class));
    }

    @Test
    @DisplayName("T24 REVERSAL: Rejects when beneficiary has insufficient funds to reverse")
    void testT24ReversalInsufficientFunds() {
        TransactionMaster originalTx = TransactionMaster.builder()
                .transactionId("TX-ORIG-HIGH")
                .fromAccountId(SENDER_ACCOUNT)
                .toAccountId(RECEIVER_ACCOUNT)
                .amount(new BigDecimal("60000.0000")) // higher than receiver's 50,000 balance
                .status("COMMITTED")
                .requires2FaOtp(0)
                .build();

        when(transactionRepository.findById("TX-ORIG-HIGH")).thenReturn(Optional.of(originalTx));
        when(balanceRepository.findByAccountIdWithLock(SENDER_ACCOUNT)).thenReturn(Optional.of(senderBalance));
        when(balanceRepository.findByAccountIdWithLock(RECEIVER_ACCOUNT)).thenReturn(Optional.of(receiverBalance));

        T24ReversalRequest request = T24ReversalRequest.builder()
                .originalTransactionId("TX-ORIG-HIGH")
                .build();

        assertThrows(InsufficientFundsException.class, () -> mutationService.executeT24Reversal(request));
    }

    @Test
    @DisplayName("T24 REVERSAL: Rejects when transaction is already reversed")
    void testT24ReversalAlreadyReversed() {
        TransactionMaster alreadyReversed = TransactionMaster.builder()
                .transactionId("TX-REV-DONE")
                .fromAccountId(SENDER_ACCOUNT)
                .toAccountId(RECEIVER_ACCOUNT)
                .amount(new BigDecimal("1000.0000"))
                .status("REVERSED")
                .build();

        when(transactionRepository.findById("TX-REV-DONE")).thenReturn(Optional.of(alreadyReversed));

        T24ReversalRequest request = T24ReversalRequest.builder()
                .originalTransactionId("TX-REV-DONE")
                .build();

        assertThrows(IllegalStateException.class, () -> mutationService.executeT24Reversal(request));
    }

    @Test
    @DisplayName("T24 REVERSAL: Rejects when original transaction is not found")
    void testT24ReversalNotFound() {
        when(transactionRepository.findById("TX-UNKNOWN")).thenReturn(Optional.empty());

        T24ReversalRequest request = T24ReversalRequest.builder()
                .originalTransactionId("TX-UNKNOWN")
                .build();

        assertThrows(IllegalArgumentException.class, () -> mutationService.executeT24Reversal(request));
    }
}
