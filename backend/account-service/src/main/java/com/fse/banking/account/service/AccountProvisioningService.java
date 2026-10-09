package com.fse.banking.account.service;

import com.fse.banking.account.dto.AccountResponse;
import com.fse.banking.account.dto.CreateAccountRequest;
import com.fse.banking.account.dto.CreateAccountResponse;
import com.fse.banking.account.model.AccountEntity;
import com.fse.banking.account.model.BalanceMasterEntity;
import com.fse.banking.account.model.UserEntity;
import com.fse.banking.account.repository.AccountRepository;
import com.fse.banking.account.repository.BalanceMasterRepository;
import com.fse.banking.account.repository.UserRepository;
import com.fse.banking.account.security.RedisSessionStore;
import com.fse.banking.common.enums.AccountStatus;
import com.fse.banking.common.enums.AccountType;
import com.fse.banking.common.enums.UserStatus;
import com.fse.banking.common.exception.ForbiddenException;
import com.fse.banking.common.exception.ResourceNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.concurrent.ThreadLocalRandom;

@Slf4j
@Service
@RequiredArgsConstructor
public class AccountProvisioningService {

    private final AccountRepository accountRepository;
    private final BalanceMasterRepository balanceMasterRepository;
    private final UserRepository userRepository;
    private final RedisSessionStore redisSessionStore;

    @Transactional
    public CreateAccountResponse provisionAccount(CreateAccountRequest request) {
        log.info("Provisioning account of type {} for user {}", request.getAccountType(), request.getUserId());

        UserEntity user = userRepository.findById(request.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("User profile not found: " + request.getUserId()));

        if (user.getStatus() == UserStatus.LOCKED || user.getStatus() == UserStatus.SUSPENDED) {
            throw new ForbiddenException("Cannot provision account for a locked or suspended customer profile.");
        }

        String accountNumber = generateUniqueAccountNumber(request.getAccountType());
        String accountId = "ACC-" + (1000000000L + ThreadLocalRandom.current().nextLong(9000000000L));

        BigDecimal initialDeposit = request.getInitialDeposit() != null
                ? request.getInitialDeposit().setScale(4, RoundingMode.HALF_UP)
                : BigDecimal.ZERO.setScale(4, RoundingMode.HALF_UP);

        AccountEntity account = AccountEntity.builder()
                .accountId(accountId)
                .userId(user.getUserId())
                .accountNumber(accountNumber)
                .accountType(request.getAccountType())
                .status(AccountStatus.ACTIVE)
                .build();

        BalanceMasterEntity balanceMaster = BalanceMasterEntity.builder()
                .accountId(accountId)
                .balanceAmount(initialDeposit)
                .holdAmount(BigDecimal.ZERO.setScale(4, RoundingMode.HALF_UP))
                .availableBalance(initialDeposit)
                .build();

        accountRepository.save(account);
        balanceMasterRepository.save(balanceMaster);

        log.info("Provisioned account {} with number {} and initial balance {}", accountId, accountNumber, initialDeposit);

        return CreateAccountResponse.builder()
                .accountId(account.getAccountId())
                .accountNumber(account.getAccountNumber())
                .userId(account.getUserId())
                .accountType(account.getAccountType())
                .status(account.getStatus().name())
                .initialBalance(initialDeposit)
                .createdAt(account.getCreatedAt())
                .build();
    }

    @Transactional
    public AccountResponse updateAccountStatus(String accountId, AccountStatus status) {
        log.info("Updating account {} status to {}", accountId, status);

        AccountEntity account = accountRepository.findById(accountId)
                .or(() -> accountRepository.findByAccountNumber(accountId))
                .orElseThrow(() -> new ResourceNotFoundException("Account not found: " + accountId));

        account.setStatus(status);
        AccountEntity updated = accountRepository.save(account);

        // Invalidate Redis read-cache
        redisSessionStore.evictCachedBalance(accountId);

        return toAccountResponse(updated);
    }

    public List<AccountResponse> getAccountsByUser(String userId) {
        return accountRepository.findByUserId(userId)
                .stream()
                .map(this::toAccountResponse)
                .toList();
    }

    public List<AccountResponse> getAllAccounts() {
        List<AccountEntity> accounts = accountRepository.findAll();
        // One batch lookup for every owner, not a query per account.
        java.util.Map<String, UserEntity> owners = userRepository
                .findAllById(accounts.stream().map(AccountEntity::getUserId).distinct().toList())
                .stream()
                .collect(java.util.stream.Collectors.toMap(UserEntity::getUserId, u -> u));
        return accounts.stream()
                .map(a -> {
                    AccountResponse r = toAccountResponse(a);
                    UserEntity u = owners.get(a.getUserId());
                    if (u != null) {
                        r.setOwnerName((u.getFirstName() + " " + u.getLastName()).trim());
                        r.setOwnerRole(u.getRole() != null ? u.getRole().name() : null);
                    }
                    return r;
                })
                .toList();
    }

    public AccountResponse getAccountById(String accountId) {
        AccountEntity account = accountRepository.findById(accountId)
                .orElseThrow(() -> new ResourceNotFoundException("Account not found: " + accountId));
        return toAccountResponse(account);
    }

    private String generateUniqueAccountNumber(AccountType type) {
        String prefix = switch (type) {
            case SAVINGS -> "1001";
        };

        String candidate;
        int attempts = 0;
        do {
            long suffix = ThreadLocalRandom.current().nextLong(10000000L, 100000000L);
            candidate = prefix + suffix;
            attempts++;
            if (attempts > 50) {
                throw new IllegalStateException("Failed to generate unique account number after 50 attempts.");
            }
        } while (accountRepository.existsByAccountNumber(candidate));

        return candidate;
    }

    private AccountResponse toAccountResponse(AccountEntity entity) {
        return AccountResponse.builder()
                .accountId(entity.getAccountId())
                .userId(entity.getUserId())
                .accountNumber(entity.getAccountNumber())
                .accountType(entity.getAccountType())
                .status(entity.getStatus())
                .createdAt(entity.getCreatedAt())
                .build();
    }
}
