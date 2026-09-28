package com.fse.banking.account.service;

import com.fse.banking.account.model.UserEntity;
import com.fse.banking.account.repository.UserRepository;
import com.fse.banking.account.security.JwtProvider;
import com.fse.banking.account.security.RedisSessionStore;
import com.fse.banking.account.security.model.RefreshTokenMetadata;
import com.fse.banking.common.exception.TokenBreachException;
import com.fse.banking.common.exception.UnauthorizedException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Duration;
import java.time.Instant;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TokenRotationServiceTest {

    @Mock
    private RedisSessionStore redisSessionStore;

    @Mock
    private JwtProvider jwtProvider;

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private TokenRotationService tokenRotationService;

    private RefreshTokenMetadata activeToken;
    private RefreshTokenMetadata revokedToken;
    private UserEntity user;

    @BeforeEach
    void setUp() {
        activeToken = RefreshTokenMetadata.builder()
                .tokenId("rt_active_123")
                .userId("USR-100001")
                .sessionId("SESS-ABC")
                .role("ROLE_CUSTOMER")
                .status("ACTIVE")
                .createdAt(Instant.now())
                .expiresAt(Instant.now().plus(Duration.ofDays(7)))
                .build();

        revokedToken = RefreshTokenMetadata.builder()
                .tokenId("rt_revoked_456")
                .userId("USR-100001")
                .sessionId("SESS-ABC")
                .role("ROLE_CUSTOMER")
                .status("REVOKED")
                .createdAt(Instant.now().minus(Duration.ofHours(1)))
                .expiresAt(Instant.now().plus(Duration.ofDays(7)))
                .build();

        user = UserEntity.builder()
                .userId("USR-100001")
                .email("juan.delacruz@example.ph")
                .build();
    }

    @Test
    @DisplayName("Should successfully rotate active refresh token and issue new token pair")
    void testRotateSuccess() {
        when(redisSessionStore.getRefreshToken("rt_active_123")).thenReturn(Optional.of(activeToken));
        when(userRepository.findById("USR-100001")).thenReturn(Optional.of(user));
        when(jwtProvider.generateAccessToken(eq("USR-100001"), eq("juan.delacruz@example.ph"), eq("ROLE_CUSTOMER"), anyString()))
                .thenReturn("new.access.token");
        when(jwtProvider.getAccessTokenExpirationSeconds()).thenReturn(900L);

        TokenRotationService.RotationResult result = tokenRotationService.rotate("rt_active_123");

        assertThat(result).isNotNull();
        assertThat(result.getResponse().getAccessToken()).isEqualTo("new.access.token");
        assertThat(result.getNewRefreshTokenId()).startsWith("rt_");

        verify(redisSessionStore).markRefreshTokenRevoked("rt_active_123");
        verify(redisSessionStore).saveRefreshToken(any(RefreshTokenMetadata.class), eq(Duration.ofDays(7)));
        verify(redisSessionStore).addToTokenFamily(eq("SESS-ABC"), anyString());
        verify(redisSessionStore, never()).purgeEntireTokenFamily(anyString(), anyString());
    }

    @Test
    @DisplayName("Should detect replay breach on revoked token, purge token family, and throw TokenBreachException")
    void testRotateBreachDetection() {
        when(redisSessionStore.getRefreshToken("rt_revoked_456")).thenReturn(Optional.of(revokedToken));

        assertThatThrownBy(() -> tokenRotationService.rotate("rt_revoked_456"))
                .isInstanceOf(TokenBreachException.class)
                .hasMessageContaining("Revoked refresh token presented. Entire session family has been terminated for security.");

        verify(redisSessionStore).purgeEntireTokenFamily("SESS-ABC", "USR-100001");
        verify(redisSessionStore, never()).saveRefreshToken(any(), any());
    }

    @Test
    @DisplayName("Should throw UnauthorizedException when refresh token is missing or blank")
    void testRotateMissingToken() {
        assertThatThrownBy(() -> tokenRotationService.rotate(null))
                .isInstanceOf(UnauthorizedException.class)
                .hasMessageContaining("Refresh token cookie is missing or empty.");

        assertThatThrownBy(() -> tokenRotationService.rotate("   "))
                .isInstanceOf(UnauthorizedException.class);
    }

    @Test
    @DisplayName("Should throw UnauthorizedException when token is not found in Redis")
    void testRotateUnknownToken() {
        when(redisSessionStore.getRefreshToken("rt_unknown")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> tokenRotationService.rotate("rt_unknown"))
                .isInstanceOf(UnauthorizedException.class)
                .hasMessageContaining("Invalid, unknown, or expired refresh token.");
    }
}
