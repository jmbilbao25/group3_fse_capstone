package com.bank.ledger.contracts.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReversalActionRequest {

    @JsonProperty("originalTransactionId")
    @JsonAlias({"originalTransactionId", "original_transaction_id", "transactionId", "transaction_id"})
    private String originalTransactionId;

    @JsonProperty("reason")
    @JsonAlias({"reason", "disputeReason", "dispute_reason"})
    private String reason;

    @JsonProperty("makerId")
    @JsonAlias({"makerId", "maker_id"})
    private String makerId;

    @JsonProperty("reversalRequestId")
    @JsonAlias({"reversalRequestId", "reversal_request_id", "ticketId", "ticket_id"})
    private String reversalRequestId;

    @JsonProperty("checkerId")
    @JsonAlias({"checkerId", "checker_id"})
    private String checkerId;

    @JsonProperty("checkerNotes")
    @JsonAlias({"checkerNotes", "checker_notes", "notes"})
    private String checkerNotes;

    @JsonProperty("rejectionReason")
    @JsonAlias({"rejectionReason", "rejection_reason"})
    private String rejectionReason;
}