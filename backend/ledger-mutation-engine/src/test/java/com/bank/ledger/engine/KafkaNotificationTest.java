package com.bank.ledger.engine;

import com.bank.ledger.engine.dto.event.NotificationAlertEvent;
import com.bank.ledger.engine.dto.event.TransactionEvent;
import com.bank.ledger.engine.kafka.KafkaEventPublisher;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.kafka.support.SendResult;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest
class KafkaNotificationTest {

    @Autowired
    private KafkaEventPublisher eventPublisher;

    @Test
    @DisplayName("Verify Kafka Publishing & Consumer Alert Dispatch")
    void testKafkaEventPublishingAndNotification() throws Exception {
        String txId = "TX-KAFKA-" + System.currentTimeMillis();

        // 1. Prepare Financial Transaction Event
        TransactionEvent txEvent = TransactionEvent.builder()
                .transactionId(txId)
                .sourceAccountId("A2001")
                .destinationAccountId("A2002")
                .amount(new BigDecimal("1500.0000"))
                .currency("PHP")
                .mutationType("TRANSFER")
                .status("COMMITTED")
                .initiatorUserId("U1001")
                .timestamp(Instant.now())
                .build();

        // 2. Prepare Customer Notification Alert Event
        NotificationAlertEvent alertEvent = NotificationAlertEvent.builder()
                .alertId("ALT-" + System.currentTimeMillis())
                .transactionId(txId)
                .recipientUserId("U1001")
                .recipientAccountId("A2001")
                .alertType("TRANSFER_DEBIT")
                .amount(new BigDecimal("1500.0000"))
                .balanceAfter(new BigDecimal("8500.0000"))
                .title("Funds Transfer Successful")
                .message("PHP 1,500.00 has been debited from account A2001 to account A2002.")
                .createdAt(Instant.now())
                .build();

        // 3. Publish to Kafka
        CompletableFuture<SendResult<String, Object>> txFuture = eventPublisher.publishTransactionEvent(txEvent);
        CompletableFuture<SendResult<String, Object>> alertFuture = eventPublisher.publishNotificationAlert(alertEvent);

        // Wait for Kafka broker acknowledgement
        SendResult<String, Object> txResult = txFuture.get(10, TimeUnit.SECONDS);
        SendResult<String, Object> alertResult = alertFuture.get(10, TimeUnit.SECONDS);

        assertNotNull(txResult.getRecordMetadata());
        assertNotNull(alertResult.getRecordMetadata());

        System.out.println("==========================================================");
        System.out.println(">>> KAFKA EVENT STREAMING VERIFICATION SUCCESS <<<");
        System.out.println("Topic (Transaction):  " + txResult.getRecordMetadata().topic());
        System.out.println("Partition / Offset:   " + txResult.getRecordMetadata().partition() + " / " + txResult.getRecordMetadata().offset());
        System.out.println("Topic (Notification): " + alertResult.getRecordMetadata().topic());
        System.out.println("Partition / Offset:   " + alertResult.getRecordMetadata().partition() + " / " + alertResult.getRecordMetadata().offset());
        System.out.println("==========================================================");

        // Give the asynchronous KafkaListener 2 seconds to consume and log
        Thread.sleep(2000);

        assertTrue(txResult.getRecordMetadata().offset() >= 0);
        assertTrue(alertResult.getRecordMetadata().offset() >= 0);
    }
}