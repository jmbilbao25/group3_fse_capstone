package com.fse.banking.account.repository;

import com.fse.banking.account.model.AccountEntity;
import com.fse.banking.account.model.BalanceMasterEntity;
import com.fse.banking.account.model.UserEntity;
import com.fse.banking.common.enums.AccountStatus;
import com.fse.banking.common.enums.AccountType;
import com.fse.banking.common.enums.UserRole;
import com.fse.banking.common.enums.UserStatus;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.test.context.TestPropertySource;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;

@DataJpaTest
@TestPropertySource(locations = "classpath:application-test.properties")
class AccountRepositoryIntegrationTest {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private AccountRepository accountRepository;

    @Autowired
    private BalanceMasterRepository balanceMasterRepository;

    @Test
    @DisplayName("Should persist and retrieve user, account, and balance master entities with 4-decimal precision")
    void testPersistAndRetrieveEntities() {
        UserEntity user = UserEntity.builder()
                .userId("USR-882190")
                .firstName("Juan")
                .lastName("Dela Cruz")
                .email("juan.delacruz@example.ph")
                .phoneNumber("+639171234567")
                .dob(LocalDate.of(1992, 5, 14))
                .governmentId("PASSPORT-P9921840A")
                .role(UserRole.CUSTOMER)
                .passwordHash("$2a$10$hashed")
                .status(UserStatus.ACTIVE)
                .build();

        userRepository.save(user);

        Optional<UserEntity> fetchedUser = userRepository.findByEmail("juan.delacruz@example.ph");
        assertThat(fetchedUser).isPresent();
        assertThat(fetchedUser.get().getUserId()).isEqualTo("USR-882190");

        AccountEntity account = AccountEntity.builder()
                .accountId("ACC-1002938471")
                .userId("USR-882190")
                .accountNumber("100100001234")
                .accountType(AccountType.SAVINGS)
                .status(AccountStatus.ACTIVE)
                .build();

        accountRepository.save(account);

        List<AccountEntity> userAccounts = accountRepository.findByUserId("USR-882190");
        assertThat(userAccounts).hasSize(1);
        assertThat(userAccounts.get(0).getAccountNumber()).isEqualTo("100100001234");

        BalanceMasterEntity balance = BalanceMasterEntity.builder()
                .accountId("ACC-1002938471")
                .balanceAmount(new BigDecimal("25000000.0000"))
                .holdAmount(new BigDecimal("15000000.0000"))
                .availableBalance(new BigDecimal("10000000.0000"))
                .build();

        balanceMasterRepository.save(balance);

        Optional<BalanceMasterEntity> fetchedBalance = balanceMasterRepository.findByAccountId("ACC-1002938471");
        assertThat(fetchedBalance).isPresent();
        assertThat(fetchedBalance.get().getBalanceAmount()).isEqualByComparingTo("25000000.0000");
        assertThat(fetchedBalance.get().getHoldAmount()).isEqualByComparingTo("15000000.0000");
        assertThat(fetchedBalance.get().getAvailableBalance()).isEqualByComparingTo("10000000.0000");
    }
}
