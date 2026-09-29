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

    @JsonProperty("requires_2fa_otp")
    @com.fasterxml.jackson.annotation.JsonAlias({"requires_maker_checker"})
    private boolean requires2FaOtp;

    @JsonProperty("initiator_user_id")
    @com.fasterxml.jackson.annotation.JsonAlias({"maker_user_id"})
    private String initiatorUserId;

    @JsonProperty("timestamp")
    private Instant timestamp;

    @JsonProperty("description")
    private String description;

    @com.fasterxml.jackson.annotation.JsonIgnore
    public boolean isRequiresMakerChecker() {
        return requires2FaOtp;
    }

    @com.fasterxml.jackson.annotation.JsonIgnore
    public void setRequiresMakerChecker(boolean requiresMakerChecker) {
        this.requires2FaOtp = requiresMakerChecker;
    }

    @com.fasterxml.jackson.annotation.JsonIgnore
    public String getMakerUserId() {
        return initiatorUserId != null ? initiatorUserId : userId;
    }

    @com.fasterxml.jackson.annotation.JsonIgnore
    public void setMakerUserId(String makerUserId) {
        this.initiatorUserId = makerUserId;
    }

    public static class TransactionNotificationEventBuilder {
        public TransactionNotificationEventBuilder requiresMakerChecker(boolean val) {
            this.requires2FaOtp = val;
            return this;
        }

        public TransactionNotificationEventBuilder makerUserId(String val) {
            this.initiatorUserId = val;
            return this;
        }
    }
}
