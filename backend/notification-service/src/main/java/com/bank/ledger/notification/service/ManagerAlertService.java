package com.bank.ledger.notification.service;

import com.bank.ledger.contracts.dto.TransactionNotificationEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Real-time WebSocket Alert Service for Operations Managers.
 * Broadcasts Dual-Control Maker-Checker and AMLA alerts to the Manager Console
 * on destination /topic/manager-alerts (and legacy /topic/teller-alerts).
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ManagerAlertService {

    private final SimpMessagingTemplate messagingTemplate;
    private final ReceiptGenerator receiptGenerator;

    public void broadcastPendingApprovalAlert(TransactionNotificationEvent event) {
        broadcastTier2MakerCheckerAlert(event);
    }

    public void broadcastTier2MakerCheckerAlert(TransactionNotificationEvent event) {
        Map<String, Object> alertPayload = new LinkedHashMap<>();
        alertPayload.put("alert_type", "TIER_2_DUAL_CONTROL_REQUIRED");
        alertPayload.put("tier", "TIER_2");
        alertPayload.put("threshold", "PHP 50,000.01 - 499,999.99");
        alertPayload.put("required_roles", "Maker: Customer | Checker: Bank Operations Manager (Level 1)");
        alertPayload.put("workflow", "Customer initiated transfer online; held in PENDING_APPROVAL. Manager review required in Manager Console.");
        alertPayload.put("transfer_id", event.getTransferId());
        alertPayload.put("amount", event.getAmount());
        alertPayload.put("formatted_amount", receiptGenerator.formatCurrencyPhp(event.getAmount()));
        alertPayload.put("maker_user_id", event.getMakerUserId() != null ? event.getMakerUserId() : (event.getUserId() != null ? event.getUserId() : "U1001"));
        alertPayload.put("source_account", event.getSourceAccount());
        alertPayload.put("destination_account", event.getDestinationAccount());
        alertPayload.put("amla_covered", false);
        alertPayload.put("timestamp", Instant.now().toString());

        log.info("Broadcasting Tier 2 Maker-Checker alert to /topic/manager-alerts for transfer: {}", event.getTransferId());
        messagingTemplate.convertAndSend("/topic/manager-alerts", alertPayload);
        messagingTemplate.convertAndSend("/topic/teller-alerts", alertPayload);
    }

    public void broadcastTier3AmlaAlert(TransactionNotificationEvent event) {
        Map<String, Object> alertPayload = new LinkedHashMap<>();
        alertPayload.put("alert_type", "TIER_3_AMLA_HOLD_REQUIRED");
        alertPayload.put("tier", "TIER_3");
        alertPayload.put("threshold", ">= PHP 500,000.00");
        alertPayload.put("required_roles", "Maker: Customer | Checker 1: Manager (Level 1) | Approver 2: Senior Manager (Level 2)");
        alertPayload.put("workflow", "Customer initiated online; requires CTR filing under AMLA + dual manager approval before balance release.");
        alertPayload.put("transfer_id", event.getTransferId());
        alertPayload.put("amount", event.getAmount());
        alertPayload.put("formatted_amount", receiptGenerator.formatCurrencyPhp(event.getAmount()));
        alertPayload.put("maker_user_id", event.getMakerUserId() != null ? event.getMakerUserId() : (event.getUserId() != null ? event.getUserId() : "U1001"));
        alertPayload.put("source_account", event.getSourceAccount());
        alertPayload.put("destination_account", event.getDestinationAccount());
        alertPayload.put("amla_covered", true);
        alertPayload.put("ctr_report_required", true);
        alertPayload.put("timestamp", Instant.now().toString());

        log.info("Broadcasting Tier 3 AMLA CTR alert to /topic/manager-alerts for transfer: {}", event.getTransferId());
        messagingTemplate.convertAndSend("/topic/manager-alerts", alertPayload);
        messagingTemplate.convertAndSend("/topic/teller-alerts", alertPayload);
    }
}
