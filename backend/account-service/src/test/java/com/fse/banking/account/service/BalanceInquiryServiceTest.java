package com.fse.banking.account.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.fse.banking.account.dto.BalanceResponse;
import com.fse.banking.account.model.AccountEntity;
import com.fse.banking.account.model.BalanceMasterEntity;
import com.fse.banking.account.repository.AccountRepository;
import com.fse.banking.account.repository.BalanceMasterRepository;
import com.fse.banking.account.security.RedisSessionStore;
import com.fse.banking.common.enums.AccountStatus;
import com.fse.banking.common.enums.AccountType;
import com.fse.banking.common.exception.ResourceNotFoundException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BalanceInquiryServiceTest {

    @Mock
    private AccountRepository accountRepository;

    @Mock
    private BalanceMasterRepository balanceMasterRepository;

    @Mock
    private RedisSessionStore redisSessionStore;

    @Spy
    private ObjectMapper objectMapper = new ObjectMapper().registerModule(new JavaTimeModule());

    @InjectMocks
    private BalanceInquiryService balanceInquiryService;

    private AccountEntity account;
    private BalanceMasterEntity balanceMaster;

    @BeforeEach
    void setUp() {
        account = AccountEntity.builder()
                .accountId("ACC-1002938471")
                .userId("USR-100001")
                .accountNumber("100100001234")
                .accountType(AccountType.SAVINGS)
                .status(AccountStatus.ACTIVE)
                .build();

        balanceMaster = BalanceMasterEntity.builder()
                .accountId("ACC-1002938471")
                .balanceAmount(new BigDecimal("25000000.0000"))
                .holdAmount(new BigDecimal("5000000.0000"))
                .availableBalance(new BigDecimal("20000000.0000"))
                .updatedAt(Instant.now())
                .build();
    }

    @Test
    @DisplayName("Should return cached balance response with cached=true when Redis hit occurs")
    void testGetBalanceCacheHit() throws Exception {
        BalanceResponse cachedResponse = BalanceResponse.builder()
                .accountId("ACC-1002938471")
                .accountType("SAVINGS")
                .currency("PHP")
                .currentBalance(new BigDecimal("25000000.0000"))
                .heldBalance(new BigDecimal("5000000.0000"))
                .availableBalance(new BigDecimal("20000000.0000"))
                .status("ACTIVE")
                .cached(false)
                .lastUpdated(Instant.now())
                .build();

        String cachedJson = objectMapper.writeValueAsString(cachedResponse);
        when(redisSessionStore.getCachedBalance("ACC-1002938471")).thenReturn(Optional.of(cachedJson));

        BalanceResponse result = balanceInquiryService.getBalance("ACC-1002938471");

        assertThat(result).isNotNull();
        assertThat(result.isCached()).isTrue();
        assertThat(result.getCurrentBalance()).isEqualByComparingTo("25000000.0000");
        assertThat(result.getAvailableBalance()).isEqualByComparingTo("20000000.0000");

        verify(accountRepository, never()).findById(anyString());
        verify(balanceMasterRepository, never()).findByAccountId(anyString());
    }

    @Test
    @DisplayName("Should query database, write to Redis with 30s TTL, and return cached=false on cache miss")
    void testGetBalanceCacheMiss() {
        when(redisSessionStore.getCachedBalance("ACC-1002938471")).thenReturn(Optional.empty());
        when(accountRepository.findById("ACC-1002938471")).thenReturn(Optional.of(account));
        when(balanceMasterRepository.findByAccountId("ACC-1002938471")).thenReturn(Optional.of(balanceMaster));

        BalanceResponse result = balanceInquiryService.getBalance("ACC-1002938471");

        assertThat(result).isNotNull();
        assertThat(result.isCached()).isFalse();
        assertThat(result.getCurrentBalance()).isEqualByComparingTo("25000000.0000");
        assertThat(result.getHeldBalance()).isEqualByComparingTo("5000000.0000");
        assertThat(result.getAvailableBalance()).isEqualByComparingTo("20000000.0000");

        verify(redisSessionStore).setCachedBalance(eq("ACC-1002938471"), anyString(), eq(Duration.ofSeconds(30)));
    }

    @Test
    @DisplayName("Should throw ResourceNotFoundException when account does not exist")
    void testGetBalanceAccountNotFound() {
        when(redisSessionStore.getCachedBalance("ACC-999")).thenReturn(Optional.empty());
        when(accountRepository.findById("ACC-999")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> balanceInquiryService.getBalance("ACC-999"))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Account not found: ACC-999");
    }
}
