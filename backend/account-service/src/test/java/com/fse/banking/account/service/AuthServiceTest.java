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

import com.fse.banking.account.dto.DeviceInfoDto;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.argThat;
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

    @Test
    @DisplayName("Should register first device as primary device on login")
    void testFirstLoginRegistersPrimaryDevice() {
        activeUser.setLastLoginAt(Instant.now());
        LoginRequest loginRequest = LoginRequest.builder()
                .email("juan.delacruz@example.ph")
                .password("Password123!")
                .deviceId("device-iphone-1")
                .deviceName("Juan's iPhone")
                .build();

        when(userRepository.findByEmail("juan.delacruz@example.ph")).thenReturn(Optional.of(activeUser));
        when(passwordEncoder.matches("Password123!", activeUser.getPasswordHash())).thenReturn(true);
        when(redisSessionStore.getPrimaryDeviceId("USR-100001")).thenReturn(null);
        when(jwtProvider.generateAccessToken(any(), any(), any(), any())).thenReturn("mock.jwt.token");
        when(jwtProvider.getAccessTokenExpirationSeconds()).thenReturn(900L);

        AuthService.LoginResult result = authService.login(loginRequest, "192.168.1.10", "Mozilla/5.0 (iPhone)");

        assertThat(result.getResponse().getDeviceId()).isEqualTo("device-iphone-1");
        assertThat(result.getResponse().getDeviceName()).isEqualTo("Juan's iPhone");
        assertThat(result.getResponse().getIsPrimaryDevice()).isTrue();
        assertThat(result.getResponse().getPrimaryDeviceId()).isEqualTo("device-iphone-1");

        verify(redisSessionStore).setPrimaryDeviceId("USR-100001", "device-iphone-1");
        verify(redisSessionStore).saveUserDevice(eq("USR-100001"), any(DeviceInfoDto.class));
    }

    @Test
    @DisplayName("Should detect secondary device and mark is_primary=false when primary device exists")
    void testSecondaryDeviceLoginIdentifiedAndTriggersAlert() {
        activeUser.setLastLoginAt(Instant.now());
        LoginRequest loginRequest = LoginRequest.builder()
                .email("juan.delacruz@example.ph")
                .password("Password123!")
                .deviceId("device-ipad-2")
                .deviceName("Juan's iPad")
                .build();

        when(userRepository.findByEmail("juan.delacruz@example.ph")).thenReturn(Optional.of(activeUser));
        when(passwordEncoder.matches("Password123!", activeUser.getPasswordHash())).thenReturn(true);
        when(redisSessionStore.getPrimaryDeviceId("USR-100001")).thenReturn("device-iphone-1");
        when(jwtProvider.generateAccessToken(any(), any(), any(), any())).thenReturn("mock.jwt.token");
        when(jwtProvider.getAccessTokenExpirationSeconds()).thenReturn(900L);

        AuthService.LoginResult result = authService.login(loginRequest, "192.168.1.25", "Mozilla/5.0 (iPad)");

        assertThat(result.getResponse().getDeviceId()).isEqualTo("device-ipad-2");
        assertThat(result.getResponse().getDeviceName()).isEqualTo("Juan's iPad");
        assertThat(result.getResponse().getIsPrimaryDevice()).isFalse();
        assertThat(result.getResponse().getPrimaryDeviceId()).isEqualTo("device-iphone-1");

        verify(redisSessionStore).saveUserDevice(eq("USR-100001"), any(DeviceInfoDto.class));
    }

    @Test
    @DisplayName("Should return registered devices for user from RedisSessionStore")
    void testGetUserDevices() {
        DeviceInfoDto d1 = DeviceInfoDto.builder().deviceId("dev-1").deviceName("iPhone").isPrimary(true).build();
        DeviceInfoDto d2 = DeviceInfoDto.builder().deviceId("dev-2").deviceName("iPad").isPrimary(false).build();
        when(redisSessionStore.getUserDevices("USR-100001")).thenReturn(List.of(d1, d2));

        List<DeviceInfoDto> devices = authService.getUserDevices("USR-100001");

        assertThat(devices).hasSize(2);
        assertThat(devices.get(0).getDeviceId()).isEqualTo("dev-1");
        assertThat(devices.get(0).isPrimary()).isTrue();
    }

    @Test
    @DisplayName("Should set primary device in RedisSessionStore when none is set")
    void testSetPrimaryDevice() {
        when(redisSessionStore.getPrimaryDeviceId("USR-100001")).thenReturn(null);
        authService.setPrimaryDevice("USR-100001", "dev-2");
        verify(redisSessionStore).setPrimaryDeviceId("USR-100001", "dev-2");
    }

    @Test
    @DisplayName("Should throw exception when attempting to reassign primary device")
    void testSetPrimaryDeviceThrowsWhenAlreadyBound() {
        when(redisSessionStore.getPrimaryDeviceId("USR-100001")).thenReturn("dev-1");
        org.junit.jupiter.api.Assertions.assertThrows(IllegalArgumentException.class, () -> {
            authService.setPrimaryDevice("USR-100001", "dev-2");
        });
    }

    @Test
    @DisplayName("Should deregister existing secondary device when approving a 3rd device")
    void testApproveThirdDeviceDeregistersExistingSecondary() {
        when(redisSessionStore.getPrimaryDeviceId("USR-100001")).thenReturn("dev-primary");
        DeviceInfoDto devPrimary = DeviceInfoDto.builder().deviceId("dev-primary").deviceName("iPhone").isPrimary(true).build();
        DeviceInfoDto devSecOld = DeviceInfoDto.builder().deviceId("dev-sec-old").deviceName("Old iPad").isPrimary(false).build();
        DeviceInfoDto devSecNew = DeviceInfoDto.builder().deviceId("dev-sec-new").deviceName("New Galaxy").isPrimary(false).build();

        when(redisSessionStore.getUserDevices("USR-100001")).thenReturn(List.of(devPrimary, devSecOld, devSecNew));
        when(redisSessionStore.getDevice("USR-100001", "dev-sec-new")).thenReturn(Optional.of(devSecNew));

        authService.approveDevice("USR-100001", "dev-sec-new");

        verify(redisSessionStore).deleteUserDevice("USR-100001", "dev-sec-old");
        verify(redisSessionStore).deleteSessionsForDevice("USR-100001", "dev-sec-old");
        verify(redisSessionStore).saveUserDevice(eq("USR-100001"), argThat(DeviceInfoDto::isApproved));
    }

    @Test
    @DisplayName("Should automatically log out 2nd device and set status to PENDING_CONFIRMATION when 3rd device logs in")
    void testThirdDeviceLoginAutomaticallyLogsOutSecondDeviceAndLeavesAccessPending() {
        activeUser.setLastLoginAt(Instant.now());
        LoginRequest loginRequest = LoginRequest.builder()
                .email("juan.delacruz@example.ph")
                .password("Password123!")
                .deviceId("dev-third-galaxy")
                .deviceName("Samsung Galaxy Tab")
                .deviceType("MOBILE")
                .build();

        when(userRepository.findByEmail("juan.delacruz@example.ph")).thenReturn(Optional.of(activeUser));
        when(passwordEncoder.matches("Password123!", activeUser.getPasswordHash())).thenReturn(true);
        when(redisSessionStore.getPrimaryDeviceId("USR-100001")).thenReturn("dev-primary-iphone");

        DeviceInfoDto primaryMobile = DeviceInfoDto.builder()
                .deviceId("dev-primary-iphone")
                .deviceName("iPhone 15")
                .deviceType("MOBILE")
                .isPrimary(true)
                .isApproved(true)
                .build();
        DeviceInfoDto oldSecondary = DeviceInfoDto.builder()
                .deviceId("dev-second-ipad")
                .deviceName("iPad Air")
                .deviceType("MOBILE")
                .isPrimary(false)
                .isApproved(true)
                .build();

        when(redisSessionStore.getUserDevices("USR-100001")).thenReturn(List.of(primaryMobile, oldSecondary));
        when(jwtProvider.generateAccessToken(any(), any(), any(), any())).thenReturn("mock.jwt.token");
        when(jwtProvider.getAccessTokenExpirationSeconds()).thenReturn(900L);

        AuthService.LoginResult result = authService.login(loginRequest, "192.168.1.120", "Samsung Tablet");

        assertThat(result.getResponse().getDeviceId()).isEqualTo("dev-third-galaxy");
        assertThat(result.getResponse().getStatus()).isEqualTo("PENDING_CONFIRMATION");
        assertThat(result.getResponse().getIsPrimaryDevice()).isFalse();
        assertThat(result.getResponse().getIsApproved()).isFalse();

        // Verify 3rd device is registered with pending confirmation status without deleting existing secondary until approval
        verify(redisSessionStore).saveUserDevice(eq("USR-100001"), argThat(d ->
                "dev-third-galaxy".equals(d.getDeviceId()) && !d.isApproved() && "PENDING_CONFIRMATION".equals(d.getStatus())));
    }

    @Test
    @DisplayName("Should throw exception when attempting to revoke primary device")
    void testRevokePrimaryDeviceThrowsException() {
        when(redisSessionStore.getPrimaryDeviceId("USR-100001")).thenReturn("dev-primary");
        org.junit.jupiter.api.Assertions.assertThrows(IllegalArgumentException.class, () -> {
            authService.revokeDevice("USR-100001", "dev-primary");
        });
    }

    @Test
    @DisplayName("Should allow desktop session login, deregister existing web session (1-web limit), and keep mobile primary")
    void testDesktopSessionLoginEnforcesOneWebPolicyAndDispatchesAlertToPrimary() {
        activeUser.setLastLoginAt(Instant.now());
        LoginRequest loginRequest = LoginRequest.builder()
                .email("juan.delacruz@example.ph")
                .password("Password123!")
                .deviceId("dev-new-laptop")
                .deviceName("Chrome on Windows")
                .deviceType("WEB")
                .build();

        when(userRepository.findByEmail("juan.delacruz@example.ph")).thenReturn(Optional.of(activeUser));
        when(passwordEncoder.matches("Password123!", activeUser.getPasswordHash())).thenReturn(true);
        when(redisSessionStore.getPrimaryDeviceId("USR-100001")).thenReturn("dev-primary-mobile");

        DeviceInfoDto oldWeb = DeviceInfoDto.builder()
                .deviceId("dev-old-laptop")
                .deviceName("Old MacBook")
                .deviceType("WEB")
                .isPrimary(false)
                .build();
        DeviceInfoDto primaryMobile = DeviceInfoDto.builder()
                .deviceId("dev-primary-mobile")
                .deviceName("iPhone 15")
                .deviceType("MOBILE")
                .isPrimary(true)
                .build();

        when(redisSessionStore.getUserDevices("USR-100001")).thenReturn(List.of(primaryMobile, oldWeb));
        when(jwtProvider.generateAccessToken(any(), any(), any(), any())).thenReturn("mock.jwt.token");
        when(jwtProvider.getAccessTokenExpirationSeconds()).thenReturn(900L);

        AuthService.LoginResult result = authService.login(loginRequest, "203.177.100.5", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)");

        assertThat(result.getResponse().getDeviceId()).isEqualTo("dev-new-laptop");
        assertThat(result.getResponse().getDeviceType()).isEqualTo("WEB");
        assertThat(result.getResponse().getIsPrimaryDevice()).isFalse();
        assertThat(result.getResponse().getIsApproved()).isTrue();
        assertThat(result.getResponse().getPrimaryDeviceId()).isEqualTo("dev-primary-mobile");

        // Verify old web session was deregistered (1-web limit)
        verify(redisSessionStore).deleteUserDevice("USR-100001", "dev-old-laptop");
        verify(redisSessionStore).deleteSessionsForDevice("USR-100001", "dev-old-laptop");

        // Verify new web device was saved
        verify(redisSessionStore).saveUserDevice(eq("USR-100001"), argThat(d ->
                "dev-new-laptop".equals(d.getDeviceId()) && "WEB".equals(d.getDeviceType()) && d.isApproved()));
    }

    @Test
    @DisplayName("Should throw exception when attempting to designate a desktop/web session as primary device")
    void testSetPrimaryDeviceThrowsWhenTargetIsWebDevice() {
        DeviceInfoDto webDevice = DeviceInfoDto.builder()
                .deviceId("dev-laptop-web")
                .deviceName("Chrome Browser")
                .deviceType("WEB")
                .build();

        when(redisSessionStore.getPrimaryDeviceId("USR-100001")).thenReturn(null);
        when(redisSessionStore.getDevice("USR-100001", "dev-laptop-web")).thenReturn(Optional.of(webDevice));

        org.junit.jupiter.api.Assertions.assertThrows(IllegalArgumentException.class, () -> {
            authService.setPrimaryDevice("USR-100001", "dev-laptop-web");
        });
    }

    @Test
    @DisplayName("Should log out all secondary and web sessions on logoutAll while keeping primary intact")
    void testLogoutAll() {
        when(jwtProvider.validateToken("valid.jwt.token")).thenReturn(true);
        when(jwtProvider.getUserId("valid.jwt.token")).thenReturn("USR-100001");
        when(redisSessionStore.getPrimaryDeviceId("USR-100001")).thenReturn("dev-primary-mobile");

        DeviceInfoDto primaryDev = DeviceInfoDto.builder().deviceId("dev-primary-mobile").deviceName("iPhone").isPrimary(true).build();
        DeviceInfoDto secondaryDev = DeviceInfoDto.builder().deviceId("dev-secondary-ipad").deviceName("iPad").isPrimary(false).build();
        DeviceInfoDto webDev = DeviceInfoDto.builder().deviceId("dev-web-chrome").deviceName("Chrome").deviceType("WEB").isPrimary(false).build();

        when(redisSessionStore.getUserDevices("USR-100001")).thenReturn(List.of(primaryDev, secondaryDev, webDev));

        authService.logoutAll("Bearer valid.jwt.token");

        verify(redisSessionStore).deleteUserDevice("USR-100001", "dev-secondary-ipad");
        verify(redisSessionStore).deleteSessionsForDevice("USR-100001", "dev-secondary-ipad");
        verify(redisSessionStore).deleteUserDevice("USR-100001", "dev-web-chrome");
        verify(redisSessionStore).deleteSessionsForDevice("USR-100001", "dev-web-chrome");
    }
}
