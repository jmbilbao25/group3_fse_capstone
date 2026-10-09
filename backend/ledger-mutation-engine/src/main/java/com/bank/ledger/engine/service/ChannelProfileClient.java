package com.bank.ledger.engine.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Optional;

/**
 * Reads the customer's current location from the channel (account-service).
 * Device telemetry belongs to the channel, not the core, so the ledger asks for
 * it per transfer. A slow or missing channel never blocks a transfer.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ChannelProfileClient {

    private final ObjectMapper objectMapper;

    @Value("${app.account-service.url:http://account-service:8081}")
    private String accountServiceUrl;

    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofMillis(500)).build();

    public record Location(double latitude, double longitude, String name, String ip) {
    }

    public Optional<Location> currentLocation(String customerId) {
        try {
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(accountServiceUrl + "/api/v1/internal/users/"
                            + URLEncoder.encode(customerId, StandardCharsets.UTF_8) + "/location"))
                    .timeout(Duration.ofMillis(800))
                    .GET()
                    .build();
            HttpResponse<String> res = http.send(req, HttpResponse.BodyHandlers.ofString());
            if (res.statusCode() != 200) return Optional.empty();
            JsonNode n = objectMapper.readTree(res.body());
            if (!n.hasNonNull("latitude") || !n.hasNonNull("longitude")) return Optional.empty();
            return Optional.of(new Location(n.get("latitude").asDouble(), n.get("longitude").asDouble(),
                    n.path("location_name").asText(null), n.path("ip_address").asText(null)));
        } catch (Exception e) {
            log.warn("[CHANNEL] Location lookup failed for {}: {}", customerId, e.getMessage());
            return Optional.empty();
        }
    }
}
