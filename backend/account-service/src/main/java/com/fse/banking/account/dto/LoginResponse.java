package com.fse.banking.account.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class LoginResponse {

    @JsonProperty("status")
    @Builder.Default
    private String status = "AUTHENTICATED";

    @JsonProperty("access_token")
    private String accessToken;

    @JsonProperty("token_type")
    private String tokenType;

    @JsonProperty("expires_in_seconds")
    private long expiresInSeconds;

    @JsonProperty("role")
    private String role;

    @JsonProperty("user_id")
    private String userId;

    @JsonProperty("masked_email")
    private String maskedEmail;

    @JsonProperty("device_id")
    private String deviceId;

    @JsonProperty("device_name")
    private String deviceName;

    @JsonProperty("is_primary_device")
    private Boolean isPrimaryDevice;

    @JsonProperty("is_approved")
    private Boolean isApproved;

    @JsonProperty("primary_device_id")
    private String primaryDeviceId;

    @JsonProperty("device_type")
    private String deviceType;
}
