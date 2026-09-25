package com.bank.ledger.engine;

import com.bank.ledger.contracts.dto.CheckerActionRequest;
import com.bank.ledger.contracts.dto.MutationRequest;
import com.bank.ledger.contracts.dto.MutationResponse;
import com.bank.ledger.contracts.enums.EventType;
import com.bank.ledger.contracts.enums.MutationType;
import com.bank.ledger.contracts.exception.SegregationOfDutiesException;
import com.bank.ledger.engine.entity.master.BalanceMaster;
import com.bank.ledger.engine.entity.master.TransactionMaster;
import com.bank.ledger.engine.repository.master.BalanceMasterRepository;
import com.bank.ledger.engine.repository.master.TransactionMasterRepository;
import com.bank.ledger.engine.service.BalanceMutationService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
class MakerCheckerIntegrationTest {

    @Autowired
    private BalanceMutationService mutationService;

    @Autowired
    private BalanceMasterRepository balanceRepository;

    @Autowired
    private TransactionMasterRepository transactionRepository;

    private static final String SENDER_ACCOUNT = "acc-2001-sav-001"; // Owned by usr-1001-cst-001
    private static final String RECEIVER_ACCOUNT = "acc-2003-sav-002"; // Owned by usr-1002-cst-002
    private static final String MAKER_USER = "usr-1001-cst-001";
    private static final String TELLER_USER = "usr-1003-tel-001";

    @BeforeEach
    void resetBalances() {
        // Reset Sender to PHP 500,000.00 with zero holds
        BalanceMaster sender = balanceRepository.findById(SENDER_ACCOUNT).orElseThrow();
        sender.setBalanceAmount(new BigDecimal("500000.0000"));
        sender.setHoldAmount(BigDecimal.ZERO);
        sender.setAvailableBalance(new BigDecimal("500000.0000"));
        sender.setUpdatedAt(Instant.now());
        balanceRepository.save(sender);

        // Reset Receiver to PHP 100,000.00
        BalanceMaster receiver = balanceRepository.findById(RECEIVER_ACCOUNT).orElseThrow();
        receiver.setBalanceAmount(new BigDecimal("100000.0000"));
        receiver.setHoldAmount(BigDecimal.ZERO);
        receiver.setAvailableBalance(new BigDecimal("100000.0000"));
        receiver.setUpdatedAt(Instant.now());
        balanceRepository.save(receiver);
    }

    @Test
    @DisplayName("1. Normal Transfer (<= 50,000 PHP): Bypasses Maker-Checker, settles immediately")
    void testNormalTransferSettlesImmediately() {
        String txId = "TX-NORM-" + UUID.randomUUID().toString().substring(0, 8);
        BigDecimal amount = new BigDecimal("25000.0000");

        MutationResponse response = mutationService.executeTransfer(MutationRequest.builder()
                .transactionId(txId)
                .accountId(SENDER_ACCOUNT)
                .targetAccountId(RECEIVER_ACCOUNT)
                .eventType(EventType.TRANSFER)
                .mutationType(MutationType.TRANSFER)
                .mutationAmount(amount)
                .initiatorUserId(MAKER_USER)
                .build());

        assertEquals("COMMITTED", response.getStatus());

        BalanceMaster sender = balanceRepository.findById(SENDER_ACCOUNT).orElseThrow();
        BalanceMaster receiver = balanceRepository.findById(RECEIVER_ACCOUNT).orElseThrow();

        assertEquals(0, new BigDecimal("475000.0000").compareTo(sender.getBalanceAmount()));
        assertEquals(0, new BigDecimal("125000.0000").compareTo(receiver.getBalanceAmount()));
        assertEquals(0, BigDecimal.ZERO.compareTo(sender.getHoldAmount()));
    }

    @Test
    @DisplayName("2. High-Value Transfer (> 50,000 PHP): Places Soft Hold & Enters PENDING_APPROVAL")
    void testHighValueTransferEntersPendingApprovalWithSoftHold() {
        String txId = "TX-HIGH-" + UUID.randomUUID().toString().substring(0, 8);
        BigDecimal amount = new BigDecimal("150000.0000");

        MutationResponse response = mutationService.executeTransfer(MutationRequest.builder()
                .transactionId(txId)
                .accountId(SENDER_ACCOUNT)
                .targetAccountId(RECEIVER_ACCOUNT)
                .eventType(EventType.TRANSFER)
                .mutationType(MutationType.TRANSFER)
                .mutationAmount(amount)
                .initiatorUserId(MAKER_USER)
                .build());

        assertEquals("PENDING_APPROVAL", response.getStatus());

        BalanceMaster sender = balanceRepository.findById(SENDER_ACCOUNT).orElseThrow();
        BalanceMaster receiver = balanceRepository.findById(RECEIVER_ACCOUNT).orElseThrow();

        // balance_amount is still 500,000 PHP (not taken yet!)
        assertEquals(0, new BigDecimal("500000.0000").compareTo(sender.getBalanceAmount()));
        // hold_amount is 150,000 PHP
        assertEquals(0, amount.compareTo(sender.getHoldAmount()));
        // available_balance is 350,000 PHP (500,000 - 150,000)
        assertEquals(0, new BigDecimal("350000.0000").compareTo(sender.getAvailableBalance()));
        // Receiver balance unchanged
        assertEquals(0, new BigDecimal("100000.0000").compareTo(receiver.getBalanceAmount()));

        TransactionMaster tx = transactionRepository.findById(txId).orElseThrow();
        assertEquals("PENDING_APPROVAL", tx.getStatus());
        assertEquals(1, tx.getRequiresMakerChecker());
    }

