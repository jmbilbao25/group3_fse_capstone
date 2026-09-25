package com.bank.ledger.contracts.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MutationResponse {

    @JsonProperty("transaction_id")
    private String transactionId;

    @JsonProperty("account_id")
    private String accountId;

    @JsonProperty("status")
    private String status;

    @JsonProperty("mutation_amount")
    private BigDecimal mutationAmount;

    @JsonProperty("balance_before")
    private BigDecimal balanceBefore;

    @JsonProperty("balance_after")
    private BigDecimal balanceAfter;

    @JsonProperty("available_balance")
    private BigDecimal availableBalance;

    @JsonProperty("timestamp")
    private Instant timestamp;

    @JsonProperty("trace_id")
    private String traceId;
}
