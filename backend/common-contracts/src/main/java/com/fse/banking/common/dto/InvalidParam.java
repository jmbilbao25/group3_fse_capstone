package com.fse.banking.common.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class InvalidParam {

    @JsonProperty("field")
    private String field;

    @JsonProperty("rejected_value")
    private Object rejectedValue;

    @JsonProperty("reason")
    private String reason;
}
