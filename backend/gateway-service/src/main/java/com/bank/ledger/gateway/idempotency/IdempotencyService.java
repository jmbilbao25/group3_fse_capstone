package com.bank.ledger.gateway.idempotency;

import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;

@Service
@RequiredArgsConstructor
public class IdempotencyService {

    private final StringRedisTemplate redisTemplate;
    private static final String PREFIX = "idempotency:";

    public boolean isDuplicate(String key) {
        return Boolean.TRUE.equals(redisTemplate.hasKey(PREFIX + key));
    }

    public void save(String key) {
        redisTemplate.opsForValue()
                .set(PREFIX + key, "PROCESSED", Duration.ofMinutes(10));
    }

    public boolean saveIfAbsent(String key) {
        return Boolean.TRUE.equals(redisTemplate.opsForValue()
                .setIfAbsent(PREFIX + key, "PROCESSED", Duration.ofMinutes(10)));
    }
}