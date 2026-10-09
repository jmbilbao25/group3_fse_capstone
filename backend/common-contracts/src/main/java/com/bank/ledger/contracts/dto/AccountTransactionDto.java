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
public class AccountTransactionDto {

    @JsonProperty("transaction_id")
    private String transactionId;

    @JsonProperty("source_account_id")
    private String sourceAccountId;

    @JsonProperty("target_account_id")
    private String targetAccountId;

    @JsonProperty("amount")
    private BigDecimal amount;

    @JsonProperty("currency")
    private String currency;

    @JsonProperty("transaction_type")
    private String transactionType;

    @JsonProperty("status")
    private String status;

    @JsonProperty("memo")
    private String memo;

    @JsonProperty("created_at")
    private Instant createdAt;
}