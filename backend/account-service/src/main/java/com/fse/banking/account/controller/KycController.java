package com.fse.banking.account.controller;

import com.fse.banking.account.dto.KycProfileResponse;
import com.fse.banking.account.dto.KycRejectRequest;
import com.fse.banking.account.dto.KycUploadIntentRequest;
import com.fse.banking.account.dto.KycUploadIntentResponse;
import com.fse.banking.account.dto.KycVerifyRequest;
import com.fse.banking.account.dto.KycVerifyResponse;
import com.fse.banking.account.security.JwtProvider;
import com.fse.banking.account.service.KycService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Slf4j
@RestController
@RequestMapping("/api/v1/kyc")
@RequiredArgsConstructor
public class KycController {

    private final KycService kycService;
    private final JwtProvider jwtProvider;

    @PostMapping("/upload-intent")
    public ResponseEntity<KycUploadIntentResponse> requestUploadIntent(
            @Valid @RequestBody KycUploadIntentRequest request,
            @RequestHeader(value = HttpHeaders.AUTHORIZATION, required = false) String authHeader) {

        String userId = extractCallerId(authHeader, null);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        KycUploadIntentResponse response = kycService.generateUploadIntent(userId, request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/verify")
    public ResponseEntity<KycVerifyResponse> verifyKyc(
            @Valid @RequestBody KycVerifyRequest request,
            @RequestHeader(value = HttpHeaders.AUTHORIZATION, required = false) String authHeader) {

        String userId = extractCallerId(authHeader, null);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        KycVerifyResponse response = kycService.verifyKycSubmission(userId, request);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/pending")
    public ResponseEntity<List<KycProfileResponse>> listPendingKyc() {
        List<KycProfileResponse> pending = kycService.listPendingKyc();
        return ResponseEntity.ok(pending);
    }

    @GetMapping("/{userId}")
    public ResponseEntity<KycProfileResponse> getKycProfile(@PathVariable("userId") String userId) {
        KycProfileResponse profile = kycService.getKycProfile(userId);
        return ResponseEntity.ok(profile);
    }

    @PostMapping("/{userId}/approve")
    public ResponseEntity<KycProfileResponse> approveKyc(
            @PathVariable("userId") String userId,
            @RequestHeader(value = HttpHeaders.AUTHORIZATION, required = false) String authHeader) {

        String reviewerId = extractCallerId(authHeader, "SYSTEM_ADMIN");
        KycProfileResponse response = kycService.approveKyc(userId, reviewerId);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/{userId}/reject")
    public ResponseEntity<KycProfileResponse> rejectKyc(
            @PathVariable("userId") String userId,
            @Valid @RequestBody KycRejectRequest request,
            @RequestHeader(value = HttpHeaders.AUTHORIZATION, required = false) String authHeader) {

        String reviewerId = extractCallerId(authHeader, "SYSTEM_ADMIN");
        KycProfileResponse response = kycService.rejectKyc(userId, reviewerId, request.getReason());
        return ResponseEntity.ok(response);
    }

    private String extractCallerId(String authHeader, String defaultId) {
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            if (jwtProvider.validateToken(token)) {
                return jwtProvider.getUserId(token);
            }
        }
        return defaultId;
    }
}
