package com.bank.ledger.contracts.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReversalTicketDto {

    @JsonProperty("ticketId")
    private String ticketId;

    @JsonProperty("originalTransactionId")
    private String originalTransactionId;

    @JsonProperty("makerId")
    private String makerId;

    @JsonProperty("checkerId")
    private String checkerId;

    @JsonProperty("status")
    private String status;

    @JsonProperty("disputeReason")
    private String disputeReason;

    @JsonProperty("makerNotes")
    private String makerNotes;

    @JsonProperty("checkerNotes")
    private String checkerNotes;

    @JsonProperty("reversalTransactionId")
    private String reversalTransactionId;

    @JsonProperty("createdAt")
    private Instant createdAt;

    @JsonProperty("resolvedAt")
    private Instant resolvedAt;
}