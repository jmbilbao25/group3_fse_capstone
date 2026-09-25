package com.bank.ledger.contracts.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * Event payload dispatched over Kafka topic 'banking.transfers.events'
 * consumed by notification-service to trigger email receipts and teller alerts.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TransactionNotificationEvent {

    @JsonProperty("transfer_id")
    private String transferId;

    @JsonProperty("source_account")
    private String sourceAccount;

    @JsonProperty("destination_account")
    private String destinationAccount;

    @JsonProperty("user_id")
    private String userId;

    @JsonProperty("recipient_email")
    private String recipientEmail;

    @JsonProperty("amount")
    private BigDecimal amount;

    @JsonProperty("currency")
    private String currency;

    @JsonProperty("before_balance")
    private BigDecimal beforeBalance;

    @JsonProperty("after_balance")
    private BigDecimal afterBalance;

    @JsonProperty("status")
    private String status; // COMMITTED, PENDING_APPROVAL, REJECTED, FAILED

    @JsonProperty("event_type")
    private String eventType; // TRANSFER_EXECUTED, TRANSFER_PENDING_APPROVAL, TRANSFER_REJECTED

    @JsonProperty("requires_maker_checker")
    private boolean requiresMakerChecker;

    @JsonProperty("maker_user_id")
    private String makerUserId;

    @JsonProperty("timestamp")
    private Instant timestamp;

    @JsonProperty("description")
    private String description;
}