    @Test
    @DisplayName("3. Segregation of Duties (TRX-503): Maker CANNOT approve their own transfer")
    void testMakerCannotApproveOwnTransfer() {
        String txId = "TX-SOD-" + UUID.randomUUID().toString().substring(0, 8);
        BigDecimal amount = new BigDecimal("100000.0000");

        mutationService.executeTransfer(MutationRequest.builder()
                .transactionId(txId)
                .accountId(SENDER_ACCOUNT)
                .targetAccountId(RECEIVER_ACCOUNT)
                .eventType(EventType.TRANSFER)
                .mutationType(MutationType.TRANSFER)
                .mutationAmount(amount)
                .initiatorUserId(MAKER_USER)
                .build());

        // Maker attempts self-approval -> Must throw SegregationOfDutiesException!
        CheckerActionRequest selfApproval = CheckerActionRequest.builder()
                .checkerUserId(MAKER_USER)
                .remarks("Trying to approve my own money")
                .build();

        assertThrows(SegregationOfDutiesException.class, () ->
                mutationService.approveTransfer(txId, selfApproval));
    }

    @Test
    @DisplayName("4. Teller Approval (TRX-502): Teller approves, hold released, funds settled")
    void testTellerApprovalSettlesFundsAndReleasesHold() {
        String txId = "TX-APP-" + UUID.randomUUID().toString().substring(0, 8);
        BigDecimal amount = new BigDecimal("150000.0000");

        mutationService.executeTransfer(MutationRequest.builder()
                .transactionId(txId)
                .accountId(SENDER_ACCOUNT)
                .targetAccountId(RECEIVER_ACCOUNT)
                .eventType(EventType.TRANSFER)
                .mutationType(MutationType.TRANSFER)
                .mutationAmount(amount)
                .initiatorUserId(MAKER_USER)
                .build());

        // Authorized Teller approves
        CheckerActionRequest tellerApproval = CheckerActionRequest.builder()
                .checkerUserId(TELLER_USER)
                .remarks("Verified customer identity & KYC")
                .build();

        MutationResponse approvedResponse = mutationService.approveTransfer(txId, tellerApproval);
        assertEquals("COMMITTED", approvedResponse.getStatus());

        BalanceMaster sender = balanceRepository.findById(SENDER_ACCOUNT).orElseThrow();
        BalanceMaster receiver = balanceRepository.findById(RECEIVER_ACCOUNT).orElseThrow();

        // Hold is cleared back to 0!
        assertEquals(0, BigDecimal.ZERO.compareTo(sender.getHoldAmount()));
        // Sender balance debited to 350,000 PHP (500,000 - 150,000)
        assertEquals(0, new BigDecimal("350000.0000").compareTo(sender.getBalanceAmount()));
        assertEquals(0, new BigDecimal("350000.0000").compareTo(sender.getAvailableBalance()));
        // Receiver credited to 250,000 PHP (100,000 + 150,000)
        assertEquals(0, new BigDecimal("250000.0000").compareTo(receiver.getBalanceAmount()));

        TransactionMaster tx = transactionRepository.findById(txId).orElseThrow();
        assertEquals("COMMITTED", tx.getStatus());
        assertEquals(TELLER_USER, tx.getApprovedByUserId());
    }

    @Test
    @DisplayName("5. Teller Rejection (TRX-502): Teller rejects, soft hold released, available restored")
    void testTellerRejectionRestoresHoldWithoutBalanceDeduction() {
        String txId = "TX-REJ-" + UUID.randomUUID().toString().substring(0, 8);
        BigDecimal amount = new BigDecimal("80000.0000");

        mutationService.executeTransfer(MutationRequest.builder()
                .transactionId(txId)
                .accountId(SENDER_ACCOUNT)
                .targetAccountId(RECEIVER_ACCOUNT)
                .eventType(EventType.TRANSFER)
                .mutationType(MutationType.TRANSFER)
                .mutationAmount(amount)
                .initiatorUserId(MAKER_USER)
                .build());

        // Authorized Teller rejects
        CheckerActionRequest tellerRejection = CheckerActionRequest.builder()
                .checkerUserId(TELLER_USER)
                .remarks("Suspicious transaction pattern")
                .build();

        MutationResponse rejectedResponse = mutationService.rejectTransfer(txId, tellerRejection);
        assertEquals("FAILED", rejectedResponse.getStatus());

        BalanceMaster sender = balanceRepository.findById(SENDER_ACCOUNT).orElseThrow();
        BalanceMaster receiver = balanceRepository.findById(RECEIVER_ACCOUNT).orElseThrow();

        // Hold released!
        assertEquals(0, BigDecimal.ZERO.compareTo(sender.getHoldAmount()));
        // Full balance restored to 500,000 PHP (Zero funds lost!)
        assertEquals(0, new BigDecimal("500000.0000").compareTo(sender.getBalanceAmount()));
        assertEquals(0, new BigDecimal("500000.0000").compareTo(sender.getAvailableBalance()));
        // Receiver balance unchanged
        assertEquals(0, new BigDecimal("100000.0000").compareTo(receiver.getBalanceAmount()));

        TransactionMaster tx = transactionRepository.findById(txId).orElseThrow();
        assertEquals("FAILED", tx.getStatus());
    }
}