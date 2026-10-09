package com.fse.banking.account.controller;

import com.fse.banking.account.dto.AccountResponse;
import com.fse.banking.account.dto.BalanceResponse;
import com.fse.banking.account.dto.CreateAccountRequest;
import com.fse.banking.account.dto.CreateAccountResponse;
import com.fse.banking.account.dto.UpdateAccountStatusRequest;
import com.fse.banking.account.security.JwtProvider;
import com.fse.banking.account.service.AccountProvisioningService;
import com.fse.banking.account.service.BalanceInquiryService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Collections;
import java.util.List;

@Slf4j
@RestController
@RequestMapping("/api/v1/accounts")
@RequiredArgsConstructor
public class AccountController {

    private final AccountProvisioningService accountProvisioningService;
    private final BalanceInquiryService balanceInquiryService;
    private final JwtProvider jwtProvider;

    @PostMapping
    public ResponseEntity<CreateAccountResponse> provisionAccount(@Valid @RequestBody CreateAccountRequest request) {
        CreateAccountResponse response = accountProvisioningService.provisionAccount(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    

    @PatchMapping("/{accountId}/status")
    public ResponseEntity<AccountResponse> updateAccountStatus(
            @PathVariable("accountId") String accountId,
            @Valid @RequestBody UpdateAccountStatusRequest request) {
        AccountResponse response = accountProvisioningService.updateAccountStatus(accountId, request.getStatus());
        return ResponseEntity.ok(response);

    }

    @GetMapping
    public ResponseEntity<List<AccountResponse>> getAccounts(
            @RequestParam(value = "userId", required = false) String userIdParam,
            @RequestHeader(value = HttpHeaders.AUTHORIZATION, required = false) String authHeader) {
        String effectiveUserId = userIdParam;
        String userRole = null;
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            if (jwtProvider.validateToken(token)) {
                if (effectiveUserId == null || effectiveUserId.isBlank()) {
                    effectiveUserId = jwtProvider.getUserId(token);
                }
                userRole = jwtProvider.getRole(token);
            }
        }

        // If specific customer userId is queried, filter by customer
        if (userIdParam != null && !userIdParam.isBlank()) {
            return ResponseEntity.ok(accountProvisioningService.getAccountsByUser(userIdParam));
        }

        // For administrators or general core inquiry, return all customer accounts
        if ("ROLE_ADMIN".equals(userRole) || "ADMIN".equals(userRole) 
                || effectiveUserId == null || effectiveUserId.isBlank() 
                || effectiveUserId.contains("adm") || effectiveUserId.contains("mgr")) {
            return ResponseEntity.ok(accountProvisioningService.getAllAccounts());
        }

        List<AccountResponse> accounts = accountProvisioningService.getAccountsByUser(effectiveUserId);
        return ResponseEntity.ok(accounts);
    }

    @GetMapping("/{accountId}")
    public ResponseEntity<AccountResponse> getAccountById(@PathVariable("accountId") String accountId) {
        AccountResponse account = accountProvisioningService.getAccountById(accountId);
        return ResponseEntity.ok(account);
    }

    @GetMapping("/{accountId}/balance")
    public ResponseEntity<BalanceResponse> getBalance(@PathVariable("accountId") String accountId) {
        BalanceResponse balance = balanceInquiryService.getBalance(accountId);
        return ResponseEntity.ok(balance);
    }
}



