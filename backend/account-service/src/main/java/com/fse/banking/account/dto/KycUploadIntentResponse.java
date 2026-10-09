package com.fse.banking.account.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class KycUploadIntentResponse {
    private String submissionId;
    private String containerName;
    private int expiresInSeconds;
    private KycUploadSlot frontSlot;
    private KycUploadSlot backSlot;
    private KycUploadSlot selfieSlot;
}
