package com.bank.ledger.engine.service;

import com.bank.ledger.contracts.dto.CheckerActionRequest;
import com.bank.ledger.contracts.dto.MutationRequest;
import com.bank.ledger.contracts.dto.MutationResponse;
import com.bank.ledger.contracts.dto.T24FundsTransferRequest;
import com.bank.ledger.contracts.dto.T24FundsTransferResponse;
import com.bank.ledger.contracts.dto.T24ReversalRequest;
import com.bank.ledger.contracts.dto.T24ReversalResponse;
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
import com.bank.ledger.engine.entity.master.UserMaster;
import com.bank.ledger.engine.kafka.KafkaEventPublisher;
import com.bank.ledger.engine.repository.audit.LedgerMutationAuditRepository;
import com.bank.ledger.engine.repository.master.AccountMasterRepository;
import com.bank.ledger.engine.repository.master.BalanceMasterRepository;
import com.bank.ledger.engine.repository.master.OutboxEventMasterRepository;
import com.bank.ledger.engine.repository.master.TransactionMasterRepository;
import com.bank.ledger.engine.repository.master.UserMasterRepository;
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
    private final UserMasterRepository userMasterRepository;
    private final LedgerMutationAuditRepository auditRepository;
    private final KafkaEventPublisher kafkaPublisher;
     private final OutboxEventMasterRepository outboxRepository; 
    private final ObjectMapper objectMapper;
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private org.springframework.data.redis.core.StringRedisTemplate redisTemplate;
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private RiskEngineClient riskEngineClient;
    @jakarta.persistence.PersistenceContext(unitName = "oracleMasterUnit")
    private jakarta.persistence.EntityManager entityManager;

    @Value("${app.maker-checker.threshold:50000.0000}")
    private BigDecimal makerCheckerThreshold;

    /**
     * Executes funds transfer with threshold routing:
     * - If amount <= threshold: Immediate atomic dual-account settlement.
     * - If amount > threshold: Soft hold placed, marked PENDING_APPROVAL for Teller review.
     */
    @Transactional(transactionManager = "oracleTransactionManager")
    public MutationResponse executeTransfer(MutationRequest request) {
        String sourceId = resolveInternalAccountId(request.getAccountId(), request.getInitiatorUserId());
        String targetId = resolveOrProvisionTargetAccountId(request.getTargetAccountId());
        request.setAccountId(sourceId);
        request.setTargetAccountId(targetId);
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
        if (entityManager != null) {
            entityManager.refresh(firstAccount);
        }
        BalanceMaster secondAccount = balanceRepository.findByAccountIdWithLock(secondLockId)
                .orElseThrow(() -> new IllegalArgumentException("Account not found: " + secondLockId));
        if (entityManager != null) {
            entityManager.refresh(secondAccount);
        }

        BalanceMaster sender = sourceId.equals(firstLockId) ? firstAccount : secondAccount;
        BalanceMaster receiver = targetId.equals(firstLockId) ? firstAccount : secondAccount;

        // =========================================================================
        // STEP 2: AVAILABLE BALANCE FINANCIAL SANITY CHECK
        // =========================================================================
        BigDecimal hold = sender.getHoldAmount() != null ? sender.getHoldAmount() : BigDecimal.ZERO;
        BigDecimal spendableBalance = sender.getBalanceAmount().subtract(hold);
        if (spendableBalance.compareTo(BigDecimal.ZERO) < 0) {
            spendableBalance = BigDecimal.ZERO;
        }
        BigDecimal effectiveAvailable = sender.getAvailableBalance() != null 
                ? sender.getAvailableBalance().min(spendableBalance) 
                : spendableBalance;

        if (effectiveAvailable.compareTo(amount) < 0) {
            log.error("[MUTATION REJECTED] Insufficient funds: Account {} available PHP {} (balance: {}, hold: {}), requested PHP {}",
                    sourceId, effectiveAvailable, sender.getBalanceAmount(), hold, amount);
            throw new InsufficientFundsException(
                    String.format("Insufficient funds in account %s. Available: PHP %s, Requested: PHP %s",
                            sourceId, effectiveAvailable, amount));
        }

        BigDecimal senderBefore = sender.getBalanceAmount();

        // =========================================================================
        // GEO-VELOCITY & IMPOSSIBLE TRAVEL RULES
        // =========================================================================
        String checkUserId = request.getInitiatorUserId() != null ? request.getInitiatorUserId() : "U1001";
        String effectiveUserId = "U1001".equalsIgnoreCase(checkUserId) ? "usr-1001-cst-001" : checkUserId;
        UserMaster userGeo = userMasterRepository != null
                ? userMasterRepository.findById(effectiveUserId)
                        .or(() -> userMasterRepository.findById(checkUserId))
                        .orElse(null)
                : null;

        // Where the customer is now: device GPS when the client sends it, otherwise
        // the last known location (device telemetry, or the admin geo simulator).
        double curLat = request.getLatitude() != null ? request.getLatitude()
                : userGeo != null && userGeo.getLastKnownLatitude() != null ? userGeo.getLastKnownLatitude() : 14.5995;
        double curLon = request.getLongitude() != null ? request.getLongitude()
                : userGeo != null && userGeo.getLastKnownLongitude() != null ? userGeo.getLastKnownLongitude() : 120.9842;
        String curPlace = request.getLatitude() == null && userGeo != null && userGeo.getLastKnownLocationName() != null
                ? userGeo.getLastKnownLocationName() : null;
        if (request.getIpAddress() == null && userGeo != null) request.setIpAddress(userGeo.getLastKnownIp());
        request.setLatitude(curLat);
        request.setLongitude(curLon);

        Optional<TransactionMaster> previous = transactionRepository
                .findTopByFromAccountIdAndLatitudeIsNotNullOrderByCreatedAtDesc(sourceId);
        GeoVelocity.Result geo = previous
                .map(p -> GeoVelocity.assess(p.getLatitude().doubleValue(), p.getLongitude().doubleValue(),
                        p.getCreatedAt(), curLat, curLon, Instant.now()))
                .orElse(GeoVelocity.Result.NONE);
        String geoReason = null;
        if (geo.impossible()) {
            String from = previous.get().getLocationName() != null ? previous.get().getLocationName() : "previous location";
            geoReason = String.format("IMPOSSIBLE_TRAVEL: %s to %s, %,.0f km in %.0f min (%,.0f km/h)",
                    from, curPlace != null ? curPlace : "current location", geo.distanceKm(), geo.minutes(), geo.speedKmh());
            log.warn("[GEO-VELOCITY ALERT] {} for user {} on {}", geoReason, checkUserId, request.getTransactionId());
        }

        // =========================================================================
        // NANOJEV SYSTEM 1 RISK & ANOMALY EVALUATION
        // =========================================================================
        Map<String, Object> geoContext = new java.util.HashMap<>();
        previous.ifPresent(p -> {
            geoContext.put("previous_latitude", p.getLatitude().doubleValue());
            geoContext.put("previous_longitude", p.getLongitude().doubleValue());
            geoContext.put("previous_timestamp", p.getCreatedAt().toString());
        });
        RiskEngineClient.RiskEvaluationResult riskResult = riskEngineClient != null
                ? riskEngineClient.evaluateRisk(request, geoContext)
                : RiskEngineClient.RiskEvaluationResult.builder().decision("ALLOW").build();

        // A geo-velocity hit is held for a human, not blocked: the customer may
        // simply be travelling. Other BLOCK verdicts (malware, tampering) still stop here.
        if (geoReason == null && "BLOCK".equalsIgnoreCase(riskResult.getDecision())) {
            log.error("[MUTATION BLOCKED] NanoJev flagged high risk for TxId: {} (Score: {}, Flag: {}, ThreatCat: {}, Cause: {}, SAR: {})",
                    request.getTransactionId(), riskResult.getFraudScore(), riskResult.getPrimaryFlag(),
                    riskResult.getThreatCategory(), riskResult.getCauseOfSuspicion(), riskResult.getSarReportId());
            throw new SecurityException("Transaction blocked by security risk engine: " + riskResult.getPrimaryFlag()
                    + (riskResult.getCauseOfSuspicion() != null ? " (" + riskResult.getCauseOfSuspicion() + ")" : ""));
        }

        BigDecimal riskScore = BigDecimal.valueOf(geoReason != null ? Math.max(riskResult.getFraudScore(), 95) : riskResult.getFraudScore());
        String riskReason = geoReason != null ? geoReason
                : riskResult.getPrimaryFlag() != null && !"NORMAL_TRANSACTION".equals(riskResult.getPrimaryFlag())
                        ? riskResult.getPrimaryFlag() : null;

        // =========================================================================
        // ROUTE 0: IMPOSSIBLE TRAVEL -> SOFT HOLD FOR COMPLIANCE REVIEW (no customer OTP)
        // =========================================================================
        if (geoReason != null) {
            sender.setHoldAmount(sender.getHoldAmount().add(amount));
            sender.setAvailableBalance(sender.getAvailableBalance().subtract(amount));
            sender.setUpdatedAt(Instant.now());
            balanceRepository.save(sender);

            transactionRepository.save(TransactionMaster.builder()
                    .transactionId(request.getTransactionId())
                    .fromAccountId(sourceId)
                    .toAccountId(targetId)
                    .type("TRANSFER")
                    .amount(amount)
                    .beforeBalance(senderBefore)
                    .afterBalance(senderBefore)
                    .status("PENDING_APPROVAL")
                    .requires2FaOtp(0)
                    .latitude(BigDecimal.valueOf(curLat))
                    .longitude(BigDecimal.valueOf(curLon))
                    .locationName(curPlace)
                    .ipAddress(request.getIpAddress())
                    .riskScore(riskScore)
                    .riskReason(geoReason.length() > 255 ? geoReason.substring(0, 255) : geoReason)
                    .createdAt(Instant.now())
                    .updatedAt(Instant.now())
                    .build());

            kafkaPublisher.publishNotificationAlert(NotificationAlertEvent.builder()
                    .alertId("ALT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                    .transactionId(request.getTransactionId())
                    .recipientUserId(request.getInitiatorUserId())
                    .recipientAccountId(sourceId)
                    .alertType("TRANSFER_HELD_FOR_REVIEW")
                    .amount(amount)
                    .balanceAfter(sender.getAvailableBalance())
                    .title("Transfer held for review")
                    .message(String.format("Your transfer of PHP %s is on hold because it came from an unusual location. Our team will review it shortly.", amount))
                    .createdAt(Instant.now())
                    .build());

            String ref = generateT24Reference(request.getTransactionId());
            return MutationResponse.builder()
                    .transactionId(request.getTransactionId())
                    .accountId(sourceId)
                    .status("PENDING_REVIEW")
                    .mutationAmount(amount)
                    .balanceBefore(senderBefore)
                    .balanceAfter(senderBefore)
                    .availableBalance(sender.getAvailableBalance())
                    .timestamp(Instant.now())
                    .traceId(UUID.randomUUID().toString())
                    .t24Reference(ref)
                    .ofsResponse(String.format("%s//1/PENDING_REVIEW", ref))
                    .riskDecision("REVIEW")
                    .riskScore(riskScore.intValue())
                    .warningTitle("Transfer held for review")
                    .warningMessage("This transfer came from a location that does not match your recent activity. A compliance officer will review it.")
                    .threatCategory("IMPOSSIBLE_TRAVEL")
                    .causeOfSuspicion(geoReason)
                    .sarDraftCreated(riskResult.isSarDraftCreated())
                    .sarReportId(riskResult.getSarReportId())
                    .message("Transfer soft held pending compliance review.")
                    .build();
        }

        // Check ADVISORY_WARNING
        boolean isAdvisoryWarning = "ADVISORY_WARNING".equalsIgnoreCase(riskResult.getDecision());
        boolean advisoryAcknowledged = Boolean.TRUE.equals(request.getScamAdvisoryAcknowledged());

        if (isAdvisoryWarning && !advisoryAcknowledged) {
            log.info("[ADVISORY_WARNING TRIGGERED] Transfer of PHP {} triggered {} warning ({}). Returning cooling-off requirement.",
                    amount, riskResult.getThreatCategory(), riskResult.getWarningTitle());

            return MutationResponse.builder()
                    .transactionId(request.getTransactionId())
                    .accountId(sourceId)
                    .status("ADVISORY_WARNING")
                    .mutationAmount(amount)
                    .balanceBefore(senderBefore)
                    .balanceAfter(senderBefore)
                    .availableBalance(sender.getAvailableBalance())
                    .timestamp(Instant.now())
                    .processedAt(Instant.now())
                    .traceId(UUID.randomUUID().toString())
                    .riskDecision("ADVISORY_WARNING")
                    .riskScore(riskResult.getFraudScore())
                    .warningTitle(riskResult.getWarningTitle())
                    .warningMessage(riskResult.getWarningMessage())
                    .threatCategory(riskResult.getThreatCategory())
                    .causeOfSuspicion(riskResult.getCauseOfSuspicion())
                    .sarDraftCreated(riskResult.isSarDraftCreated())
                    .sarReportId(riskResult.getSarReportId())
                    .coolingOffRequired(true)
                    .coolingOffExpiresInSeconds(600)
                    .biometricRequired(true)
                    .message(riskResult.getWarningMessage() != null ? riskResult.getWarningMessage() : "Advisory warning triggered. 10-minute hold or acknowledgment required.")
                    .build();
        }

        boolean isHighValue = amount.compareTo(makerCheckerThreshold) > 0;
        boolean requires2Fa = isHighValue || "REQUIRE_2FA".equalsIgnoreCase(riskResult.getDecision());

        // =========================================================================
        // ROUTE A: HIGH-VALUE OR HIGH-RISK TRANSACTION -> SOFT HOLD & 2FA OTP (TRX-501)
        // =========================================================================
        if (requires2Fa) {
            log.info("[2FA / REVIEW TRIGGERED] Transfer of PHP {} (isHighValue={}, risk={}). Placing soft hold.",
                    amount, isHighValue, riskResult.getDecision());

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
                    .latitude(BigDecimal.valueOf(curLat))
                    .longitude(BigDecimal.valueOf(curLon))
                    .locationName(curPlace)
                    .ipAddress(request.getIpAddress())
                    .riskScore(riskScore)
                    .riskReason(riskReason)
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
                        .otpCode(generatedOtp)
                        .initiatorUserId(request.getInitiatorUserId() != null ? request.getInitiatorUserId() : "U1001")
                        .timestamp(Instant.now())
                        .description("Customer 2FA Email OTP Verification Required: [ " + generatedOtp + " ]")
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

            String t24RefA = generateT24Reference(request.getTransactionId());
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
                    .t24Reference(t24RefA)
                    .ofsResponse(String.format("%s//1/PENDING_APPROVAL", t24RefA))
                    .riskDecision(riskResult.getDecision())
                    .riskScore(riskResult.getFraudScore())
                    .warningTitle(riskResult.getWarningTitle())
                    .warningMessage(riskResult.getWarningMessage())
                    .threatCategory(riskResult.getThreatCategory())
                    .causeOfSuspicion(riskResult.getCauseOfSuspicion())
                    .sarDraftCreated(riskResult.isSarDraftCreated())
                    .sarReportId(riskResult.getSarReportId())
                    .message("Transfer soft held pending customer 2FA OTP verification.")
                    .build();
        }

        // =========================================================================
        // ROUTE B: NORMAL TRANSFER -> IMMEDIATE ATOMIC SETTLEMENT
        // =========================================================================
        BigDecimal senderAfter = senderBefore.subtract(amount);
        BigDecimal receiverBefore = receiver.getBalanceAmount();
        BigDecimal receiverAfter = receiverBefore.add(amount);

        sender.setBalanceAmount(senderAfter);
        sender.setAvailableBalance(senderAfter.subtract(hold).max(BigDecimal.ZERO));
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
                .latitude(BigDecimal.valueOf(curLat))
                .longitude(BigDecimal.valueOf(curLon))
                .locationName(curPlace)
                .ipAddress(request.getIpAddress())
                .riskScore(riskScore)
                .riskReason(riskReason)
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

        LedgerMutationAudit auditCredit = LedgerMutationAudit.builder()
                .transactionId(request.getTransactionId() + "-CR")
                .accountId(targetId)
                .mutationType("TRANSFER")
                .mutationAmount(amount)
                .beforeBalance(receiverBefore)
                .afterBalance(receiverAfter)
                .initiatorUserId(request.getInitiatorUserId())
                .approvedByUserId(request.getApprovedByUserId())
                .status("COMMITTED")
                .createdAt(Instant.now())
                .build();
        auditRepository.save(auditCredit);

        try {
            kafkaPublisher.publishAuditEvent(audit);
            kafkaPublisher.publishAuditEvent(auditCredit);
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

        String t24RefB = generateT24Reference(request.getTransactionId());
        String ofsResponseB = String.format("%s//1/COMMITTED", t24RefB);

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
                .t24Reference(t24RefB)
                .ofsResponse(ofsResponseB)
                .riskDecision(riskResult.getDecision())
                .riskScore(riskResult.getFraudScore())
                .warningTitle(riskResult.getWarningTitle())
                .warningMessage(riskResult.getWarningMessage())
                .threatCategory(riskResult.getThreatCategory())
                .causeOfSuspicion(riskResult.getCauseOfSuspicion())
                .sarDraftCreated(riskResult.isSarDraftCreated())
                .sarReportId(riskResult.getSarReportId())
                .message("Funds transfer committed successfully via Temenos T24 CBS: " + t24RefB)
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

        // A held transfer must still have its reservation; fail before the Postgres audit and Kafka writes below.
        if (sender.getHoldAmount().compareTo(tx.getAmount()) < 0) {
            throw new IllegalStateException("Hold for " + transactionId + " is missing on " + sourceId
                    + " (held " + sender.getHoldAmount() + ", needs " + tx.getAmount() + "). Reconcile the ledger before releasing.");
        }

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
        // shortcut: holds are per account, not per transfer; release at most what is still held. Upgrade with per-transfer holds.
        BigDecimal release = sender.getHoldAmount().min(amount);
        sender.setHoldAmount(sender.getHoldAmount().subtract(release));
        sender.setAvailableBalance(sender.getAvailableBalance().add(release));
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
    @Transactional(transactionManager = "oracleTransactionManager", readOnly = true)
    public List<TransactionMaster> getAllTransactions() {
        return transactionRepository.findAllByOrderByCreatedAtDesc();
    }

    /**
     * T24 Compensating Reversal of a Transfer (Compensating Double-Entry Transaction)
     */
    @Transactional(transactionManager = "oracleTransactionManager")
    public MutationResponse reverseTransfer(String transactionId, Map<String, Object> reversalRequest) {
        log.info("[REVERSAL START] Reversing transaction {}", transactionId);

        TransactionMaster tx = transactionRepository.findById(transactionId)
                .orElseThrow(() -> new IllegalArgumentException("Transaction not found: " + transactionId));

        if ("REVERSED".equalsIgnoreCase(tx.getStatus())) {
            throw new IllegalStateException("Transaction " + transactionId + " is already reversed.");
        }

        String reversingAdmin = reversalRequest != null && reversalRequest.get("reversed_by_user_id") != null
                ? String.valueOf(reversalRequest.get("reversed_by_user_id"))
                : (reversalRequest != null && reversalRequest.get("admin_id") != null
                        ? String.valueOf(reversalRequest.get("admin_id"))
                        : "usr-1004-adm-001");

        String approverAdmin = reversalRequest != null && reversalRequest.get("approved_by_admin_id") != null
                ? String.valueOf(reversalRequest.get("approved_by_admin_id"))
                : reversingAdmin;

        String reason = reversalRequest != null && reversalRequest.get("reason") != null
                ? String.valueOf(reversalRequest.get("reason"))
                : "CUSTOMER_DISPUTE_WRONG_ACCOUNT";

        String memo = reversalRequest != null && reversalRequest.get("memo") != null
                ? String.valueOf(reversalRequest.get("memo"))
                : "Reversal authorized by Operations Admin";

        String sourceId = tx.getFromAccountId();
        String targetId = tx.getToAccountId();
        BigDecimal amount = tx.getAmount();

        if ("COMMITTED".equalsIgnoreCase(tx.getStatus()) || "POSTED".equalsIgnoreCase(tx.getStatus())) {
            // Deterministic lock ordering to prevent deadlocks
            String firstLockId = sourceId.compareTo(targetId) < 0 ? sourceId : targetId;
            String secondLockId = sourceId.compareTo(targetId) < 0 ? targetId : sourceId;

            BalanceMaster firstAccount = balanceRepository.findByAccountIdWithLock(firstLockId)
                    .orElseThrow(() -> new IllegalArgumentException("Account not found: " + firstLockId));
            BalanceMaster secondAccount = balanceRepository.findByAccountIdWithLock(secondLockId)
                    .orElseThrow(() -> new IllegalArgumentException("Account not found: " + secondLockId));

            BalanceMaster sender = sourceId.equals(firstLockId) ? firstAccount : secondAccount;
            BalanceMaster receiver = targetId.equals(firstLockId) ? firstAccount : secondAccount;

            // Debit destination account, restore source account
            sender.setBalanceAmount(sender.getBalanceAmount().add(amount));
            sender.setAvailableBalance(sender.getAvailableBalance().add(amount));
            sender.setUpdatedAt(Instant.now());

            receiver.setBalanceAmount(receiver.getBalanceAmount().subtract(amount));
            receiver.setAvailableBalance(receiver.getAvailableBalance().subtract(amount));
            receiver.setUpdatedAt(Instant.now());

            balanceRepository.save(sender);
            balanceRepository.save(receiver);

            // Mark original transaction as REVERSED with audit attribution
            tx.setStatus("REVERSED");
            tx.setReversedByUserId(reversingAdmin);
            tx.setReversalReason(reason);
            tx.setReversalMemo(memo);
            tx.setUpdatedAt(Instant.now());
            transactionRepository.save(tx);

            // Post compensating contra-entry (T24 Core Banking standard)
            String revTxId = tx.getTransactionId() + "-REV";
            TransactionMaster contraEntry = TransactionMaster.builder()
                    .transactionId(revTxId)
                    .fromAccountId(targetId)
                    .toAccountId(sourceId)
                    .type("TRANSFER")
                    .amount(amount)
                    .beforeBalance(receiver.getBalanceAmount().add(amount))
                    .afterBalance(receiver.getBalanceAmount())
                    .status("COMMITTED")
                    .requires2FaOtp(0)
                    .approvedByUserId(approverAdmin)
                    .reversedByUserId(reversingAdmin)
                    .reversalReason(reason)
                    .reversalMemo(memo)
                    .createdAt(Instant.now())
                    .updatedAt(Instant.now())
                    .build();
            transactionRepository.save(contraEntry);

            // Write immutable audit log to PostgreSQL audit vault
            try {
                auditRepository.save(LedgerMutationAudit.builder()
                        .transactionId(revTxId)
                        .accountId(sourceId)
                        .mutationType("TRANSFER")
                        .mutationAmount(amount)
                        .beforeBalance(sender.getBalanceAmount().subtract(amount))
                        .afterBalance(sender.getBalanceAmount())
                        .initiatorUserId(reversingAdmin)
                        .approvedByUserId(approverAdmin)
                        .reversedByUserId(reversingAdmin)
                        .reversalReason(reason)
                        .status("ROLLED_BACK")
                        .createdAt(Instant.now())
                        .build());
            } catch (Exception ex) {
                log.warn("[AUDIT VAULT] Failed to write reversal audit record: {}", ex.getMessage());
            }

            return MutationResponse.builder()
                    .transactionId(tx.getTransactionId())
                    .accountId(sourceId)
                    .status("REVERSED")
                    .mutationAmount(amount)
                    .balanceBefore(sender.getBalanceAmount().subtract(amount))
                    .balanceAfter(sender.getBalanceAmount())
                    .availableBalance(sender.getAvailableBalance())
                    .timestamp(Instant.now())
                    .traceId(UUID.randomUUID().toString())
                    .build();

        } else if ("PENDING_APPROVAL".equalsIgnoreCase(tx.getStatus())) {
            // Release soft hold on sender
            BalanceMaster sender = balanceRepository.findByAccountIdWithLock(sourceId)
                    .orElseThrow(() -> new IllegalArgumentException("Source account not found: " + sourceId));

            sender.setHoldAmount(sender.getHoldAmount().subtract(amount));
            sender.setAvailableBalance(sender.getAvailableBalance().add(amount));
            sender.setUpdatedAt(Instant.now());
            balanceRepository.save(sender);

            tx.setStatus("CANCELLED");
            tx.setUpdatedAt(Instant.now());
            transactionRepository.save(tx);

            return MutationResponse.builder()
                    .transactionId(tx.getTransactionId())
                    .accountId(sourceId)
                    .status("CANCELLED")
                    .mutationAmount(amount)
                    .balanceBefore(sender.getBalanceAmount())
                    .balanceAfter(sender.getBalanceAmount())
                    .availableBalance(sender.getAvailableBalance())
                    .timestamp(Instant.now())
                    .traceId(UUID.randomUUID().toString())
                    .build();
        } else {
            throw new IllegalStateException("Cannot reverse transaction with status: " + tx.getStatus());
        }
    }

    /**
     * Updates Customer Geolocation in Oracle XE Master USERS Table
     */
    @Transactional(transactionManager = "oracleTransactionManager")
    public Map<String, Object> updateUserLocation(String userId, Map<String, Object> locationPayload) {
        log.info("[GEO UPDATE] User {}: {}", userId, locationPayload);

        String effectiveId = userId;
        if ("U1001".equalsIgnoreCase(userId)) effectiveId = "usr-1001-cst-001";
        if ("U1002".equalsIgnoreCase(userId)) effectiveId = "usr-1002-cst-002";

        final String searchId = effectiveId;
        UserMaster user = userMasterRepository != null
                ? userMasterRepository.findById(searchId)
                        .or(() -> userMasterRepository.findById(userId))
                        .orElse(null)
                : null;

        if (user != null) {
            if (locationPayload.containsKey("latitude")) {
                user.setLastKnownLatitude(Double.valueOf(String.valueOf(locationPayload.get("latitude"))));
            }
            if (locationPayload.containsKey("longitude")) {
                user.setLastKnownLongitude(Double.valueOf(String.valueOf(locationPayload.get("longitude"))));
            }
            if (locationPayload.containsKey("location_name")) {
                user.setLastKnownLocationName(String.valueOf(locationPayload.get("location_name")));
            }
            if (locationPayload.containsKey("ip_address")) {
                user.setLastKnownIp(String.valueOf(locationPayload.get("ip_address")));
            }
            user.setLastGeoUpdatedAt(Instant.now());
            user.setUpdatedAt(Instant.now());
            userMasterRepository.save(user);

            log.info("[GEO UPDATE COMPLETE] Successfully updated Oracle user {}: location={}, lat={}, lon={}",
                    user.getUserId(), user.getLastKnownLocationName(), user.getLastKnownLatitude(), user.getLastKnownLongitude());
        } else {
            log.warn("[GEO UPDATE WARNING] User {} not found in Oracle USERS table", userId);
        }

        return Map.of(
                "status", "SUCCESS",
                "user_id", userId,
                "location", locationPayload,
                "timestamp", Instant.now()
        );
    }

    /**
     * Query User Location from Oracle XE Master
     */
    @Transactional(transactionManager = "oracleTransactionManager", readOnly = true)
    public Map<String, Object> getUserLocation(String userId) {
        String effectiveId = userId;
        if ("U1001".equalsIgnoreCase(userId)) effectiveId = "usr-1001-cst-001";
        if ("U1002".equalsIgnoreCase(userId)) effectiveId = "usr-1002-cst-002";

        final String searchId = effectiveId;
        UserMaster user = userMasterRepository != null
                ? userMasterRepository.findById(searchId)
                        .or(() -> userMasterRepository.findById(userId))
                        .orElse(null)
                : null;

        if (user == null) {
            return Map.of("user_id", userId, "status", "NOT_FOUND");
        }

        return Map.of(
                "user_id", user.getUserId(),
                "first_name", user.getFirstName(),
                "last_name", user.getLastName(),
                "location_name", user.getLastKnownLocationName() != null ? user.getLastKnownLocationName() : "Manila, Philippines",
                "latitude", user.getLastKnownLatitude() != null ? user.getLastKnownLatitude() : 14.5995,
                "longitude", user.getLastKnownLongitude() != null ? user.getLastKnownLongitude() : 120.9842,
                "ip_address", user.getLastKnownIp() != null ? user.getLastKnownIp() : "112.198.45.10"
        );
    }

    /**
     * T24 Core Banking Funds Transfer API (FUNDS.TRANSFER)
     * Executes atomic dual-account settlement following Temenos Transact core banking protocol.
     */
    @Transactional(transactionManager = "oracleTransactionManager")
    public T24FundsTransferResponse executeT24FundsTransfer(T24FundsTransferRequest request) {
        if (request.getOfsMessage() != null && !request.getOfsMessage().isBlank()) {
            parseOfsTransferMessage(request.getOfsMessage(), request);
        }

        String txId = request.getTransactionReference();
        if (txId == null || txId.isBlank()) {
            txId = "FT" + java.time.LocalDate.now().format(java.time.format.DateTimeFormatter.ofPattern("yyMMdd"))
                    + UUID.randomUUID().toString().substring(0, 6).toUpperCase();
            request.setTransactionReference(txId);
        }

        log.info("[T24 FUNDS.TRANSFER] Ref: {}, Debit: {}, Credit: {}, Amount: PHP {}",
                txId, request.getDebitAccountId(), request.getCreditAccountId(), request.getAmount());

        MutationRequest mutationReq = MutationRequest.builder()
                .transactionId(txId)
                .accountId(request.getDebitAccountId())
                .targetAccountId(request.getCreditAccountId())
                .mutationAmount(request.getAmount())
                .initiatorUserId(request.getCustomerId() != null ? request.getCustomerId() : "T24-USER")
                .memo(request.getPaymentDetails() != null ? request.getPaymentDetails() : "T24 Funds Transfer")
                .eventType(com.bank.ledger.contracts.enums.EventType.TRANSFER)
                .mutationType(com.bank.ledger.contracts.enums.MutationType.TRANSFER)
                .build();

        MutationResponse res = executeTransfer(mutationReq);

        BigDecimal debitBalAfter = res.getBalanceAfter();
        BigDecimal creditBalAfter = BigDecimal.ZERO;
        Optional<BalanceMaster> creditAcc = balanceRepository.findByAccountId(request.getCreditAccountId());
        if (creditAcc.isPresent()) {
            creditBalAfter = creditAcc.get().getBalanceAmount();
        }

        String ofsResponse = String.format("%s//1/%s", txId, res.getStatus());

        return T24FundsTransferResponse.builder()
                .t24Reference(txId)
                .status(res.getStatus())
                .debitAccountId(request.getDebitAccountId())
                .debitAmount(request.getAmount())
                .debitBalanceAfter(debitBalAfter)
                .creditAccountId(request.getCreditAccountId())
                .creditAmount(request.getAmount())
                .creditBalanceAfter(creditBalAfter)
                .currency(request.getCurrency() != null ? request.getCurrency() : "PHP")
                .valueDate(request.getValueDate() != null ? request.getValueDate() : java.time.LocalDate.now().toString())
                .ofsResponse(ofsResponse)
                .timestamp(Instant.now())
                .message("T24 Funds Transfer executed successfully: " + res.getStatus())
                .build();
    }

    /**
     * T24 Core Banking Transaction Reversal API (FUNDS.TRANSFER,REVERSE)
     * Reverses a previously settled transfer via compensating double-entry mutation.
     */
    @Transactional(transactionManager = "oracleTransactionManager")
    public T24ReversalResponse executeT24Reversal(T24ReversalRequest request) {
        if (request.getOfsMessage() != null && !request.getOfsMessage().isBlank()) {
            parseOfsReversalMessage(request.getOfsMessage(), request);
        }

        String originalTxId = request.getOriginalTransactionId();
        if (originalTxId == null || originalTxId.isBlank()) {
            throw new IllegalArgumentException("Original transaction ID is required for T24 reversal.");
        }

        log.info("[T24 REVERSAL START] OriginalTxId: {}, Reason: {}, Checker: {}",
                originalTxId, request.getReversalReason(), request.getCheckerId());

        TransactionMaster originalTx = transactionRepository.findById(originalTxId)
                .orElseThrow(() -> new IllegalArgumentException("Original transaction not found: " + originalTxId));

        if ("REVERSED".equalsIgnoreCase(originalTx.getStatus())) {
            throw new IllegalStateException("Transaction " + originalTxId + " has already been reversed.");
        }

        if (!"COMMITTED".equalsIgnoreCase(originalTx.getStatus()) && !"POSTED".equalsIgnoreCase(originalTx.getStatus()) && !"SETTLED".equalsIgnoreCase(originalTx.getStatus())) {
            throw new IllegalStateException("Cannot reverse transaction in status '" + originalTx.getStatus() + "'. Only settled transactions can be reversed.");
        }

        String originalSenderId = originalTx.getFromAccountId();
        String originalReceiverId = originalTx.getToAccountId();
        BigDecimal amount = originalTx.getAmount();

        if (originalReceiverId == null || originalReceiverId.isBlank()) {
            throw new IllegalStateException("Original transaction " + originalTxId + " does not have a destination account to debit for reversal.");
        }

        // 1. Deterministic Lock Ordering
        String firstLockId = originalSenderId.compareTo(originalReceiverId) < 0 ? originalSenderId : originalReceiverId;
        String secondLockId = originalSenderId.compareTo(originalReceiverId) < 0 ? originalReceiverId : originalSenderId;

        BalanceMaster firstAccount = balanceRepository.findByAccountIdWithLock(firstLockId)
                .orElseThrow(() -> new IllegalArgumentException("Account not found: " + firstLockId));
        BalanceMaster secondAccount = balanceRepository.findByAccountIdWithLock(secondLockId)
                .orElseThrow(() -> new IllegalArgumentException("Account not found: " + secondLockId));

        BalanceMaster originalSender = originalSenderId.equals(firstLockId) ? firstAccount : secondAccount;
        BalanceMaster originalReceiver = originalReceiverId.equals(firstLockId) ? firstAccount : secondAccount;

        // 2. Solvency check on beneficiary account
        if (originalReceiver.getAvailableBalance().compareTo(amount) < 0) {
            log.error("[T24 REVERSAL REJECTED] Beneficiary account {} has insufficient funds (PHP {}) to reverse PHP {}",
                    originalReceiverId, originalReceiver.getAvailableBalance(), amount);
            throw new InsufficientFundsException(String.format(
                    "Beneficiary account %s has insufficient funds to reverse transfer. Available: PHP %s, Reversal Amount: PHP %s",
                    originalReceiverId, originalReceiver.getAvailableBalance(), amount));
        }

        // 3. Compensating Double-Entry Mutation (Debit recipient back, Credit sender back)
        BigDecimal receiverBefore = originalReceiver.getBalanceAmount();
        BigDecimal receiverAfter = receiverBefore.subtract(amount);
        originalReceiver.setBalanceAmount(receiverAfter);
        originalReceiver.setAvailableBalance(originalReceiver.getAvailableBalance().subtract(amount));
        originalReceiver.setUpdatedAt(Instant.now());

        BigDecimal senderBefore = originalSender.getBalanceAmount();
        BigDecimal senderAfter = senderBefore.add(amount);
        originalSender.setBalanceAmount(senderAfter);
        originalSender.setAvailableBalance(originalSender.getAvailableBalance().add(amount));
        originalSender.setUpdatedAt(Instant.now());

        balanceRepository.save(originalReceiver);
        balanceRepository.save(originalSender);

        // Update original transaction status
        originalTx.setStatus("REVERSED");
        originalTx.setUpdatedAt(Instant.now());
        transactionRepository.save(originalTx);

        // Record compensating reversal transaction
        String reversalRef = "REV-" + originalTxId + "-" + UUID.randomUUID().toString().substring(0, 6).toUpperCase();
        // Validate approvedBy against user directory to preserve FK constraint
        String checkerId = request.getCheckerId();
        String approvedBy = null;
        if (checkerId != null && !checkerId.isBlank()) {
            if (accountRepository.existsByUserId(checkerId)
                    || "usr-1003-tel-001".equals(checkerId)
                    || "usr-1004-adm-001".equals(checkerId)
                    || "U1001".equals(checkerId)) {
                approvedBy = checkerId;
            }
        }

        TransactionMaster reversalTx = TransactionMaster.builder()
                .transactionId(reversalRef)
                .fromAccountId(originalReceiverId) // debited back
                .toAccountId(originalSenderId)     // credited back
                .type("REVERSAL")
                .amount(amount)
                .beforeBalance(receiverBefore)
                .afterBalance(receiverAfter)
                .status("COMMITTED")
                .requires2FaOtp(0)
                .approvedByUserId(approvedBy)
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();
        transactionRepository.save(reversalTx);

        // 4. Immutable PostgreSQL Audit Vault
        LedgerMutationAudit audit = LedgerMutationAudit.builder()
                .transactionId(reversalRef)
                .accountId(originalReceiverId)
                .mutationType("REVERSAL")
                .mutationAmount(amount)
                .beforeBalance(receiverBefore)
                .afterBalance(receiverAfter)
                .initiatorUserId(request.getMakerId() != null ? request.getMakerId() : "T24-OPERATOR")
                .approvedByUserId(request.getCheckerId())
                .status("COMMITTED")
                .createdAt(Instant.now())
                .build();
        auditRepository.save(audit);

        try {
            kafkaPublisher.publishAuditEvent(audit);
        } catch (Exception ex) {
            log.warn("[KAFKA AUDIT WARNING] Failed to stream reversal audit: {}", ex.getMessage());
        }

        try {
            TransactionEvent event = TransactionEvent.builder()
                    .transactionId(reversalRef)
                    .sourceAccountId(originalReceiverId)
                    .destinationAccountId(originalSenderId)
                    .amount(amount)
                    .currency("PHP")
                    .mutationType("REVERSAL")
                    .status("COMMITTED")
                    .initiatorUserId(request.getMakerId() != null ? request.getMakerId() : "T24-OPERATOR")
                    .timestamp(Instant.now())
                    .build();

            outboxRepository.save(OutboxEventMaster.builder()
                    .eventId("EVT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                    .aggregateType("TRANSACTION")
                    .aggregateId(reversalRef)
                    .eventType("TRANSFER_REVERSED")
                    .kafkaTopic("transaction-events")
                    .payload(objectMapper.writeValueAsString(event))
                    .status("PENDING")
                    .retryCount(0)
                    .createdAt(Instant.now())
                    .build());
        } catch (Exception e) {
            log.error("[OUTBOX ERROR] Failed to record reversal in outbox", e);
        }

        String ofsResponse = String.format("%s//1/REVERSED,REV.REF=%s", originalTxId, reversalRef);

        log.info("[T24 REVERSAL COMPLETED] Original: {}, ReversalRef: {}, Amount: PHP {}, Debited: {}, Credited: {}",
                originalTxId, reversalRef, amount, originalReceiverId, originalSenderId);

        return T24ReversalResponse.builder()
                .reversalReference(reversalRef)
                .originalTransactionId(originalTxId)
                .status("REVERSED")
                .reversalReason(request.getReversalReason() != null ? request.getReversalReason() : "ADMIN_REVERSAL")
                .amount(amount)
                .debitedAccountId(originalReceiverId)
                .debitedBalanceAfter(receiverAfter)
                .creditedAccountId(originalSenderId)
                .creditedBalanceAfter(senderAfter)
                .ofsResponse(ofsResponse)
                .timestamp(Instant.now())
                .message("T24 transaction successfully reversed with compensating double-entry mutation.")
                .build();
    }

    private void parseOfsTransferMessage(String ofs, T24FundsTransferRequest req) {
        if (ofs == null) return;
        for (String part : ofs.split(",")) {
            String[] kv = part.split("=", 2);
            if (kv.length == 2) {
                String key = kv[0].trim().toUpperCase();
                String val = kv[1].trim();
                switch (key) {
                    case "DEBIT.ACCT.NO":
                    case "DEBIT_ACCT_NO":
                        req.setDebitAccountId(val);
                        break;
                    case "CREDIT.ACCT.NO":
                    case "CREDIT_ACCT_NO":
                        req.setCreditAccountId(val);
                        break;
                    case "DEBIT.AMOUNT":
                    case "AMOUNT":
                        try { req.setAmount(new BigDecimal(val)); } catch (Exception ignored) {}
                        break;
                    case "PAYMENT.DETAILS":
                    case "PAYMENT_DETAILS":
                        req.setPaymentDetails(val);
                        break;
                    case "DEBIT.CURRENCY":
                        req.setCurrency(val);
                        break;
                    case "CUSTOMER.ID":
                        req.setCustomerId(val);
                        break;
                    default:
                        break;
                }
            }
        }
    }

    private void parseOfsReversalMessage(String ofs, T24ReversalRequest req) {
        if (ofs == null) return;
        for (String part : ofs.split(",")) {
            String[] kv = part.split("=", 2);
            if (kv.length == 2) {
                String key = kv[0].trim().toUpperCase();
                String val = kv[1].trim();
                switch (key) {
                    case "TX.ID":
                    case "TRANSACTION.ID":
                    case "REF":
                        req.setOriginalTransactionId(val);
                        break;
                    case "REASON":
                        req.setReversalReason(val);
                        break;
                    case "CHECKER":
                        req.setCheckerId(val);
                        break;
                    case "MAKER":
                        req.setMakerId(val);
                        break;
                    case "TICKET":
                        req.setTicketId(val);
                        break;
                    default:
                        break;
                }
            } else if (!part.contains("/") && !part.contains(":") && req.getOriginalTransactionId() == null) {
                req.setOriginalTransactionId(part.trim());
            }
        }
    }

    /**
     * Resolves source account ID from account number, user ID, or direct account ID.
     */
    public String resolveInternalAccountId(String sourceId, String userId) {
        if (sourceId != null && !sourceId.isBlank()) {
            if (balanceRepository.existsById(sourceId)) {
                return sourceId;
            }
            Optional<AccountMaster> byNum = accountRepository.findByAccountNumber(sourceId);
            if (byNum.isPresent() && balanceRepository.existsById(byNum.get().getAccountId())) {
                return byNum.get().getAccountId();
            }
        }
        if (userId != null && !userId.isBlank()) {
            Optional<AccountMaster> byUser = accountRepository.findFirstByUserId(userId);
            if (byUser.isPresent() && balanceRepository.existsById(byUser.get().getAccountId())) {
                return byUser.get().getAccountId();
            }
        }
        if (balanceRepository.existsById("1000-2000-3001")) {
            return "1000-2000-3001";
        }
        return sourceId != null ? sourceId : "1000-2000-3001";
    }

    /**
     * Resolves target account ID from internal accounts, or auto-provisions an external clearing ledger account.
     */
    public String resolveOrProvisionTargetAccountId(String targetId) {
        if (targetId == null || targetId.isBlank()) {
            return "T24-CLEARING-SUSPENSE";
        }
        // 1. Direct match in balance_master
        if (balanceRepository.findByAccountId(targetId).isPresent()) {
            return targetId;
        }
        // 2. Match by account_number
        Optional<AccountMaster> byNum = accountRepository.findByAccountNumber(targetId);
        if (byNum.isPresent()) {
            return byNum.get().getAccountId();
        }
        // 3. External recipient (e.g. 1234568898951 MeyBank) -> Provision mirror account in Oracle master
        try {
            if (!accountRepository.existsById(targetId)) {
                AccountMaster externalAccount = AccountMaster.builder()
                        .accountId(targetId)
                        .userId("U0001")
                        .accountNumber(targetId)
                        .accountType("SAVINGS")
                        .status("ACTIVE")
                        .build();
                accountRepository.save(externalAccount);
            }
            if (!balanceRepository.existsById(targetId)) {
                BalanceMaster externalBalance = BalanceMaster.builder()
                        .accountId(targetId)
                        .balanceAmount(BigDecimal.ZERO)
                        .holdAmount(BigDecimal.ZERO)
                        .availableBalance(BigDecimal.ZERO)
                        .createdAt(Instant.now())
                        .updatedAt(Instant.now())
                        .build();
                balanceRepository.save(externalBalance);
            }
            return targetId;
        } catch (Exception ex) {
            log.warn("[EXTERNAL CLEARING] Could not auto-provision {}, falling back to T24-CLEARING-SUSPENSE: {}",
                    targetId, ex.getMessage());
            return "T24-CLEARING-SUSPENSE";
        }
    }

    /**
     * Generates a Temenos T24 standard transaction reference (FT + YYMMDD + 6 alphanumeric).
     */
    public String generateT24Reference(String txId) {
        if (txId != null && txId.startsWith("FT")) {
            return txId;
        }
        String datePart = java.time.LocalDate.now().format(java.time.format.DateTimeFormatter.ofPattern("yyMMdd"));
        String suffix = UUID.randomUUID().toString().substring(0, 6).toUpperCase();
        return "FT" + datePart + suffix;
    }
}