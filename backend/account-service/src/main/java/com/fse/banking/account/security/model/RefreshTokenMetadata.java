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
public class RefreshTokenMetadata implements Serializable {

    private String tokenId;
    private String userId;
    private String sessionId;
    private String role;
    private String status; // "ACTIVE" or "REVOKED"
    private String parentTokenId;
    private Instant createdAt;
    private Instant expiresAt;

    public boolean isActive() {
        return "ACTIVE".equalsIgnoreCase(this.status);
    }

    public boolean isRevoked() {
        return "REVOKED".equalsIgnoreCase(this.status);
    }
}
