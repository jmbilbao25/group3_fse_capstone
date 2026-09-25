package com.bank.ledger.engine.controller;

import com.bank.ledger.engine.dto.event.NotificationAlertEvent;
import com.bank.ledger.engine.kafka.KafkaEventPublisher;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("/api/v1/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final KafkaEventPublisher eventPublisher;

    /**
     * Dispatches an asynchronous notification event through Apache Kafka.
     * Endpoint for API Gateway and downstream notification triggering.
     */
    @PostMapping("/dispatch")
    public ResponseEntity<Map<String, Object>> dispatchNotification(
            @RequestParam String userId,
            @RequestParam String accountId,
            @RequestParam String type,
            @RequestParam BigDecimal amount,
            @RequestParam BigDecimal balanceAfter,
            @RequestParam String message) {

        String alertId = "ALT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        String txId = "TX-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();

        NotificationAlertEvent alert = NotificationAlertEvent.builder()
                .alertId(alertId)
                .transactionId(txId)
                .recipientUserId(userId)
                .recipientAccountId(accountId)
                .alertType(type)
                .amount(amount)
                .balanceAfter(balanceAfter)
                .title("Account Balance Update")
                .message(message)
                .createdAt(Instant.now())
                .build();

        // Publish to Kafka asynchronously (non-blocking)
        eventPublisher.publishNotificationAlert(alert);

        return ResponseEntity.ok(Map.of(
                "status", "DISPATCHED",
                "alertId", alertId,
                "transactionId", txId,
                "topic", "notification-alerts",
                "message", "Notification event emitted to Kafka cluster successfully."
        ));
    }
}