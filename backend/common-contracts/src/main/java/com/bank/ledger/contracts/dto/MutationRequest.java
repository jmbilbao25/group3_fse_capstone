package com.bank.ledger.contracts.dto;

import com.bank.ledger.contracts.enums.EventType;
import com.bank.ledger.contracts.enums.MutationType;
import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Flexible & Strict JSR-380 Payload for the Core Mutation Perimeter.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MutationRequest {

    @JsonProperty("transaction_id")
    @JsonAlias({"transaction_id", "transactionId", "refNumber", "reference_number"})
    private String transactionId;

    @NotBlank(message = "account_id is mandatory")
    @JsonProperty("account_id")
    @JsonAlias({"account_id", "accountId", "from_account_id", "fromAccountId", "fromAccount", "source_account_id", "sourceAccountId"})
    private String accountId;

    @JsonProperty("target_account_id")
    @JsonAlias({"target_account_id", "targetAccountId", "to_account_id", "toAccountId", "toAccount", "destination_account_id", "destinationAccountId"})
    private String targetAccountId;

    @JsonProperty("event_type")
    @JsonAlias({"event_type", "eventType"})
    @Builder.Default
    private EventType eventType = EventType.TRANSFER;

    @JsonProperty("mutation_type")
    @JsonAlias({"mutation_type", "mutationType"})
    @Builder.Default
    private MutationType mutationType = MutationType.TRANSFER;

    @NotNull(message = "mutation_amount cannot be null")
    @Positive(message = "mutation_amount must be strictly positive")
    @Digits(integer = 14, fraction = 4, message = "mutation_amount must match precision with maximum 14 integer digits and 4 decimal places")
    @JsonProperty("mutation_amount")
    @JsonAlias({"mutation_amount", "mutationAmount", "amount"})
    private BigDecimal mutationAmount;

    @JsonProperty("initiator_user_id")
    @JsonAlias({"initiator_user_id", "initiatorUserId", "maker_user_id", "makerUserId", "userId", "user_id"})
    @Builder.Default
    private String initiatorUserId = "U1001";

    @JsonProperty("approved_by_user_id")
    @JsonAlias({"approved_by_user_id", "approvedByUserId", "checker_user_id"})
    private String approvedByUserId;
}
