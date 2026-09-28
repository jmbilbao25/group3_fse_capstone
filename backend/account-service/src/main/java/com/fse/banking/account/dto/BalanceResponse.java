package com.fse.banking.account.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.math.BigDecimal;
import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BalanceResponse implements Serializable {

    @JsonProperty("account_id")
    private String accountId;

    @JsonProperty("account_type")
    private String accountType;

    @JsonProperty("currency")
    @Builder.Default
    private String currency = "PHP";

    @JsonProperty("current_balance")
    private BigDecimal currentBalance;

    @JsonProperty("held_balance")
    private BigDecimal heldBalance;

    @JsonProperty("available_balance")
    private BigDecimal availableBalance;

    @JsonProperty("status")
    private String status;

    @JsonProperty("cached")
    private boolean cached;

    @JsonProperty("last_updated")
    private Instant lastUpdated;
}
