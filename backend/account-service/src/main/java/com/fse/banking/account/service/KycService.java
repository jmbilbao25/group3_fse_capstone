package com.fse.banking.account.service;

import com.fse.banking.account.client.KycClient;
import com.fse.banking.account.client.dto.KycEvaluationClientRequest;
import com.fse.banking.account.client.dto.KycEvaluationClientResponse;
import com.fse.banking.account.dto.KycProfileResponse;
import com.fse.banking.account.dto.KycUploadIntentRequest;
import com.fse.banking.account.dto.KycUploadIntentResponse;
import com.fse.banking.account.dto.KycVerifyRequest;
import com.fse.banking.account.dto.KycVerifyResponse;
import com.fse.banking.account.model.UserEntity;
import com.fse.banking.account.repository.UserRepository;
import com.fse.banking.account.storage.BlobStorageAdapter;
import com.fse.banking.common.enums.KycStatus;
import com.fse.banking.common.enums.UserRole;
import com.fse.banking.common.enums.UserStatus;
import com.fse.banking.common.exception.ResourceNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class KycService {

    private final UserRepository userRepository;
    private final BlobStorageAdapter blobStorageAdapter;
    private final KycClient kycClient;

    public KycUploadIntentResponse generateUploadIntent(String userId, KycUploadIntentRequest request) {
        log.info("Generating KYC upload intent for user {} and ID type {}", userId, request.getIdType());
        userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Customer profile not found for user: " + userId));

        return blobStorageAdapter.generateUploadIntent(userId, request.getIdType(), request.isRequireBack());
    }

    @Transactional
    public KycVerifyResponse verifyKycSubmission(String userId, KycVerifyRequest request) {
        log.info("Processing KYC verification submission {} for user {}", request.getSubmissionId(), userId);
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Customer profile not found for user: " + userId));

        String basePath = "users/" + userId + "/" + request.getSubmissionId();
        KycEvaluationClientRequest evalRequest = KycEvaluationClientRequest.builder()
                .userId(userId)
                .submissionId(request.getSubmissionId())
                .idType(request.getIdType())
                .frontBlobPath(basePath + "/id_front.jpg")
                .backBlobPath(basePath + "/id_back.jpg")
                .selfieBlobPath(basePath + "/selfie.jpg")
                .declaredFirstName(user.getFirstName())
                .declaredLastName(user.getLastName())
                .declaredDob(user.getDob() != null ? user.getDob().toString() : null)
                .build();

        KycEvaluationClientResponse evalResponse = kycClient.evaluateKyc(evalRequest);
        String decision = evalResponse.getDecision() != null ? evalResponse.getDecision() : "PENDING_REVIEW";
        String message;

        if ("APPROVED".equalsIgnoreCase(decision)) {
            user.setStatus(UserStatus.ACTIVE);
            user.setKycStatus(KycStatus.VERIFIED);
            user.setKycReviewReason("Automated KYC approval via Laya Vision Engine");
            message = "Account successfully verified and activated.";
        } else if ("REJECTED".equalsIgnoreCase(decision)) {
            user.setKycStatus(KycStatus.REJECTED);
            String reasonsSummary = evalResponse.getReasons() != null && !evalResponse.getReasons().isEmpty()
                    ? String.join("; ", evalResponse.getReasons())
                    : "Identity verification checks did not meet compliance criteria";
            user.setKycReviewReason(reasonsSummary);
            message = "Identity verification could not be completed. Please review requirements and try again.";
        } else {
            user.setKycStatus(KycStatus.PENDING_REVIEW);
            String reasonsSummary = evalResponse.getReasons() != null && !evalResponse.getReasons().isEmpty()
                    ? String.join("; ", evalResponse.getReasons())
                    : "Standard compliance review required";
            user.setKycReviewReason(reasonsSummary);
            message = "Your documents have been received and are undergoing standard compliance review.";
        }

        userRepository.save(user);

        return KycVerifyResponse.builder()
                .userId(userId)
                .submissionId(request.getSubmissionId())
                .kycStatus(user.getKycStatus().name())
                .userStatus(user.getStatus().name())
                .confidenceScore(evalResponse.getConfidenceScore())
                .message(message)
                .reasons(evalResponse.getReasons())
                .build();
    }

    public List<KycProfileResponse> listPendingKyc() {
        return userRepository.findByRole(UserRole.CUSTOMER)
                .stream()
                .map(this::toProfileResponse)
                .toList();
    }

    public KycProfileResponse getKycProfile(String userId) {
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Customer profile not found for user: " + userId));
        return toProfileResponse(user);
    }

    @Transactional
    public KycProfileResponse approveKyc(String userId, String reviewerId) {
        log.info("Approving KYC for user {} by reviewer {}", userId, reviewerId);
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Customer profile not found for user: " + userId));

        user.setStatus(UserStatus.ACTIVE);
        user.setKycStatus(KycStatus.VERIFIED);
        user.setKycReviewReason("Approved by " + reviewerId);
        UserEntity updated = userRepository.save(user);
        return toProfileResponse(updated);
    }

    @Transactional
    public KycProfileResponse rejectKyc(String userId, String reviewerId, String reason) {
        log.info("Rejecting KYC for user {} by reviewer {} with reason: {}", userId, reviewerId, reason);
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Customer profile not found for user: " + userId));

        user.setStatus(UserStatus.SUSPENDED);
        user.setKycStatus(KycStatus.REJECTED);
        user.setKycReviewReason(reason);
        UserEntity updated = userRepository.save(user);
        return toProfileResponse(updated);
    }

    private KycProfileResponse toProfileResponse(UserEntity user) {
        return KycProfileResponse.builder()
                .userId(user.getUserId())
                .firstName(user.getFirstName())
                .middleName(user.getMiddleName())
                .lastName(user.getLastName())
                .email(user.getEmail())
                .phoneNumber(user.getPhoneNumber())
                .dob(user.getDob())
                .governmentId(user.getGovernmentId())
                .role(user.getRole() != null ? user.getRole().name() : null)
                .status(user.getStatus() != null ? user.getStatus().name() : null)
                .kycStatus(user.getKycStatus() != null ? user.getKycStatus().name() : null)
                .kycReviewReason(user.getKycReviewReason())
                .createdAt(user.getCreatedAt())
                .build();
    }
}
