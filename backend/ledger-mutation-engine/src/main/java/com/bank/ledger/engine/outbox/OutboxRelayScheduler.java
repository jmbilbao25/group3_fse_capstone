package com.bank.ledger.engine.outbox;

import com.bank.ledger.engine.entity.master.OutboxEventMaster;
import com.bank.ledger.engine.repository.master.OutboxEventMasterRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;

@Slf4j
@Component
@RequiredArgsConstructor
public class OutboxRelayScheduler {

    private final OutboxEventMasterRepository outboxRepository;
    private final KafkaTemplate<String, Object> kafkaTemplate;
    private final ObjectMapper objectMapper;

    private static final int MAX_RETRIES = 3;

    /**
     * Polls Oracle outbox_events every 2000ms (2 seconds).
     * Dispatches PENDING financial events to Kafka KRaft broker with guaranteed delivery.
     */
    @Scheduled(fixedDelayString = "${app.outbox.poll-interval-ms:2000}")
    @Transactional(transactionManager = "oracleTransactionManager")
    public void processOutboxEvents() {
        List<OutboxEventMaster> pendingEvents = outboxRepository.findTop50ByStatusOrderByCreatedAtAsc("PENDING");

        if (pendingEvents.isEmpty()) {
            return;
        }

        log.info("[OUTBOX WORKER] Discovered {} pending event(s) to relay to Kafka...", pendingEvents.size());

        for (OutboxEventMaster event : pendingEvents) {
            try {
                // Parse stored CLOB payload so Kafka JSON serializer transmits valid clean JSON
                JsonNode payloadNode = objectMapper.readTree(event.getPayload());

                CompletableFuture<SendResult<String, Object>> future =
                        kafkaTemplate.send(event.getKafkaTopic(), event.getAggregateId(), payloadNode);

                // Synchronous wait: ensures we do NOT mark PUBLISHED unless Kafka acknowledges with acks=all
                SendResult<String, Object> sendResult = future.get(5, TimeUnit.SECONDS);

                event.setStatus("PUBLISHED");
                event.setPublishedAt(Instant.now());
                outboxRepository.save(event);

                log.info("[OUTBOX SUCCESS] Relayed eventId={} [type={}] to topic={} partition={} offset={}",
                        event.getEventId(), event.getEventType(), event.getKafkaTopic(),
                        sendResult.getRecordMetadata().partition(), sendResult.getRecordMetadata().offset());

            } catch (Exception ex) {
                int newRetry = event.getRetryCount() + 1;
                event.setRetryCount(newRetry);

                if (newRetry >= MAX_RETRIES) {
                    log.error("[OUTBOX EXHAUSTED] Event {} exceeded max retries. Marking FAILED: {}",
                            event.getEventId(), ex.getMessage());
                    event.setStatus("FAILED");
                } else {
                    log.warn("[OUTBOX RETRY] Event {} failed (attempt {}/{}): {}",
                            event.getEventId(), newRetry, MAX_RETRIES, ex.getMessage());
                }

                outboxRepository.save(event);
            }
        }
    }
}