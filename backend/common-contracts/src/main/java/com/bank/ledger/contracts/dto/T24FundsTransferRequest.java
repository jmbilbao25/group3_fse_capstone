package com.bank.ledger.contracts.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
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
 * Standard Temenos T24 Funds Transfer API Request Payload.
 * Supports both JSON REST invocation and optional OFS command string integration.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class T24FundsTransferRequest {

    @JsonProperty("transaction_reference")
    @JsonAlias({"transaction_reference", "transactionReference", "reference_number", "transaction_id", "transactionId", "refNumber"})
    private String transactionReference;

    @NotBlank(message = "debit_account_id is required")
    @JsonProperty("debit_account_id")
    @JsonAlias({"debit_account_id", "debitAccountId", "from_account_id", "fromAccountId", "source_account_id", "sourceAccountId", "accountId", "account_id"})
    private String debitAccountId;

    @NotBlank(message = "credit_account_id is required")
    @JsonProperty("credit_account_id")
    @JsonAlias({"credit_account_id", "creditAccountId", "to_account_id", "toAccountId", "target_account_id", "targetAccountId", "destination_account_id", "destinationAccountId"})
    private String creditAccountId;

    @NotNull(message = "amount is required")
    @Positive(message = "amount must be strictly positive")
    @Digits(integer = 14, fraction = 4, message = "amount must match precision up to 14 integer digits and 4 decimal places")
    @JsonProperty("amount")
    @JsonAlias({"amount", "mutation_amount", "mutationAmount", "debit_amount", "debitAmount"})
    private BigDecimal amount;

    @JsonProperty("currency")
    @JsonAlias({"currency", "debit_currency", "credit_currency"})
    @Builder.Default
    private String currency = "PHP";

    @JsonProperty("payment_details")
    @JsonAlias({"payment_details", "paymentDetails", "memo", "remarks", "narrative", "description"})
    private String paymentDetails;

    @JsonProperty("value_date")
    @JsonAlias({"value_date", "valueDate"})
    private String valueDate;

    @JsonProperty("customer_id")
    @JsonAlias({"customer_id", "customerId", "user_id", "userId", "initiator_user_id", "initiatorUserId"})
    @Builder.Default
    private String customerId = "T24-USER";

    @JsonProperty("ofs_message")
    @JsonAlias({"ofs_message", "ofsMessage", "raw_ofs", "rawOfs"})
    private String ofsMessage;
}
