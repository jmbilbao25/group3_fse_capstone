package com.bank.ledger.engine.entity.master;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "outbox_events")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OutboxEventMaster {

    @Id
    @Column(name = "event_id", length = 64)
    private String eventId;

    @Column(name = "aggregate_type", nullable = false, length = 50)
    private String aggregateType; // 'TRANSACTION', 'MAKER_CHECKER', 'BALANCE_MUTATION'

    @Column(name = "aggregate_id", nullable = false, length = 64)
    private String aggregateId;

    @Column(name = "event_type", nullable = false, length = 50)
    private String eventType; // 'MAKER_PENDING', 'CHECKER_APPROVED', 'MUTATION_COMMITTED'

    @Column(name = "kafka_topic", nullable = false, length = 100)
    private String kafkaTopic;

    @Lob
    @Column(name = "payload", nullable = false)
    private String payload;

    @Column(name = "status", nullable = false, length = 20)
    private String status; // 'PENDING', 'PUBLISHED', 'FAILED'

    @Column(name = "retry_count", nullable = false)
    private Integer retryCount;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "published_at")
    private Instant publishedAt;
}