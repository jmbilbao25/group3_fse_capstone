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

    @PostMapping("/send-otp")
    public ResponseEntity<Map<String, Object>> sendOtpNotification(
            @RequestBody(required = false) Map<String, Object> request) {

        String transferId = "TRX-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        String recipientEmail = "juan.dc@email.com";
        BigDecimal amount = new BigDecimal("90000.0000");
        String verificationCode = "849201";
        String sourceAccount = "ACC-1002938471";
        String destinationAccount = "ACC-2009847192";
        String recipientName = "Maria Clara Santos";

        if (request != null) {
            if (request.get("transfer_id") != null) transferId = request.get("transfer_id").toString();
            if (request.get("transferId") != null) transferId = request.get("transferId").toString();
            if (request.get("recipient_email") != null) recipientEmail = request.get("recipient_email").toString();
            if (request.get("recipientEmail") != null) recipientEmail = request.get("recipientEmail").toString();
            if (request.get("amount") != null) amount = new BigDecimal(request.get("amount").toString());
            if (request.get("verification_code") != null) verificationCode = request.get("verification_code").toString();
            if (request.get("verificationCode") != null) verificationCode = request.get("verificationCode").toString();
            if (request.get("otp") != null) verificationCode = request.get("otp").toString();
            if (request.get("from_account_id") != null) sourceAccount = request.get("from_account_id").toString();
            if (request.get("source_account_id") != null) sourceAccount = request.get("source_account_id").toString();
            if (request.get("sourceAccount") != null) sourceAccount = request.get("sourceAccount").toString();
            if (request.get("to_account_id") != null) destinationAccount = request.get("to_account_id").toString();
            if (request.get("destination_account_id") != null) destinationAccount = request.get("destination_account_id").toString();
            if (request.get("destinationAccount") != null) destinationAccount = request.get("destinationAccount").toString();
            if (request.get("recipient_name") != null) recipientName = request.get("recipient_name").toString();
            if (request.get("recipientName") != null) recipientName = request.get("recipientName").toString();
        }

        log.info("Sending OTP verification email for transferId={}, recipient={}, code={}", transferId, recipientEmail, verificationCode);
        boolean dispatched = emailService.sendOtpVerification(
                transferId, recipientEmail, amount, verificationCode, sourceAccount, destinationAccount, recipientName);

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("status", dispatched ? "DISPATCHED" : "BUFFERED");
        response.put("transferId", transferId);
        response.put("recipientEmail", recipientEmail);
        response.put("verificationCode", verificationCode);
        response.put("amount", amount);
        response.put("message", "Customer 2FA Verification OTP email dispatched to " + recipientEmail + " via MailHog.");
        return ResponseEntity.ok(response);
    }

    @PostMapping("/simulate-transfer")
    public ResponseEntity<Map<String, Object>> simulateTransferNotification(
            @RequestBody(required = false) Map<String, Object> request,
            @RequestParam(required = false) BigDecimal amountParam) {

        boolean isSettle = request != null && ("COMMITTED".equalsIgnoreCase(String.valueOf(request.get("status"))) || "SETTLED".equalsIgnoreCase(String.valueOf(request.get("status"))));
        boolean hasExplicitOtp = request != null && (request.get("verification_code") != null || request.get("otp") != null);
        boolean isOtpMemo = request != null && request.get("memo") != null && request.get("memo").toString().contains("Customer Security Verification OTP");

        if (!isSettle && (hasExplicitOtp || isOtpMemo)) {
            return sendOtpNotification(request);
        }

        BigDecimal amount = new BigDecimal("7500.0000");
        String transferId = "TRX-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        String sourceAccount = "ACC-1002938471";
        String destinationAccount = "ACC-2009847192";
        String recipientEmail = "juan.delacruz@retailbank.ph";
        String memo = "Tier 1: Normal Retail Fund Transfer (Automated STP - No Manager Approval)";

        if (request != null) {
            if (request.get("amount") != null) {
                amount = new BigDecimal(request.get("amount").toString());
            }
            if (request.get("transfer_id") != null) {
                transferId = request.get("transfer_id").toString();
            }
            if (request.get("from_account_id") != null) {
                sourceAccount = request.get("from_account_id").toString();
            }
            if (request.get("to_account_id") != null) {
                destinationAccount = request.get("to_account_id").toString();
            }
            if (request.get("recipient_email") != null) {
                recipientEmail = request.get("recipient_email").toString();
            }
            if (request.get("memo") != null) {
                memo = request.get("memo").toString();
            }
        } else if (amountParam != null) {
            amount = amountParam;
        }

        TransactionNotificationEvent event = TransactionNotificationEvent.builder()
                .transferId(transferId)
                .sourceAccount(sourceAccount)
                .destinationAccount(destinationAccount)
                .userId("U1001")
                .makerUserId("U1001")
                .recipientEmail(recipientEmail)
                .amount(amount)
                .currency("PHP")
                .beforeBalance(new BigDecimal("275000.0000"))
                .afterBalance(new BigDecimal("275000.0000").subtract(amount))
                .status("COMMITTED")
                .eventType("TRANSFER_EXECUTED")
                .timestamp(Instant.now())
                .description(memo)
                .build();

        log.info("Simulating transfer notification for: {}, amount: {}", event.getTransferId(), event.getAmount());
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
        return simulateTier2MakerChecker(null, null);
    }

    @PostMapping("/simulate-tier2-maker-checker")
    public ResponseEntity<Map<String, Object>> simulateTier2MakerChecker(
            @RequestBody(required = false) Map<String, Object> request,
            @RequestParam(required = false) BigDecimal amountParam) {

        BigDecimal amount = new BigDecimal("150000.0000");
        String transferId = "TRX-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        String recipientEmail = "juan.dc@email.com";
        String description = "Tier 2: Customer Security Verification OTP: [ 849201 ]";

        if (request != null) {
            if (request.get("amount") != null) {
                amount = new BigDecimal(request.get("amount").toString());
            }
            if (request.get("transfer_id") != null) {
                transferId = request.get("transfer_id").toString();
            }
            if (request.get("recipient_email") != null) {
                recipientEmail = request.get("recipient_email").toString();
            }
            if (request.get("verification_code") != null) {
                description = "Tier 2: Customer Security Verification OTP: [ " + request.get("verification_code") + " ]";
            }
        } else if (amountParam != null) {
            amount = amountParam;
        }

        TransactionNotificationEvent event = TransactionNotificationEvent.builder()
                .transferId(transferId)
                .sourceAccount("ACC-1002938471")
                .destinationAccount("ACC-9988776655")
                .userId("U1001")
                .makerUserId("U1001")
                .recipientEmail(recipientEmail)
                .amount(amount)
                .currency("PHP")
                .beforeBalance(new BigDecimal("500000.0000"))
                .afterBalance(new BigDecimal("500000.0000").subtract(amount))
                .status("PENDING_APPROVAL")
                .eventType("TRANSFER_PENDING_APPROVAL")
                .requiresMakerChecker(true)
                .timestamp(Instant.now())
                .description(description)
                .build();

        log.info("Simulating Tier 2 Maker-Checker hold alert for: {}, amount: {}", event.getTransferId(), event.getAmount());
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
    public ResponseEntity<Map<String, Object>> simulateTier2Approval(
            @RequestBody(required = false) Map<String, Object> request,
            @RequestParam(required = false) BigDecimal amountParam) {

        BigDecimal amount = new BigDecimal("150000.0000");
        String transferId = "TRX-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        if (request != null) {
            if (request.get("amount") != null) {
                amount = new BigDecimal(request.get("amount").toString());
            }
            if (request.get("transfer_id") != null) {
                transferId = request.get("transfer_id").toString();
            }
        } else if (amountParam != null) {
            amount = amountParam;
        }

        TransactionNotificationEvent event = TransactionNotificationEvent.builder()
                .transferId(transferId)
                .sourceAccount("ACC-1002938471")
                .destinationAccount("ACC-9988776655")
                .userId("U1001")
                .makerUserId("U1001")
                .recipientEmail("juan.delacruz@retailbank.ph")
                .amount(amount)
                .currency("PHP")
                .beforeBalance(new BigDecimal("500000.0000"))
                .afterBalance(new BigDecimal("500000.0000").subtract(amount))
                .status("COMMITTED")
                .eventType("TRANSFER_APPROVED_BY_CHECKER")
                .timestamp(Instant.now())
                .description("Funds Released: Tier 2 Transfer PHP " + amount + " Approved by Bank Operations Manager Beatriz Ocampo (U3002)")
                .build();

        log.info("Simulating Tier 2 Manager Approval release for: {}, amount: {}", event.getTransferId(), event.getAmount());
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
    public ResponseEntity<Map<String, Object>> simulateTier3Amla(
            @RequestBody(required = false) Map<String, Object> request,
            @RequestParam(required = false) BigDecimal amountParam) {

        BigDecimal amount = new BigDecimal("750000.0000");
        String transferId = "TRX-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        if (request != null) {
            if (request.get("amount") != null) {
                amount = new BigDecimal(request.get("amount").toString());
            }
            if (request.get("transfer_id") != null) {
                transferId = request.get("transfer_id").toString();
            }
        } else if (amountParam != null) {
            amount = amountParam;
        }

        TransactionNotificationEvent event = TransactionNotificationEvent.builder()
                .transferId(transferId)
                .sourceAccount("ACC-1002938471")
                .destinationAccount("ACC-9988776655")
                .userId("U1001")
                .makerUserId("U1001")
                .recipientEmail("compliance-officer@corebank.ph")
                .amount(amount)
                .currency("PHP")
                .beforeBalance(new BigDecimal("2000000.0000"))
                .afterBalance(new BigDecimal("2000000.0000").subtract(amount))
                .status("PENDING_APPROVAL")
                .eventType("TRANSFER_PENDING_APPROVAL")
                .requiresMakerChecker(true)
                .timestamp(Instant.now())
                .description("Tier 3: AMLA Covered Transfer (Requires CTR Filing + Dual Manager Approval)")
                .build();

        log.info("Simulating Tier 3 AMLA High-Value hold alert for: {}, amount: {}", event.getTransferId(), event.getAmount());
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
