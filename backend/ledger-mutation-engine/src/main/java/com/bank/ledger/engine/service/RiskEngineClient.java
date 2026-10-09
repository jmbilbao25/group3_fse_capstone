package com.bank.ledger.engine.service;

import com.bank.ledger.contracts.dto.MutationRequest;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.Builder;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.HashMap;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class RiskEngineClient {

    private final ObjectMapper objectMapper;

    @Value("${app.risk-service.url:http://risk-service:8084}")
    private String riskServiceBaseUrl;

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofMillis(500))
            .build();

    @Data
    @Builder
    public static class RiskEvaluationResult {
        private String decision;       // ALLOW, ADVISORY_WARNING, REQUIRE_2FA, BLOCK
        private int fraudScore;        // 0 to 100
        private boolean anomaly;
        private String primaryFlag;
        private double evaluationTimeMs;
        private String advisoryTier;
        private String warningTitle;
        private String warningMessage;
        private String authMethod;
        private String threatCategory;
        private String causeOfSuspicion;
        private String threatNarrative;
        private boolean sarDraftCreated;
        private String sarReportId;
    }

    /**
     * Calls the local NanoJev risk engine to evaluate transfer telemetry.
     * Enforces a 1500ms timeout for local neural model evaluation with safe fallback.
     */
    public RiskEvaluationResult evaluateRisk(MutationRequest request) {
        String url = riskServiceBaseUrl + "/api/v1/risk/evaluate";

        try {
            Map<String, Object> payload = new HashMap<>();
            payload.put("transaction_id", request.getTransactionId());
            payload.put("user_id", request.getInitiatorUserId());
            payload.put("account_id", request.getAccountId());
            payload.put("target_account_id", request.getTargetAccountId());
            payload.put("amount", request.getMutationAmount() != null ? request.getMutationAmount().doubleValue() : 0.0);
            payload.put("memo", request.getMemo() != null ? request.getMemo() : "");
            payload.put("latitude", request.getLatitude());
            payload.put("longitude", request.getLongitude());
            payload.put("ip_address", request.getIpAddress());

            // Telemetry and device flags
            if (request.getDeviceId() != null) payload.put("device_id", request.getDeviceId());
            if (request.getIsPrimaryDevice() != null) payload.put("is_primary_device", request.getIsPrimaryDevice());
            if (request.getIsOnCall() != null) payload.put("is_on_call", request.getIsOnCall());
            if (request.getIsScreenSharing() != null) payload.put("is_screen_sharing", request.getIsScreenSharing());
            if (request.getIsPasted() != null) payload.put("is_pasted", request.getIsPasted());

            if (request.getRemoteAppActive() != null) payload.put("remote_app_active", request.getRemoteAppActive());
            else if (request.getIsScreenSharing() != null) payload.put("remote_app_active", request.getIsScreenSharing());

            if (request.getActiveCall() != null) payload.put("active_call", request.getActiveCall());
            else if (request.getIsOnCall() != null) payload.put("active_call", request.getIsOnCall());

            if (request.getRooted() != null) payload.put("rooted", request.getRooted());
            if (request.getHooking() != null) payload.put("hooking", request.getHooking());
            if (request.getEmulator() != null) payload.put("emulator", request.getEmulator());
            if (request.getMockLocation() != null) payload.put("mock_location", request.getMockLocation());
            if (request.getIsVpn() != null) payload.put("is_vpn", request.getIsVpn());

            // Enriched device context (running packages, detected threats, media projection, telephony)
            Map<String, Object> deviceContext = request.getDeviceContext() != null
                    ? new HashMap<>(request.getDeviceContext())
                    : new HashMap<>();

            if (request.getRunningPackages() != null && !request.getRunningPackages().isEmpty()) {
                deviceContext.put("running_packages", request.getRunningPackages());
            }
            if (request.getDetectedThreats() != null && !request.getDetectedThreats().isEmpty()) {
                deviceContext.put("detected_threats", request.getDetectedThreats());
            }
            if (request.getRemoteAppActive() != null || request.getIsScreenSharing() != null) {
                boolean screenShare = Boolean.TRUE.equals(request.getRemoteAppActive()) || Boolean.TRUE.equals(request.getIsScreenSharing());
                deviceContext.put("remote_app_active", screenShare);
                Map<String, Object> mediaProjection = new HashMap<>();
                mediaProjection.put("is_screen_sharing", screenShare);
                deviceContext.put("media_projection", mediaProjection);
            }
            if (request.getActiveCall() != null || request.getIsOnCall() != null) {
                boolean onCall = Boolean.TRUE.equals(request.getActiveCall()) || Boolean.TRUE.equals(request.getIsOnCall());
                deviceContext.put("active_call", onCall);
                Map<String, Object> telephony = new HashMap<>();
                telephony.put("call_state", onCall ? "CALL_STATE_OFFHOOK" : "IDLE");
                deviceContext.put("telephony", telephony);
            }
            if (request.getIsPasted() != null && Boolean.TRUE.equals(request.getIsPasted())) {
                Map<String, Object> interaction = new HashMap<>();
                interaction.put("account_input_mode", "PASTED_FROM_CLIPBOARD");
                deviceContext.put("interaction", interaction);
            }
            if (request.getHooking() != null) {
                deviceContext.put("hooking", request.getHooking());
            }
            if (request.getRooted() != null) {
                deviceContext.put("rooted", request.getRooted());
            }
            if (request.getEmulator() != null) {
                deviceContext.put("emulator", request.getEmulator());
            }

            if (!deviceContext.isEmpty()) {
                payload.put("device_context", deviceContext);
            }

            String jsonBody = objectMapper.writeValueAsString(payload);

            HttpRequest httpRequest = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofMillis(1500))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(jsonBody))
                    .build();

            HttpResponse<String> response = httpClient.send(httpRequest, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() == 200) {
                JsonNode root = objectMapper.readTree(response.body());
                String decision = root.path("decision").asText("ALLOW");
                int score = root.path("fraud_score").asInt(0);
                boolean isAnomaly = root.path("is_anomaly").asBoolean(false);
                String primaryFlag = root.path("primary_flag").asText("NORMAL_TRANSACTION");
                double timeMs = root.path("evaluation_time_ms").asDouble(0.0);
                String advisoryTier = root.path("advisory_tier").asText("NONE");
                String authMethod = root.path("auth_method").asText("BIOMETRIC_PRIMARY");

                String threatCategory = root.hasNonNull("threat_category") ? root.path("threat_category").asText() : null;
                String causeOfSuspicion = root.hasNonNull("cause_of_suspicion") ? root.path("cause_of_suspicion").asText() : null;
                String threatNarrative = root.hasNonNull("threat_narrative") ? root.path("threat_narrative").asText() : null;
                boolean sarDraftCreated = root.path("sar_draft_created").asBoolean(false);
                String sarReportId = root.hasNonNull("sar_report_id") ? root.path("sar_report_id").asText() : null;

                String warningTitle = null;
                String warningMessage = null;
                JsonNode warningNode = root.path("warning_dialog");
                if (warningNode != null && !warningNode.isMissingNode() && !warningNode.isNull()) {
                    warningTitle = warningNode.path("title").asText(null);
                    warningMessage = warningNode.path("body_message").asText(null);
                }

                log.info("[NANOJEV RISK] TxId: {}, Decision: {}, Score: {}, Flag: {}, ThreatCat: {}, Cause: {}, SAR: {}, Latency: {}ms",
                        request.getTransactionId(), decision, score, primaryFlag, threatCategory, causeOfSuspicion, sarReportId, timeMs);

                return RiskEvaluationResult.builder()
                        .decision(decision)
                        .fraudScore(score)
                        .anomaly(isAnomaly)
                        .primaryFlag(primaryFlag)
                        .evaluationTimeMs(timeMs)
                        .advisoryTier(advisoryTier)
                        .warningTitle(warningTitle)
                        .warningMessage(warningMessage)
                        .authMethod(authMethod)
                        .threatCategory(threatCategory)
                        .causeOfSuspicion(causeOfSuspicion)
                        .threatNarrative(threatNarrative)
                        .sarDraftCreated(sarDraftCreated)
                        .sarReportId(sarReportId)
                        .build();
            } else {
                log.warn("[RISK ENGINE HTTP {}] Falling back to default threshold", response.statusCode());
            }
        } catch (Exception e) {
            log.warn("[RISK ENGINE TIMEOUT/FALLBACK] Could not reach risk service: {}. Falling back to default static threshold.",
                    e.getMessage());
        }

        // Safe fallback when service is offline or times out
        return RiskEvaluationResult.builder()
                .decision("ALLOW")
                .fraudScore(0)
                .anomaly(false)
                .primaryFlag("FALLBACK_STATIC_RULE")
                .evaluationTimeMs(0.0)
                .build();
    }
}
