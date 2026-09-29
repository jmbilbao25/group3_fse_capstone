package com.bank.ledger.gateway.idempotency;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.http.HttpStatus;
import org.springframework.mock.http.server.reactive.MockServerHttpRequest;
import org.springframework.mock.web.server.MockServerWebExchange;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class IdempotencyFilterTest {

    @Mock
    private IdempotencyService idempotencyService;

    @Mock
    private GatewayFilterChain chain;

    private IdempotencyFilter filter;

    @BeforeEach
    void setUp() {
        filter = new IdempotencyFilter(idempotencyService);
        lenient().when(chain.filter(any(ServerWebExchange.class))).thenReturn(Mono.empty());
    }

    @Test
    @DisplayName("Should detect Idempotency-Key and save key when not duplicate")
    void testFilterWithStandardHeader() {
        MockServerHttpRequest request = MockServerHttpRequest
                .post("/api/v1/ledger/transfer")
                .header("Idempotency-Key", "key-std-1")
                .build();
        MockServerWebExchange exchange = MockServerWebExchange.from(request);

        when(idempotencyService.isDuplicate("key-std-1")).thenReturn(false);

        filter.filter(exchange, chain).block();

        verify(idempotencyService).isDuplicate("key-std-1");
        verify(idempotencyService).save("key-std-1");

        ArgumentCaptor<ServerWebExchange> captor = ArgumentCaptor.forClass(ServerWebExchange.class);
        verify(chain).filter(captor.capture());
        assertThat(captor.getValue().getRequest().getHeaders().getFirst("X-Idempotency-Key"))
                .isEqualTo("key-std-1");
    }

    @Test
    @DisplayName("Should detect X-Idempotency-Key and save key when not duplicate")
    void testFilterWithXHeader() {
        MockServerHttpRequest request = MockServerHttpRequest
                .post("/api/v1/ledger/transfer")
                .header("X-Idempotency-Key", "key-custom-2")
                .build();
        MockServerWebExchange exchange = MockServerWebExchange.from(request);

        when(idempotencyService.isDuplicate("key-custom-2")).thenReturn(false);

        filter.filter(exchange, chain).block();

        verify(idempotencyService).isDuplicate("key-custom-2");
        verify(idempotencyService).save("key-custom-2");
        verify(chain).filter(exchange);
    }

    @Test
    @DisplayName("Should return 409 CONFLICT if key is duplicate")
    void testFilterConflictOnDuplicate() {
        MockServerHttpRequest request = MockServerHttpRequest
                .post("/api/v1/ledger/transfer")
                .header("X-Idempotency-Key", "duplicate-key")
                .build();
        MockServerWebExchange exchange = MockServerWebExchange.from(request);

        when(idempotencyService.isDuplicate("duplicate-key")).thenReturn(true);

        filter.filter(exchange, chain).block();

        verify(idempotencyService).isDuplicate("duplicate-key");
        verify(idempotencyService, never()).save(any());
        verify(chain, never()).filter(any());
        assertThat(exchange.getResponse().getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    @DisplayName("Should proceed without idempotency check when header is absent")
    void testFilterWithoutHeader() {
        MockServerHttpRequest request = MockServerHttpRequest
                .get("/api/v1/accounts/123")
                .build();
        MockServerWebExchange exchange = MockServerWebExchange.from(request);

        filter.filter(exchange, chain).block();

        verify(idempotencyService, never()).isDuplicate(any());
        verify(idempotencyService, never()).save(any());
        verify(chain).filter(exchange);
    }
}
