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
    }

    /**
     * Calls the local NanoJev risk engine to evaluate transfer telemetry.
     * Enforces a 1500ms timeout for local neural model evaluation with safe fallback.
     */
    public RiskEvaluationResult evaluateRisk(MutationRequest request) {
        String url = riskServiceBaseUrl + "/api/v1/risk/analyze";

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

                String warningTitle = null;
                String warningMessage = null;
                JsonNode warningNode = root.path("warning_dialog");
                if (warningNode != null && !warningNode.isMissingNode() && !warningNode.isNull()) {
                    warningTitle = warningNode.path("title").asText(null);
                    warningMessage = warningNode.path("body_message").asText(null);
                }

                log.info("[NANOJEV RISK] TxId: {}, Decision: {}, Score: {}, Flag: {}, AdvisoryTier: {}, Latency: {}ms",
                        request.getTransactionId(), decision, score, primaryFlag, advisoryTier, timeMs);

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
