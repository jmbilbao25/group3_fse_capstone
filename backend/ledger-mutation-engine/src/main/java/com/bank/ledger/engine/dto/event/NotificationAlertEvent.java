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
public class NotificationAlertEvent implements Serializable {
    private String alertId;
    private String transactionId;
    private String recipientUserId;
    private String recipientAccountId;
    private String alertType; // "TRANSFER_DEBIT", "TRANSFER_CREDIT"
    private BigDecimal amount;
    private BigDecimal balanceAfter;
    private String title;
    private String message;
    private Instant createdAt;
}