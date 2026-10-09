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
import com.fse.banking.account.kyc.KycReview;
import com.fse.banking.account.kyc.KycReviewStore;
import com.fse.banking.common.exception.ConflictException;
import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.Map;
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
    private final KycReviewStore reviewStore;

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

        KycEvaluationClientResponse eval = kycClient.evaluateKyc(evalRequest);
        String layaDecision = eval.getDecision() != null ? eval.getDecision() : "PENDING_REVIEW";
        List<String> reasons = eval.getReasons() != null ? eval.getReasons() : List.of();

        // Laya recommends; a person decides. Every submission waits for a maker
        // and a different checker, whatever Laya's confidence.
        user.setKycStatus(KycStatus.PENDING_REVIEW);
        user.setKycReviewReason(truncate("Laya recommends " + layaDecision.toLowerCase().replace('_', ' ')
                + (reasons.isEmpty() ? "" : ": " + String.join("; ", reasons)), 500));
        userRepository.save(user);

        reviewStore.save(KycReview.builder()
                .userId(userId)
                .submissionId(request.getSubmissionId())
                .idType(request.getIdType())
                .frontBlobPath(evalRequest.getFrontBlobPath())
                .backBlobPath(evalRequest.getBackBlobPath())
                .selfieBlobPath(evalRequest.getSelfieBlobPath())
                .layaDecision(layaDecision)
                .confidenceScore(eval.getConfidenceScore())
                .faceSimilarity(eval.getFaceSimilarity())
                .livenessScore(eval.getLivenessScore())
                .layaSummary(summarize(layaDecision, eval))
                .layaReasons(reasons)
                .layaFlags(eval.getFlags() != null ? eval.getFlags() : List.of())
                .status("PENDING_MAKER")
                .submittedAt(Instant.now())
                .build());

        return KycVerifyResponse.builder()
                .userId(userId)
                .submissionId(request.getSubmissionId())
                .kycStatus(user.getKycStatus().name())
                .userStatus(user.getStatus().name())
                .confidenceScore(eval.getConfidenceScore())
                .message("Your documents have been received. Our team reviews every application, usually within one business day.")
                .reasons(reasons)
                .build();
    }

    /** One-paragraph summary for the reviewer: verdict, confidence, the checks that drove it. */
    static String summarize(String decision, KycEvaluationClientResponse e) {
        String verdict = switch (decision) {
            case "APPROVED" -> "Laya recommends approval";
            case "REJECTED" -> "Laya recommends rejection";
            default -> "Laya could not decide and needs a closer look";
        };
        StringBuilder sb = new StringBuilder(verdict);
        if (e.getConfidenceScore() != null) sb.append(String.format(" (confidence %.1f%%)", e.getConfidenceScore()));
        sb.append('.');
        if (e.getFaceSimilarity() != null) sb.append(String.format(" Selfie matches the ID photo at %.0f%%.", e.getFaceSimilarity() * 100));
        if (e.getLivenessScore() != null) sb.append(String.format(" Liveness %.0f%%.", e.getLivenessScore() * 100));
        if (e.getChecks() != null) {
            List<String> failed = e.getChecks().entrySet().stream()
                    .filter(c -> Boolean.FALSE.equals(c.getValue()))
                    .map(c -> c.getKey().replace('_', ' '))
                    .toList();
            sb.append(failed.isEmpty() ? " All document checks passed." : " Failed checks: " + String.join(", ", failed) + ".");
        }
        return sb.toString();
    }

    /** Maker step: record a recommendation. */
    @Transactional
    public KycReview recommend(String userId, String makerId, String decision, String note) {
        if (!"APPROVE".equals(decision) && !"REJECT".equals(decision)) {
            throw new IllegalArgumentException("decision must be APPROVE or REJECT");
        }
        if ("REJECT".equals(decision) && (note == null || note.isBlank())) {
            throw new IllegalArgumentException("A reason is required to recommend rejection.");
        }
        KycReview review = reviewFor(userId);
        if (!"PENDING_MAKER".equals(review.getStatus())) {
            throw new ConflictException("This application is " + review.getStatus().toLowerCase().replace('_', ' ') + ".");
        }
        review.setStatus("PENDING_CHECKER");
        review.setMakerId(makerId);
        review.setMakerDecision(decision);
        review.setMakerNote(note);
        review.setMakerAt(Instant.now());
        reviewStore.save(review);
        log.info("KYC maker {} recommends {} for {}", makerId, decision, userId);
        return review;
    }

    /**
     * Checker step. {@code confirm} applies the maker's decision; otherwise the
     * case goes back to the maker queue. The checker must not be the maker.
     */
    @Transactional
    public KycReview check(String userId, String checkerId, boolean confirm, String note) {
        KycReview review = reviewFor(userId);
        if (!"PENDING_CHECKER".equals(review.getStatus())) {
            throw new ConflictException("This application has no recommendation waiting for a checker.");
        }
        if (checkerId == null || checkerId.equals(review.getMakerId())) {
            throw new ConflictException("Four-eyes rule: a different reviewer must check this recommendation.");
        }
        review.setCheckerId(checkerId);
        review.setCheckerNote(note);
        review.setCheckerAt(Instant.now());
        if (!confirm) {
            review.setStatus("PENDING_MAKER");
            reviewStore.save(review);
            return review;
        }
        boolean approve = "APPROVE".equals(review.getMakerDecision());
        review.setStatus(approve ? "APPROVED" : "REJECTED");
        reviewStore.save(review);
        if (approve) {
            approveKyc(userId, review.getMakerId() + " / " + checkerId);
        } else {
            rejectKyc(userId, checkerId, review.getMakerNote());
        }
        return review;
    }

    public List<KycReview> listReviews() {
        return reviewStore.findAll().stream()
                .sorted(Comparator.comparing(KycReview::getSubmittedAt, Comparator.nullsLast(Comparator.reverseOrder())))
                .toList();
    }

    /** Review with short-lived read links to the uploaded ID and selfie. */
    public Map<String, Object> reviewWithImages(String userId) {
        KycReview review = reviewFor(userId);
        Map<String, Object> images = new LinkedHashMap<>();
        for (Map.Entry<String, String> e : Map.of("front", nz(review.getFrontBlobPath()), "back", nz(review.getBackBlobPath()),
                "selfie", nz(review.getSelfieBlobPath())).entrySet()) {
            if (e.getValue().isBlank()) continue;
            try {
                images.put(e.getKey(), blobStorageAdapter.generateReadSasUri(e.getValue(), Duration.ofMinutes(10)));
            } catch (Exception ex) {
                log.warn("No read link for {} {}: {}", userId, e.getKey(), ex.getMessage());
            }
        }
        return Map.of("review", review, "profile", getKycProfile(userId), "images", images);
    }

    private KycReview reviewFor(String userId) {
        return reviewStore.find(userId)
                .orElseThrow(() -> new ResourceNotFoundException("No KYC submission found for user: " + userId));
    }

    private static String nz(String s) {
        return s == null ? "" : s;
    }

    private static String truncate(String s, int max) {
        return s.length() <= max ? s : s.substring(0, max);
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
