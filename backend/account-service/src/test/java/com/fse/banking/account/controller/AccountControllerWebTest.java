package com.fse.banking.account.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fse.banking.account.dto.AccountResponse;
import com.fse.banking.account.dto.BalanceResponse;
import com.fse.banking.account.dto.CreateAccountRequest;
import com.fse.banking.account.dto.CreateAccountResponse;
import com.fse.banking.account.dto.UpdateAccountStatusRequest;
import com.fse.banking.account.exception.GlobalExceptionHandler;
import com.fse.banking.account.security.JwtProvider;
import com.fse.banking.account.service.AccountProvisioningService;
import com.fse.banking.account.service.BalanceInquiryService;
import com.fse.banking.common.enums.AccountStatus;
import com.fse.banking.common.enums.AccountType;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.time.Instant;

import static org.hamcrest.Matchers.notNullValue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = AccountController.class)
@AutoConfigureMockMvc(addFilters = false)
@Import(GlobalExceptionHandler.class)
class AccountControllerWebTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private AccountProvisioningService accountProvisioningService;

    @MockBean
    private BalanceInquiryService balanceInquiryService;

    @MockBean
    private JwtProvider jwtProvider;

    @Test
    @DisplayName("POST /api/v1/accounts should provision account and return 201 Created")
    void testProvisionAccount() throws Exception {
        CreateAccountRequest request = CreateAccountRequest.builder()
                .userId("USR-882190")
                .accountType(AccountType.SAVINGS)
                .initialDeposit(new BigDecimal("5000.0000"))
                .currency("PHP")
                .build();

        CreateAccountResponse response = CreateAccountResponse.builder()
                .accountId("ACC-1002938471")
                .accountNumber("100100001234")
                .userId("USR-882190")
                .accountType(AccountType.SAVINGS)
                .status("ACTIVE")
                .initialBalance(new BigDecimal("5000.0000"))
                .createdAt(Instant.now())
                .build();

        when(accountProvisioningService.provisionAccount(any(CreateAccountRequest.class))).thenReturn(response);

        mockMvc.perform(post("/api/v1/accounts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.account_id").value("ACC-1002938471"))
                .andExpect(jsonPath("$.account_number").value("100100001234"))
                .andExpect(jsonPath("$.status").value("ACTIVE"))
                .andExpect(jsonPath("$.initial_balance").value(5000.0000));
    }

    @Test
    @DisplayName("POST /api/v1/accounts should return 400 when initial deposit is negative")
    void testProvisionAccountNegativeDeposit() throws Exception {
        CreateAccountRequest request = CreateAccountRequest.builder()
                .userId("USR-882190")
                .accountType(AccountType.SAVINGS)
                .initialDeposit(new BigDecimal("-100.0000"))
                .currency("PHP")
                .build();

        mockMvc.perform(post("/api/v1/accounts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.type").value("https://api.banking.capstone/errors/validation-failed"))
                .andExpect(jsonPath("$.invalid_params", notNullValue()));
    }

    @Test
    @DisplayName("PATCH /api/v1/accounts/{id}/status should update account status")
    void testUpdateAccountStatus() throws Exception {
        UpdateAccountStatusRequest request = UpdateAccountStatusRequest.builder()
                .status(AccountStatus.LOCKED)
                .build();

        AccountResponse response = AccountResponse.builder()
                .accountId("ACC-1002938471")
                .userId("USR-882190")
                .accountNumber("100100001234")
                .accountType(AccountType.SAVINGS)
                .status(AccountStatus.LOCKED)
                .createdAt(Instant.now())
                .build();

        when(accountProvisioningService.updateAccountStatus(eq("ACC-1002938471"), eq(AccountStatus.LOCKED))).thenReturn(response);

        mockMvc.perform(patch("/api/v1/accounts/ACC-1002938471/status")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.account_id").value("ACC-1002938471"))
                .andExpect(jsonPath("$.status").value("LOCKED"));
    }

    @Test
    @DisplayName("GET /api/v1/accounts/{id}/balance should return balance breakdown")
    void testGetBalance() throws Exception {
        BalanceResponse response = BalanceResponse.builder()
                .accountId("ACC-1002938471")
                .accountType("SAVINGS")
                .currency("PHP")
                .currentBalance(new BigDecimal("25000000.0000"))
                .heldBalance(new BigDecimal("15000000.0000"))
                .availableBalance(new BigDecimal("10000000.0000"))
                .status("ACTIVE")
                .cached(true)
                .lastUpdated(Instant.now())
                .build();

        when(balanceInquiryService.getBalance("ACC-1002938471")).thenReturn(response);

        mockMvc.perform(get("/api/v1/accounts/ACC-1002938471/balance"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.account_id").value("ACC-1002938471"))
                .andExpect(jsonPath("$.currency").value("PHP"))
                .andExpect(jsonPath("$.current_balance").value(25000000.0000))
                .andExpect(jsonPath("$.held_balance").value(15000000.0000))
                .andExpect(jsonPath("$.available_balance").value(10000000.0000))
                .andExpect(jsonPath("$.cached").value(true));
    }

    @Test
    @DisplayName("GET /api/v1/accounts with a teller token should list every account, not the teller's own")
    void testStaffListsAllAccounts() throws Exception {
        when(jwtProvider.validateToken("teller-token")).thenReturn(true);
        when(jwtProvider.getUserId("teller-token")).thenReturn("U3002");
        when(jwtProvider.getRole("teller-token")).thenReturn("ROLE_TELLER");
        when(accountProvisioningService.getAllAccounts()).thenReturn(java.util.List.of(
                AccountResponse.builder().accountId("A2001").userId("U1001").accountType(AccountType.SAVINGS).build()));

        mockMvc.perform(get("/api/v1/accounts").header("Authorization", "Bearer teller-token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].user_id").value("U1001"));
    }
}
