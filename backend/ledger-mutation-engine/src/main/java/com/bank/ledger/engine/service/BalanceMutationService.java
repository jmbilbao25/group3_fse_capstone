package com.bank.ledger.engine.service;

import com.bank.ledger.contracts.dto.CheckerActionRequest;
import com.bank.ledger.contracts.dto.MutationRequest;
import com.bank.ledger.contracts.dto.MutationResponse;
import com.bank.ledger.contracts.exception.InsufficientFundsException;
import com.bank.ledger.contracts.exception.SegregationOfDutiesException;
import com.bank.ledger.engine.dto.event.NotificationAlertEvent;
import com.bank.ledger.engine.dto.event.TransactionEvent;
import com.bank.ledger.engine.entity.audit.LedgerMutationAudit;
import com.bank.ledger.engine.entity.master.AccountMaster;
import com.bank.ledger.engine.entity.master.BalanceMaster;
import com.bank.ledger.engine.entity.master.TransactionMaster;
import com.bank.ledger.engine.kafka.KafkaEventPublisher;
import com.bank.ledger.engine.repository.audit.LedgerMutationAuditRepository;
import com.bank.ledger.engine.repository.master.AccountMasterRepository;
import com.bank.ledger.engine.repository.master.BalanceMasterRepository;
import com.bank.ledger.engine.repository.master.TransactionMasterRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class BalanceMutationService {

    private final BalanceMasterRepository balanceRepository;
    private final TransactionMasterRepository transactionRepository;
    private final AccountMasterRepository accountRepository;
    private final LedgerMutationAuditRepository auditRepository;
    private final KafkaEventPublisher kafkaPublisher;

    @Value("${app.maker-checker.threshold:50000.0000}")
    private BigDecimal makerCheckerThreshold;

    /**
     * Executes funds transfer with threshold routing:
     * - If amount <= threshold: Immediate atomic dual-account settlement.
     * - If amount > threshold: Soft hold placed, marked PENDING_APPROVAL for Teller review.
     */
    @Transactional(transactionManager = "oracleTransactionManager")
    public MutationResponse executeTransfer(MutationRequest request) {
        String sourceId = request.getAccountId();
        String targetId = request.getTargetAccountId();
        BigDecimal amount = request.getMutationAmount();

        if (sourceId.equals(targetId)) {
            throw new IllegalArgumentException("Source and target accounts must be different.");
        }

        log.info("[MUTATION START] TxId: {}, Amount: PHP {} from {} to {}",
                request.getTransactionId(), amount, sourceId, targetId);

        // =========================================================================
        // STEP 1: DETERMINISTIC LOCK ORDERING (Zero Deadlock)
        // =========================================================================
        String firstLockId = sourceId.compareTo(targetId) < 0 ? sourceId : targetId;
        String secondLockId = sourceId.compareTo(targetId) < 0 ? targetId : sourceId;

        BalanceMaster firstAccount = balanceRepository.findByAccountIdWithLock(firstLockId)
                .orElseThrow(() -> new IllegalArgumentException("Account not found: " + firstLockId));
        BalanceMaster secondAccount = balanceRepository.findByAccountIdWithLock(secondLockId)
                .orElseThrow(() -> new IllegalArgumentException("Account not found: " + secondLockId));

        BalanceMaster sender = sourceId.equals(firstLockId) ? firstAccount : secondAccount;
        BalanceMaster receiver = targetId.equals(firstLockId) ? firstAccount : secondAccount;

        // =========================================================================
        // STEP 2: AVAILABLE BALANCE FINANCIAL SANITY CHECK
        // =========================================================================
        if (sender.getAvailableBalance().compareTo(amount) < 0) {
            log.error("[MUTATION REJECTED] Insufficient funds: Account {} available PHP {}, requested PHP {}",
                    sourceId, sender.getAvailableBalance(), amount);
            throw new InsufficientFundsException(
                    String.format("Insufficient funds in account %s. Available: PHP %s, Requested: PHP %s",
                            sourceId, sender.getAvailableBalance(), amount));
        }

        BigDecimal senderBefore = sender.getBalanceAmount();
        boolean isHighValue = amount.compareTo(makerCheckerThreshold) > 0;

        // =========================================================================
        // ROUTE A: HIGH-VALUE TRANSACTION -> SOFT HOLD & MAKER-CHECKER (TRX-501)
        // =========================================================================
        if (isHighValue) {
            log.info("[MAKER-CHECKER TRIGGERED] Transfer of PHP {} exceeds threshold PHP {}. Placing soft hold.",
                    amount, makerCheckerThreshold);

            // Soft hold: reserve the funds without taking them out of balance_amount yet
            sender.setHoldAmount(sender.getHoldAmount().add(amount));
            sender.setAvailableBalance(sender.getAvailableBalance().subtract(amount));
            sender.setUpdatedAt(Instant.now());
            balanceRepository.save(sender);

            TransactionMaster pendingTx = TransactionMaster.builder()
                    .transactionId(request.getTransactionId())
                    .fromAccountId(sourceId)
                    .toAccountId(targetId)
                    .type("TRANSFER")
                    .amount(amount)
                    .beforeBalance(senderBefore)
                    .afterBalance(senderBefore)
                    .status("PENDING_APPROVAL")
                    .requiresMakerChecker(1)
                    .createdAt(Instant.now())
                    .updatedAt(Instant.now())
                    .build();
            transactionRepository.save(pendingTx);

            // Kafka Alert: Notify customer of pending dual control review
            kafkaPublisher.publishNotificationAlert(NotificationAlertEvent.builder()
                    .alertId("ALT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                    .transactionId(request.getTransactionId())
                    .recipientUserId(request.getInitiatorUserId())
                    .recipientAccountId(sourceId)
                    .alertType("MAKER_CHECKER_PENDING")
                    .amount(amount)
                    .balanceAfter(sender.getAvailableBalance())
                    .title("Transfer Pending Approval")
                    .message(String.format("Transfer of PHP %s to %s exceeds ₱%s threshold and is awaiting Teller approval.",
                            amount, targetId, makerCheckerThreshold))
                    .createdAt(Instant.now())
                    .build());

            return MutationResponse.builder()
                    .transactionId(request.getTransactionId())
                    .accountId(sourceId)
                    .status("PENDING_APPROVAL")
                    .mutationAmount(amount)
                    .balanceBefore(senderBefore)
                    .balanceAfter(senderBefore)
                    .availableBalance(sender.getAvailableBalance())
                    .timestamp(Instant.now())
                    .traceId(UUID.randomUUID().toString())
                    .build();
        }

        // =========================================================================
        // ROUTE B: NORMAL TRANSFER -> IMMEDIATE ATOMIC SETTLEMENT
        // =========================================================================
        BigDecimal senderAfter = senderBefore.subtract(amount);
        BigDecimal receiverBefore = receiver.getBalanceAmount();
        BigDecimal receiverAfter = receiverBefore.add(amount);

        sender.setBalanceAmount(senderAfter);
        sender.setAvailableBalance(sender.getAvailableBalance().subtract(amount));
        sender.setUpdatedAt(Instant.now());

        receiver.setBalanceAmount(receiverAfter);
        receiver.setAvailableBalance(receiver.getAvailableBalance().add(amount));
        receiver.setUpdatedAt(Instant.now());

        balanceRepository.save(sender);
        balanceRepository.save(receiver);

        TransactionMaster committedTx = TransactionMaster.builder()
                .transactionId(request.getTransactionId())
                .fromAccountId(sourceId)
                .toAccountId(targetId)
                .type("TRANSFER")
                .amount(amount)
                .beforeBalance(senderBefore)
                .afterBalance(senderAfter)
                .status("COMMITTED")
                .requiresMakerChecker(0)
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();
        transactionRepository.save(committedTx);

        // Immutable Postgres Audit
        auditRepository.save(LedgerMutationAudit.builder()
                .transactionId(request.getTransactionId() + "-DR")
                .accountId(sourceId)
                .mutationType("TRANSFER")
                .mutationAmount(amount)
                .beforeBalance(senderBefore)
                .afterBalance(senderAfter)
                .initiatorUserId(request.getInitiatorUserId())
                .approvedByUserId(request.getApprovedByUserId())
                .status("COMMITTED")
                .createdAt(Instant.now())
                .build());

        // Kafka Streaming
        kafkaPublisher.publishTransactionEvent(TransactionEvent.builder()
                .transactionId(request.getTransactionId())
                .sourceAccountId(sourceId)
                .destinationAccountId(targetId)
                .amount(amount)
                .currency("PHP")
                .mutationType("TRANSFER")
                .status("COMMITTED")
                .initiatorUserId(request.getInitiatorUserId())
                .timestamp(Instant.now())
                .build());

        kafkaPublisher.publishNotificationAlert(NotificationAlertEvent.builder()
                .alertId("ALT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                .transactionId(request.getTransactionId())
                .recipientUserId(request.getInitiatorUserId())
                .recipientAccountId(sourceId)
                .alertType("TRANSFER_DEBIT")
                .amount(amount)
                .balanceAfter(senderAfter)
                .title("Debit Alert: Funds Transferred")
                .message(String.format("PHP %s has been transferred to %s. New balance: PHP %s",
                        amount, targetId, senderAfter))
                .createdAt(Instant.now())
                .build());

        return MutationResponse.builder()
                .transactionId(request.getTransactionId())
                .accountId(sourceId)
                .status("COMMITTED")
                .mutationAmount(amount)
                .balanceBefore(senderBefore)
                .balanceAfter(senderAfter)
                .availableBalance(sender.getAvailableBalance())
                .timestamp(Instant.now())
                .traceId(UUID.randomUUID().toString())
                .build();
    }

    /**
     * Teller / Checker Approval (TRX-502, TRX-503)
     * - Enforces Segregation of Duties: Maker CANNOT approve own transfer!
     * - Releases soft hold and settles debit & credit atomically.
     */
    @Transactional(transactionManager = "oracleTransactionManager")
    public MutationResponse approveTransfer(String transactionId, CheckerActionRequest checkerRequest) {
        TransactionMaster tx = transactionRepository.findById(transactionId)
                .orElseThrow(() -> new IllegalArgumentException("Transaction not found: " + transactionId));

        if (!"PENDING_APPROVAL".equals(tx.getStatus())) {
            throw new IllegalStateException("Transaction is not pending approval. Current status: " + tx.getStatus());
        }

        // =========================================================================
        // SEGREGATION OF DUTIES ENFORCEMENT (TRX-503)
        // =========================================================================
        AccountMaster sourceAccount = accountRepository.findById(tx.getFromAccountId())
                .orElseThrow(() -> new IllegalArgumentException("Account not found: " + tx.getFromAccountId()));

        if (checkerRequest.getCheckerUserId().equals(sourceAccount.getUserId())) {
            log.error("[SECURITY VIOLATION] Maker {} attempted to approve their own transfer {}",
                    checkerRequest.getCheckerUserId(), transactionId);
            throw new SegregationOfDutiesException(
                    "Maker-Checker Violation: The initiator cannot approve their own transfer.");
        }

        // Lock accounts in order
        String sourceId = tx.getFromAccountId();
        String targetId = tx.getToAccountId();
        String firstLockId = sourceId.compareTo(targetId) < 0 ? sourceId : targetId;
        String secondLockId = sourceId.compareTo(targetId) < 0 ? targetId : sourceId;

        BalanceMaster firstAccount = balanceRepository.findByAccountIdWithLock(firstLockId).orElseThrow();
        BalanceMaster secondAccount = balanceRepository.findByAccountIdWithLock(secondLockId).orElseThrow();

        BalanceMaster sender = sourceId.equals(firstLockId) ? firstAccount : secondAccount;
        BalanceMaster receiver = targetId.equals(firstLockId) ? firstAccount : secondAccount;

        BigDecimal amount = tx.getAmount();
        BigDecimal senderBefore = sender.getBalanceAmount();
        BigDecimal senderAfter = senderBefore.subtract(amount);

        // Release hold and finalize debit
        sender.setHoldAmount(sender.getHoldAmount().subtract(amount));
        sender.setBalanceAmount(senderAfter);
        sender.setUpdatedAt(Instant.now());

        // Finalize credit on receiver
        receiver.setBalanceAmount(receiver.getBalanceAmount().add(amount));
        receiver.setAvailableBalance(receiver.getAvailableBalance().add(amount));
        receiver.setUpdatedAt(Instant.now());

        balanceRepository.save(sender);
        balanceRepository.save(receiver);

        // Update Transaction Record
        tx.setStatus("COMMITTED");
        tx.setApprovedByUserId(checkerRequest.getCheckerUserId());
        tx.setAfterBalance(senderAfter);
        tx.setUpdatedAt(Instant.now());
        transactionRepository.save(tx);

        // Postgres Audit
        auditRepository.save(LedgerMutationAudit.builder()
                .transactionId(transactionId + "-APPROVED")
                .accountId(sourceId)
                .mutationType("TRANSFER")
                .mutationAmount(amount)
                .beforeBalance(senderBefore)
                .afterBalance(senderAfter)
                .initiatorUserId(sourceAccount.getUserId())
                .approvedByUserId(checkerRequest.getCheckerUserId())
                .status("COMMITTED")
                .createdAt(Instant.now())
                .build());

        // Kafka Event
        kafkaPublisher.publishTransactionEvent(TransactionEvent.builder()
                .transactionId(transactionId)
                .sourceAccountId(sourceId)
                .destinationAccountId(targetId)
                .amount(amount)
                .currency("PHP")
                .mutationType("TRANSFER")
                .status("COMMITTED")
                .initiatorUserId(sourceAccount.getUserId())
                .timestamp(Instant.now())
                .build());

        kafkaPublisher.publishNotificationAlert(NotificationAlertEvent.builder()
                .alertId("ALT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                .transactionId(transactionId)
                .recipientUserId(sourceAccount.getUserId())
                .recipientAccountId(sourceId)
                .alertType("TRANSFER_DEBIT_APPROVED")
                .amount(amount)
                .balanceAfter(senderAfter)
                .title("Transfer Approved & Executed")
                .message(String.format("Transfer of PHP %s to %s has been approved by Teller %s and settled.",
                        amount, targetId, checkerRequest.getCheckerUserId()))
                .createdAt(Instant.now())
                .build());

        return MutationResponse.builder()
                .transactionId(transactionId)
                .accountId(sourceId)
                .status("COMMITTED")
                .mutationAmount(amount)
                .balanceBefore(senderBefore)
                .balanceAfter(senderAfter)
                .availableBalance(sender.getAvailableBalance())
                .timestamp(Instant.now())
                .traceId(UUID.randomUUID().toString())
                .build();
    }

    /**
     * Teller / Checker Rejection (TRX-502)
     * - Releases soft hold, restoring available balance. No money leaves the account!
     */
    @Transactional(transactionManager = "oracleTransactionManager")
    public MutationResponse rejectTransfer(String transactionId, CheckerActionRequest checkerRequest) {
        TransactionMaster tx = transactionRepository.findById(transactionId)
                .orElseThrow(() -> new IllegalArgumentException("Transaction not found: " + transactionId));

        if (!"PENDING_APPROVAL".equals(tx.getStatus())) {
            throw new IllegalStateException("Transaction is not pending approval. Current status: " + tx.getStatus());
        }

        AccountMaster sourceAccount = accountRepository.findById(tx.getFromAccountId())
                .orElseThrow(() -> new IllegalArgumentException("Account not found: " + tx.getFromAccountId()));

        BalanceMaster sender = balanceRepository.findByAccountIdWithLock(tx.getFromAccountId()).orElseThrow();
        BigDecimal amount = tx.getAmount();

        // Release soft hold and restore available balance
        sender.setHoldAmount(sender.getHoldAmount().subtract(amount));
        sender.setAvailableBalance(sender.getAvailableBalance().add(amount));
        sender.setUpdatedAt(Instant.now());
        balanceRepository.save(sender);

        // Update Transaction Record
        tx.setStatus("FAILED");
        tx.setApprovedByUserId(checkerRequest.getCheckerUserId());
        tx.setUpdatedAt(Instant.now());
        transactionRepository.save(tx);

        // Audit Record
        auditRepository.save(LedgerMutationAudit.builder()
                .transactionId(transactionId + "-REJECTED")
                .accountId(tx.getFromAccountId())
                .mutationType("TRANSFER")
                .mutationAmount(amount)
                .beforeBalance(sender.getBalanceAmount())
                .afterBalance(sender.getBalanceAmount())
                .initiatorUserId(sourceAccount.getUserId())
                .approvedByUserId(checkerRequest.getCheckerUserId())
                .status("FAILED")
                .createdAt(Instant.now())
                .build());

        // Kafka Alert
        kafkaPublisher.publishNotificationAlert(NotificationAlertEvent.builder()
                .alertId("ALT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                .transactionId(transactionId)
                .recipientUserId(sourceAccount.getUserId())
                .recipientAccountId(tx.getFromAccountId())
                .alertType("TRANSFER_REJECTED")
                .amount(amount)
                .balanceAfter(sender.getAvailableBalance())
                .title("Transfer Rejected")
                .message(String.format("Transfer of PHP %s to %s was rejected by Teller %s. Reason: %s",
                        amount, tx.getToAccountId(), checkerRequest.getCheckerUserId(),
                        checkerRequest.getRemarks() != null ? checkerRequest.getRemarks() : "Not specified"))
                .createdAt(Instant.now())
                .build());

        return MutationResponse.builder()
                .transactionId(transactionId)
                .accountId(tx.getFromAccountId())
                .status("FAILED")
                .mutationAmount(amount)
                .balanceBefore(sender.getBalanceAmount())
                .balanceAfter(sender.getBalanceAmount())
                .availableBalance(sender.getAvailableBalance())
                .timestamp(Instant.now())
                .traceId(UUID.randomUUID().toString())
                .build();
    }

    /**
     * Retrieve all pending transactions for Teller review queue (UI-703)
     */
    @Transactional(readOnly = true, transactionManager = "oracleTransactionManager")
    public List<TransactionMaster> getPendingTransfers() {
        return transactionRepository.findByStatus("PENDING_APPROVAL");
    }
}