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
    @PostMapping("/transfer")
    public ResponseEntity<MutationResponse> executeTransfer(@Valid @RequestBody MutationRequest request) {
        log.info("[HTTP REQUEST] POST /api/v1/ledger/transfer from account: {} to {}",
                request.getAccountId(), request.getTargetAccountId());

        MutationResponse response = mutationService.executeTransfer(request);
        return ResponseEntity.ok(response);
    }

    /**
     * 2. Teller Approval of High-Value Transfer (TRX-502, TRX-503)
     */
    @PostMapping("/transfers/{transactionId}/approve")
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