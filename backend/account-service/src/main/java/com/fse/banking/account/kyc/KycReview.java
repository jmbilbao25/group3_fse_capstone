package com.fse.banking.account.kyc;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.List;

/**
 * Laya's evaluation of one KYC submission plus the human maker/checker trail.
 * Laya only recommends; a maker records a decision and a different checker
 * confirms it before the customer's KYC status changes.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class KycReview {

    @JsonProperty("user_id")
    private String userId;
    @JsonProperty("submission_id")
    private String submissionId;
    @JsonProperty("id_type")
    private String idType;
    @JsonProperty("front_blob_path")
    private String frontBlobPath;
    @JsonProperty("back_blob_path")
    private String backBlobPath;
    @JsonProperty("selfie_blob_path")
    private String selfieBlobPath;

    @JsonProperty("laya_decision")
    private String layaDecision;
    @JsonProperty("confidence_score")
    private Double confidenceScore;
    @JsonProperty("face_similarity")
    private Double faceSimilarity;
    @JsonProperty("liveness_score")
    private Double livenessScore;
    @JsonProperty("laya_summary")
    private String layaSummary;
    @JsonProperty("laya_reasons")
    private List<String> layaReasons;
    @JsonProperty("laya_flags")
    private List<String> layaFlags;

    /** PENDING_MAKER, PENDING_CHECKER, APPROVED, REJECTED */
    @JsonProperty("status")
    private String status;
    @JsonProperty("maker_id")
    private String makerId;
    @JsonProperty("maker_decision")
    private String makerDecision;
    @JsonProperty("maker_note")
    private String makerNote;
    @JsonProperty("maker_at")
    private Instant makerAt;
    @JsonProperty("checker_id")
    private String checkerId;
    @JsonProperty("checker_note")
    private String checkerNote;
    @JsonProperty("checker_at")
    private Instant checkerAt;
    @JsonProperty("submitted_at")
    private Instant submittedAt;
}
