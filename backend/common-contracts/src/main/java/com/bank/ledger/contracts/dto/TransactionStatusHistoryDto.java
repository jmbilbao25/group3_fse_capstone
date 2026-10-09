package com.bank.ledger.contracts.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TransactionStatusHistoryDto {

    @JsonProperty("historyId")
    private String historyId;

    @JsonProperty("transactionId")
    private String transactionId;

    @JsonProperty("fromStatus")
    private String fromStatus;

    @JsonProperty("toStatus")
    private String toStatus;

    @JsonProperty("changeReason")
    private String changeReason;

    @JsonProperty("reasonDetails")
    private String reasonDetails;

    @JsonProperty("actorId")
    private String actorId;

    @JsonProperty("actorType")
    private String actorType;

    @JsonProperty("changedAt")
    private Instant changedAt;
}