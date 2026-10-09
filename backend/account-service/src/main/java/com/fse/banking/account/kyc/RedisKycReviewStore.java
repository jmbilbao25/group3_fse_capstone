package com.fse.banking.account.kyc;

import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Redis hash keyed by user id, no TTL: review evidence must not expire.
 * shortcut: interim store until the AURA_ADMIN review_cases table lands
 * (see docs/architecture/ADR-001); swap this bean, callers do not change.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RedisKycReviewStore implements KycReviewStore {

    static final String KEY = "kyc:reviews";

    private final StringRedisTemplate redis;
    private final ObjectMapper objectMapper;

    @Override
    public void save(KycReview review) {
        try {
            redis.opsForHash().put(KEY, review.getUserId(), objectMapper.writeValueAsString(review));
        } catch (Exception e) {
            throw new IllegalStateException("Could not persist KYC review for " + review.getUserId(), e);
        }
    }

    @Override
    public Optional<KycReview> find(String userId) {
        Object raw = redis.opsForHash().get(KEY, userId);
        return Optional.ofNullable(raw).map(r -> read(r.toString()));
    }

    @Override
    public List<KycReview> findAll() {
        List<KycReview> out = new ArrayList<>();
        for (Map.Entry<Object, Object> e : redis.opsForHash().entries(KEY).entrySet()) {
            KycReview r = read(e.getValue().toString());
            if (r != null) out.add(r);
        }
        return out;
    }

    private KycReview read(String json) {
        try {
            return objectMapper.readValue(json, KycReview.class);
        } catch (Exception e) {
            log.warn("Skipping unreadable KYC review: {}", e.getMessage());
            return null;
        }
    }
}
