package com.fse.banking.account.service;

import com.fse.banking.account.dto.LoginRequest;
import com.fse.banking.account.dto.LoginResponse;
import com.fse.banking.account.dto.RegisterRequest;
import com.fse.banking.account.dto.RegisterResponse;
import com.fse.banking.account.model.UserEntity;
import com.fse.banking.account.repository.UserRepository;
import com.fse.banking.account.security.JwtProvider;
import com.fse.banking.account.security.RedisSessionStore;
import com.fse.banking.account.security.model.RefreshTokenMetadata;
import com.fse.banking.account.security.model.SessionMetadata;
import com.fse.banking.common.enums.UserRole;
import com.fse.banking.common.enums.UserStatus;
import com.fse.banking.common.exception.ConflictException;
import com.fse.banking.common.exception.ForbiddenException;
import com.fse.banking.common.exception.LockedUserException;
import com.fse.banking.common.exception.UnauthorizedException;
import lombok.Builder;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtProvider jwtProvider;
    private final RedisSessionStore redisSessionStore;

    private static final int MAX_FAILED_ATTEMPTS = 5;
    private static final Duration REFRESH_TOKEN_TTL = Duration.ofDays(7);

    @Data
    @Builder
    public static class LoginResult {
        private LoginResponse response;
        private String refreshTokenId;
    }

    @Transactional
    public RegisterResponse register(RegisterRequest request) {
        log.info("Processing registration for email: {}", request.getEmail());

        if (userRepository.existsByEmail(request.getEmail())) {
            throw new ConflictException("Email " + request.getEmail() + " is already registered.");
        }
        if (userRepository.existsByPhoneNumber(request.getPhoneNumber())) {
            throw new ConflictException("Phone number " + request.getPhoneNumber() + " is already registered.");
        }
        String formattedGovId = request.getGovernmentIdType() + "-" + request.getGovernmentIdNumber();
        if (userRepository.existsByGovernmentId(formattedGovId) || userRepository.existsByGovernmentId(request.getGovernmentIdNumber())) {
            throw new ConflictException("Government ID " + request.getGovernmentIdNumber() + " is already registered.");
        }

        String userId = "USR-" + (100000 + ThreadLocalRandom.current().nextInt(900000));

        UserEntity user = UserEntity.builder()
                .userId(userId)
                .firstName(request.getFirstName())
                .middleName(request.getMiddleName())
                .lastName(request.getLastName())
                .email(request.getEmail())
                .phoneNumber(request.getPhoneNumber())
                .dob(request.getDateOfBirth())
                .governmentId(request.getGovernmentIdType() + "-" + request.getGovernmentIdNumber())
                .role(UserRole.CUSTOMER)
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .maxConcurrentSessions(3)
                .failedLoginAttempts(0)
                .status(UserStatus.ACTIVE)
                .build();

        UserEntity saved = userRepository.save(user);
        log.info("User registered successfully: userId={}", saved.getUserId());

        return RegisterResponse.builder()
                .userId(saved.getUserId())
                .email(saved.getEmail())
                .kycStatus("PENDING")
                .createdAt(saved.getCreatedAt())
                .build();
    }

    @Transactional
    public LoginResult login(LoginRequest request, String clientIp, String userAgent) {
        log.info("Processing login attempt for: {}", request.getEmail());

        UserEntity user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new UnauthorizedException("Invalid email or password."));

        if (user.getStatus() == UserStatus.LOCKED) {
            throw new LockedUserException("User account is locked due to security policy. Contact customer support.");
        }
        if (user.getStatus() == UserStatus.SUSPENDED) {
            throw new ForbiddenException("User account is suspended. Contact customer support.");
        }

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            int attempts = user.getFailedLoginAttempts() + 1;
            user.setFailedLoginAttempts(attempts);
            if (attempts >= MAX_FAILED_ATTEMPTS) {
                user.setStatus(UserStatus.LOCKED);
                log.warn("Account {} locked due to {} consecutive failed login attempts", user.getUserId(), attempts);
            }
            userRepository.save(user);
            throw new UnauthorizedException("Invalid email or password.");
        }

        // Reset failed login counter on success
        if (user.getFailedLoginAttempts() > 0) {
            user.setFailedLoginAttempts(0);
            userRepository.save(user);
        }

        String jti = UUID.randomUUID().toString();
        String roleAuthority = user.getRole().getAuthority();
        String accessToken = jwtProvider.generateAccessToken(user.getUserId(), user.getEmail(), roleAuthority, jti);

        // Enforce max concurrent sessions in Redis
        redisSessionStore.registerSessionToken(user.getUserId(), jti, user.getMaxConcurrentSessions());

        String sessionId = "SESS-" + UUID.randomUUID();
        String refreshTokenId = "rt_" + UUID.randomUUID().toString().replace("-", "");

        SessionMetadata sessionMetadata = SessionMetadata.builder()
                .sessionId(sessionId)
                .userId(user.getUserId())
                .activeRefreshTokenId(refreshTokenId)
                .clientIp(clientIp)
                .userAgent(userAgent)
                .createdAt(Instant.now())
                .build();
        redisSessionStore.saveSession(user.getUserId(), sessionId, sessionMetadata, REFRESH_TOKEN_TTL);

        RefreshTokenMetadata tokenMetadata = RefreshTokenMetadata.builder()
                .tokenId(refreshTokenId)
                .userId(user.getUserId())
                .sessionId(sessionId)
                .role(roleAuthority)
                .status("ACTIVE")
                .parentTokenId(null)
                .createdAt(Instant.now())
                .expiresAt(Instant.now().plus(REFRESH_TOKEN_TTL))
                .build();
        redisSessionStore.saveRefreshToken(tokenMetadata, REFRESH_TOKEN_TTL);
        redisSessionStore.addToTokenFamily(sessionId, refreshTokenId);

        LoginResponse loginResponse = LoginResponse.builder()
                .accessToken(accessToken)
                .tokenType("Bearer")
                .expiresInSeconds(jwtProvider.getAccessTokenExpirationSeconds())
                .role(roleAuthority)
                .userId(user.getUserId())
                .build();

        return LoginResult.builder()
                .response(loginResponse)
                .refreshTokenId(refreshTokenId)
                .build();
    }

    public void logout(String authHeader, String refreshTokenCookie) {
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            if (jwtProvider.validateToken(token)) {
                String jti = jwtProvider.getJti(token);
                String userId = jwtProvider.getUserId(token);
                long remainingTtl = jwtProvider.getRemainingTtlSeconds(token);
                redisSessionStore.blacklistToken(jti, remainingTtl);
                redisSessionStore.removeSessionToken(userId, jti);
                log.info("Access token jti {} blacklisted on logout for user {}", jti, userId);
            }
        }

        if (refreshTokenCookie != null && !refreshTokenCookie.isBlank()) {
            redisSessionStore.getRefreshToken(refreshTokenCookie).ifPresent(metadata -> {
                redisSessionStore.purgeEntireTokenFamily(metadata.getSessionId(), metadata.getUserId());
                log.info("Token family for session {} purged on logout", metadata.getSessionId());
            });
        }
    }
}
