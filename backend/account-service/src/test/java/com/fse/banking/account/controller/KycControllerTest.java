package com.fse.banking.account.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fse.banking.account.dto.KycProfileResponse;
import com.fse.banking.account.dto.KycUploadIntentRequest;
import com.fse.banking.account.dto.KycUploadIntentResponse;
import com.fse.banking.account.dto.KycUploadSlot;
import com.fse.banking.account.dto.KycVerifyRequest;
import com.fse.banking.account.dto.KycVerifyResponse;
import com.fse.banking.account.exception.GlobalExceptionHandler;
import com.fse.banking.account.security.JwtProvider;
import com.fse.banking.account.service.KycService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = KycController.class)
@AutoConfigureMockMvc(addFilters = false)
@Import(GlobalExceptionHandler.class)
class KycControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private KycService kycService;

    @MockBean
    private JwtProvider jwtProvider;

    @Test
    @DisplayName("POST /api/v1/kyc/upload-intent should return 200 and pre-signed upload slots")
    void testRequestUploadIntent_Success() throws Exception {
        String token = "valid-customer-token";
        String userId = "USR-100001";

        when(jwtProvider.validateToken(token)).thenReturn(true);
        when(jwtProvider.getUserId(token)).thenReturn(userId);

        KycUploadIntentResponse mockResponse = KycUploadIntentResponse.builder()
                .submissionId("KYC-2026-99120")
                .containerName("kyc-vault")
                .expiresInSeconds(300)
                .frontSlot(KycUploadSlot.builder()
                        .slotName("id_front")
                        .blobPath("users/USR-100001/KYC-2026-99120/id_front.jpg")
                        .uploadUrl("http://localhost:10000/devstoreaccount1/kyc-vault/users/USR-100001/KYC-2026-99120/id_front.jpg?sig=testFront")
                        .httpMethod("PUT")
                        .build())
                .backSlot(KycUploadSlot.builder()
                        .slotName("id_back")
                        .blobPath("users/USR-100001/KYC-2026-99120/id_back.jpg")
                        .uploadUrl("http://localhost:10000/devstoreaccount1/kyc-vault/users/USR-100001/KYC-2026-99120/id_back.jpg?sig=testBack")
                        .httpMethod("PUT")
                        .build())
                .selfieSlot(KycUploadSlot.builder()
                        .slotName("selfie")
                        .blobPath("users/USR-100001/KYC-2026-99120/selfie.jpg")
                        .uploadUrl("http://localhost:10000/devstoreaccount1/kyc-vault/users/USR-100001/KYC-2026-99120/selfie.jpg?sig=testSelfie")
                        .httpMethod("PUT")
                        .build())
                .build();

        when(kycService.generateUploadIntent(eq(userId), any(KycUploadIntentRequest.class))).thenReturn(mockResponse);

        KycUploadIntentRequest request = KycUploadIntentRequest.builder()
                .idType("DRIVERS_LICENSE")
                .requireBack(true)
                .build();

        mockMvc.perform(post("/api/v1/kyc/upload-intent")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.submissionId").value("KYC-2026-99120"))
                .andExpect(jsonPath("$.containerName").value("kyc-vault"))
                .andExpect(jsonPath("$.expiresInSeconds").value(300))
                .andExpect(jsonPath("$.frontSlot.slotName").value("id_front"))
                .andExpect(jsonPath("$.frontSlot.httpMethod").value("PUT"))
                .andExpect(jsonPath("$.frontSlot.uploadUrl").exists())
                .andExpect(jsonPath("$.backSlot.slotName").value("id_back"))
                .andExpect(jsonPath("$.selfieSlot.slotName").value("selfie"));
    }

    @Test
    @DisplayName("POST /api/v1/kyc/upload-intent should return 401 when Authorization header is missing")
    void testRequestUploadIntent_Unauthorized_WhenMissingAuth() throws Exception {
        KycUploadIntentRequest request = KycUploadIntentRequest.builder()
                .idType("PHILID")
                .requireBack(true)
                .build();

        mockMvc.perform(post("/api/v1/kyc/upload-intent")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("POST /api/v1/kyc/upload-intent should return 401 when token is invalid")
    void testRequestUploadIntent_Unauthorized_WhenInvalidToken() throws Exception {
        when(jwtProvider.validateToken("bad-token")).thenReturn(false);

        KycUploadIntentRequest request = KycUploadIntentRequest.builder()
                .idType("PASSPORT")
                .requireBack(false)
                .build();

        mockMvc.perform(post("/api/v1/kyc/upload-intent")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer bad-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("POST /api/v1/kyc/upload-intent should return 400 when idType is blank")
    void testRequestUploadIntent_BadRequest_WhenEmptyIdType() throws Exception {
        when(jwtProvider.validateToken("valid-token")).thenReturn(true);
        when(jwtProvider.getUserId("valid-token")).thenReturn("USR-100001");

        KycUploadIntentRequest request = KycUploadIntentRequest.builder()
                .idType("")
                .build();

        mockMvc.perform(post("/api/v1/kyc/upload-intent")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer valid-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("GET /api/v1/kyc/pending should return list of pending profiles")
    void testListPendingKyc() throws Exception {
        KycProfileResponse profile = KycProfileResponse.builder()
                .userId("USR-100001")
                .firstName("Maria")
                .lastName("Santos")
                .email("maria.santos@example.ph")
                .kycStatus("PENDING_REVIEW")
                .createdAt(Instant.now())
                .build();

        when(kycService.listPendingKyc()).thenReturn(List.of(profile));

        mockMvc.perform(get("/api/v1/kyc/pending"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].user_id").value("USR-100001"))
                .andExpect(jsonPath("$[0].kyc_status").value("PENDING_REVIEW"));
    }

    @Test
    @DisplayName("Maker/checker endpoints refuse callers without a staff token")
    void testReviewEndpointsRequireStaff() throws Exception {
        when(jwtProvider.validateToken("cust")).thenReturn(true);
        when(jwtProvider.getRole("cust")).thenReturn("ROLE_CUSTOMER");
        mockMvc.perform(post("/api/v1/kyc/USR-100001/recommend")
                        .header("Authorization", "Bearer cust")
                        .contentType("application/json").content("{\"decision\":\"APPROVE\"}"))
                .andExpect(status().isForbidden());
        mockMvc.perform(get("/api/v1/kyc/reviews")).andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("POST /api/v1/kyc/{userId}/recommend records the maker from the JWT")
    void testRecommendUsesJwtMaker() throws Exception {
        when(jwtProvider.validateToken("staff")).thenReturn(true);
        when(jwtProvider.getRole("staff")).thenReturn("ROLE_ADMIN");
        when(jwtProvider.getUserId("staff")).thenReturn("usr-1005-boo-001");
        when(kycService.recommend("USR-100001", "usr-1005-boo-001", "APPROVE", "IDs match"))
                .thenReturn(com.fse.banking.account.kyc.KycReview.builder().userId("USR-100001").status("PENDING_CHECKER").build());
        mockMvc.perform(post("/api/v1/kyc/USR-100001/recommend")
                        .header("Authorization", "Bearer staff")
                        .contentType("application/json").content("{\"decision\":\"APPROVE\",\"note\":\"IDs match\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PENDING_CHECKER"));
    }

    @Test
    @DisplayName("POST /api/v1/kyc/verify should return 200 and KycVerifyResponse when authenticated")
    void testVerifyKyc_Success() throws Exception {
        String token = "valid-customer-token";
        String userId = "USR-100001";

        when(jwtProvider.validateToken(token)).thenReturn(true);
        when(jwtProvider.getUserId(token)).thenReturn(userId);

        KycVerifyResponse mockResponse = KycVerifyResponse.builder()
                .userId(userId)
                .submissionId("KYC-2026-99120")
                .kycStatus("VERIFIED")
                .userStatus("ACTIVE")
                .confidenceScore(94.5)
                .message("Account successfully verified and activated.")
                .reasons(List.of("Automated verification completed."))
                .build();

        when(kycService.verifyKycSubmission(eq(userId), any(KycVerifyRequest.class))).thenReturn(mockResponse);

        KycVerifyRequest request = KycVerifyRequest.builder()
                .submissionId("KYC-2026-99120")
                .idType("PHILID")
                .build();

        mockMvc.perform(post("/api/v1/kyc/verify")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(userId))
                .andExpect(jsonPath("$.submissionId").value("KYC-2026-99120"))
                .andExpect(jsonPath("$.kycStatus").value("VERIFIED"))
                .andExpect(jsonPath("$.userStatus").value("ACTIVE"))
                .andExpect(jsonPath("$.confidenceScore").value(94.5));
    }

    @Test
    @DisplayName("POST /api/v1/kyc/verify should return 401 when unauthenticated")
    void testVerifyKyc_Unauthorized() throws Exception {
        KycVerifyRequest request = KycVerifyRequest.builder()
                .submissionId("KYC-2026-99120")
                .idType("PHILID")
                .build();

        mockMvc.perform(post("/api/v1/kyc/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isUnauthorized());
    }
}
