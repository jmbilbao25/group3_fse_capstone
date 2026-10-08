package com.fse.banking.account.security.model;

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
public class SessionMetadata implements Serializable {

    private String sessionId;
    private String userId;
    private String activeRefreshTokenId;
    private String clientIp;
    private String userAgent;
    private String deviceId;
    private String deviceName;
    private Instant createdAt;
}
