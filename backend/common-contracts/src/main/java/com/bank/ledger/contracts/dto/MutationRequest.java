package com.bank.ledger.contracts.dto;

import com.bank.ledger.contracts.enums.EventType;
import com.bank.ledger.contracts.enums.MutationType;
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
 * Strict JSR-380 Payload for the Core Mutation Perimeter (/api/v1/ledger/mutate).
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MutationRequest {

    @NotBlank(message = "transaction_id (idempotency key) is mandatory")
    @JsonProperty("transaction_id")
    private String transactionId;

    @NotBlank(message = "account_id is mandatory")
    @JsonProperty("account_id")
    private String accountId;

    @JsonProperty("target_account_id")
    private String targetAccountId;

    @NotNull(message = "event_type is mandatory")
    @JsonProperty("event_type")
    private EventType eventType;

    @NotNull(message = "mutation_type is mandatory")
    @JsonProperty("mutation_type")
    private MutationType mutationType;

    /**
     * Strict Precision Constraint:
     * Decimal format with maximum precision of 18 digits and exactly 4 decimal places.
     * Negative values are blocked at perimeter via @Positive.
     */
    @NotNull(message = "mutation_amount cannot be null")
    @Positive(message = "mutation_amount must be strictly positive")
    @Digits(integer = 14, fraction = 4, message = "mutation_amount must match precision with maximum 14 integer digits and 4 decimal places")
    @JsonProperty("mutation_amount")
    private BigDecimal mutationAmount;

    @NotBlank(message = "initiator_user_id (maker) is mandatory")
    @JsonProperty("initiator_user_id")
    private String initiatorUserId;

    @JsonProperty("approved_by_user_id")
    private String approvedByUserId;
}
