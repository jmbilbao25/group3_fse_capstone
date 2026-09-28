package com.fse.banking.common.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ProblemDetails {

    @JsonProperty("type")
    private String type;

    @JsonProperty("title")
    private String title;

    @JsonProperty("status")
    private int status;

    @JsonProperty("detail")
    private String detail;

    @JsonProperty("instance")
    private String instance;

    @JsonProperty("timestamp")
    private Instant timestamp;

    @JsonProperty("invalid_params")
    private List<InvalidParam> invalidParams;

    @JsonProperty("trace_id")
    private String traceId;
}
