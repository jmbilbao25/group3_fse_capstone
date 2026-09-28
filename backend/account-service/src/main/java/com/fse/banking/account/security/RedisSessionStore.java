package com.fse.banking.account.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fse.banking.account.security.model.RefreshTokenMetadata;
import com.fse.banking.account.security.model.SessionMetadata;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Optional;
import java.util.Set;

@Slf4j
@Service
@RequiredArgsConstructor
public class RedisSessionStore {

    private final StringRedisTemplate stringRedisTemplate;
    private final RedisTemplate<String, Object> redisTemplate;
    private final ObjectMapper objectMapper;

    private static final String BLACKLIST_PREFIX = "auth:blacklist:";
    private static final String GATEWAY_BLACKLIST_PREFIX = "blacklist:jti:";
    private static final String USER_SESSIONS_PREFIX = "auth:user-sessions:";
    private static final String REFRESH_TOKEN_PREFIX = "refresh_token:";
    private static final String TOKEN_FAMILY_PREFIX = "token_family:";
    private static final String SESSION_PREFIX = "session:";
    private static final String BALANCE_CACHE_PREFIX = "account:balance:";

    // --- Blacklist Operations ---
    public void blacklistToken(String jti, long remainingTtlSeconds) {
        if (jti == null || remainingTtlSeconds <= 0) {
            return;
        }
        Duration ttl = Duration.ofSeconds(remainingTtlSeconds);
        stringRedisTemplate.opsForValue().set(BLACKLIST_PREFIX + jti, "REVOKED", ttl);
        stringRedisTemplate.opsForValue().set(GATEWAY_BLACKLIST_PREFIX + jti, "REVOKED", ttl);
        log.debug("Access token jti {} blacklisted for {} seconds", jti, remainingTtlSeconds);
    }

    public boolean isBlacklisted(String jti) {
        if (jti == null) {
            return false;
        }
        Boolean blacklisted = stringRedisTemplate.hasKey(BLACKLIST_PREFIX + jti);
        if (Boolean.TRUE.equals(blacklisted)) {
            return true;
        }
        return Boolean.TRUE.equals(stringRedisTemplate.hasKey(GATEWAY_BLACKLIST_PREFIX + jti));
    }

    // --- Active Sessions & Concurrency Limits ---
    public void registerSessionToken(String userId, String jti, int maxSessions) {
        String key = USER_SESSIONS_PREFIX + userId;
        Long currentCount = stringRedisTemplate.opsForSet().size(key);
        if (currentCount != null && currentCount >= maxSessions) {
            String evictedJti = stringRedisTemplate.opsForSet().pop(key);
            if (evictedJti != null) {
                blacklistToken(evictedJti, 900); // 15m blacklist
                log.info("Evicted session token jti {} for user {} due to concurrency limit", evictedJti, userId);
            }
        }
        stringRedisTemplate.opsForSet().add(key, jti);
        stringRedisTemplate.expire(key, Duration.ofDays(7));
    }

    public void removeSessionToken(String userId, String jti) {
        String key = USER_SESSIONS_PREFIX + userId;
        stringRedisTemplate.opsForSet().remove(key, jti);
    }

    // --- Refresh Tokens ---
    public void saveRefreshToken(RefreshTokenMetadata metadata, Duration ttl) {
        String key = REFRESH_TOKEN_PREFIX + metadata.getTokenId();
        redisTemplate.opsForValue().set(key, metadata, ttl);
    }

    public Optional<RefreshTokenMetadata> getRefreshToken(String tokenId) {
        String key = REFRESH_TOKEN_PREFIX + tokenId;
        Object val = redisTemplate.opsForValue().get(key);
        if (val == null) {
            return Optional.empty();
        }
        if (val instanceof RefreshTokenMetadata metadata) {
            return Optional.of(metadata);
        }
        try {
            RefreshTokenMetadata metadata = objectMapper.convertValue(val, RefreshTokenMetadata.class);
            return Optional.of(metadata);
        } catch (Exception e) {
            log.error("Failed to deserialize refresh token metadata for key {}: {}", key, e.getMessage());
            return Optional.empty();
        }
    }

    public void markRefreshTokenRevoked(String tokenId) {
        getRefreshToken(tokenId).ifPresent(metadata -> {
            metadata.setStatus("REVOKED");
            saveRefreshToken(metadata, Duration.ofDays(7));
        });
    }

    public void deleteRefreshToken(String tokenId) {
        redisTemplate.delete(REFRESH_TOKEN_PREFIX + tokenId);
    }

    // --- Token Family & Breach Purge ---
    public void addToTokenFamily(String sessionId, String tokenId) {
        String key = TOKEN_FAMILY_PREFIX + sessionId;
        stringRedisTemplate.opsForSet().add(key, tokenId);
        stringRedisTemplate.expire(key, Duration.ofDays(7));
    }

    public void purgeEntireTokenFamily(String sessionId, String userId) {
        String familyKey = TOKEN_FAMILY_PREFIX + sessionId;
        Set<String> tokenIds = stringRedisTemplate.opsForSet().members(familyKey);
        if (tokenIds != null) {
            for (String tokenId : tokenIds) {
                deleteRefreshToken(tokenId);
            }
        }
        stringRedisTemplate.delete(familyKey);
        deleteSession(userId, sessionId);
        log.warn("Breach detection: purged entire token family for session {} and user {}", sessionId, userId);
    }

    // --- Session Metadata ---
    public void saveSession(String userId, String sessionId, SessionMetadata metadata, Duration ttl) {
        String key = SESSION_PREFIX + userId + ":" + sessionId;
        redisTemplate.opsForValue().set(key, metadata, ttl);
    }

    public void deleteSession(String userId, String sessionId) {
        redisTemplate.delete(SESSION_PREFIX + userId + ":" + sessionId);
    }

    // --- Balance Read-Through Cache ---
    public Optional<String> getCachedBalance(String accountId) {
        String val = stringRedisTemplate.opsForValue().get(BALANCE_CACHE_PREFIX + accountId);
        return Optional.ofNullable(val);
    }

    public void setCachedBalance(String accountId, String jsonPayload, Duration ttl) {
        stringRedisTemplate.opsForValue().set(BALANCE_CACHE_PREFIX + accountId, jsonPayload, ttl);
    }

    public void evictCachedBalance(String accountId) {
        stringRedisTemplate.delete(BALANCE_CACHE_PREFIX + accountId);
    }
}
