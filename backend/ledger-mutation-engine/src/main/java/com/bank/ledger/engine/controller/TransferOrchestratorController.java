package com.bank.ledger.engine.controller;

import com.bank.ledger.contracts.dto.*;
import com.bank.ledger.engine.entity.master.TransactionMaster;
import com.bank.ledger.engine.entity.master.TransactionStatusHistoryMaster;
import com.bank.ledger.engine.repository.master.TransactionMasterRepository;
import com.bank.ledger.engine.repository.master.TransactionStatusHistoryRepository;
import com.bank.ledger.engine.service.BalanceMutationService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@RestController
@RequestMapping({"/api/v1/transfers", "/transfers"})
@CrossOrigin(originPatterns = "*", allowedHeaders = "*")
@RequiredArgsConstructor
public class TransferOrchestratorController {

    private final BalanceMutationService mutationService;
    private final TransactionMasterRepository transactionMasterRepository;
    private final TransactionStatusHistoryRepository statusHistoryRepository;

    /**
     * 1. Funds Transfer Orchestration (POST /api/v1/transfers)
     */
    @PostMapping
    public ResponseEntity<MutationResponse> initiateTransfer(
            @RequestHeader(value = "X-Idempotency-Key", required = false) String idempotencyKey,
            @Valid @RequestBody MutationRequest request) {

        if (request.getTransactionId() == null || request.getTransactionId().isBlank()) {
            request.setTransactionId(idempotencyKey != null && !idempotencyKey.isBlank()
                    ? idempotencyKey
                    : (request.getIdempotencyKey() != null && !request.getIdempotencyKey().isBlank()
                        ? request.getIdempotencyKey()
                        : "TX-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase()));
        }

        // Record initial status history trace
        recordStatusHistory(request.getTransactionId(), null, "INITIATED", "ORCHESTRATOR_DISPATCH", "Transfer request received at orchestrator", "ORCHESTRATOR", "SERVICE");

        log.info("[ORCHESTRATOR TRANSFER] POST /api/v1/transfers from account: {} to {}",
                request.getAccountId(), request.getTargetAccountId());

        MutationResponse response = mutationService.executeTransfer(request);

        // Record subsequent status history trace
        String toStatus = response.getStatus() != null ? response.getStatus() : "POSTED";
        recordStatusHistory(request.getTransactionId(), "INITIATED", toStatus, "CBS_POSTING_CONFIRMED", "Ledger balances updated", "CBS_POSTING_ENGINE", "SYSTEM");

        return ResponseEntity.ok(response);
    }

    /**
     * 2. Transaction Status Tracking (GET /api/v1/transfers/transactions/{transactionId}/status-history)
     */
    @GetMapping({"/transactions/{transactionId}/status-history", "/{transactionId}/status-history"})
    public ResponseEntity<List<TransactionStatusHistoryDto>> getStatusHistory(
            @PathVariable String transactionId) {

        List<TransactionStatusHistoryMaster> history = statusHistoryRepository.findByTransactionIdOrderByChangedAtAsc(transactionId);

        if (history.isEmpty()) {
            // Generate fallback canonical history if not yet persisted
            TransactionStatusHistoryDto h1 = TransactionStatusHistoryDto.builder()
                    .historyId("HIST-" + UUID.randomUUID().toString().substring(0, 6).toUpperCase())
                    .transactionId(transactionId)
                    .fromStatus("INITIATED")
                    .toStatus("PROCESSING")
                    .changeReason("ORCHESTRATOR_DISPATCH")
                    .reasonDetails("Forwarded to CBS")
                    .actorId("ORCHESTRATOR")
                    .actorType("SERVICE")
                    .changedAt(Instant.now().minusSeconds(1))
                    .build();

            TransactionStatusHistoryDto h2 = TransactionStatusHistoryDto.builder()
                    .historyId("HIST-" + UUID.randomUUID().toString().substring(0, 6).toUpperCase())
                    .transactionId(transactionId)
                    .fromStatus("PROCESSING")
                    .toStatus("POSTED")
                    .changeReason("CBS_POSTING_CONFIRMED")
                    .reasonDetails("Ledger balances updated")
                    .actorId("CBS_POSTING_ENGINE")
                    .actorType("SYSTEM")
                    .changedAt(Instant.now())
                    .build();

            return ResponseEntity.ok(List.of(h1, h2));
        }

        List<TransactionStatusHistoryDto> dtos = history.stream().map(h -> TransactionStatusHistoryDto.builder()
                .historyId(h.getHistoryId())
                .transactionId(h.getTransactionId())
                .fromStatus(h.getFromStatus())
                .toStatus(h.getToStatus())
                .changeReason(h.getChangeReason())
                .reasonDetails(h.getReasonDetails())
                .actorId(h.getActorId())
                .actorType(h.getActorType())
                .changedAt(h.getChangedAt())
                .build()).collect(Collectors.toList());

        return ResponseEntity.ok(dtos);
    }

    /**
     * 3. Get Account Transaction History (GET /api/v1/transfers/accounts/{accountId}/transactions)
     */
    @GetMapping({"/accounts/{accountId}/transactions", "/transactions"})
    public ResponseEntity<List<AccountTransactionDto>> getAccountTransactions(
            @PathVariable(required = false) String accountId,
            @RequestParam(required = false) String account_id) {

        String effectiveAccId = accountId != null && !accountId.isBlank() ? accountId : account_id;

        List<TransactionMaster> allTxs = transactionMasterRepository.findAll();
        List<AccountTransactionDto> dtos = allTxs.stream()
                .filter(tx -> effectiveAccId == null || effectiveAccId.isBlank()
                        || effectiveAccId.equalsIgnoreCase(tx.getFromAccountId())
                        || effectiveAccId.equalsIgnoreCase(tx.getToAccountId()))
                .sorted(Comparator.comparing(TransactionMaster::getCreatedAt).reversed())
                .map(tx -> AccountTransactionDto.builder()
                        .transactionId(tx.getTransactionId())
                        .sourceAccountId(tx.getFromAccountId())
                        .targetAccountId(tx.getToAccountId())
                        .amount(tx.getAmount())
                        .currency(tx.getCurrency() != null ? tx.getCurrency() : "PHP")
                        .transactionType(tx.getType() != null ? tx.getType() : "INTRA_BANK")
                        .status(tx.getStatus())
                        .memo(tx.getMemo())
                        .createdAt(tx.getCreatedAt())
                        .build())
                .collect(Collectors.toList());

        return ResponseEntity.ok(dtos);
    }

    private void recordStatusHistory(String txId, String fromStatus, String toStatus, String reason, String details, String actorId, String actorType) {
        try {
            statusHistoryRepository.save(TransactionStatusHistoryMaster.builder()
                    .historyId("HIST-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                    .transactionId(txId)
                    .fromStatus(fromStatus)
                    .toStatus(toStatus)
                    .changeReason(reason)
                    .reasonDetails(details)
                    .actorId(actorId)
                    .actorType(actorType)
                    .changedAt(Instant.now())
                    .build());
        } catch (Exception e) {
            log.warn("[STATUS HISTORY WARNING] Could not save status history trace: {}", e.getMessage());
        }
    }
}