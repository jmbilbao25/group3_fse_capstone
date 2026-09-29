package com.bank.ledger.engine.controller;

import com.bank.ledger.contracts.dto.CheckerActionRequest;
import com.bank.ledger.contracts.dto.MutationRequest;
import com.bank.ledger.contracts.dto.MutationResponse;
import com.bank.ledger.contracts.exception.InsufficientFundsException;
import com.bank.ledger.contracts.exception.SegregationOfDutiesException;
import com.bank.ledger.engine.entity.master.TransactionMaster;
import com.bank.ledger.engine.service.BalanceMutationService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/v1/ledger")
@RequiredArgsConstructor
public class BalanceMutationController {

    private final BalanceMutationService mutationService;

    /**
     * 1. Initiate Funds Transfer (TRX-501)
     * - Immediate settlement if <= PHP 50,000.00
     * - Soft hold & Maker-Checker routed if > PHP 50,000.00
     */
    @PostMapping({"/transfer", "/transfers"})
    public ResponseEntity<MutationResponse> executeTransfer(
            @RequestHeader(value = "X-Idempotency-Key", required = false) String idempotencyKey,
            @Valid @RequestBody MutationRequest request) {
        if (request.getTransactionId() == null || request.getTransactionId().isBlank()) {
            request.setTransactionId(idempotencyKey != null && !idempotencyKey.isBlank()
                    ? idempotencyKey
                    : "TX-" + java.util.UUID.randomUUID().toString().substring(0, 8).toUpperCase());
        }
        if (request.getEventType() == null) {
            request.setEventType(com.bank.ledger.contracts.enums.EventType.TRANSFER);
        }
        if (request.getMutationType() == null) {
            request.setMutationType(com.bank.ledger.contracts.enums.MutationType.TRANSFER);
        }
        if (request.getInitiatorUserId() == null || request.getInitiatorUserId().isBlank()) {
            request.setInitiatorUserId("U1001");
        }

        log.info("[HTTP REQUEST] POST /api/v1/ledger/transfer from account: {} to {}",
                request.getAccountId(), request.getTargetAccountId());

        MutationResponse response = mutationService.executeTransfer(request);
        return ResponseEntity.ok(response);
    }

    /**
     * 2. Teller Approval of High-Value Transfer (TRX-502, TRX-503)
     */
    @PostMapping({"/transfers/{transactionId}/approve", "/transfers/{transactionId}/sign-l1", "/transfers/{transactionId}/sign-l2", "/transfers/{transactionId}/approve-first", "/transfers/{transactionId}/approve-second"})
    public ResponseEntity<MutationResponse> approveTransfer(
            @PathVariable String transactionId,
            @Valid @RequestBody CheckerActionRequest request) {
        log.info("[HTTP REQUEST] POST /api/v1/ledger/transfers/{}/approve by checker {}",
                transactionId, request.getCheckerUserId());

        MutationResponse response = mutationService.approveTransfer(transactionId, request);
        return ResponseEntity.ok(response);
    }

    /**
     * 3. Teller Rejection of High-Value Transfer (TRX-502)
     */
    @PostMapping("/transfers/{transactionId}/reject")
    public ResponseEntity<MutationResponse> rejectTransfer(
            @PathVariable String transactionId,
            @Valid @RequestBody CheckerActionRequest request) {
        log.info("[HTTP REQUEST] POST /api/v1/ledger/transfers/{}/reject by checker {}",
                transactionId, request.getCheckerUserId());

        MutationResponse response = mutationService.rejectTransfer(transactionId, request);
        return ResponseEntity.ok(response);
    }

    /**
     * 4. Teller Review Queue: Query all pending approval transfers (UI-703)
     */
    @GetMapping("/transfers/pending")
    public ResponseEntity<List<TransactionMaster>> getPendingTransfers() {
        return ResponseEntity.ok(mutationService.getPendingTransfers());
    }

    /**
     * 5. Customer 2FA Email OTP Verification & Settlement (UI-704 / TRX-504)
     */
    @PostMapping("/transfers/verify-otp")
    public ResponseEntity<Map<String, Object>> verifyOtp(@RequestBody Map<String, Object> request) {
        log.info("[HTTP REQUEST] POST /api/v1/ledger/transfers/verify-otp payload: {}", request);
        Map<String, Object> response = mutationService.verifyOtp(request);
        return ResponseEntity.ok(response);
    }

    /**
     * 6. PostgreSQL Compliance Audit Vault: Query all immutable mutation audit records
     */
    @GetMapping({"/audit", "/audit-logs", "/audit/records"})
    public ResponseEntity<List<com.bank.ledger.engine.entity.audit.LedgerMutationAudit>> getAuditRecords() {
        log.info("[HTTP REQUEST] GET /api/v1/ledger/audit querying PostgreSQL ledger_mutation_audit");
        return ResponseEntity.ok(mutationService.getAuditRecords());
    }

    // =========================================================================
    // RFC-7807 FINANCIAL & SECURITY EXCEPTION HANDLERS
    // =========================================================================

    /**
     * Segregation of Duties Violation (TRX-503) -> HTTP 403 Forbidden
     */
    @ExceptionHandler(SegregationOfDutiesException.class)
    public ResponseEntity<Map<String, Object>> handleSegregationOfDuties(SegregationOfDutiesException ex) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of(
                "status", "FORBIDDEN",
                "error_code", "SEGREGATION_OF_DUTIES_VIOLATION",
                "message", ex.getMessage(),
                "timestamp", Instant.now()
        ));
    }

    /**
     * Insufficient Funds -> HTTP 422 Unprocessable Entity
     */
    @ExceptionHandler(InsufficientFundsException.class)
    public ResponseEntity<Map<String, Object>> handleInsufficientFunds(InsufficientFundsException ex) {
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(Map.of(
                "status", "REJECTED",
                "error_code", "INSUFFICIENT_FUNDS",
                "message", ex.getMessage(),
                "timestamp", Instant.now()
        ));
    }

    /**
     * Invalid State (e.g. attempting to re-approve an already committed transfer) -> HTTP 409 Conflict
     */
    @ExceptionHandler(IllegalStateException.class)
    public ResponseEntity<Map<String, Object>> handleIllegalState(IllegalStateException ex) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of(
                "status", "CONFLICT",
                "error_code", "INVALID_TRANSACTION_STATE",
                "message", ex.getMessage(),
                "timestamp", Instant.now()
        ));
    }

    /**
     * Invalid Argument -> HTTP 400 Bad Request
     */
    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> handleIllegalArgument(IllegalArgumentException ex) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of(
                "status", "REJECTED",
                "error_code", "INVALID_ARGUMENT",
                "message", ex.getMessage(),
                "timestamp", Instant.now()
        ));
    }
}