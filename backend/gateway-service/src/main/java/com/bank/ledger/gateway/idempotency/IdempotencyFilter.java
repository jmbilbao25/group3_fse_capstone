package com.bank.ledger.gateway.idempotency;

import lombok.RequiredArgsConstructor;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

@Component
@RequiredArgsConstructor
public class IdempotencyFilter implements GlobalFilter {

    private final IdempotencyService idempotencyService;

    @Override
    public Mono<Void> filter(ServerWebExchange exchange,
                             GatewayFilterChain chain) {

        if (Boolean.TRUE.equals(exchange.getAttribute("IDEMPOTENCY_PROCESSED"))) {
            return chain.filter(exchange);
        }
        exchange.getAttributes().put("IDEMPOTENCY_PROCESSED", Boolean.TRUE);

        String key =
                exchange.getRequest()
                        .getHeaders()
                        .getFirst("Idempotency-Key");

        if (key == null || key.isBlank()) {
            key = exchange.getRequest()
                    .getHeaders()
                    .getFirst("X-Idempotency-Key");
        }

        if (key != null && !key.isBlank()) {

            System.out.println("IDEMPOTENCY KEY = " + key);

            boolean duplicate = idempotencyService.isDuplicate(key);
            System.out.println("IS DUPLICATE = " + duplicate);

            if (duplicate) {

                exchange.getResponse()
                        .setStatusCode(HttpStatus.CONFLICT);

                return exchange.getResponse()
                        .setComplete();
            }

            System.out.println("SAVING KEY = " + key);
            idempotencyService.save(key);
            System.out.println("KEY SAVED = " + key);

            if (exchange.getRequest().getHeaders().getFirst("X-Idempotency-Key") == null) {
                final String finalKey = key;
                ServerWebExchange mutatedExchange = exchange.mutate()
                        .request(builder -> builder.header("X-Idempotency-Key", finalKey))
                        .build();
                return chain.filter(mutatedExchange);
            }
        }

        return chain.filter(exchange);
    }
}