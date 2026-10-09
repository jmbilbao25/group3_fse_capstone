package com.bank.ledger.engine.controller;

import com.bank.ledger.contracts.dto.ReversalActionRequest;
import com.bank.ledger.contracts.dto.ReversalTicketDto;
import com.bank.ledger.contracts.dto.T24ReversalRequest;
import com.bank.ledger.contracts.dto.T24ReversalResponse;
import com.bank.ledger.contracts.exception.SegregationOfDutiesException;
import com.bank.ledger.engine.entity.master.ReversalRequestMaster;
import com.bank.ledger.engine.repository.master.ReversalRequestRepository;
import com.bank.ledger.engine.service.BalanceMutationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@RestController
@RequestMapping({"/api/v1/reversals", "/reversals"})
@CrossOrigin(originPatterns = "*", allowedHeaders = "*")
@RequiredArgsConstructor
public class ReversalOrchestratorController {

    private final ReversalRequestRepository reversalRequestRepository;
    private final BalanceMutationService mutationService;

    /**
     * 1. Register Reversal Request (Dual-Control Maker step)
     * POST /api/v1/reversals/request
     */
    @PostMapping({"/request", "/cbs/request"})
    public ResponseEntity<Map<String, Object>> requestReversal(@RequestBody ReversalActionRequest request) {
        String ticketId = UUID.randomUUID().toString();
        String originalTx = request.getOriginalTransactionId();
        String makerId = request.getMakerId() != null ? request.getMakerId() : "MAKER_01";
        String reason = request.getReason() != null ? request.getReason() : "Customer fraud claim";

        ReversalRequestMaster entity = ReversalRequestMaster.builder()
                .ticketId(ticketId)
                .originalTransactionId(originalTx)
                .makerId(makerId)
                .status("PENDING")
                .disputeReason(reason)
                .makerNotes(request.getCheckerNotes() != null ? request.getCheckerNotes() : reason)
                .createdAt(Instant.now())
                .build();
        reversalRequestRepository.save(entity);

        log.info("[REVERSAL REQUEST REGISTERED] Ticket: {} for Tx: {} by Maker: {}", ticketId, originalTx, makerId);

        Map<String, Object> resp = new LinkedHashMap<>();
        resp.put("STATUS_CODE", "1");
        resp.put("STATUS", "PENDING");
        resp.put("TICKET.ID", ticketId);
        resp.put("ORIGINAL.FT.NO", originalTx);
        resp.put("MESSAGE", "Reversal request registered");
        return ResponseEntity.ok(resp);
    }

    /**
     * 2. Approve Reversal Request (Dual-Control Checker step)
     * POST /api/v1/reversals/approve
     */
    @PostMapping({"/approve", "/cbs/approve"})
    public ResponseEntity<Map<String, Object>> approveReversal(@RequestBody ReversalActionRequest request) {
        String ticketId = request.getReversalRequestId();
        if (ticketId == null || ticketId.isBlank()) {
            ticketId = request.getOriginalTransactionId();
        }
        String checkerId = request.getCheckerId() != null ? request.getCheckerId() : "MGR_02";
        String notes = request.getCheckerNotes() != null ? request.getCheckerNotes() : "Approved after dispute investigation";

        ReversalRequestMaster entity = reversalRequestRepository.findById(ticketId).orElse(null);
        String origTxId = entity != null ? entity.getOriginalTransactionId() : request.getOriginalTransactionId();

        if (entity != null) {
            if (checkerId.equalsIgnoreCase(entity.getMakerId())) {
                throw new SegregationOfDutiesException("Maker [" + entity.getMakerId() + "] cannot approve own reversal request! Segregation of duties violation.");
            }
        }

        // Execute compensating mutation via T24/BalanceMutationService
        T24ReversalRequest t24Req = T24ReversalRequest.builder()
                .originalTransactionId(origTxId)
                .checkerId(checkerId)
                .makerId(entity != null ? entity.getMakerId() : "MAKER_01")
                .reversalReason(entity != null ? entity.getDisputeReason() : "DISPUTE_APPROVED")
                .notes(notes)
                .build();
        T24ReversalResponse t24Res = mutationService.executeT24Reversal(t24Req);

        String revTxId = t24Res.getReversalReference() != null ? t24Res.getReversalReference() : UUID.randomUUID().toString();

        if (entity != null) {
            entity.setCheckerId(checkerId);
            entity.setCheckerNotes(notes);
            entity.setStatus("APPROVED");
            entity.setReversalTransactionId(revTxId);
            entity.setResolvedAt(Instant.now());
            reversalRequestRepository.save(entity);
        }

        log.info("[REVERSAL APPROVED] Ticket: {} for Tx: {} by Checker: {}", ticketId, origTxId, checkerId);

        Map<String, Object> resp = new LinkedHashMap<>();
        resp.put("STATUS_CODE", "1");
        resp.put("STATUS", "APPROVED");
        resp.put("TICKET.ID", ticketId);
        resp.put("ORIGINAL.FT.NO", origTxId);
        resp.put("REVERSAL.TX.ID", revTxId);
        resp.put("MESSAGE", "Reversal executed successfully");
        return ResponseEntity.ok(resp);
    }

