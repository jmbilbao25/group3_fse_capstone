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
@CrossOrigin(originPatterns = "*", allowedHeaders = "*")
@RequiredArgsConstructor
public class BalanceMutationController {

    private final BalanceMutationService mutationService;

    /**
     * 1. Initiate Funds Transfer (TRX-501)
     * - Immediate settlement if <= PHP 50,000.00
     * - Soft hold & Maker-Checker routed if > PHP 50,000.00
     */
    @PostMapping({"/transfer", "/transfers", "/mutate"})
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
    @PostMapping({"/transfers/{transactionId}/approve", "/transfers/{transactionId}/sign-l1", "/transfers/{transactionId}/sign-l2", "/transfers/{transactionId}/approve-first", "/transfers/{transactionId}/approve-second", "/approve"})
    public ResponseEntity<MutationResponse> approveTransfer(
            @PathVariable(required = false) String transactionId,
            @Valid @RequestBody CheckerActionRequest request) {
        String effectiveTxId = transactionId != null && !transactionId.isBlank()
                ? transactionId
                : request.getTransactionId();
        if (effectiveTxId == null || effectiveTxId.isBlank()) {
            throw new IllegalArgumentException("Transaction ID is required in path or body for approval.");
        }

        log.info("[HTTP REQUEST] POST /api/v1/ledger/transfers/{}/approve by checker {}",
                effectiveTxId, request.getCheckerUserId());

        MutationResponse response = mutationService.approveTransfer(effectiveTxId, request);
        return ResponseEntity.ok(response);
    }

    /**
     * 3. Teller Rejection of High-Value Transfer (TRX-502)
     */
    @PostMapping({"/transfers/{transactionId}/reject", "/reject"})
    public ResponseEntity<MutationResponse> rejectTransfer(
            @PathVariable(required = false) String transactionId,
            @Valid @RequestBody CheckerActionRequest request) {
        String effectiveTxId = transactionId != null && !transactionId.isBlank()
                ? transactionId
                : request.getTransactionId();
        if (effectiveTxId == null || effectiveTxId.isBlank()) {
            throw new IllegalArgumentException("Transaction ID is required in path or body for rejection.");
        }

        log.info("[HTTP REQUEST] POST /api/v1/ledger/transfers/{}/reject by checker {}",
                effectiveTxId, request.getCheckerUserId());

        MutationResponse response = mutationService.rejectTransfer(effectiveTxId, request);
        return ResponseEntity.ok(response);
    }

    /**
     * 4. Teller Review Queue: Query all pending approval transfers (UI-703)
     */
    @GetMapping({"/transfers/pending", "/pending"})
    public ResponseEntity<List<TransactionMaster>> getPendingTransfers() {
        return ResponseEntity.ok(mutationService.getPendingTransfers());
    }

    /**
     * 4b. Admin Real-Time Transaction Journal: Query all transactions
     */
    @GetMapping({"/transfers", "/transactions"})
    public ResponseEntity<List<TransactionMaster>> getAllTransactions() {
        return ResponseEntity.ok(mutationService.getAllTransactions());
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

    /**
     * 7. T24 Reversal / Rollback: Reverse a committed transfer with compensating contra-entry
     */
    @PostMapping("/transfers/{transactionId}/reverse")
    public ResponseEntity<MutationResponse> reverseTransfer(
            @PathVariable String transactionId,
            @RequestBody(required = false) Map<String, Object> reversalRequest) {
        log.info("[HTTP REQUEST] POST /api/v1/ledger/transfers/{}/reverse payload: {}", transactionId, reversalRequest);
        MutationResponse response = mutationService.reverseTransfer(transactionId, reversalRequest != null ? reversalRequest : Map.of());
        return ResponseEntity.ok(response);
    }

    /**
     * 8. Update Customer Location in Oracle XE Master (Geo-Simulator)
     */
    @RequestMapping(value = "/users/{userId}/location", method = {RequestMethod.PATCH, RequestMethod.PUT, RequestMethod.POST})
    public ResponseEntity<Map<String, Object>> updateUserLocation(
            @PathVariable String userId,
            @RequestBody Map<String, Object> locationPayload) {
        log.info("[HTTP REQUEST] UPDATE /api/v1/ledger/users/{}/location: {}", userId, locationPayload);
        Map<String, Object> response = mutationService.updateUserLocation(userId, locationPayload);
        return ResponseEntity.ok(response);
    }

    /**
     * 9. Query Customer Location from Oracle XE Master
     */
    @GetMapping("/users/{userId}/location")
    public ResponseEntity<Map<String, Object>> getUserLocation(@PathVariable String userId) {
        log.info("[HTTP REQUEST] GET /api/v1/ledger/users/{}/location", userId);
        Map<String, Object> response = mutationService.getUserLocation(userId);
        return ResponseEntity.ok(response);
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

    /**
     * Security Risk Engine Blocked -> HTTP 422 Unprocessable Entity (Matches Fraud Security Notice Modal)
     */
    @ExceptionHandler(SecurityException.class)
    public ResponseEntity<Map<String, Object>> handleSecurityBlocked(SecurityException ex) {
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(Map.of(
                "status", "REJECTED_FRAUD",
                "error_code", "RISK_THRESHOLD_EXCEEDED",
                "title", "Security Notice: Transaction Temporarily Held",
                "message", ex.getMessage(),
                "timestamp", Instant.now()
        ));
    }

    /**
     * Ledger Data Integrity / Database Constraint Violation -> HTTP 422 Unprocessable Entity
     */
    @ExceptionHandler(org.springframework.dao.DataIntegrityViolationException.class)
    public ResponseEntity<Map<String, Object>> handleDataIntegrityViolation(org.springframework.dao.DataIntegrityViolationException ex) {
        log.error("[LEDGER INTEGRITY VIOLATION] {}", ex.getMessage());
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(Map.of(
                "status", "REJECTED",
                "error_code", "LEDGER_CONSTRAINT_VIOLATION",
                "message", "Transfer rejected due to financial ledger constraint violation. Please verify available account balance.",
                "timestamp", Instant.now()
        ));
    }
}