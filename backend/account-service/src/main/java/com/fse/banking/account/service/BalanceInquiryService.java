package com.fse.banking.account.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fse.banking.account.dto.BalanceResponse;
import com.fse.banking.account.model.AccountEntity;
import com.fse.banking.account.model.BalanceMasterEntity;
import com.fse.banking.account.repository.AccountRepository;
import com.fse.banking.account.repository.BalanceMasterRepository;
import com.fse.banking.account.security.RedisSessionStore;
import com.fse.banking.common.exception.ResourceNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Optional;

@Slf4j
@Service
@RequiredArgsConstructor
public class BalanceInquiryService {

    private final AccountRepository accountRepository;
    private final BalanceMasterRepository balanceMasterRepository;
    private final RedisSessionStore redisSessionStore;
    private final ObjectMapper objectMapper;

    private static final Duration BALANCE_CACHE_TTL = Duration.ofSeconds(30);

    public BalanceResponse getBalance(String accountId) {
        // 1. Inspect Redis read-cache
        Optional<String> cachedJson = redisSessionStore.getCachedBalance(accountId);
        if (cachedJson.isPresent()) {
            try {
                BalanceResponse cached = objectMapper.readValue(cachedJson.get(), BalanceResponse.class);
                cached.setCached(true);
                log.debug("Balance read-cache hit for account: {}", accountId);
                return cached;
            } catch (Exception e) {
                log.warn("Failed to parse cached balance JSON for account {}: {}", accountId, e.getMessage());
            }
        }

        // 2. Cache miss: query persistence layer
        log.debug("Balance read-cache miss for account: {}. Querying database.", accountId);
        AccountEntity account = accountRepository.findById(accountId)
                .orElseThrow(() -> new ResourceNotFoundException("Account not found: " + accountId));

        BalanceMasterEntity balance = balanceMasterRepository.findByAccountId(accountId)
                .orElseThrow(() -> new ResourceNotFoundException("Balance record not found for account: " + accountId));

        BalanceResponse response = BalanceResponse.builder()
                .accountId(account.getAccountId())
                .accountType(account.getAccountType().name())
                .currency("PHP")
                .currentBalance(balance.getBalanceAmount())
                .heldBalance(balance.getHoldAmount())
                .availableBalance(balance.getAvailableBalance())
                .status(account.getStatus().name())
                .cached(false)
                .lastUpdated(balance.getUpdatedAt())
                .build();

        // 3. Populate Redis with 30-second TTL
        try {
            String jsonToCache = objectMapper.writeValueAsString(response);
            redisSessionStore.setCachedBalance(accountId, jsonToCache, BALANCE_CACHE_TTL);
        } catch (Exception e) {
            log.error("Failed to serialize balance payload for cache: {}", e.getMessage());
        }

        return response;
    }
}
