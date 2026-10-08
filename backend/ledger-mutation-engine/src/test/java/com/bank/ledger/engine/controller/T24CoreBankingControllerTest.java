package com.bank.ledger.engine.controller;

import com.bank.ledger.contracts.dto.T24FundsTransferRequest;
import com.bank.ledger.contracts.dto.T24FundsTransferResponse;
import com.bank.ledger.contracts.dto.T24ReversalRequest;
import com.bank.ledger.contracts.dto.T24ReversalResponse;
import com.bank.ledger.contracts.exception.InsufficientFundsException;
import com.bank.ledger.engine.service.BalanceMutationService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Map;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(T24CoreBankingController.class)
@AutoConfigureMockMvc(addFilters = false)
class T24CoreBankingControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private BalanceMutationService mutationService;

    @Test
    @DisplayName("POST /api/v1/t24/funds-transfer - Success")
    void testExecuteFundsTransferSuccess() throws Exception {
        T24FundsTransferResponse mockResponse = T24FundsTransferResponse.builder()
                .t24Reference("FT261007A001")
                .status("COMMITTED")
                .debitAccountId("ACC-101")
                .debitAmount(new BigDecimal("1500.0000"))
                .debitBalanceAfter(new BigDecimal("48500.0000"))
                .creditAccountId("ACC-202")
                .creditAmount(new BigDecimal("1500.0000"))
                .creditBalanceAfter(new BigDecimal("21500.0000"))
                .currency("PHP")
                .ofsResponse("FT261007A001//1/COMMITTED")
                .timestamp(Instant.now())
                .message("T24 Funds Transfer executed successfully: COMMITTED")
                .build();

        when(mutationService.executeT24FundsTransfer(any(T24FundsTransferRequest.class))).thenReturn(mockResponse);

        T24FundsTransferRequest request = T24FundsTransferRequest.builder()
                .debitAccountId("ACC-101")
                .creditAccountId("ACC-202")
                .amount(new BigDecimal("1500.0000"))
                .currency("PHP")
                .paymentDetails("Utility bill payment")
                .build();

        mockMvc.perform(post("/api/v1/t24/funds-transfer")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.t24_reference").value("FT261007A001"))
                .andExpect(jsonPath("$.status").value("COMMITTED"))
                .andExpect(jsonPath("$.debit_account_id").value("ACC-101"))
                .andExpect(jsonPath("$.credit_account_id").value("ACC-202"))
                .andExpect(jsonPath("$.ofs_response").value("FT261007A001//1/COMMITTED"));
    }

    @Test
    @DisplayName("POST /api/v1/t24/reversal - Success")
    void testExecuteReversalSuccess() throws Exception {
        T24ReversalResponse mockResponse = T24ReversalResponse.builder()
                .reversalReference("REV-TX-901-A1B2")
                .originalTransactionId("TX-901")
                .status("REVERSED")
                .reversalReason("DUPLICATE_TRANSFER")
                .amount(new BigDecimal("2500.0000"))
                .debitedAccountId("ACC-202")
                .debitedBalanceAfter(new BigDecimal("17500.0000"))
                .creditedAccountId("ACC-101")
                .creditedBalanceAfter(new BigDecimal("52500.0000"))
                .ofsResponse("TX-901//1/REVERSED,REV.REF=REV-TX-901-A1B2")
                .timestamp(Instant.now())
                .message("T24 transaction successfully reversed with compensating double-entry mutation.")
                .build();

        when(mutationService.executeT24Reversal(any(T24ReversalRequest.class))).thenReturn(mockResponse);

        T24ReversalRequest request = T24ReversalRequest.builder()
                .originalTransactionId("TX-901")
                .reversalReason("DUPLICATE_TRANSFER")
                .checkerId("OP-SUPERVISOR")
                .makerId("OP-TELLER")
                .build();

        mockMvc.perform(post("/api/v1/t24/reversal")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.reversal_reference").value("REV-TX-901-A1B2"))
                .andExpect(jsonPath("$.original_transaction_id").value("TX-901"))
                .andExpect(jsonPath("$.status").value("REVERSED"))
                .andExpect(jsonPath("$.debited_account_id").value("ACC-202"))
                .andExpect(jsonPath("$.credited_account_id").value("ACC-101"))
                .andExpect(jsonPath("$.ofs_response").value("TX-901//1/REVERSED,REV.REF=REV-TX-901-A1B2"));
    }

    @Test
    @DisplayName("POST /api/v1/t24/transfers/{transactionId}/reverse - Path variable success")
    void testExecuteReversalByPath() throws Exception {
        T24ReversalResponse mockResponse = T24ReversalResponse.builder()
                .reversalReference("REV-TX-888-9999")
                .originalTransactionId("TX-888")
                .status("REVERSED")
                .amount(new BigDecimal("1000.0000"))
                .debitedAccountId("ACC-202")
                .debitedBalanceAfter(new BigDecimal("19000.0000"))
                .creditedAccountId("ACC-101")
                .creditedBalanceAfter(new BigDecimal("51000.0000"))
                .timestamp(Instant.now())
                .build();

        when(mutationService.executeT24Reversal(any(T24ReversalRequest.class))).thenReturn(mockResponse);

        mockMvc.perform(post("/api/v1/t24/transfers/TX-888/reverse")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reversal_reason\":\"CUSTOMER_DISPUTE\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.original_transaction_id").value("TX-888"))
                .andExpect(jsonPath("$.status").value("REVERSED"));
    }

    @Test
    @DisplayName("POST /api/v1/t24/reversal - Insufficient Funds returns 422")
    void testReversalInsufficientFunds() throws Exception {
        when(mutationService.executeT24Reversal(any(T24ReversalRequest.class)))
                .thenThrow(new InsufficientFundsException("Beneficiary account has insufficient funds to reverse."));

        T24ReversalRequest request = T24ReversalRequest.builder()
                .originalTransactionId("TX-901")
                .build();

        mockMvc.perform(post("/api/v1/t24/reversal")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.t24_error_code").value("INSUFFICIENT_FUNDS"));
    }

    @Test
    @DisplayName("POST /api/v1/t24/ofs-command - Raw OFS Command Dispatcher")
    void testOfsCommandDispatcher() throws Exception {
        T24FundsTransferResponse mockResponse = T24FundsTransferResponse.builder()
                .t24Reference("FT999")
                .status("COMMITTED")
                .ofsResponse("FT999//1/SUCCESS")
                .build();

        when(mutationService.executeT24FundsTransfer(any(T24FundsTransferRequest.class))).thenReturn(mockResponse);

        mockMvc.perform(post("/api/v1/t24/ofs-command")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ofs_message\":\"FUNDS.TRANSFER,AUTH/I/PROCESS,,DEBIT.ACCT.NO=ACC-101,CREDIT.ACCT.NO=ACC-202,DEBIT.AMOUNT=500.00\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ofs_response").value("FT999//1/SUCCESS"));
    }
}
