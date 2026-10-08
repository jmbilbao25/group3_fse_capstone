package com.bank.ledger.contracts.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Standard Temenos T24 Transaction Reversal API Request Payload.
 * Reverses a previously settled transfer via compensating double-entry mutation.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class T24ReversalRequest {

    @NotBlank(message = "original_transaction_id is required")
    @JsonProperty("original_transaction_id")
    @JsonAlias({"original_transaction_id", "originalTransactionId", "transaction_id", "transactionId", "ref_number", "referenceNumber"})
    private String originalTransactionId;

    @JsonProperty("reversal_reason")
    @JsonAlias({"reversal_reason", "reversalReason", "reason"})
    @Builder.Default
    private String reversalReason = "ADMIN_REVERSAL";

    @JsonProperty("checker_id")
    @JsonAlias({"checker_id", "checkerId", "supervisor_id", "supervisorId", "approved_by", "approvedBy"})
    private String checkerId;

    @JsonProperty("maker_id")
    @JsonAlias({"maker_id", "makerId", "operator_id", "operatorId", "user_id", "userId"})
    @Builder.Default
    private String makerId = "T24-OPERATOR";

    @JsonProperty("ticket_id")
    @JsonAlias({"ticket_id", "ticketId", "dispute_id", "disputeId"})
    private String ticketId;

    @JsonProperty("notes")
    @JsonAlias({"notes", "remarks", "justification", "comment"})
    private String notes;

    @JsonProperty("ofs_message")
    @JsonAlias({"ofs_message", "ofsMessage", "raw_ofs", "rawOfs"})
    private String ofsMessage;
}
