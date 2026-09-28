package com.fse.banking.account.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class KycRejectRequest {

    @NotBlank(message = "Rejection reason is required")
    @JsonProperty("reason")
    private String reason;
}
