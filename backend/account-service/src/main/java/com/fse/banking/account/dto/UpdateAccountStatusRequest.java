package com.fse.banking.account.dto;

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
public class UpdateAccountStatusRequest {

    @NotNull(message = "Account status is required")
    @JsonProperty("status")
    private AccountStatus status;
}
