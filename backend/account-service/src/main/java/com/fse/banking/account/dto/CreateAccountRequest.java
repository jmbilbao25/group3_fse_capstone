package com.fse.banking.account.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fse.banking.common.enums.AccountType;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CreateAccountRequest {

    @NotBlank(message = "User ID is required")
    @JsonProperty("user_id")
    private String userId;

    @NotNull(message = "Account type is required")
    @JsonProperty("account_type")
    private AccountType accountType;

    @NotNull(message = "Initial deposit is required")
    @DecimalMin(value = "0.0000", message = "Initial deposit cannot be negative")
    @Digits(integer = 14, fraction = 4, message = "Numeric value out of bounds (<14 digits>.<4 digits> expected)")
    @JsonProperty("initial_deposit")
    private BigDecimal initialDeposit;

    @NotBlank(message = "Currency is required")
    @JsonProperty("currency")
    @Builder.Default
    private String currency = "PHP";
}
