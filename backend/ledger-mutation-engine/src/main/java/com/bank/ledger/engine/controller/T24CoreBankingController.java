package com.bank.ledger.engine.controller;

import com.bank.ledger.contracts.dto.T24FundsTransferRequest;
import com.bank.ledger.contracts.dto.T24FundsTransferResponse;
import com.bank.ledger.contracts.dto.T24ReversalRequest;
import com.bank.ledger.contracts.dto.T24ReversalResponse;
import com.bank.ledger.contracts.exception.InsufficientFundsException;
import com.bank.ledger.engine.service.BalanceMutationService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.Map;

/**
 * Temenos T24 Core Banking Engine REST & OFS Endpoints.
 * Exposes core banking APIs for:
 * 1. Funds Transfer (FUNDS.TRANSFER) - Atomic dual-account settlement
 * 2. Reversal (FUNDS.TRANSFER,REVERSE) - Compensating double-entry mutation
 */
@Slf4j
@RestController
@RequestMapping({"/api/v1/t24", "/api/t24"})
@RequiredArgsConstructor
public class T24CoreBankingController {

    private final BalanceMutationService mutationService;

    /**
     * Endpoint 1: T24 Core Banking Funds Transfer API
     * POST /api/v1/t24/funds-transfer
     * Aliases: /api/v1/t24/transfers, /api/t24/funds-transfer
     */
    @PostMapping({"/funds-transfer", "/transfers", "/transfer"})
    public ResponseEntity<T24FundsTransferResponse> executeFundsTransfer(
            @Valid @RequestBody T24FundsTransferRequest request) {
        log.info("[T24 REST API] POST /api/v1/t24/funds-transfer from {} to {}, amount: PHP {}",
                request.getDebitAccountId(), request.getCreditAccountId(), request.getAmount());
        T24FundsTransferResponse response = mutationService.executeT24FundsTransfer(request);
        return ResponseEntity.ok(response);
    }

    /**
     * Endpoint 2: T24 Core Banking Transaction Reversal API
     * POST /api/v1/t24/reversal
     * Aliases: /api/v1/t24/reverse, /api/t24/reversal
     */
    @PostMapping({"/reversal", "/reverse"})
    public ResponseEntity<T24ReversalResponse> executeReversal(
            @Valid @RequestBody T24ReversalRequest request) {
        log.info("[T24 REST API] POST /api/v1/t24/reversal for original TxId: {}, reason: {}",
                request.getOriginalTransactionId(), request.getReversalReason());
        T24ReversalResponse response = mutationService.executeT24Reversal(request);
        return ResponseEntity.ok(response);
    }

    /**
     * Path-Variable Reversal Endpoint:
     * POST /api/v1/t24/transfers/{transactionId}/reverse
     * POST /api/v1/t24/transfers/{transactionId}/reversal
     */
    @PostMapping({"/transfers/{transactionId}/reverse", "/transfers/{transactionId}/reversal"})
    public ResponseEntity<T24ReversalResponse> executeReversalByPath(
            @PathVariable String transactionId,
            @RequestBody(required = false) T24ReversalRequest request) {
        if (request == null) {
            request = new T24ReversalRequest();
        }
        request.setOriginalTransactionId(transactionId);
        log.info("[T24 REST API] POST /api/v1/t24/transfers/{}/reverse", transactionId);
        T24ReversalResponse response = mutationService.executeT24Reversal(request);
        return ResponseEntity.ok(response);
    }

    /**
     * Temenos OFS Command Gateway Endpoint:
     * POST /api/v1/t24/ofs-command
     * Executes raw Temenos OFS syntax commands (FUNDS.TRANSFER or FUNDS.TRANSFER,REVERSE).
     */
    @PostMapping({"/ofs-command", "/internal/cbs/ofs-command"})
    public ResponseEntity<?> executeOfsCommand(@RequestBody Map<String, Object> body) {
        String ofs = (String) body.getOrDefault("ofs_message", body.get("command"));
        if (ofs == null || ofs.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "ofs_message or command is required"));
        }

        log.info("[T24 OFS GATEWAY] Inbound OFS command: {}", ofs);

        if (ofs.toUpperCase().contains("REVERSE")) {
            T24ReversalRequest revReq = new T24ReversalRequest();
            revReq.setOfsMessage(ofs);
            T24ReversalResponse res = mutationService.executeT24Reversal(revReq);
            return ResponseEntity.ok(res);
        } else {
            T24FundsTransferRequest ftReq = new T24FundsTransferRequest();
            ftReq.setOfsMessage(ofs);
            T24FundsTransferResponse res = mutationService.executeT24FundsTransfer(ftReq);
            return ResponseEntity.ok(res);
        }
    }

    // =========================================================================
    // RFC-7807 T24 ERROR RESPONSES
    // =========================================================================

    @ExceptionHandler(InsufficientFundsException.class)
    public ResponseEntity<Map<String, Object>> handleInsufficientFunds(InsufficientFundsException ex) {
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(Map.of(
                "status", "REJECTED",
                "t24_error_code", "INSUFFICIENT_FUNDS",
                "message", ex.getMessage(),
                "timestamp", Instant.now()
        ));
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> handleBadRequest(IllegalArgumentException ex) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of(
                "status", "BAD_REQUEST",
                "t24_error_code", "INVALID_ARGUMENT",
                "message", ex.getMessage(),
                "timestamp", Instant.now()
        ));
    }

    @ExceptionHandler(IllegalStateException.class)
    public ResponseEntity<Map<String, Object>> handleConflict(IllegalStateException ex) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of(
                "status", "CONFLICT",
                "t24_error_code", "INVALID_TRANSACTION_STATE",
                "message", ex.getMessage(),
                "timestamp", Instant.now()
        ));
    }
}
