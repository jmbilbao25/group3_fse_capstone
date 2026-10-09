package com.fse.banking.account.client.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;
import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class KycEvaluationClientResponse {

    @JsonProperty("user_id")
    private String userId;

    @JsonProperty("submission_id")
    private String submissionId;

    @JsonProperty("decision")
    private String decision; // "APPROVED", "PENDING_REVIEW", "REJECTED"

    @JsonProperty("confidence_score")
    private Double confidenceScore;

    @JsonProperty("face_similarity")
    private Double faceSimilarity;

    @JsonProperty("liveness_score")
    private Double livenessScore;

    @JsonProperty("ocr_data")
    private Map<String, Object> ocrData;

    @JsonProperty("checks")
    private Map<String, Boolean> checks;

    @JsonProperty("flags")
    private List<String> flags;

    @JsonProperty("reasons")
    private List<String> reasons;
}
