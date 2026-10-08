package com.bank.ledger.contracts.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import jakarta.validation.constraints.NotBlank;
import lombok.*;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CheckerActionRequest {

    @JsonAlias({"transaction_id", "transactionId", "txId", "transferId"})
    private String transactionId;

    @NotBlank(message = "Checker User ID is mandatory")
    @JsonAlias({"checker_user_id", "checkerId", "approved_by_user_id", "checker"})
    private String checkerUserId;

    @JsonAlias({"notes", "comment", "reason", "rejection_reason"})
    private String remarks;
}