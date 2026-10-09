package com.fse.banking.account.controller;

import com.fse.banking.account.dto.KycProfileResponse;
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
import java.util.Map;

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

    /** Review queue: Laya result, summary, confidence and maker/checker state. */
    @GetMapping("/reviews")
    public ResponseEntity<?> listReviews(@RequestHeader(value = HttpHeaders.AUTHORIZATION, required = false) String authHeader) {
        if (staffId(authHeader) == null) return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        return ResponseEntity.ok(kycService.listReviews());
    }

    /** One application with short-lived links to the ID front, back and selfie. */
    @GetMapping("/{userId}/review")
    public ResponseEntity<?> getReview(@PathVariable("userId") String userId,
                                       @RequestHeader(value = HttpHeaders.AUTHORIZATION, required = false) String authHeader) {
        if (staffId(authHeader) == null) return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        return ResponseEntity.ok(kycService.reviewWithImages(userId));
    }

    /** Maker: recommend APPROVE or REJECT. */
    @PostMapping("/{userId}/recommend")
    public ResponseEntity<?> recommend(@PathVariable("userId") String userId,
                                       @RequestBody Map<String, String> body,
                                       @RequestHeader(value = HttpHeaders.AUTHORIZATION, required = false) String authHeader) {
        String maker = staffId(authHeader);
        if (maker == null) return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        return ResponseEntity.ok(kycService.recommend(userId, maker, body.get("decision"), body.get("note")));
    }

    /** Checker: CONFIRM applies the maker's decision, RETURN sends it back. */
    @PostMapping("/{userId}/check")
    public ResponseEntity<?> check(@PathVariable("userId") String userId,
                                   @RequestBody Map<String, String> body,
                                   @RequestHeader(value = HttpHeaders.AUTHORIZATION, required = false) String authHeader) {
        String checker = staffId(authHeader);
        if (checker == null) return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        String action = body.getOrDefault("action", "");
        if (!"CONFIRM".equals(action) && !"RETURN".equals(action)) {
            throw new IllegalArgumentException("action must be CONFIRM or RETURN");
        }
        return ResponseEntity.ok(kycService.check(userId, checker, "CONFIRM".equals(action), body.get("note")));
    }

    /** Staff id from a valid bearer token, or null for customers and anonymous callers. */
    private String staffId(String authHeader) {
        if (authHeader == null || !authHeader.startsWith("Bearer ")) return null;
        String token = authHeader.substring(7);
        if (!jwtProvider.validateToken(token)) return null;
        String role = String.valueOf(jwtProvider.getRole(token)).replace("ROLE_", "");
        return "ADMIN".equals(role) || "TELLER".equals(role) || "MANAGER".equals(role) ? jwtProvider.getUserId(token) : null;
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
