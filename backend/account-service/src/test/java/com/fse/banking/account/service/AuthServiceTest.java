package com.fse.banking.account.service;

import com.fse.banking.account.dto.LoginRequest;
import com.fse.banking.account.dto.RegisterRequest;
import com.fse.banking.account.dto.RegisterResponse;
import com.fse.banking.account.dto.VerifyLoginOtpRequest;
import com.fse.banking.account.model.UserEntity;
import com.fse.banking.account.repository.UserRepository;
import com.fse.banking.account.security.JwtProvider;
import com.fse.banking.account.security.RedisSessionStore;
import com.fse.banking.common.enums.UserRole;
import com.fse.banking.common.enums.UserStatus;
import com.fse.banking.common.exception.ConflictException;
import com.fse.banking.common.exception.LockedUserException;
import com.fse.banking.common.exception.UnauthorizedException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.Instant;
import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private JwtProvider jwtProvider;

    @Mock
    private RedisSessionStore redisSessionStore;

    @InjectMocks
    private AuthService authService;

    private RegisterRequest registerRequest;
    private UserEntity activeUser;

    @BeforeEach
    void setUp() {
        registerRequest = RegisterRequest.builder()
                .email("juan.delacruz@example.ph")
                .password("Password123!")
                .firstName("Juan")
                .lastName("Dela Cruz")
                .dateOfBirth(LocalDate.of(1992, 5, 14))
                .phoneNumber("+639171234567")
                .addressLine("123 Ayala Ave, Makati City")
                .governmentIdType("PASSPORT")
                .governmentIdNumber("P9921840A")
                .build();

        activeUser = UserEntity.builder()
                .userId("USR-100001")
                .email("juan.delacruz@example.ph")
                .passwordHash("$2a$10$hashedpassword")
                .role(UserRole.CUSTOMER)
                .status(UserStatus.ACTIVE)
                .maxConcurrentSessions(3)
                .failedLoginAttempts(0)
                .build();
    }

    @Test
    @DisplayName("Should successfully register customer profile and return 201 DTO")
    void testRegisterSuccess() {
        when(userRepository.existsByEmail(anyString())).thenReturn(false);
        when(userRepository.existsByPhoneNumber(anyString())).thenReturn(false);
        when(userRepository.existsByGovernmentId(anyString())).thenReturn(false);
        when(passwordEncoder.encode(anyString())).thenReturn("$2a$10$encodedPassword");
        when(userRepository.save(any(UserEntity.class))).thenAnswer(inv -> inv.getArgument(0));

        RegisterResponse response = authService.register(registerRequest);

        assertThat(response).isNotNull();
        assertThat(response.getEmail()).isEqualTo("juan.delacruz@example.ph");
        assertThat(response.getKycStatus()).isEqualTo("PENDING");
        assertThat(response.getUserId()).startsWith("USR-");
        verify(userRepository).save(any(UserEntity.class));
    }

    @Test
    @DisplayName("Should reject registration when email already exists with 409 Conflict")
    void testRegisterDuplicateEmail() {
        when(userRepository.existsByEmail("juan.delacruz@example.ph")).thenReturn(true);

        assertThatThrownBy(() -> authService.register(registerRequest))
                .isInstanceOf(ConflictException.class)
                .hasMessageContaining("Email juan.delacruz@example.ph is already registered.");
    }

    @Test
    @DisplayName("Should reject registration when phone number already exists with 409 Conflict")
    void testRegisterDuplicatePhone() {
        when(userRepository.existsByEmail(anyString())).thenReturn(false);
        when(userRepository.existsByPhoneNumber("+639171234567")).thenReturn(true);

        assertThatThrownBy(() -> authService.register(registerRequest))
                .isInstanceOf(ConflictException.class)
                .hasMessageContaining("Phone number +639171234567 is already registered.");
    }

    @Test
    @DisplayName("Should reject registration when government ID already exists with 409 Conflict")
    void testRegisterDuplicateGovernmentId() {
        when(userRepository.existsByEmail(anyString())).thenReturn(false);
        when(userRepository.existsByPhoneNumber(anyString())).thenReturn(false);
        when(userRepository.existsByGovernmentId("PASSPORT-P9921840A")).thenReturn(true);

        assertThatThrownBy(() -> authService.register(registerRequest))
                .isInstanceOf(ConflictException.class)
                .hasMessageContaining("Government ID P9921840A is already registered.");
    }

    @Test
    @DisplayName("Should successfully authenticate returning credentials and issue tokens")
    void testLoginSuccess() {
        activeUser.setLastLoginAt(Instant.now());
        LoginRequest loginRequest = LoginRequest.builder()
                .email("juan.delacruz@example.ph")
                .password("Password123!")
                .build();

        when(userRepository.findByEmail("juan.delacruz@example.ph")).thenReturn(Optional.of(activeUser));
        when(passwordEncoder.matches("Password123!", activeUser.getPasswordHash())).thenReturn(true);
        when(jwtProvider.generateAccessToken(eq("USR-100001"), eq("juan.delacruz@example.ph"), eq("ROLE_CUSTOMER"), anyString()))
                .thenReturn("mock.jwt.token");
        when(jwtProvider.getAccessTokenExpirationSeconds()).thenReturn(900L);

        AuthService.LoginResult result = authService.login(loginRequest, "127.0.0.1", "Mozilla/5.0");

        assertThat(result).isNotNull();
        assertThat(result.getResponse().getStatus()).isEqualTo("AUTHENTICATED");
        assertThat(result.getResponse().getAccessToken()).isEqualTo("mock.jwt.token");
        assertThat(result.getResponse().getRole()).isEqualTo("ROLE_CUSTOMER");
        assertThat(result.getRefreshTokenId()).startsWith("rt_");
        verify(redisSessionStore).registerSessionToken(eq("USR-100001"), anyString(), eq(3));
    }

    @Test
    @DisplayName("Should challenge first-time login with MFA_REQUIRED and dispatch OTP without tokens")
    void testFirstTimeLoginRequiresOtp() {
        activeUser.setLastLoginAt(null);
        LoginRequest loginRequest = LoginRequest.builder()
                .email("juan.delacruz@example.ph")
                .password("Password123!")
                .build();

        when(userRepository.findByEmail("juan.delacruz@example.ph")).thenReturn(Optional.of(activeUser));
        when(passwordEncoder.matches("Password123!", activeUser.getPasswordHash())).thenReturn(true);

        AuthService.LoginResult result = authService.login(loginRequest, "127.0.0.1", "Mozilla/5.0");

        assertThat(result).isNotNull();
        assertThat(result.getResponse().getStatus()).isEqualTo("MFA_REQUIRED");
        assertThat(result.getResponse().getUserId()).isEqualTo("USR-100001");
        assertThat(result.getResponse().getMaskedEmail()).isNotNull();
        assertThat(result.getResponse().getAccessToken()).isNull();
        assertThat(result.getRefreshTokenId()).isNull();

        verify(redisSessionStore).storeLoginOtp(eq("USR-100001"), anyString(), any());
    }

    @Test
    @DisplayName("Should successfully verify login OTP and issue JWT tokens")
    void testVerifyLoginOtpSuccess() {
        VerifyLoginOtpRequest verifyRequest = VerifyLoginOtpRequest.builder()
                .userId("USR-100001")
                .otp("123456")
                .build();

        when(userRepository.findById("USR-100001")).thenReturn(Optional.of(activeUser));
        when(redisSessionStore.getLoginOtp("USR-100001")).thenReturn("123456");
        when(jwtProvider.generateAccessToken(eq("USR-100001"), eq("juan.delacruz@example.ph"), eq("ROLE_CUSTOMER"), anyString()))
                .thenReturn("mock.verified.jwt");
        when(jwtProvider.getAccessTokenExpirationSeconds()).thenReturn(900L);

        AuthService.LoginResult result = authService.verifyLoginOtp(verifyRequest, "127.0.0.1", "Mozilla/5.0");

        assertThat(result).isNotNull();
        assertThat(result.getResponse().getStatus()).isEqualTo("AUTHENTICATED");
        assertThat(result.getResponse().getAccessToken()).isEqualTo("mock.verified.jwt");
        assertThat(activeUser.getLastLoginAt()).isNotNull();

        verify(redisSessionStore).clearLoginOtp("USR-100001");
        verify(userRepository).save(activeUser);
    }

    @Test
    @DisplayName("Should increment failed attempts on invalid credentials and throw UnauthorizedException")
    void testLoginBadCredentials() {
        LoginRequest loginRequest = LoginRequest.builder()
                .email("juan.delacruz@example.ph")
                .password("WrongPassword")
                .build();

        when(userRepository.findByEmail("juan.delacruz@example.ph")).thenReturn(Optional.of(activeUser));
        when(passwordEncoder.matches("WrongPassword", activeUser.getPasswordHash())).thenReturn(false);

        assertThatThrownBy(() -> authService.login(loginRequest, "127.0.0.1", "Mozilla/5.0"))
                .isInstanceOf(UnauthorizedException.class)
                .hasMessageContaining("Invalid email or password.");

        assertThat(activeUser.getFailedLoginAttempts()).isEqualTo(1);
        verify(userRepository).save(activeUser);
    }

    @Test
    @DisplayName("Should lock account when consecutive failed login attempts reach 5")
    void testLoginAccountLockoutAfterFiveAttempts() {
        activeUser.setFailedLoginAttempts(4);
        LoginRequest loginRequest = LoginRequest.builder()
                .email("juan.delacruz@example.ph")
                .password("WrongPassword")
                .build();

        when(userRepository.findByEmail("juan.delacruz@example.ph")).thenReturn(Optional.of(activeUser));
        when(passwordEncoder.matches("WrongPassword", activeUser.getPasswordHash())).thenReturn(false);

        assertThatThrownBy(() -> authService.login(loginRequest, "127.0.0.1", "Mozilla/5.0"))
                .isInstanceOf(UnauthorizedException.class);

        assertThat(activeUser.getFailedLoginAttempts()).isEqualTo(5);
        assertThat(activeUser.getStatus()).isEqualTo(UserStatus.LOCKED);
        verify(userRepository).save(activeUser);
    }

    @Test
    @DisplayName("Should immediately reject authentication for locked account")
    void testLoginLockedAccountRejection() {
        activeUser.setStatus(UserStatus.LOCKED);
        LoginRequest loginRequest = LoginRequest.builder()
                .email("juan.delacruz@example.ph")
                .password("Password123!")
                .build();

        when(userRepository.findByEmail("juan.delacruz@example.ph")).thenReturn(Optional.of(activeUser));

        assertThatThrownBy(() -> authService.login(loginRequest, "127.0.0.1", "Mozilla/5.0"))
                .isInstanceOf(LockedUserException.class);
    }

    @Test
    @DisplayName("Should blacklist token on logout")
    void testLogout() {
        String authHeader = "Bearer mock.jwt.token";
        when(jwtProvider.validateToken("mock.jwt.token")).thenReturn(true);
        when(jwtProvider.getJti("mock.jwt.token")).thenReturn("jti-12345");
        when(jwtProvider.getUserId("mock.jwt.token")).thenReturn("USR-100001");
        when(jwtProvider.getRemainingTtlSeconds("mock.jwt.token")).thenReturn(600L);

        authService.logout(authHeader, null);

        verify(redisSessionStore).blacklistToken("jti-12345", 600L);
        verify(redisSessionStore).removeSessionToken("USR-100001", "jti-12345");
    }
}
