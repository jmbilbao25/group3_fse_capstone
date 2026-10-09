package com.fse.banking.account.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RegisterResponse {

    @JsonProperty("user_id")
    private String userId;

    @JsonProperty("email")
    private String email;

    @JsonProperty("masked_email")
    private String maskedEmail;

    @JsonProperty("kyc_status")
    private String kycStatus;

    @JsonProperty("created_at")
    private Instant createdAt;
}
