package com.bank.ledger.engine.kafka;

import com.bank.ledger.engine.dto.event.NotificationAlertEvent;
import com.bank.ledger.engine.dto.event.TransactionEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;
import org.springframework.stereotype.Service;

import java.util.concurrent.CompletableFuture;

@Slf4j
@Service
@RequiredArgsConstructor
public class KafkaEventPublisher {

    private final KafkaTemplate<String, Object> kafkaTemplate;

    @Value("${app.kafka.topics.transaction-events:transaction-events}")
    private String transactionEventsTopic;

    @Value("${app.kafka.topics.notification-alerts:notification-alerts}")
    private String notificationAlertsTopic;

    /**
     * Publishes a committed transaction event.
     * Uses sourceAccountId as the partition key to guarantee FIFO ordering per account.
     */
    public CompletableFuture<SendResult<String, Object>> publishTransactionEvent(TransactionEvent event) {
        log.info("[KAFKA PUBLISH] Emitting TransactionEvent: txId={}, from={}, to={}, amount=PHP {}",
                event.getTransactionId(), event.getSourceAccountId(), event.getDestinationAccountId(), event.getAmount());

        return kafkaTemplate.send(transactionEventsTopic, event.getSourceAccountId(), event)
                .whenComplete((result, ex) -> {
                    if (ex == null) {
                        log.info("[KAFKA SUCCESS] TransactionEvent sent to partition: {}, offset: {}",
                                result.getRecordMetadata().partition(), result.getRecordMetadata().offset());
                    } else {
                        log.error("[KAFKA ERROR] Failed to send TransactionEvent for txId={}: {}",
                                event.getTransactionId(), ex.getMessage());
                    }
                });
    }

    /**
     * Publishes a real-time notification alert for customer notifications.
     */
    public CompletableFuture<SendResult<String, Object>> publishNotificationAlert(NotificationAlertEvent alert) {
        log.info("[KAFKA PUBLISH] Emitting NotificationAlert: user={}, account={}, type={}, amount=PHP {}",
                alert.getRecipientUserId(), alert.getRecipientAccountId(), alert.getAlertType(), alert.getAmount());

        return kafkaTemplate.send(notificationAlertsTopic, alert.getRecipientAccountId(), alert)
                .whenComplete((result, ex) -> {
                    if (ex == null) {
                        log.info("[KAFKA SUCCESS] NotificationAlert sent to partition: {}, offset: {}",
                                result.getRecordMetadata().partition(), result.getRecordMetadata().offset());
                    } else {
                        log.error("[KAFKA ERROR] Failed to send NotificationAlert for alertId={}: {}",
                                alert.getAlertId(), ex.getMessage());
                    }
                });
    }
}