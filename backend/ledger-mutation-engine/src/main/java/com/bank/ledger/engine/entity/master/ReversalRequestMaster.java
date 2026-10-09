package com.bank.ledger.engine.entity.master;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "reversal_requests")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReversalRequestMaster {

    @Id
    @Column(name = "ticket_id", length = 64, nullable = false)
    private String ticketId;

    @Column(name = "original_transaction_id", length = 64, nullable = false)
    private String originalTransactionId;

    @Column(name = "maker_id", length = 64, nullable = false)
    private String makerId;

    @Column(name = "checker_id", length = 64)
    private String checkerId;

    @Column(name = "status", length = 30, nullable = false)
    private String status;

    @Column(name = "dispute_reason", length = 100, nullable = false)
    private String disputeReason;

    @Column(name = "maker_notes", length = 255)
    private String makerNotes;

    @Column(name = "checker_notes", length = 255)
    private String checkerNotes;

    @Column(name = "reversal_transaction_id", length = 64)
    private String reversalTransactionId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "resolved_at")
    private Instant resolvedAt;
}