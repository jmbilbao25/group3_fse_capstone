package com.fse.banking.account.security.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
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
@JsonIgnoreProperties(ignoreUnknown = true)
public class RefreshTokenMetadata implements Serializable {

    private String tokenId;
    private String userId;
    private String sessionId;
    private String role;
    private String status; // "ACTIVE" or "REVOKED"
    private String parentTokenId;
    private Instant createdAt;
    private Instant expiresAt;

    @JsonIgnore
    public boolean isActive() {
        return "ACTIVE".equalsIgnoreCase(this.status);
    }

    @JsonIgnore
    public boolean isRevoked() {
        return "REVOKED".equalsIgnoreCase(this.status);
    }
}
