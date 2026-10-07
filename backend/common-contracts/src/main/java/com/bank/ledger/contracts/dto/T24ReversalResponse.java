package com.bank.ledger.contracts.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * Standard Temenos T24 Transaction Reversal API Response.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class T24ReversalResponse {

    @JsonProperty("reversal_reference")
    private String reversalReference;

    @JsonProperty("original_transaction_id")
    private String originalTransactionId;

    @JsonProperty("status")
    private String status; // REVERSED

    @JsonProperty("reversal_reason")
    private String reversalReason;

    @JsonProperty("amount")
    private BigDecimal amount;

    @JsonProperty("debited_account_id")
    private String debitedAccountId;

    @JsonProperty("debited_balance_after")
    private BigDecimal debitedBalanceAfter;

    @JsonProperty("credited_account_id")
    private String creditedAccountId;

    @JsonProperty("credited_balance_after")
    private BigDecimal creditedBalanceAfter;

    @JsonProperty("ofs_response")
    private String ofsResponse;

    @JsonProperty("timestamp")
    private Instant timestamp;

    @JsonProperty("message")
    private String message;
}
