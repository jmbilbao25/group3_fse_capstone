package com.bank.ledger.engine;

import com.bank.ledger.contracts.dto.MutationRequest;
import com.bank.ledger.contracts.dto.MutationResponse;
import com.bank.ledger.engine.entity.master.OutboxEventMaster;
import com.bank.ledger.engine.outbox.OutboxRelayScheduler;
import com.bank.ledger.engine.repository.master.OutboxEventMasterRepository;
import com.bank.ledger.engine.service.BalanceMutationService;
import com.bank.ledger.contracts.enums.EventType;
import com.bank.ledger.contracts.enums.MutationType;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
class OutboxWorkerIntegrationTest {

    @Autowired
    private BalanceMutationService balanceMutationService;

    @Autowired
    private OutboxEventMasterRepository outboxRepository;

    @Autowired
    private OutboxRelayScheduler outboxRelayScheduler;

    @org.junit.jupiter.api.BeforeEach
    void checkPrerequisites() {
        try (java.net.Socket socket = new java.net.Socket()) {
            socket.connect(new java.net.InetSocketAddress("localhost", 1521), 1000);
        } catch (Exception e) {
            org.junit.jupiter.api.Assumptions.abort("Oracle XE is not running on localhost:1521; skipping live outbox worker test.");
        }
        try (java.net.Socket socket = new java.net.Socket()) {
            socket.connect(new java.net.InetSocketAddress("localhost", 9092), 1000);
        } catch (Exception e) {
            org.junit.jupiter.api.Assumptions.abort("Kafka broker is not running on localhost:9092; skipping live outbox worker test.");
        }
    }

    @Test
    @DisplayName("Verify Transactional Outbox Pattern & Background Relay Worker (EVT-601)")
    void testOutboxWorkerRelaysEventToKafka() throws Exception {
        String txId = "TX-OUTBOX-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();

        // 1. Execute a financial transfer (Route B - Normal settlement)
        MutationRequest request = MutationRequest.builder()
                .transactionId(txId)
                .accountId("acc-2001-sav-001")
                .targetAccountId("acc-2003-sav-002")
                .eventType(EventType.TRANSFER)
                .mutationType(MutationType.TRANSFER)
                .mutationAmount(new BigDecimal("1200.0000"))
                .initiatorUserId("usr-1001-cst-001")
                .build();

        MutationResponse response = balanceMutationService.executeTransfer(request);
        assertEquals("COMMITTED", response.getStatus());

        // 2. Query Oracle outbox_events table for the pending event
        List<OutboxEventMaster> pendingList = outboxRepository.findByStatusOrderByCreatedAtAsc("PENDING");
        assertFalse(pendingList.isEmpty(), "Outbox table must contain pending events waiting for relay");

        OutboxEventMaster pendingEvent = pendingList.stream()
                .filter(e -> txId.equals(e.getAggregateId()))
                .findFirst()
                .orElseThrow(() -> new AssertionError("Pending outbox event not found for txId: " + txId));

        assertEquals("TRANSACTION", pendingEvent.getAggregateType());
        assertEquals("MUTATION_COMMITTED", pendingEvent.getEventType());
        assertEquals("PENDING", pendingEvent.getStatus());
        assertNull(pendingEvent.getPublishedAt(), "published_at must be null while PENDING");

        // 3. Trigger Outbox Relay Scheduler Worker
        outboxRelayScheduler.processOutboxEvents();

        // 4. Verify status transition to PUBLISHED
        OutboxEventMaster publishedEvent = outboxRepository.findById(pendingEvent.getEventId())
                .orElseThrow(() -> new AssertionError("Outbox event disappeared!"));

        assertEquals("PUBLISHED", publishedEvent.getStatus(), "Status must transition to PUBLISHED after Kafka ACK");
        assertNotNull(publishedEvent.getPublishedAt(), "published_at must be populated with timestamp");
        assertEquals(0, publishedEvent.getRetryCount(), "Retry count should remain 0 on clean delivery");

        System.out.println("==========================================================");
        System.out.println(">>> TRANSACTIONAL OUTBOX WORKER VERIFICATION SUCCESS <<<");
        System.out.println("Event ID:       " + publishedEvent.getEventId());
        System.out.println("Tx ID (Agg):    " + publishedEvent.getAggregateId());
        System.out.println("Event Type:     " + publishedEvent.getEventType());
        System.out.println("Kafka Topic:    " + publishedEvent.getKafkaTopic());
        System.out.println("Relay Status:   " + publishedEvent.getStatus());
        System.out.println("Published At:   " + publishedEvent.getPublishedAt());
        System.out.println("Payload Preview: " + publishedEvent.getPayload());
        System.out.println("==========================================================");
    }
}