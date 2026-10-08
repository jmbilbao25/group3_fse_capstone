package com.bank.ledger.gateway.security;

import lombok.RequiredArgsConstructor;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter implements GlobalFilter {

    private final JwtTokenValidator jwtTokenValidator;
    private final RedisTokenBlacklistService blacklistService;

    @Override
    public Mono<Void> filter(ServerWebExchange exchange,
                             GatewayFilterChain chain) {

        System.out.println("JWT FILTER EXECUTED: " +
                exchange.getRequest().getURI());

        // Allow CORS preflight OPTIONS requests
        if (HttpMethod.OPTIONS.equals(exchange.getRequest().getMethod())) {
            return chain.filter(exchange);
        }

        String path = exchange.getRequest().getPath().toString();

        // Allow public endpoints (actuator, authentication, SSE notification streams, simulation, websockets, t24 core banking)
        if (path.startsWith("/actuator")
                || path.startsWith("/api/v1/auth")
                || path.startsWith("/api/auth")
                || path.startsWith("/api/v1/notifications/stream")
                || path.startsWith("/api/v1/notifications/simulate")
                || path.startsWith("/api/v1/notifications/send-otp")
                || path.startsWith("/api/v1/t24")
                || path.startsWith("/api/t24")
                || path.startsWith("/ws")) {
            return chain.filter(exchange);
        }

        String authHeader =
                exchange.getRequest()
                        .getHeaders()
                        .getFirst(HttpHeaders.AUTHORIZATION);

        // If no auth header is provided, permit access for channel / demo integration
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return chain.filter(exchange);
        }

        String token = authHeader.substring(7);

        // Check Redis blacklist
        if (blacklistService.isBlacklisted(token)) {
            System.err.println("[GATEWAY JWT] Token is blacklisted in Redis");
            exchange.getResponse().setStatusCode(HttpStatus.UNAUTHORIZED);
            return exchange.getResponse().setComplete();
        }

        // Validate token
        if (!jwtTokenValidator.validate(token)) {
            System.err.println("[GATEWAY JWT] jwtTokenValidator returned false");
            exchange.getResponse().setStatusCode(HttpStatus.UNAUTHORIZED);
            return exchange.getResponse().setComplete();
        }

        return chain.filter(exchange);
    }
}