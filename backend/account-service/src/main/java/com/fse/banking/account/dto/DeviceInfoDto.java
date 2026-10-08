package com.fse.banking.account.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class DeviceInfoDto implements Serializable {

    @JsonProperty("device_id")
    private String deviceId;

    @JsonProperty("device_name")
    private String deviceName;

    @JsonProperty("device_type")
    private String deviceType;

    @JsonProperty("is_primary")
    private boolean isPrimary;

    @JsonProperty("is_approved")
    private boolean isApproved;

    @JsonProperty("status")
    private String status;

    @JsonProperty("client_ip")
    private String clientIp;

    @JsonProperty("user_agent")
    private String userAgent;

    @JsonProperty("registered_at")
    private Instant registeredAt;

    @JsonProperty("last_login_at")
    private Instant lastLoginAt;

    @JsonProperty("screen_sharing")
    private Boolean screenSharing;
}
