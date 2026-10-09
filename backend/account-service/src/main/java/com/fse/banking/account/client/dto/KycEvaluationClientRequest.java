package com.fse.banking.account.client.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class KycEvaluationClientRequest {

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

    @JsonProperty("declared_first_name")
    private String declaredFirstName;

    @JsonProperty("declared_last_name")
    private String declaredLastName;

    @JsonProperty("declared_dob")
    private String declaredDob;
}
