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
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AccountProvisioningServiceTest {

    @Mock
    private AccountRepository accountRepository;

    @Mock
    private BalanceMasterRepository balanceMasterRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private RedisSessionStore redisSessionStore;

    @InjectMocks
    private AccountProvisioningService provisioningService;

    private UserEntity activeUser;

    @BeforeEach
    void setUp() {
        activeUser = UserEntity.builder()
                .userId("USR-100001")
                .email("juan.delacruz@example.ph")
                .status(UserStatus.ACTIVE)
                .build();
    }

    @Test
    @DisplayName("Should provision Savings account with 1001-prefix 12-digit account number and exact 4-decimal balance")
    void testProvisionSavingsAccount() {
        CreateAccountRequest request = CreateAccountRequest.builder()
                .userId("USR-100001")
                .accountType(AccountType.SAVINGS)
                .initialDeposit(new BigDecimal("5000.0000"))
                .currency("PHP")
                .build();

        when(userRepository.findById("USR-100001")).thenReturn(Optional.of(activeUser));
        when(accountRepository.existsByAccountNumber(anyString())).thenReturn(false);

        CreateAccountResponse response = provisioningService.provisionAccount(request);

        assertThat(response).isNotNull();
        assertThat(response.getAccountId()).startsWith("ACC-");
        assertThat(response.getAccountNumber()).hasSize(12).startsWith("1001");
        assertThat(response.getAccountType()).isEqualTo(AccountType.SAVINGS);
        assertThat(response.getStatus()).isEqualTo("ACTIVE");
        assertThat(response.getInitialBalance()).isEqualByComparingTo("5000.0000");

        ArgumentCaptor<BalanceMasterEntity> balanceCaptor = ArgumentCaptor.forClass(BalanceMasterEntity.class);
        verify(balanceMasterRepository).save(balanceCaptor.capture());
        BalanceMasterEntity savedBalance = balanceCaptor.getValue();
        assertThat(savedBalance.getBalanceAmount()).isEqualByComparingTo("5000.0000");
        assertThat(savedBalance.getHoldAmount()).isEqualByComparingTo("0.0000");
        assertThat(savedBalance.getAvailableBalance()).isEqualByComparingTo("5000.0000");
    }

    @Test
    @DisplayName("Should throw ResourceNotFoundException when user does not exist")
    void testProvisionUserNotFound() {
        CreateAccountRequest request = CreateAccountRequest.builder()
                .userId("USR-999999")
                .accountType(AccountType.SAVINGS)
                .initialDeposit(BigDecimal.ZERO)
                .build();

        when(userRepository.findById("USR-999999")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> provisioningService.provisionAccount(request))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("User profile not found: USR-999999");
    }

    @Test
    @DisplayName("Should throw ForbiddenException when user is locked or suspended")
    void testProvisionLockedUser() {
        activeUser.setStatus(UserStatus.LOCKED);
        CreateAccountRequest request = CreateAccountRequest.builder()
                .userId("USR-100001")
                .accountType(AccountType.SAVINGS)
                .initialDeposit(BigDecimal.ZERO)
                .build();

        when(userRepository.findById("USR-100001")).thenReturn(Optional.of(activeUser));

        assertThatThrownBy(() -> provisioningService.provisionAccount(request))
                .isInstanceOf(ForbiddenException.class)
                .hasMessageContaining("Cannot provision account for a locked or suspended customer profile.");
    }

    @Test
    @DisplayName("Should update account status and evict Redis read-cache")
    void testUpdateAccountStatus() {
        AccountEntity account = AccountEntity.builder()
                .accountId("ACC-101")
                .userId("USR-100001")
                .accountNumber("100100001234")
                .accountType(AccountType.SAVINGS)
                .status(AccountStatus.ACTIVE)
                .build();

        when(accountRepository.findById("ACC-101")).thenReturn(Optional.of(account));
        when(accountRepository.save(any(AccountEntity.class))).thenAnswer(inv -> inv.getArgument(0));

        AccountResponse response = provisioningService.updateAccountStatus("ACC-101", AccountStatus.LOCKED);

        assertThat(response.getStatus()).isEqualTo(AccountStatus.LOCKED);
        verify(redisSessionStore).evictCachedBalance("ACC-101");
    }

    @Test
    @DisplayName("Should attach the owner's name and role to every account in the staff listing")
    void testGetAllAccountsCarriesOwner() {
        AccountEntity owned = AccountEntity.builder()
                .accountId("ACC-201").userId("USR-200001").accountNumber("100100009876")
                .accountType(AccountType.SAVINGS).status(AccountStatus.ACTIVE).build();
        UserEntity owner = UserEntity.builder()
                .userId("USR-200001").firstName("Juan").lastName("Dela Cruz")
                .role(com.fse.banking.common.enums.UserRole.CUSTOMER).build();
        when(accountRepository.findAll()).thenReturn(List.of(owned));
        when(userRepository.findAllById(List.of("USR-200001"))).thenReturn(List.of(owner));

        AccountResponse r = provisioningService.getAllAccounts().get(0);
        assertThat(r.getOwnerName()).isEqualTo("Juan Dela Cruz");
        assertThat(r.getOwnerRole()).isEqualTo("CUSTOMER");
    }

    @Test
    @DisplayName("Should retrieve list of accounts for a user")
    void testGetAccountsByUser() {
        AccountEntity account = AccountEntity.builder()
                .accountId("ACC-101")
                .userId("USR-100001")
                .accountNumber("100100001234")
                .accountType(AccountType.SAVINGS)
                .status(AccountStatus.ACTIVE)
                .build();

        when(accountRepository.findByUserId("USR-100001")).thenReturn(List.of(account));

        List<AccountResponse> accounts = provisioningService.getAccountsByUser("USR-100001");

        assertThat(accounts).hasSize(1);
        assertThat(accounts.get(0).getAccountId()).isEqualTo("ACC-101");
    }
}
