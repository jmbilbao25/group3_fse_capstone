package com.fse.banking.account.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class KycVerifyRequest {

    @NotBlank(message = "Submission ID is required")
    private String submissionId;

    @NotBlank(message = "ID Type is required")
    private String idType;

    private String declaredName;

    private String declaredDob;

    private String declaredIdNumber;
}

