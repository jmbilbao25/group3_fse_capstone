package com.bank.ledger.contracts.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.*;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CheckerActionRequest {

    @NotBlank(message = "Checker User ID is mandatory")
    private String checkerUserId;

    private String remarks;
}