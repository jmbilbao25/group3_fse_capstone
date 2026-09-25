package com.bank.ledger.engine.kafka;

import com.bank.ledger.engine.dto.event.NotificationAlertEvent;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Component;

@Slf4j
@Component
public class NotificationEventListener {

    /**
     * Downstream Notification Consumer:
     * In an enterprise bank, this service acts as the gateway to SMS/Email/Push aggregators.
     */
    @KafkaListener(
        topics = "${app.kafka.topics.notification-alerts:notification-alerts}",
        groupId = "ledger-notification-group"
    )
    public void handleNotificationAlert(@Payload NotificationAlertEvent alert) {
        log.info("================================================================================");
        log.info("🔔 [DOWNSTREAM NOTIFICATION DISPATCHED]");
        log.info("To User:      {}", alert.getRecipientUserId());
        log.info("Account:      {}", alert.getRecipientAccountId());
        log.info("Type:         {}", alert.getAlertType());
        log.info("Title:        {}", alert.getTitle());
        log.info("Message:      {}", alert.getMessage());
        log.info("Post-Balance: PHP {}", alert.getBalanceAfter());
        log.info("================================================================================");
    }
}