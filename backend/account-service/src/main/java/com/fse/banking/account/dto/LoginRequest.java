package com.fse.banking.account.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@com.fasterxml.jackson.annotation.JsonIgnoreProperties(ignoreUnknown = true)
public class LoginRequest {

    @NotBlank(message = "Email is required")
    @Email(message = "Invalid email format")
    private String email;

    @NotBlank(message = "Password is required")
    private String password;

    @com.fasterxml.jackson.annotation.JsonProperty("device_id")
    @com.fasterxml.jackson.annotation.JsonAlias({"deviceId"})
    private String deviceId;

    @com.fasterxml.jackson.annotation.JsonProperty("device_name")
    @com.fasterxml.jackson.annotation.JsonAlias({"deviceName"})
    private String deviceName;

    @com.fasterxml.jackson.annotation.JsonProperty("device_type")
    @com.fasterxml.jackson.annotation.JsonAlias({"deviceType"})
    private String deviceType;

    @com.fasterxml.jackson.annotation.JsonProperty("is_device_compromised")
    @com.fasterxml.jackson.annotation.JsonAlias({"isDeviceCompromised", "deviceCompromised"})
    private Boolean isDeviceCompromised;

    @com.fasterxml.jackson.annotation.JsonProperty("compromise_reasons")
    @com.fasterxml.jackson.annotation.JsonAlias({"compromiseReasons"})
    private String compromiseReasons;
}
