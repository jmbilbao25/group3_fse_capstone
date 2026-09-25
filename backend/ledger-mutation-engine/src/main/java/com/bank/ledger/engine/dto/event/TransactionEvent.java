package com.bank.ledger.engine.dto.event;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.math.BigDecimal;
import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TransactionEvent implements Serializable {
    private String transactionId;
    private String sourceAccountId;
    private String destinationAccountId;
    private BigDecimal amount;
    private String currency; // "PHP"
    private String mutationType; // "TRANSFER"
    private String status; // "COMMITTED", "FAILED"
    private String initiatorUserId;
    private Instant timestamp;
}