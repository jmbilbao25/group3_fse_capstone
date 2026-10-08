package com.bank.ledger.contracts.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * Standard Temenos T24 Funds Transfer API Response.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class T24FundsTransferResponse {

    @JsonProperty("t24_reference")
    private String t24Reference;

    @JsonProperty("status")
    private String status; // COMMITTED, PENDING_APPROVAL, REJECTED, FAILED

    @JsonProperty("debit_account_id")
    private String debitAccountId;

    @JsonProperty("debit_amount")
    private BigDecimal debitAmount;

    @JsonProperty("debit_balance_after")
    private BigDecimal debitBalanceAfter;

    @JsonProperty("credit_account_id")
    private String creditAccountId;

    @JsonProperty("credit_amount")
    private BigDecimal creditAmount;

    @JsonProperty("credit_balance_after")
    private BigDecimal creditBalanceAfter;

    @JsonProperty("currency")
    private String currency;

    @JsonProperty("value_date")
    private String valueDate;

    @JsonProperty("ofs_response")
    private String ofsResponse;

    @JsonProperty("timestamp")
    private Instant timestamp;

    @JsonProperty("message")
    private String message;
}
