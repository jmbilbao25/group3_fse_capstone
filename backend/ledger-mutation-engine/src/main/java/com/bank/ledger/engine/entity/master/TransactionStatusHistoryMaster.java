package com.bank.ledger.engine.entity.master;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "transaction_status_history")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TransactionStatusHistoryMaster {

    @Id
    @Column(name = "history_id", length = 64, nullable = false)
    private String historyId;

    @Column(name = "transaction_id", length = 64, nullable = false)
    private String transactionId;

    @Column(name = "from_status", length = 30)
    private String fromStatus;

    @Column(name = "to_status", length = 30, nullable = false)
    private String toStatus;

    @Column(name = "change_reason", length = 50, nullable = false)
    private String changeReason;

    @Column(name = "reason_details", length = 255)
    private String reasonDetails;

    @Column(name = "actor_id", length = 64, nullable = false)
    private String actorId;

    @Column(name = "actor_type", length = 30, nullable = false)
    private String actorType;

    @Column(name = "changed_at", nullable = false)
    private Instant changedAt;
}