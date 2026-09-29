package com.bank.ledger.gateway.idempotency;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

import java.time.Duration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class IdempotencyServiceTest {

    @Mock
    private StringRedisTemplate redisTemplate;

    @Mock
    private ValueOperations<String, String> valueOperations;

    private IdempotencyService idempotencyService;

    @BeforeEach
    void setUp() {
        idempotencyService = new IdempotencyService(redisTemplate);
    }

    @Test
    @DisplayName("isDuplicate should query Redis with idempotency: prefix")
    void testIsDuplicate() {
        when(redisTemplate.hasKey("idempotency:test-key-123")).thenReturn(true);

        boolean duplicate = idempotencyService.isDuplicate("test-key-123");

        assertThat(duplicate).isTrue();
        verify(redisTemplate).hasKey("idempotency:test-key-123");
    }

    @Test
    @DisplayName("save should set value with idempotency: prefix and 10 minute TTL")
    void testSave() {
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);

        idempotencyService.save("test-key-123");

        verify(valueOperations).set("idempotency:test-key-123", "PROCESSED", Duration.ofMinutes(10));
    }

    @Test
    @DisplayName("saveIfAbsent should call setIfAbsent with idempotency: prefix")
    void testSaveIfAbsent() {
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(valueOperations.setIfAbsent("idempotency:test-key-123", "PROCESSED", Duration.ofMinutes(10))).thenReturn(true);

        boolean saved = idempotencyService.saveIfAbsent("test-key-123");

        assertThat(saved).isTrue();
        verify(valueOperations).setIfAbsent("idempotency:test-key-123", "PROCESSED", Duration.ofMinutes(10));
    }
}
