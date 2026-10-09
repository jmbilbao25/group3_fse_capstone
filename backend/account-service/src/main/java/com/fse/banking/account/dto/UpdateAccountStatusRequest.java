package com.fse.banking.account.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fse.banking.common.enums.AccountStatus;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class UpdateAccountStatusRequest {

    @NotNull(message = "Account status is required")
    @JsonProperty("status")
    private AccountStatus status;

    private String reason;
    private String memo;

    @JsonProperty("actioned_by_user_id")
    private String actionedByUserId;
}

