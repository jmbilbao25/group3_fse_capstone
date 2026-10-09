package com.bank.ledger.contracts.dto;

import com.bank.ledger.contracts.enums.EventType;
import com.bank.ledger.contracts.enums.MutationType;
import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Flexible & Strict JSR-380 Payload for the Core Mutation Perimeter.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MutationRequest {

    @JsonProperty("transaction_id")
    @JsonAlias({"transaction_id", "transactionId", "refNumber", "reference_number"})
    private String transactionId;

    @NotBlank(message = "account_id is mandatory")
    @JsonProperty("account_id")
    @JsonAlias({"account_id", "accountId", "from_account_id", "fromAccountId", "fromAccount", "source_account_id", "sourceAccountId"})
    private String accountId;

    @JsonProperty("target_account_id")
    @JsonAlias({"target_account_id", "targetAccountId", "to_account_id", "toAccountId", "toAccount", "destination_account_id", "destinationAccountId"})
    private String targetAccountId;

    @JsonProperty("event_type")
    @JsonAlias({"event_type", "eventType"})
    @Builder.Default
    private EventType eventType = EventType.TRANSFER;

    @JsonProperty("mutation_type")
    @JsonAlias({"mutation_type", "mutationType"})
    @Builder.Default
    private MutationType mutationType = MutationType.TRANSFER;

    @NotNull(message = "mutation_amount cannot be null")
    @Positive(message = "mutation_amount must be strictly positive")
    @Digits(integer = 14, fraction = 4, message = "mutation_amount must match precision with maximum 14 integer digits and 4 decimal places")
    @JsonProperty("mutation_amount")
    @JsonAlias({"mutation_amount", "mutationAmount", "amount"})
    private BigDecimal mutationAmount;

    @JsonProperty("initiator_user_id")
    @JsonAlias({"initiator_user_id", "initiatorUserId", "maker_user_id", "makerUserId", "userId", "user_id"})
    @Builder.Default
    private String initiatorUserId = "U1001";

    @JsonProperty("approved_by_user_id")
    @JsonAlias({"approved_by_user_id", "approvedByUserId", "checker_user_id"})
    private String approvedByUserId;

    @JsonProperty("memo")
    @JsonAlias({"memo", "remarks", "note", "description"})
    private String memo;

    @JsonProperty("latitude")
    @JsonAlias({"latitude", "lat"})
    private Double latitude;

    @JsonProperty("longitude")
    @JsonAlias({"longitude", "lng", "lon"})
    private Double longitude;

    @JsonProperty("ip_address")
    @JsonAlias({"ip_address", "ipAddress", "ip", "client_ip"})
    private String ipAddress;

    @JsonProperty("device_id")
    @JsonAlias({"device_id", "deviceId"})
    private String deviceId;

    @JsonProperty("is_primary_device")
    @JsonAlias({"is_primary_device", "isPrimaryDevice"})
    private Boolean isPrimaryDevice;

    @JsonProperty("remote_app_active")
    @JsonAlias({"remote_app_active", "remoteAppActive", "isScreenSharing", "is_screen_sharing"})
    private Boolean remoteAppActive;

    @JsonProperty("active_call")
    @JsonAlias({"active_call", "activeCall", "callState", "call_state"})
    private Boolean activeCall;

    @JsonProperty("rooted")
    @JsonAlias({"rooted", "isRooted", "is_rooted"})
    private Boolean rooted;

    @JsonProperty("hooking")
    @JsonAlias({"hooking", "isHooked", "is_hooked"})
    private Boolean hooking;

    @JsonProperty("emulator")
    @JsonAlias({"emulator", "isEmulator", "is_emulator"})
    private Boolean emulator;

    @JsonProperty("mock_location")
    @JsonAlias({"mock_location", "mockLocation", "isMockLocation"})
    private Boolean mockLocation;

    @JsonProperty("is_vpn")
    @JsonAlias({"is_vpn", "isVpn", "vpnActive"})
    private Boolean isVpn;

    @JsonProperty("running_packages")
    @JsonAlias({"running_packages", "runningPackages"})
    private java.util.List<String> runningPackages;

    @JsonProperty("detected_threats")
    @JsonAlias({"detected_threats", "detectedThreats"})
    private java.util.List<String> detectedThreats;

    @JsonProperty("device_context")
    @JsonAlias({"device_context", "deviceContext"})
    private java.util.Map<String, Object> deviceContext;

    @JsonProperty("is_on_call")
    @JsonAlias({"is_on_call", "isOnCall"})
    private Boolean isOnCall;

    @JsonProperty("is_screen_sharing")
    @JsonAlias({"is_screen_sharing", "isScreenSharing"})
    private Boolean isScreenSharing;

    @JsonProperty("is_pasted")
    @JsonAlias({"is_pasted", "isPasted"})
    private Boolean isPasted;

    @JsonProperty("biometric_signature")
    @JsonAlias({"biometric_signature", "biometricSignature"})
    private String biometricSignature;

    @JsonProperty("scam_advisory_acknowledged")
    @JsonAlias({"scam_advisory_acknowledged", "scamAdvisoryAcknowledged"})
    private Boolean scamAdvisoryAcknowledged;

    @JsonProperty("idempotency_key")
    @JsonAlias({"idempotency_key", "idempotencyKey"})
    private String idempotencyKey;
}
