package com.bank.ledger.notification.controller;

import com.bank.ledger.contracts.dto.TransactionNotificationEvent;
import com.bank.ledger.notification.consumer.TransactionEventConsumer;
import com.bank.ledger.notification.entity.NotificationEntity;
import com.bank.ledger.notification.repository.NotificationRepository;
import com.bank.ledger.notification.service.EmailNotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;

@Slf4j
@RestController
@RequestMapping("/api/v1/notifications")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class NotificationController {

    private final EmailNotificationService emailService;
    private final TransactionEventConsumer transactionEventConsumer;
    private final NotificationRepository notificationRepository;

    @PostMapping("/simulate-transfer")
    public ResponseEntity<Map<String, Object>> simulateTransferNotification() {
        TransactionNotificationEvent event = TransactionNotificationEvent.builder()
                .transferId("TRX-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                .sourceAccount("ACC-1002938471")
                .destinationAccount("ACC-2009847192")
                .userId("U1001")
                .makerUserId("U1001")
                .recipientEmail("juan.delacruz@retailbank.ph")
                .amount(new BigDecimal("7500.0000")) // Tier 1: <= PHP 50,000.00 (STP)
                .currency("PHP")
                .beforeBalance(new BigDecimal("250000.0000"))
                .afterBalance(new BigDecimal("242500.0000"))
                .status("COMMITTED")
                .eventType("TRANSFER_EXECUTED")
                .timestamp(Instant.now())
                .description("Tier 1: Normal Retail Fund Transfer (Automated STP - No Manager Approval)")
                .build();

        log.info("Simulating transfer notification for: {}", event.getTransferId());
        transactionEventConsumer.consumeTransactionEvent(event);

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("status", "DISPATCHED");
        response.put("tier", "TIER_1_NORMAL");
        response.put("transferId", event.getTransferId());
        response.put("amount", event.getAmount());
        response.put("senderEmail", event.getRecipientEmail());
        response.put("beneficiaryEmail", "maria.santos@retailbank.ph");
        response.put("message", "Tier 1 normal transaction consumed; Debit Receipt sent to Sender (Juan Dela Cruz) & Credit Advice sent to Beneficiary (Maria Santos).");
        return ResponseEntity.ok(response);
    }

    @PostMapping("/simulate-maker-checker")
    public ResponseEntity<Map<String, Object>> simulateMakerCheckerNotification() {
        return simulateTier2MakerChecker();
    }

    @PostMapping("/simulate-tier2-maker-checker")
    public ResponseEntity<Map<String, Object>> simulateTier2MakerChecker() {
        TransactionNotificationEvent event = TransactionNotificationEvent.builder()
                .transferId("TRX-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                .sourceAccount("ACC-1002938471")
                .destinationAccount("ACC-9988776655")
                .userId("U1001")
                .makerUserId("U1001")
                .recipientEmail("beatriz.ocampo@retailbank.ph")
                .amount(new BigDecimal("150000.0000")) // Tier 2: PHP 50k - 499,999.99
                .currency("PHP")
                .beforeBalance(new BigDecimal("500000.0000"))
                .afterBalance(new BigDecimal("350000.0000"))
                .status("PENDING_APPROVAL")
                .eventType("TRANSFER_PENDING_APPROVAL")
                .requiresMakerChecker(true)
                .timestamp(Instant.now())
                .description("Tier 2: Dual Control Transfer (Maker: Customer, Checker: Manager)")
                .build();

        log.info("Simulating Tier 2 Maker-Checker hold alert for: {}", event.getTransferId());
        transactionEventConsumer.consumeTransactionEvent(event);

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("status", "ALERT_BROADCAST");
        response.put("tier", "TIER_2_DUAL_CONTROL");
        response.put("threshold", "PHP 50,000.01 - 499,999.99");
        response.put("requiredRoles", "Maker: Customer | Checker: Bank Operations Manager (Level 1)");
        response.put("transferId", event.getTransferId());
        response.put("amount", event.getAmount());
        response.put("message", "Tier 2 dual-control alert broadcast and Manager compliance email dispatched.");
        return ResponseEntity.ok(response);
    }

    @PostMapping("/simulate-tier2-approval")
    public ResponseEntity<Map<String, Object>> simulateTier2Approval() {
        TransactionNotificationEvent event = TransactionNotificationEvent.builder()
                .transferId("TRX-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                .sourceAccount("ACC-1002938471")
                .destinationAccount("ACC-9988776655")
                .userId("U1001")
                .makerUserId("U1001")
                .recipientEmail("juan.delacruz@retailbank.ph")
                .amount(new BigDecimal("150000.0000"))
                .currency("PHP")
                .beforeBalance(new BigDecimal("500000.0000"))
                .afterBalance(new BigDecimal("350000.0000"))
                .status("COMMITTED")
                .eventType("TRANSFER_APPROVED_BY_CHECKER")
                .timestamp(Instant.now())
                .description("Funds Released: Tier 2 Transfer PHP 150,000.00 Approved by Bank Operations Manager Beatriz Ocampo (U3002)")
                .build();

        log.info("Simulating Tier 2 Manager Approval release for: {}", event.getTransferId());
        transactionEventConsumer.consumeTransactionEvent(event);

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("status", "APPROVED_AND_RELEASED");
        response.put("tier", "TIER_2_APPROVAL");
        response.put("checker", "Beatriz Ocampo (U3002)");
        response.put("transferId", event.getTransferId());
        response.put("amount", event.getAmount());
        response.put("senderEmail", event.getRecipientEmail());
        response.put("beneficiaryEmail", "maria.santos@retailbank.ph");
        response.put("message", "Funds Released: Tier 2 transfer approved by Manager Beatriz Ocampo. Official debit receipt and credit advice dispatched.");
        return ResponseEntity.ok(response);
    }

    @PostMapping("/simulate-tier3-amla")
    public ResponseEntity<Map<String, Object>> simulateTier3Amla() {
        TransactionNotificationEvent event = TransactionNotificationEvent.builder()
                .transferId("TRX-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                .sourceAccount("ACC-1002938471")
                .destinationAccount("ACC-9988776655")
                .userId("U1001")
                .makerUserId("U1001")
                .recipientEmail("compliance-officer@corebank.ph")
                .amount(new BigDecimal("750000.0000")) // Tier 3: >= PHP 500,000.00 (AMLA Covered)
                .currency("PHP")
                .beforeBalance(new BigDecimal("2000000.0000"))
                .afterBalance(new BigDecimal("1250000.0000"))
                .status("PENDING_APPROVAL")
                .eventType("TRANSFER_PENDING_APPROVAL")
                .requiresMakerChecker(true)
                .timestamp(Instant.now())
                .description("Tier 3: AMLA Covered Transfer (Requires CTR Filing + Dual Manager Approval)")
                .build();

        log.info("Simulating Tier 3 AMLA High-Value hold alert for: {}", event.getTransferId());
        transactionEventConsumer.consumeTransactionEvent(event);

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("status", "ALERT_BROADCAST");
        response.put("tier", "TIER_3_AMLA_COVERED");
        response.put("threshold", ">= PHP 500,000.00");
        response.put("requiredRoles", "Maker: Customer | Checker 1: Manager (Level 1) | Approver 2: Senior Manager (Level 2)");
        response.put("amlaNotice", "MANDATORY: Covered Transaction Report (CTR) filing required under AMLA before balance mutation.");
        response.put("transferId", event.getTransferId());
        response.put("amount", event.getAmount());
        response.put("message", "Tier 3 AMLA CTR alert broadcast and Dual Manager compliance email dispatched.");
        return ResponseEntity.ok(response);
    }

    @GetMapping("/history")
    public ResponseEntity<List<NotificationEntity>> getNotificationHistory(
            @RequestParam(value = "userId", required = false) String userId) {
        if (notificationRepository == null) {
            return ResponseEntity.ok(Collections.emptyList());
        }
        if (userId != null && !userId.isBlank()) {
            return ResponseEntity.ok(notificationRepository.findByUserIdOrderBySentAtDesc(userId));
        }
        return ResponseEntity.ok(notificationRepository.findTop50ByOrderBySentAtDesc());
    }

    @GetMapping("/spool-status")
    public ResponseEntity<Map<String, Object>> getSpoolStatus() {
        return ResponseEntity.ok(emailService.getSpoolStatus());
    }

    @PostMapping("/flush-spool")
    public ResponseEntity<Map<String, Object>> flushSpool() {
        int count = emailService.flushRetrySpool();
        return ResponseEntity.ok(Map.of("flushed_count", count, "status", "SUCCESS"));
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of("service", "notification-service", "status", "UP", "port", "8083"));
    }
}