    /**
     * 3. Reject Reversal Request
     * POST /api/v1/reversals/reject
     */
    @PostMapping({"/reject", "/cbs/reject"})
    public ResponseEntity<Map<String, Object>> rejectReversal(@RequestBody ReversalActionRequest request) {
        String ticketId = request.getReversalRequestId();
        if (ticketId == null || ticketId.isBlank()) {
            ticketId = request.getOriginalTransactionId();
        }
        String checkerId = request.getCheckerId() != null ? request.getCheckerId() : "MGR_02";
        String reason = request.getRejectionReason() != null ? request.getRejectionReason() : "Insufficient evidence of fraud";

        ReversalRequestMaster entity = reversalRequestRepository.findById(ticketId).orElse(null);
        String origTxId = entity != null ? entity.getOriginalTransactionId() : request.getOriginalTransactionId();

        if (entity != null) {
            entity.setCheckerId(checkerId);
            entity.setCheckerNotes(reason);
            entity.setStatus("REJECTED");
            entity.setResolvedAt(Instant.now());
            reversalRequestRepository.save(entity);
        }

        log.info("[REVERSAL REJECTED] Ticket: {} by Checker: {}", ticketId, checkerId);

        Map<String, Object> resp = new LinkedHashMap<>();
        resp.put("STATUS_CODE", "1");
        resp.put("STATUS", "REJECTED");
        resp.put("TICKET.ID", ticketId);
        resp.put("ORIGINAL.FT.NO", origTxId);
        resp.put("MESSAGE", "Reversal rejected");
        return ResponseEntity.ok(resp);
    }

    /**
     * 4. List Reversal Requests (for Admin Portal Maker-Checker desk)
     * GET /api/v1/reversals
     */
    @GetMapping
    public ResponseEntity<List<ReversalTicketDto>> getReversals(
            @RequestParam(required = false) String status) {
        List<ReversalRequestMaster> entities = (status != null && !status.isBlank())
                ? reversalRequestRepository.findByStatusOrderByCreatedAtDesc(status.toUpperCase())
                : reversalRequestRepository.findAllByOrderByCreatedAtDesc();

        List<ReversalTicketDto> dtos = entities.stream().map(e -> ReversalTicketDto.builder()
                .ticketId(e.getTicketId())
                .originalTransactionId(e.getOriginalTransactionId())
                .makerId(e.getMakerId())
                .checkerId(e.getCheckerId())
                .status(e.getStatus())
                .disputeReason(e.getDisputeReason())
                .makerNotes(e.getMakerNotes())
                .checkerNotes(e.getCheckerNotes())
                .reversalTransactionId(e.getReversalTransactionId())
                .createdAt(e.getCreatedAt())
                .resolvedAt(e.getResolvedAt())
                .build()).collect(Collectors.toList());

        return ResponseEntity.ok(dtos);
    }
}