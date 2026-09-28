package com.bank.ledger.gateway.security;

import org.springframework.cloud.gateway.filter.ratelimit.KeyResolver;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import reactor.core.publisher.Mono;

@Configuration
public class RateLimiterConfig {

    @Bean
    public KeyResolver userKeyResolver() {
        return exchange -> {
            String xff = exchange.getRequest().getHeaders().getFirst("X-Forwarded-For");
            if (xff != null && !xff.isBlank()) {
                return Mono.just(xff.split(",")[0].trim());
            }
            if (exchange.getRequest().getRemoteAddress() != null) {
                if (exchange.getRequest().getRemoteAddress().getAddress() != null) {
                    return Mono.just(exchange.getRequest().getRemoteAddress().getAddress().getHostAddress());
                }
                return Mono.just(exchange.getRequest().getRemoteAddress().getHostString());
            }
            return Mono.just("anonymous");
        };
    }
}