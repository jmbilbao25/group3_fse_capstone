package com.fse.banking.account.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class KycVerifyResponse {
    private String userId;
    private String submissionId;
    private String kycStatus; // "VERIFIED", "PENDING_REVIEW", "REJECTED"
    private String userStatus; // "ACTIVE", "SUSPENDED"
    private Double confidenceScore;
    private String message;
    private List<String> reasons;
}
