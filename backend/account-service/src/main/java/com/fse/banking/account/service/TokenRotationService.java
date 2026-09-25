package com.fse.banking.account.service;

import com.fse.banking.account.dto.TokenRefreshResponse;
import com.fse.banking.account.model.UserEntity;
import com.fse.banking.account.repository.UserRepository;
import com.fse.banking.account.security.JwtProvider;
import com.fse.banking.account.security.RedisSessionStore;
import com.fse.banking.account.security.model.RefreshTokenMetadata;
import com.fse.banking.common.exception.TokenBreachException;
import com.fse.banking.common.exception.UnauthorizedException;
import lombok.Builder;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class TokenRotationService {

    private final RedisSessionStore redisSessionStore;
    private final JwtProvider jwtProvider;
    private final UserRepository userRepository;

    private static final Duration REFRESH_TOKEN_TTL = Duration.ofDays(7);

    @Data
    @Builder
    public static class RotationResult {
        private TokenRefreshResponse response;
        private String newRefreshTokenId;
    }

    public RotationResult rotate(String presentedToken) {
        if (presentedToken == null || presentedToken.isBlank()) {
            throw new UnauthorizedException("Refresh token cookie is missing or empty.");
        }

        RefreshTokenMetadata metadata = redisSessionStore.getRefreshToken(presentedToken)
                .orElseThrow(() -> new UnauthorizedException("Invalid, unknown, or expired refresh token."));

        // Breach Detection Check
        if (metadata.isRevoked()) {
            log.warn("REPLAY ATTACK DETECTED: presented revoked token {} for session {}", presentedToken, metadata.getSessionId());
            redisSessionStore.purgeEntireTokenFamily(metadata.getSessionId(), metadata.getUserId());
            throw new TokenBreachException("Revoked refresh token presented. Entire session family has been terminated for security.");
        }

        // Normal Rotation Flow
        redisSessionStore.markRefreshTokenRevoked(presentedToken);

        String newRefreshTokenId = "rt_" + UUID.randomUUID().toString().replace("-", "");
        RefreshTokenMetadata newMetadata = RefreshTokenMetadata.builder()
                .tokenId(newRefreshTokenId)
                .userId(metadata.getUserId())
                .sessionId(metadata.getSessionId())
                .role(metadata.getRole())
                .status("ACTIVE")
                .parentTokenId(presentedToken)
                .createdAt(Instant.now())
                .expiresAt(Instant.now().plus(REFRESH_TOKEN_TTL))
                .build();

        redisSessionStore.saveRefreshToken(newMetadata, REFRESH_TOKEN_TTL);
        redisSessionStore.addToTokenFamily(metadata.getSessionId(), newRefreshTokenId);

        String email = userRepository.findById(metadata.getUserId())
                .map(UserEntity::getEmail)
                .orElse("user@banking.ph");

        String jti = UUID.randomUUID().toString();
        String newAccessToken = jwtProvider.generateAccessToken(metadata.getUserId(), email, metadata.getRole(), jti);

        log.info("Refresh token rotated successfully for user {} in session {}", metadata.getUserId(), metadata.getSessionId());

        TokenRefreshResponse response = TokenRefreshResponse.builder()
                .accessToken(newAccessToken)
                .tokenType("Bearer")
                .expiresInSeconds(jwtProvider.getAccessTokenExpirationSeconds())
                .build();

        return RotationResult.builder()
                .response(response)
                .newRefreshTokenId(newRefreshTokenId)
                .build();
    }
}
