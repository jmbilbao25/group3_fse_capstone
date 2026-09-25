package com.bank.ledger.gateway.security;

import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class RedisTokenBlacklistService {

    private final StringRedisTemplate redisTemplate;

    public boolean isBlacklisted(String token) {
        return Boolean.TRUE.equals(
                redisTemplate.hasKey(token)
        );
    }

    public void blacklist(String token) {
        redisTemplate.opsForValue()
                .set(token, "BLACKLISTED");
    }
}