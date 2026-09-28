package com.fse.banking.account.tracing;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fse.banking.account.config.TraceCorrelationFilter;
import com.fse.banking.account.dto.CreateAccountRequest;
import com.fse.banking.account.dto.LoginRequest;
import com.fse.banking.account.model.UserEntity;
import com.fse.banking.account.repository.UserRepository;
import com.fse.banking.account.security.RedisSessionStore;
import com.fse.banking.common.enums.AccountType;
import com.fse.banking.common.enums.UserRole;
import com.fse.banking.common.enums.UserStatus;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.math.BigDecimal;
import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.matchesPattern;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@TestPropertySource(locations = "classpath:application-test.properties")
class TraceCorrelationWebTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserRepository userRepository;

    @MockBean
    private RedisConnectionFactory redisConnectionFactory;

    @MockBean
    private RedisSessionStore redisSessionStore;

    @BeforeEach
    void setUp() {
        userRepository.deleteAll();
    }

    @Test

    @DisplayName("Every successful API request should be traced with X-Trace-Id and traceparent")
    void testApiRequestIsTraced() throws Exception {
        // Query an existing API endpoint without auth required (e.g. GET accounts without user returns 200 with empty list)
        mockMvc.perform(get("/api/v1/accounts"))
                .andExpect(status().isOk())
                .andExpect(header().exists(TraceCorrelationFilter.TRACE_ID_HEADER))
                .andExpect(header().string(TraceCorrelationFilter.TRACE_ID_HEADER, matchesPattern("^[0-9a-fA-F]{32}$")))
                .andExpect(header().exists(TraceCorrelationFilter.TRACEPARENT_HEADER))
                .andExpect(header().string(TraceCorrelationFilter.TRACEPARENT_HEADER, matchesPattern("^00-[0-9a-fA-F]{32}-[0-9a-fA-F]{16}-01$")));
    }

    @Test
    @DisplayName("Inbound W3C traceparent should be propagated through the trace")
    void testTraceparentContextPropagation() throws Exception {
        String parentTraceId = "4bf92f3577b34da6a3ce929d0e0e4736";
        String parentSpanId = "00f067aa0ba902b7";
        String incomingTraceparent = "00-" + parentTraceId + "-" + parentSpanId + "-01";

        mockMvc.perform(get("/api/v1/accounts")
                        .header("traceparent", incomingTraceparent))
                .andExpect(status().isOk())
                .andExpect(header().string(TraceCorrelationFilter.TRACE_ID_HEADER, parentTraceId))
                .andExpect(header().string(TraceCorrelationFilter.TRACEPARENT_HEADER, matchesPattern("^00-" + parentTraceId + "-[0-9a-fA-F]{16}-01$")));
    }

    @Test
    @DisplayName("Validation error responses should contain X-Trace-Id header and ProblemDetails.trace_id")
    void testValidationErrorResponseTracing() throws Exception {
        CreateAccountRequest invalidRequest = CreateAccountRequest.builder()
                .userId("") // invalid blank
                .accountType(null)
                .build();

        MvcResult result = mockMvc.perform(post("/api/v1/accounts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(invalidRequest)))
                .andExpect(status().isBadRequest())
                .andExpect(header().exists(TraceCorrelationFilter.TRACE_ID_HEADER))
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.title").value("Bad Request"))
                .andExpect(jsonPath("$.trace_id").isNotEmpty())
                .andReturn();

        String headerTraceId = result.getResponse().getHeader(TraceCorrelationFilter.TRACE_ID_HEADER);
        assertThat(headerTraceId).isNotNull().matches("^[0-9a-fA-F]{32}$");

        String body = result.getResponse().getContentAsString();
        assertThat(body).contains("\"trace_id\":\"" + headerTraceId + "\"");
    }

    @Test
    @DisplayName("Business exception should preserve X-Trace-Id and correlate in ProblemDetails")
    void testBusinessExceptionTracing() throws Exception {
        // Calling balance inquiry for a non-existent account produces 404 ResourceNotFoundException
        MvcResult result = mockMvc.perform(get("/api/v1/accounts/ACC-NONEXISTENT/balance"))
                .andExpect(status().isNotFound())
                .andExpect(header().exists(TraceCorrelationFilter.TRACE_ID_HEADER))
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.trace_id").isNotEmpty())
                .andReturn();

        String headerTraceId = result.getResponse().getHeader(TraceCorrelationFilter.TRACE_ID_HEADER);
        assertThat(headerTraceId).isNotNull().matches("^[0-9a-fA-F]{32}$");

        String body = result.getResponse().getContentAsString();
        assertThat(body).contains("\"trace_id\":\"" + headerTraceId + "\"");
    }
}
