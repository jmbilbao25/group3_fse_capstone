package com.fse.banking.account.service;

import com.fse.banking.account.dto.KycProfileResponse;
import com.fse.banking.account.model.UserEntity;
import com.fse.banking.account.repository.UserRepository;
import com.fse.banking.common.enums.UserRole;
import com.fse.banking.common.enums.UserStatus;
import com.fse.banking.common.enums.KycStatus;
import com.fse.banking.common.exception.ResourceNotFoundException;
import com.fse.banking.account.dto.KycUploadIntentRequest;
import com.fse.banking.account.dto.KycUploadIntentResponse;
import com.fse.banking.account.dto.KycUploadSlot;
import com.fse.banking.account.storage.BlobStorageAdapter;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.fse.banking.account.client.KycClient;
import com.fse.banking.account.client.dto.KycEvaluationClientRequest;
import com.fse.banking.account.client.dto.KycEvaluationClientResponse;
import com.fse.banking.account.dto.KycVerifyRequest;
import com.fse.banking.account.dto.KycVerifyResponse;

@ExtendWith(MockitoExtension.class)
class KycServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private BlobStorageAdapter blobStorageAdapter;

    @Mock
    private KycClient kycClient;

    @InjectMocks
    private KycService kycService;

    private UserEntity user;

    @BeforeEach
    void setUp() {
        user = UserEntity.builder()
                .userId("USR-100001")
                .firstName("Juan")
                .lastName("Dela Cruz")
                .email("juan.delacruz@example.ph")
                .phoneNumber("+639171234567")
                .dob(LocalDate.of(1990, 5, 15))
                .governmentId("PASSPORT-P9876543A")
                .role(UserRole.CUSTOMER)
                .status(UserStatus.ACTIVE)
                .build();
    }

    @Test
    @DisplayName("Should list all customer profiles for KYC review")
    void testListPendingKyc() {
        when(userRepository.findByRole(UserRole.CUSTOMER)).thenReturn(List.of(user));

        List<KycProfileResponse> results = kycService.listPendingKyc();

        assertThat(results).hasSize(1);
        assertThat(results.get(0).getUserId()).isEqualTo("USR-100001");
        assertThat(results.get(0).getEmail()).isEqualTo("juan.delacruz@example.ph");
    }

    @Test
    @DisplayName("Should retrieve individual KYC profile by user ID")
    void testGetKycProfile() {
        when(userRepository.findById("USR-100001")).thenReturn(Optional.of(user));

        KycProfileResponse profile = kycService.getKycProfile("USR-100001");

        assertThat(profile).isNotNull();
        assertThat(profile.getUserId()).isEqualTo("USR-100001");
        assertThat(profile.getGovernmentId()).isEqualTo("PASSPORT-P9876543A");
    }

    @Test
    @DisplayName("Should throw ResourceNotFoundException when profile not found")
    void testGetKycProfileNotFound() {
        when(userRepository.findById("USR-999999")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> kycService.getKycProfile("USR-999999"))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Customer profile not found for user: USR-999999");
    }

    @Test
    @DisplayName("Should approve customer KYC profile and set status to ACTIVE")
    void testApproveKyc() {
        when(userRepository.findById("USR-100001")).thenReturn(Optional.of(user));
        when(userRepository.save(any(UserEntity.class))).thenAnswer(inv -> inv.getArgument(0));

        KycProfileResponse response = kycService.approveKyc("USR-100001", "ADMIN-01");

        assertThat(response.getStatus()).isEqualTo("ACTIVE");
        verify(userRepository).save(user);
    }

    @Test
    @DisplayName("Should reject customer KYC profile and set status to SUSPENDED")
    void testRejectKyc() {
        when(userRepository.findById("USR-100001")).thenReturn(Optional.of(user));
        when(userRepository.save(any(UserEntity.class))).thenAnswer(inv -> inv.getArgument(0));

        KycProfileResponse response = kycService.rejectKyc("USR-100001", "ADMIN-01", "Invalid ID photo");

        assertThat(response.getStatus()).isEqualTo("SUSPENDED");
        verify(userRepository).save(user);
    }

    @Test
    @DisplayName("Should generate upload intent with SAS slots for valid user")
    void testGenerateUploadIntent() {
        when(userRepository.findById("USR-100001")).thenReturn(Optional.of(user));

        KycUploadIntentResponse mockResponse = KycUploadIntentResponse.builder()
                .submissionId("KYC-TEST-001")
                .containerName("kyc-vault")
                .expiresInSeconds(300)
                .frontSlot(KycUploadSlot.builder().slotName("id_front").blobPath("path/front.jpg").uploadUrl("http://sas-front").httpMethod("PUT").build())
                .backSlot(KycUploadSlot.builder().slotName("id_back").blobPath("path/back.jpg").uploadUrl("http://sas-back").httpMethod("PUT").build())
                .selfieSlot(KycUploadSlot.builder().slotName("selfie").blobPath("path/selfie.jpg").uploadUrl("http://sas-selfie").httpMethod("PUT").build())
                .build();

        when(blobStorageAdapter.generateUploadIntent("USR-100001", "DRIVERS_LICENSE", true)).thenReturn(mockResponse);

        KycUploadIntentRequest request = KycUploadIntentRequest.builder()
                .idType("DRIVERS_LICENSE")
                .requireBack(true)
                .build();

        KycUploadIntentResponse result = kycService.generateUploadIntent("USR-100001", request);

        assertThat(result).isNotNull();
        assertThat(result.getSubmissionId()).isEqualTo("KYC-TEST-001");
        assertThat(result.getExpiresInSeconds()).isEqualTo(300);
        assertThat(result.getFrontSlot().getUploadUrl()).isEqualTo("http://sas-front");
        assertThat(result.getSelfieSlot().getUploadUrl()).isEqualTo("http://sas-selfie");
    }

    @Test
    @DisplayName("Should approve and activate user when Laya returns APPROVED")
    void testVerifyKycSubmission_Approved() {
        when(userRepository.findById("USR-100001")).thenReturn(Optional.of(user));
        when(userRepository.save(any(UserEntity.class))).thenAnswer(inv -> inv.getArgument(0));

        KycEvaluationClientResponse clientResponse = KycEvaluationClientResponse.builder()
                .decision("APPROVED")
                .confidenceScore(94.5)
                .faceSimilarity(0.92)
                .livenessScore(0.96)
                .reasons(List.of("Automated verification successfully completed with high confidence."))
                .build();

        when(kycClient.evaluateKyc(any(KycEvaluationClientRequest.class))).thenReturn(clientResponse);

        KycVerifyRequest request = KycVerifyRequest.builder()
                .submissionId("KYC-2026-001")
                .idType("PHILID")
                .build();

        KycVerifyResponse response = kycService.verifyKycSubmission("USR-100001", request);

        assertThat(response.getKycStatus()).isEqualTo("VERIFIED");
        assertThat(response.getUserStatus()).isEqualTo("ACTIVE");
        assertThat(response.getConfidenceScore()).isEqualTo(94.5);
        assertThat(user.getKycStatus()).isEqualTo(KycStatus.VERIFIED);
        assertThat(user.getStatus()).isEqualTo(UserStatus.ACTIVE);
    }

    @Test
    @DisplayName("Should set PENDING_REVIEW when Laya returns PENDING_REVIEW")
    void testVerifyKycSubmission_PendingReview() {
        when(userRepository.findById("USR-100001")).thenReturn(Optional.of(user));
        when(userRepository.save(any(UserEntity.class))).thenAnswer(inv -> inv.getArgument(0));

        KycEvaluationClientResponse clientResponse = KycEvaluationClientResponse.builder()
                .decision("PENDING_REVIEW")
                .confidenceScore(78.5)
                .faceSimilarity(0.81)
                .livenessScore(0.95)
                .reasons(List.of("Minor discrepancy detected between declared name and document name."))
                .build();

        when(kycClient.evaluateKyc(any(KycEvaluationClientRequest.class))).thenReturn(clientResponse);

        KycVerifyRequest request = KycVerifyRequest.builder()
                .submissionId("KYC-2026-002")
                .idType("DRIVERS_LICENSE")
                .build();

        KycVerifyResponse response = kycService.verifyKycSubmission("USR-100001", request);

        assertThat(response.getKycStatus()).isEqualTo("PENDING_REVIEW");
        assertThat(user.getKycStatus()).isEqualTo(KycStatus.PENDING_REVIEW);
        assertThat(user.getKycReviewReason()).contains("Minor discrepancy");
    }

    @Test
    @DisplayName("Should set REJECTED when Laya returns REJECTED")
    void testVerifyKycSubmission_Rejected() {
        when(userRepository.findById("USR-100001")).thenReturn(Optional.of(user));
        when(userRepository.save(any(UserEntity.class))).thenAnswer(inv -> inv.getArgument(0));

        KycEvaluationClientResponse clientResponse = KycEvaluationClientResponse.builder()
                .decision("REJECTED")
                .confidenceScore(45.0)
                .faceSimilarity(0.35)
                .livenessScore(0.95)
                .reasons(List.of("Biometric verification failed: Selfie does not match the photo on the government ID."))
                .build();

        when(kycClient.evaluateKyc(any(KycEvaluationClientRequest.class))).thenReturn(clientResponse);

        KycVerifyRequest request = KycVerifyRequest.builder()
                .submissionId("KYC-2026-003")
                .idType("PASSPORT")
                .build();

        KycVerifyResponse response = kycService.verifyKycSubmission("USR-100001", request);

        assertThat(response.getKycStatus()).isEqualTo("REJECTED");
        assertThat(user.getKycStatus()).isEqualTo(KycStatus.REJECTED);
        assertThat(user.getKycReviewReason()).contains("Biometric verification failed");
    }
}
