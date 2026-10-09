package com.fse.banking.account.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fse.banking.account.dto.DeviceInfoDto;
import com.fse.banking.account.dto.LoginRequest;
import com.fse.banking.account.dto.LoginResponse;
import com.fse.banking.account.dto.LogoutResponse;
import com.fse.banking.account.dto.RegisterRequest;
import com.fse.banking.account.dto.RegisterResponse;
import com.fse.banking.account.dto.TokenRefreshResponse;
import com.fse.banking.account.dto.VerifyLoginOtpRequest;
import com.fse.banking.account.exception.GlobalExceptionHandler;
import com.fse.banking.account.security.JwtProvider;
import com.fse.banking.account.service.AuthService;
import com.fse.banking.account.service.TokenRotationService;
import com.fse.banking.common.exception.TokenBreachException;
import jakarta.servlet.http.Cookie;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.notNullValue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = AuthController.class)
@AutoConfigureMockMvc(addFilters = false)
@Import(GlobalExceptionHandler.class)
class AuthControllerWebTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private AuthService authService;

    @MockBean
    private TokenRotationService tokenRotationService;

    @MockBean
    private JwtProvider jwtProvider;

    @Test
    @DisplayName("POST /api/v1/auth/register should return 201 Created on valid input")
    void testRegisterValidInput() throws Exception {
        RegisterRequest request = RegisterRequest.builder()
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

        RegisterResponse response = RegisterResponse.builder()
                .userId("USR-882190")
                .email("juan.delacruz@example.ph")
                .kycStatus("PENDING")
                .createdAt(Instant.now())
                .build();

        when(authService.register(any(RegisterRequest.class))).thenReturn(response);

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.user_id").value("USR-882190"))
                .andExpect(jsonPath("$.email").value("juan.delacruz@example.ph"))
                .andExpect(jsonPath("$.kyc_status").value("PENDING"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/register should return 400 with RFC-7807 when email is invalid")
    void testRegisterInvalidEmail() throws Exception {
        RegisterRequest request = RegisterRequest.builder()
                .email("invalid-email-format")
                .password("short")
                .firstName("Juan")
                .lastName("Dela Cruz")
                .dateOfBirth(LocalDate.of(1992, 5, 14))
                .phoneNumber("+639171234567")
                .addressLine("123 Ayala Ave")
                .governmentIdType("PASSPORT")
                .governmentIdNumber("P9921840A")
                .build();

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.type").value("https://api.banking.capstone/errors/validation-failed"))
                .andExpect(jsonPath("$.invalid_params", notNullValue()));
    }

    @Test
    @DisplayName("POST /api/v1/auth/login should set HttpOnly refresh cookie and return 200 OK")
    void testLoginSetsCookie() throws Exception {
        LoginRequest request = LoginRequest.builder()
                .email("juan.delacruz@example.ph")
                .password("Password123!")
                .build();

        LoginResponse loginResponse = LoginResponse.builder()
                .accessToken("mock.access.token")
                .tokenType("Bearer")
                .expiresInSeconds(900)
                .role("ROLE_CUSTOMER")
                .userId("USR-882190")
                .build();

        AuthService.LoginResult loginResult = AuthService.LoginResult.builder()
                .response(loginResponse)
                .refreshTokenId("rt_9f8c2b4e8a1d0f3c")
                .build();

        when(authService.login(any(LoginRequest.class), anyString(), any())).thenReturn(loginResult);

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(header().string("Set-Cookie", containsString("refresh_token=rt_9f8c2b4e8a1d0f3c")))
                .andExpect(header().string("Set-Cookie", containsString("HttpOnly")))
                .andExpect(header().string("Set-Cookie", containsString("SameSite=Strict")))
                .andExpect(jsonPath("$.access_token").value("mock.access.token"))
                .andExpect(jsonPath("$.role").value("ROLE_CUSTOMER"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/refresh should rotate cookie and return new access token")
    void testRefreshRotatesCookie() throws Exception {
        TokenRefreshResponse refreshResponse = TokenRefreshResponse.builder()
                .accessToken("new.rotated.jwt")
                .tokenType("Bearer")
                .expiresInSeconds(900)
                .build();

        TokenRotationService.RotationResult rotationResult = TokenRotationService.RotationResult.builder()
                .response(refreshResponse)
                .newRefreshTokenId("rt_1a4e7f9c2d5b8e0a")
                .build();

        when(tokenRotationService.rotate(eq("rt_9f8c2b4e8a1d0f3c"))).thenReturn(rotationResult);

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .cookie(new Cookie("refresh_token", "rt_9f8c2b4e8a1d0f3c")))
                .andExpect(status().isOk())
                .andExpect(header().string("Set-Cookie", containsString("refresh_token=rt_1a4e7f9c2d5b8e0a")))
                .andExpect(jsonPath("$.access_token").value("new.rotated.jwt"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/refresh should return 401 on token breach")
    void testRefreshBreachDetection() throws Exception {
        when(tokenRotationService.rotate(eq("rt_stolen_token")))
                .thenThrow(new TokenBreachException("Revoked refresh token presented. Entire session family has been terminated for security."));

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .cookie(new Cookie("refresh_token", "rt_stolen_token")))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.type").value("https://api.retailbank.ph/errors/token-breach-detected"))
                .andExpect(jsonPath("$.title").value("Token Replay Breach Detected"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/logout should clear refresh cookie with Max-Age=0")
    void testLogoutClearsCookie() throws Exception {
        doNothing().when(authService).logout(any(), any());

        mockMvc.perform(post("/api/v1/auth/logout")
                        .header("Authorization", "Bearer mock.jwt.token")
                        .cookie(new Cookie("refresh_token", "rt_1a4e7f9c2d5b8e0a")))
                .andExpect(status().isOk())
                .andExpect(header().string("Set-Cookie", containsString("Max-Age=0")))
                .andExpect(jsonPath("$.message").value("Session terminated successfully. Access token blacklisted and token family revoked."));
    }

    @Test
    @DisplayName("POST /api/v1/auth/verify-login-otp should return 200 and set refresh cookie on valid OTP")
    void testVerifyLoginOtpEndpoint() throws Exception {
        VerifyLoginOtpRequest request = VerifyLoginOtpRequest.builder()
                .userId("USR-882190")
                .otp("123456")
                .build();

        LoginResponse loginResponse = LoginResponse.builder()
                .status("AUTHENTICATED")
                .accessToken("mock.verified.access.token")
                .tokenType("Bearer")
                .expiresInSeconds(900)
                .role("ROLE_CUSTOMER")
                .userId("USR-882190")
                .build();

        AuthService.LoginResult loginResult = AuthService.LoginResult.builder()
                .response(loginResponse)
                .refreshTokenId("rt_verified_998877")
                .build();

        when(authService.verifyLoginOtp(any(VerifyLoginOtpRequest.class), anyString(), any())).thenReturn(loginResult);

        mockMvc.perform(post("/api/v1/auth/verify-login-otp")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(header().string("Set-Cookie", containsString("refresh_token=rt_verified_998877")))
                .andExpect(jsonPath("$.status").value("AUTHENTICATED"))
                .andExpect(jsonPath("$.access_token").value("mock.verified.access.token"))
                .andExpect(jsonPath("$.user_id").value("USR-882190"));
    }

    @Test
    @DisplayName("GET /api/v1/auth/devices should return registered device list for authenticated user")
    void testGetDevicesEndpoint() throws Exception {
        DeviceInfoDto d1 = DeviceInfoDto.builder().deviceId("dev-1").deviceName("iPhone").isPrimary(true).build();
        DeviceInfoDto d2 = DeviceInfoDto.builder().deviceId("dev-2").deviceName("iPad").isPrimary(false).build();

        when(jwtProvider.validateToken("mock.jwt.token")).thenReturn(true);
        when(jwtProvider.getUserId("mock.jwt.token")).thenReturn("USR-882190");
        when(authService.getUserDevices("USR-882190")).thenReturn(List.of(d1, d2));

        mockMvc.perform(get("/api/v1/auth/devices")
                        .header("Authorization", "Bearer mock.jwt.token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].device_id").value("dev-1"))
                .andExpect(jsonPath("$[0].device_name").value("iPhone"))
                .andExpect(jsonPath("$[0].is_primary").value(true))
                .andExpect(jsonPath("$[1].device_id").value("dev-2"))
                .andExpect(jsonPath("$[1].is_primary").value(false));
    }

    @Test
    @DisplayName("POST /api/v1/auth/devices/primary should update primary device and return 200")
    void testSetPrimaryDeviceEndpoint() throws Exception {
        when(jwtProvider.validateToken("mock.jwt.token")).thenReturn(true);
        when(jwtProvider.getUserId("mock.jwt.token")).thenReturn("USR-882190");

        mockMvc.perform(post("/api/v1/auth/devices/primary")
                        .header("Authorization", "Bearer mock.jwt.token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("device_id", "dev-2"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("SUCCESS"))
                .andExpect(jsonPath("$.primary_device_id").value("dev-2"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/logout-all should invoke logoutAll and return 200")
    void testLogoutAllEndpoint() throws Exception {
        when(jwtProvider.validateToken("mock.jwt.token")).thenReturn(true);
        when(jwtProvider.getUserId("mock.jwt.token")).thenReturn("USR-882190");

        mockMvc.perform(post("/api/v1/auth/logout-all")
                        .header("Authorization", "Bearer mock.jwt.token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("SUCCESS"))
                .andExpect(jsonPath("$.message").value("All secondary and web sessions have been terminated."));
    }

    @Test
    @DisplayName("POST /api/v1/auth/logout-sessions should invoke logoutAllWebSessions and return 200")
    void testLogoutSessionsEndpoint() throws Exception {
        when(jwtProvider.validateToken("mock.jwt.token")).thenReturn(true);
        when(jwtProvider.getUserId("mock.jwt.token")).thenReturn("USR-882190");

        mockMvc.perform(post("/api/v1/auth/logout-sessions")
                        .header("Authorization", "Bearer mock.jwt.token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("SUCCESS"))
                .andExpect(jsonPath("$.message").value("All web sessions have been terminated."));
    }
}
