package com.fse.banking.account.controller;

import com.fse.banking.account.dto.LoginRequest;
import com.fse.banking.account.dto.LoginResponse;
import com.fse.banking.account.dto.LogoutResponse;
import com.fse.banking.account.dto.RegisterRequest;
import com.fse.banking.account.dto.RegisterResponse;
import com.fse.banking.account.dto.TokenRefreshResponse;
import com.fse.banking.account.dto.VerifyLoginOtpRequest;
import com.fse.banking.account.service.AuthService;
import com.fse.banking.account.service.TokenRotationService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseCookie;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.CookieValue;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Duration;

@Slf4j
@RestController
@CrossOrigin(origins = "*", allowedHeaders = "*")
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final TokenRotationService tokenRotationService;

    @Value("${jwt.cookie.secure:false}")
    private boolean cookieSecure;

    @Value("${jwt.cookie.same-site:Strict}")
    private String cookieSameSite;

    @Value("${jwt.cookie.path:/api/v1/auth}")
    private String cookiePath;

    @PostMapping("/register")
    public ResponseEntity<RegisterResponse> register(@Valid @RequestBody RegisterRequest request) {
        RegisterResponse response = authService.register(request);
        
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @PostMapping("/login")
    public ResponseEntity<LoginResponse> login(@Valid @RequestBody LoginRequest request, HttpServletRequest httpRequest) {
        String clientIp = httpRequest.getRemoteAddr();
        String userAgent = httpRequest.getHeader("User-Agent");

        AuthService.LoginResult result = authService.login(request, clientIp, userAgent);

        if (result.getRefreshTokenId() != null) {
            ResponseCookie cookie = createRefreshTokenCookie(result.getRefreshTokenId(), Duration.ofDays(7));
            return ResponseEntity.ok()
                    .header(HttpHeaders.SET_COOKIE, cookie.toString())
                    .body(result.getResponse());
        }

        // MFA Required path: return challenge without issuing tokens or session cookies
        return ResponseEntity.ok(result.getResponse());
    }

    @PostMapping("/verify-login-otp")
    public ResponseEntity<LoginResponse> verifyLoginOtp(
            @Valid @RequestBody VerifyLoginOtpRequest request,
            HttpServletRequest httpRequest) {
        String clientIp = httpRequest.getRemoteAddr();
        String userAgent = httpRequest.getHeader("User-Agent");

        AuthService.LoginResult result = authService.verifyLoginOtp(request, clientIp, userAgent);

        ResponseCookie cookie = createRefreshTokenCookie(result.getRefreshTokenId(), Duration.ofDays(7));

        return ResponseEntity.ok()
                .header(HttpHeaders.SET_COOKIE, cookie.toString())
                .body(result.getResponse());
    }

    @PostMapping("/refresh")
    public ResponseEntity<TokenRefreshResponse> refresh(
            @CookieValue(name = "refresh_token", required = false) String refreshTokenCookie) {

        TokenRotationService.RotationResult result = tokenRotationService.rotate(refreshTokenCookie);

        ResponseCookie cookie = createRefreshTokenCookie(result.getNewRefreshTokenId(), Duration.ofDays(7));

        return ResponseEntity.ok()
                .header(HttpHeaders.SET_COOKIE, cookie.toString())
                .body(result.getResponse());
    }

    @PostMapping("/logout")
    public ResponseEntity<LogoutResponse> logout(
            @RequestHeader(value = HttpHeaders.AUTHORIZATION, required = false) String authHeader,
            @CookieValue(name = "refresh_token", required = false) String refreshTokenCookie) {

        authService.logout(authHeader, refreshTokenCookie);

        ResponseCookie cookie = createRefreshTokenCookie("", Duration.ZERO);

        LogoutResponse response = LogoutResponse.builder()
                .message("Session terminated successfully. Access token blacklisted and token family revoked.")
                .build();

        return ResponseEntity.ok()
                .header(HttpHeaders.SET_COOKIE, cookie.toString())
                .body(response);
    }

    private ResponseCookie createRefreshTokenCookie(String value, Duration maxAge) {
        return ResponseCookie.from("refresh_token", value)
                .httpOnly(true)
                .secure(cookieSecure)
                .sameSite(cookieSameSite)
                .path(cookiePath)
                .maxAge(maxAge)
                .build();
    }
}
