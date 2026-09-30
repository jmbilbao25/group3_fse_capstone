package com.bank.ledger.engine.service;

import com.bank.ledger.contracts.dto.CheckerActionRequest;
import com.bank.ledger.contracts.dto.MutationRequest;
import com.bank.ledger.contracts.dto.MutationResponse;
import com.bank.ledger.contracts.dto.TransactionNotificationEvent;
import com.bank.ledger.contracts.exception.InsufficientFundsException;
import com.bank.ledger.contracts.exception.SegregationOfDutiesException;
import com.bank.ledger.engine.dto.event.NotificationAlertEvent;
import com.bank.ledger.engine.dto.event.TransactionEvent;
import com.bank.ledger.engine.entity.audit.LedgerMutationAudit;
import com.bank.ledger.engine.entity.master.AccountMaster;
import com.bank.ledger.engine.entity.master.BalanceMaster;
import com.bank.ledger.engine.entity.master.OutboxEventMaster;
import com.bank.ledger.engine.entity.master.TransactionMaster;
import com.bank.ledger.engine.kafka.KafkaEventPublisher;
import com.bank.ledger.engine.repository.audit.LedgerMutationAuditRepository;
import com.bank.ledger.engine.repository.master.AccountMasterRepository;
import com.bank.ledger.engine.repository.master.BalanceMasterRepository;
import com.bank.ledger.engine.repository.master.OutboxEventMasterRepository;
import com.bank.ledger.engine.repository.master.TransactionMasterRepository;
import com.fasterxml.jackson.databind.ObjectMapper;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
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
     private final OutboxEventMasterRepository outboxRepository; 
    private final ObjectMapper objectMapper;
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private org.springframework.data.redis.core.StringRedisTemplate redisTemplate;

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
                    .requires2FaOtp(1)
                    .createdAt(Instant.now())
                    .updatedAt(Instant.now())
                    .build();
            transactionRepository.save(pendingTx);

            // Generate cryptographically secure 6-digit OTP and store in Redis (5-min TTL)
            String generatedOtp = String.format("%06d", new java.security.SecureRandom().nextInt(1000000));
            if (redisTemplate != null) {
                redisTemplate.opsForValue().set("otp:transfer:" + request.getTransactionId(), generatedOtp, java.time.Duration.ofMinutes(5));
                log.info("[OTP GENERATED] Stored OTP for transferId={}", request.getTransactionId());
            }

            // Persist to Oracle Transactional Outbox (EVT-601)
            try {
                // Notify notification-service consumer of Customer 2FA OTP requirement
                TransactionNotificationEvent pendingNotif = TransactionNotificationEvent.builder()
                        .transferId(request.getTransactionId())
                        .sourceAccount(sourceId)
                        .destinationAccount(targetId)
                        .userId(request.getInitiatorUserId() != null ? request.getInitiatorUserId() : "U1001")
                        .recipientEmail("juan.dc@email.com")
                        .amount(amount)
                        .currency("PHP")
                        .beforeBalance(sender.getBalanceAmount())
                        .afterBalance(sender.getBalanceAmount())
                        .status("PENDING_APPROVAL")
                        .eventType("TRANSFER_PENDING_APPROVAL")
                        .requires2FaOtp(true)
                        .initiatorUserId(request.getInitiatorUserId() != null ? request.getInitiatorUserId() : "U1001")
                        .timestamp(Instant.now())
                        .description("Customer 2FA Email OTP Verification Required (> PHP 50,000)")
                        .build();

                outboxRepository.save(OutboxEventMaster.builder()
                        .eventId("EVT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                        .aggregateType("TRANSACTION")
                        .aggregateId(request.getTransactionId())
                        .eventType("TRANSFER_PENDING_APPROVAL")
                        .kafkaTopic("banking.transfers.events")
                        .payload(objectMapper.writeValueAsString(pendingNotif))
                        .status("PENDING")
                        .retryCount(0)
                        .createdAt(Instant.now())
                        .build());
            } catch (Exception e) {
                log.error("[OUTBOX ERROR] Failed to serialize pending transaction for outbox", e);
            }

            // Kafka Alert: Notify customer of pending 2FA Email OTP requirement
            kafkaPublisher.publishNotificationAlert(NotificationAlertEvent.builder()
                    .alertId("ALT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                    .transactionId(request.getTransactionId())
                    .recipientUserId(request.getInitiatorUserId())
                    .recipientAccountId(sourceId)
                    .alertType("CUSTOMER_OTP_REQUIRED")
                    .amount(amount)
                    .balanceAfter(sender.getAvailableBalance())
                    .title("Transfer Pending 2FA Verification")
                    .message(String.format("Transfer of PHP %s to %s exceeds ₱%s threshold and requires Customer 2FA Email OTP verification.",
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
                .requires2FaOtp(0)
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();
        transactionRepository.save(committedTx);

        // Immutable Postgres Audit & Kafka Audit Stream
        LedgerMutationAudit audit = LedgerMutationAudit.builder()
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
                .build();
        auditRepository.save(audit);
        try {
            kafkaPublisher.publishAuditEvent(audit);
        } catch (Exception ex) {
            log.warn("[KAFKA AUDIT WARNING] Failed to stream to audit-events: {}", ex.getMessage());
        }

        // Persist to Oracle Transactional Outbox (EVT-601)
        try {
            TransactionEvent event = TransactionEvent.builder()
                    .transactionId(request.getTransactionId())
                    .sourceAccountId(sourceId)
                    .destinationAccountId(targetId)
                    .amount(amount)
                    .currency("PHP")
                    .mutationType("TRANSFER")
                    .status("COMMITTED")
                    .initiatorUserId(request.getInitiatorUserId())
                    .timestamp(Instant.now())
                    .build();

            String outboxPayload = objectMapper.writeValueAsString(event);
            outboxRepository.save(OutboxEventMaster.builder()
                    .eventId("EVT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                    .aggregateType("TRANSACTION")
                    .aggregateId(request.getTransactionId())
                    .eventType("MUTATION_COMMITTED")
                    .kafkaTopic("transaction-events")
                    .payload(outboxPayload)
                    .status("PENDING")
                    .retryCount(0)
                    .createdAt(Instant.now())
                    .build());

            // Notify notification-service consumer of executed transfer
            TransactionNotificationEvent notifEvent = TransactionNotificationEvent.builder()
                    .transferId(request.getTransactionId())
                    .sourceAccount(sourceId)
                    .destinationAccount(targetId)
                    .userId(request.getInitiatorUserId() != null ? request.getInitiatorUserId() : "U1001")
                    .recipientEmail("juan.delacruz@retailbank.ph")
                    .amount(amount)
                    .currency("PHP")
                    .beforeBalance(senderBefore)
                    .afterBalance(senderAfter)
                    .status("COMMITTED")
                    .eventType("TRANSFER_EXECUTED")
                    .requires2FaOtp(false)
                    .initiatorUserId(request.getInitiatorUserId() != null ? request.getInitiatorUserId() : "U1001")
                    .timestamp(Instant.now())
                    .description("Retail Fund Transfer")
                    .build();

            outboxRepository.save(OutboxEventMaster.builder()
                    .eventId("EVT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                    .aggregateType("TRANSACTION")
                    .aggregateId(request.getTransactionId())
                    .eventType("TRANSFER_EXECUTED")
                    .kafkaTopic("banking.transfers.events")
                    .payload(objectMapper.writeValueAsString(notifEvent))
                    .status("PENDING")
                    .retryCount(0)
                    .createdAt(Instant.now())
                    .build());
        } catch (Exception e) {
            log.error("[OUTBOX ERROR] Failed to serialize committed transaction for outbox", e);
        }

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
        BigDecimal amlaThreshold = new BigDecimal("500000.0000");

        // Dual-Control 2-Manager Approval Enforcement for transfers >= 500,000 PHP
        if (amount.compareTo(amlaThreshold) >= 0) {
            String priorApprover = tx.getApprovedByUserId();
            if (priorApprover == null || priorApprover.isBlank()) {
                // FIRST MANAGER APPROVAL
                tx.setApprovedByUserId(checkerRequest.getCheckerUserId());
                tx.setUpdatedAt(Instant.now());
                transactionRepository.save(tx);

                // Persist event to Oracle Transactional Outbox (EVT-601)
                try {
                    TransactionEvent firstApprovalEvent = TransactionEvent.builder()
                            .transactionId(transactionId)
                            .sourceAccountId(sourceId)
                            .destinationAccountId(targetId)
                            .amount(amount)
                            .currency("PHP")
                            .mutationType("TRANSFER")
                            .status("PENDING_APPROVAL")
                            .initiatorUserId(sourceAccount.getUserId())
                            .timestamp(Instant.now())
                            .build();

                    outboxRepository.save(OutboxEventMaster.builder()
                            .eventId("EVT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                            .aggregateType("MAKER_CHECKER")
                            .aggregateId(transactionId)
                            .eventType("MAKER_PENDING")
                            .kafkaTopic("banking.transfers.events")
                            .payload(objectMapper.writeValueAsString(firstApprovalEvent))
                            .status("PENDING")
                            .retryCount(0)
                            .createdAt(Instant.now())
                            .build());
                } catch (Exception e) {
                    log.error("[OUTBOX ERROR] Failed to serialize first approval event", e);
                }

                // Kafka Alert: Notify customer and operations team of first approval
                try {
                    kafkaPublisher.publishNotificationAlert(NotificationAlertEvent.builder()
                            .alertId("ALT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                            .transactionId(transactionId)
                            .recipientUserId(sourceAccount.getUserId())
                            .recipientAccountId(sourceId)
                            .alertType("MAKER_CHECKER_PENDING")
                            .amount(amount)
                            .balanceAfter(sender.getAvailableBalance())
                            .title("First Manager Approval Recorded")
                            .message(String.format("Transfer of PHP %s approved by %s (1 of 2). Awaiting second manager approval.",
                                    amount, checkerRequest.getCheckerUserId()))
                            .createdAt(Instant.now())
                            .build());
                } catch (Exception e) {
                    log.error("[KAFKA ERROR] Failed to publish notification alert for first approval", e);
                }

                log.info("[DUAL CONTROL] Transfer {} ({} PHP) recorded 1st approval by {}. Awaiting 2nd manager.",
                        transactionId, amount, checkerRequest.getCheckerUserId());

                return MutationResponse.builder()
                        .transactionId(transactionId)
                        .accountId(sourceId)
                        .status("PENDING_APPROVAL")
                        .mutationAmount(amount)
                        .balanceBefore(sender.getBalanceAmount())
                        .balanceAfter(sender.getBalanceAmount())
                        .availableBalance(sender.getAvailableBalance())
                        .timestamp(Instant.now())
                        .traceId(UUID.randomUUID().toString())
                        .message("First manager approval recorded by " + checkerRequest.getCheckerUserId() + ". Awaiting second manager approval for final release.")
                        .build();
            } else {
                // SECOND MANAGER APPROVAL: Ensure second approver is distinct from first approver!
                if (checkerRequest.getCheckerUserId().equals(priorApprover)) {
                    log.error("[SECURITY VIOLATION] Manager {} attempted to execute second approval for transfer {} which they already approved",
                            checkerRequest.getCheckerUserId(), transactionId);
                    throw new SegregationOfDutiesException(
                            "Dual-Control Violation: The second approval must be performed by a different manager. Manager " + priorApprover + " already approved.");
                }
            }
        }

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

                // Persist to Oracle Transactional Outbox (EVT-601)
        try {
            TransactionEvent approvedEvent = TransactionEvent.builder()
                    .transactionId(transactionId)
                    .sourceAccountId(sourceId)
                    .destinationAccountId(targetId)
                    .amount(amount)
                    .currency("PHP")
                    .mutationType("TRANSFER")
                    .status("COMMITTED")
                    .initiatorUserId(sourceAccount.getUserId())
                    .timestamp(Instant.now())
                    .build();

            String outboxPayload = objectMapper.writeValueAsString(approvedEvent);
            outboxRepository.save(OutboxEventMaster.builder()
                    .eventId("EVT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                    .aggregateType("TRANSACTION")
                    .aggregateId(transactionId)
                    .eventType("CHECKER_APPROVED")
                    .kafkaTopic("transaction-events")
                    .payload(outboxPayload)
                    .status("PENDING")
                    .retryCount(0)
                    .createdAt(Instant.now())
                    .build());

            // Notify notification-service of checker approved transaction
            TransactionNotificationEvent approvedNotif = TransactionNotificationEvent.builder()
                    .transferId(transactionId)
                    .sourceAccount(sourceId)
                    .destinationAccount(targetId)
                    .userId(sourceAccount.getUserId())
                    .recipientEmail("juan.delacruz@retailbank.ph")
                    .amount(amount)
                    .currency("PHP")
                    .beforeBalance(senderBefore)
                    .afterBalance(senderAfter)
                    .status("COMMITTED")
                    .eventType("TRANSFER_EXECUTED")
                    .requires2FaOtp(false)
                    .initiatorUserId(sourceAccount.getUserId())
                    .timestamp(Instant.now())
                    .description(checkerRequest.getRemarks() != null ? checkerRequest.getRemarks() : "Approved by Dual-Control Checker")
                    .build();

            outboxRepository.save(OutboxEventMaster.builder()
                    .eventId("EVT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                    .aggregateType("TRANSACTION")
                    .aggregateId(transactionId)
                    .eventType("TRANSFER_EXECUTED")
                    .kafkaTopic("banking.transfers.events")
                    .payload(objectMapper.writeValueAsString(approvedNotif))
                    .status("PENDING")
                    .retryCount(0)
                    .createdAt(Instant.now())
                    .build());
        } catch (Exception e) {
            log.error("[OUTBOX ERROR] Failed to serialize approved transaction for outbox", e);
        }

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

        if (checkerRequest.getCheckerUserId().equals(sourceAccount.getUserId())) {
            log.error("[SECURITY VIOLATION] Maker {} attempted to reject their own transfer {}",
                    checkerRequest.getCheckerUserId(), transactionId);
            throw new SegregationOfDutiesException(
                    "Maker-Checker Violation: The initiator cannot reject their own transfer.");
        }

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

    /**
     * Customer 2FA Email OTP Verification (TRX-504)
     * - Validates 6-digit OTP code dispatched via MailHog.
     * - Releases soft hold and settles debit & credit atomically.
     */
    @Transactional(transactionManager = "oracleTransactionManager")
    public Map<String, Object> verifyOtp(Map<String, Object> request) {
        String transferId = "";
        if (request.get("transfer_id") != null) transferId = request.get("transfer_id").toString();
        else if (request.get("transferId") != null) transferId = request.get("transferId").toString();
        else if (request.get("transactionId") != null) transferId = request.get("transactionId").toString();
        else if (request.get("id") != null) transferId = request.get("id").toString();

        String otp = "";
        if (request.get("otp") != null) otp = request.get("otp").toString().trim();
        else if (request.get("otpCode") != null) otp = request.get("otpCode").toString().trim();
        else if (request.get("verification_code") != null) otp = request.get("verification_code").toString().trim();
        else if (request.get("code") != null) otp = request.get("code").toString().trim();

        if (otp.length() != 6) {
            throw new IllegalArgumentException("Please enter a valid 6-digit verification code.");
        }

        String redisKey = "otp:transfer:" + transferId;
        String storedOtp = redisTemplate != null ? redisTemplate.opsForValue().get(redisKey) : null;
        log.info("[VERIFY-OTP] Validating OTP code {} for transfer ID {}. Stored in Redis: {}", otp, transferId, storedOtp);

        if (storedOtp != null && !storedOtp.isBlank()) {
            if (!storedOtp.equals(otp)) {
                log.warn("[VERIFY-OTP FAILED] Incorrect OTP for transferId={}. Expected={}, Provided={}", transferId, storedOtp, otp);
                throw new IllegalArgumentException("The verification code you entered is incorrect. Please check your email and try again.");
            }
            // Invalidate OTP immediately so it cannot be reused
            redisTemplate.delete(redisKey);
        } else {
            log.warn("[VERIFY-OTP EXPIRED] No active OTP found in Redis for transferId={}", transferId);
            throw new IllegalArgumentException("Verification code has expired or is invalid. Please request a new verification code.");
        }

        // Check if transaction exists in DB
        Optional<TransactionMaster> txOpt = transactionRepository.findById(transferId);
        if (txOpt.isPresent()) {
            TransactionMaster tx = txOpt.get();
            if ("COMMITTED".equalsIgnoreCase(tx.getStatus()) || "SETTLED".equalsIgnoreCase(tx.getStatus())) {
                return Map.of(
                        "transfer_id", transferId,
                        "status", "SETTLED",
                        "message", "Transfer has already been settled and committed to the ledger."
                );
            }

            // Settle soft hold in Oracle DB
            String sourceId = tx.getFromAccountId();
            String targetId = tx.getToAccountId();
            BigDecimal amount = tx.getAmount();

            String firstLockId = sourceId.compareTo(targetId) < 0 ? sourceId : targetId;
            String secondLockId = sourceId.compareTo(targetId) < 0 ? targetId : sourceId;

            BalanceMaster firstAccount = balanceRepository.findByAccountIdWithLock(firstLockId).orElse(null);
            BalanceMaster secondAccount = balanceRepository.findByAccountIdWithLock(secondLockId).orElse(null);

            String customerUserId = accountRepository.findById(tx.getFromAccountId())
                    .map(AccountMaster::getUserId)
                    .orElse("U1001");

            if (firstAccount != null && secondAccount != null) {
                BalanceMaster sender = sourceId.equals(firstLockId) ? firstAccount : secondAccount;
                BalanceMaster receiver = targetId.equals(firstLockId) ? firstAccount : secondAccount;

                BigDecimal senderBefore = sender.getBalanceAmount();
                BigDecimal senderAfter = senderBefore.subtract(amount);

                if (sender.getHoldAmount() != null && sender.getHoldAmount().compareTo(amount) >= 0) {
                    sender.setHoldAmount(sender.getHoldAmount().subtract(amount));
                } else {
                    sender.setHoldAmount(BigDecimal.ZERO);
                }
                sender.setBalanceAmount(senderAfter);
                sender.setAvailableBalance(senderAfter.subtract(sender.getHoldAmount()));
                sender.setUpdatedAt(Instant.now());

                receiver.setBalanceAmount(receiver.getBalanceAmount().add(amount));
                receiver.setAvailableBalance(receiver.getAvailableBalance().add(amount));
                receiver.setUpdatedAt(Instant.now());

                balanceRepository.save(sender);
                balanceRepository.save(receiver);

                tx.setStatus("COMMITTED");
                tx.setAfterBalance(senderAfter);
                tx.setApprovedByUserId(customerUserId);
                tx.setUpdatedAt(Instant.now());
                transactionRepository.save(tx);

                // Publish settled event to Transactional Outbox for Kafka relay
                try {
                    TransactionNotificationEvent settledNotif = TransactionNotificationEvent.builder()
                            .transferId(transferId)
                            .sourceAccount(sourceId)
                            .destinationAccount(targetId)
                            .userId(customerUserId)
                            .recipientEmail("juan.dc@email.com")
                            .amount(amount)
                            .currency("PHP")
                            .beforeBalance(senderBefore)
                            .afterBalance(senderAfter)
                            .status("COMMITTED")
                            .eventType("MUTATION_COMMITTED")
                            .requires2FaOtp(false)
                            .initiatorUserId(customerUserId)
                            .timestamp(Instant.now())
                            .description("Customer 2FA OTP Verified - Funds Settled")
                            .build();

                    outboxRepository.save(OutboxEventMaster.builder()
                            .eventId("EVT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                            .aggregateType("TRANSACTION")
                            .aggregateId(transferId)
                            .eventType("MUTATION_COMMITTED")
                            .kafkaTopic("banking.transfers.events")
                            .payload(objectMapper.writeValueAsString(settledNotif))
                            .status("PENDING")
                            .retryCount(0)
                            .createdAt(Instant.now())
                            .build());
                } catch (Exception ex) {
                    log.warn("[OUTBOX WARNING] Failed to persist settled outbox event: {}", ex.getMessage());
                }

                // Postgres Audit Log & Kafka Audit Stream
                LedgerMutationAudit auditLog = LedgerMutationAudit.builder()
                        .transactionId(transferId + "-OTP-VERIFIED")
                        .accountId(sourceId)
                        .mutationType("TRANSFER")
                        .mutationAmount(amount)
                        .beforeBalance(senderBefore)
                        .afterBalance(senderAfter)
                        .initiatorUserId(customerUserId)
                        .approvedByUserId(customerUserId)
                        .status("COMMITTED")
                        .createdAt(Instant.now())
                        .build();

                // Immutable Postgres Audit persistence: if Postgres is down, triggers rollback in Oracle
                auditRepository.save(auditLog);

                // 1. Kafka Audit Stream (topic: audit-events)
                try {
                    kafkaPublisher.publishAuditEvent(auditLog);
                } catch (Exception ex) {
                    log.warn("[KAFKA AUDIT WARNING] Failed to stream to audit-events: {}", ex.getMessage());
                }

                // 2. Kafka Transaction Stream (topic: transaction-events)
                try {
                    kafkaPublisher.publishTransactionEvent(TransactionEvent.builder()
                            .transactionId(transferId)
                            .sourceAccountId(sourceId)
                            .destinationAccountId(targetId)
                            .amount(amount)
                            .currency("PHP")
                            .mutationType("TRANSFER")
                            .status("COMMITTED")
                            .initiatorUserId(customerUserId)
                            .timestamp(Instant.now())
                            .build());
                } catch (Exception ex) {
                    log.warn("[KAFKA TRANSACTION WARNING] Failed to stream to transaction-events: {}", ex.getMessage());
                }

                // 3. Kafka Notification Alert (topic: notification-alerts)
                try {
                    kafkaPublisher.publishNotificationAlert(NotificationAlertEvent.builder()
                            .alertId("ALT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                            .transactionId(transferId)
                            .recipientUserId(customerUserId)
                            .recipientAccountId(sourceId)
                            .alertType("CUSTOMER_OTP_VERIFIED")
                            .amount(amount)
                            .balanceAfter(senderAfter)
                            .title("Transfer Successfully Settled")
                            .message(String.format("Transfer of PHP %s to %s has been verified via Customer 2FA OTP and settled.", amount, targetId))
                            .createdAt(Instant.now())
                            .build());
                } catch (Exception ex) {
                    log.warn("[KAFKA ALERT WARNING] Failed to stream to notification-alerts: {}", ex.getMessage());
                }
            } else {
                tx.setStatus("COMMITTED");
                tx.setApprovedByUserId(customerUserId);
                tx.setUpdatedAt(Instant.now());
                transactionRepository.save(tx);
            }
        }

        return Map.of(
                "transfer_id", transferId,
                "status", "SETTLED",
                "message", "Transfer verified successfully via Customer 2FA OTP. Funds settled."
        );
    }

    /**
     * Retrieves all immutable mutation audit records directly from PostgreSQL ledger_mutation_audit table.
     */
    @Transactional(transactionManager = "postgresTransactionManager", readOnly = true)
    public List<LedgerMutationAudit> getAuditRecords() {
        return auditRepository.findAllByOrderByAuditIdDesc();
    }
}