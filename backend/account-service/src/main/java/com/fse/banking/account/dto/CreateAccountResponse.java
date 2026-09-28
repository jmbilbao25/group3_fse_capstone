package com.fse.banking.account.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fse.banking.common.enums.AccountType;
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
public class CreateAccountResponse {

    @JsonProperty("account_id")
    private String accountId;

    @JsonProperty("account_number")
    private String accountNumber;

    @JsonProperty("user_id")
    private String userId;

    @JsonProperty("account_type")
    private AccountType accountType;

    @JsonProperty("status")
    private String status;

    @JsonProperty("initial_balance")
    private BigDecimal initialBalance;

    @JsonProperty("created_at")
    private Instant createdAt;
}
