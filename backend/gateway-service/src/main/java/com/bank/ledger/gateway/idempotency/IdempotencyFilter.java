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

        String key =
                exchange.getRequest()
                        .getHeaders()
                        .getFirst("Idempotency-Key");

        if (key != null && !key.isBlank()) {

            System.out.println("IDEMPOTENCY KEY = " + key);

            System.out.println("IS DUPLICATE = " + idempotencyService.isDuplicate(key));

            if (idempotencyService.isDuplicate(key)) {

                exchange.getResponse()
                        .setStatusCode(HttpStatus.CONFLICT);

                return exchange.getResponse()
                        .setComplete();
            }

            System.out.println("SAVING KEY = " + key);
            idempotencyService.save(key);
            System.out.println("KEY SAVED = " + key);
        }

        return chain.filter(exchange);
    }
}