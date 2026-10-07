package com.fse.banking.account.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@com.fasterxml.jackson.annotation.JsonIgnoreProperties(ignoreUnknown = true)
public class VerifyLoginOtpRequest {

    @NotBlank(message = "User ID is required.")
    @JsonProperty("user_id")
    private String userId;

    @NotBlank(message = "OTP code is required.")
    @Pattern(regexp = "^\\d{6}$", message = "OTP code must be exactly 6 digits.")
    @JsonProperty("otp")
    private String otp;

    @JsonProperty("device_id")
    private String deviceId;

    @JsonProperty("device_name")
    private String deviceName;

    @JsonProperty("device_type")
    private String deviceType;
}
