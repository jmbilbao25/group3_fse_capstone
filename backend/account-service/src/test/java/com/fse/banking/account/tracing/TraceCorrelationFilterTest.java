package com.fse.banking.account.tracing;

import com.fse.banking.account.config.TraceCorrelationFilter;
import io.micrometer.tracing.Span;
import io.micrometer.tracing.TraceContext;
import io.micrometer.tracing.Tracer;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.slf4j.MDC;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import java.io.IOException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TraceCorrelationFilterTest {

    @Mock
    private Tracer tracer;

    @Mock
    private Span span;

    @Mock
    private TraceContext traceContext;

    @Mock
    private FilterChain filterChain;

    private TraceCorrelationFilter filter;

    @BeforeEach
    void setUp() {
        filter = new TraceCorrelationFilter(tracer);
        MDC.clear();
    }

    @Test
    @DisplayName("Should inject X-Trace-Id and traceparent when active span exists")
    void testActiveSpanInjectsHeaders() throws ServletException, IOException {
        String testTraceId = "4bf92f3577b34da6a3ce929d0e0e4736";
        String testSpanId = "00f067aa0ba902b7";

        when(tracer.currentSpan()).thenReturn(span);
        when(span.context()).thenReturn(traceContext);
        when(traceContext.traceId()).thenReturn(testTraceId);
        when(traceContext.spanId()).thenReturn(testSpanId);

        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/accounts");
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(request, response, filterChain);

        assertThat(response.getHeader("X-Trace-Id")).isEqualTo(testTraceId);
        assertThat(response.getHeader("traceparent")).isEqualTo("00-" + testTraceId + "-" + testSpanId + "-01");
        assertThat(request.getAttribute(TraceCorrelationFilter.TRACE_ID_ATTRIBUTE)).isEqualTo(testTraceId);

        verify(filterChain).doFilter(request, response);
    }

    @Test
    @DisplayName("Should propagate incoming traceparent when tracer span is not yet active")
    void testTraceparentPropagationFallback() throws ServletException, IOException {
        when(tracer.currentSpan()).thenReturn(null);

        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/accounts");
        request.addHeader("traceparent", "00-11223344556677889900aabbccddeeff-1234567890abcdef-01");
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(request, response, filterChain);

        assertThat(response.getHeader("X-Trace-Id")).isEqualTo("11223344556677889900aabbccddeeff");
        assertThat(response.getHeader("traceparent")).isEqualTo("00-11223344556677889900aabbccddeeff-1234567890abcdef-01");
        assertThat(request.getAttribute(TraceCorrelationFilter.TRACE_ID_ATTRIBUTE)).isEqualTo("11223344556677889900aabbccddeeff");

        verify(filterChain).doFilter(request, response);
    }

    @Test
    @DisplayName("Should tag custom request ID on active span when header present")
    void testCustomRequestIdTagging() throws ServletException, IOException {
        String testTraceId = "4bf92f3577b34da6a3ce929d0e0e4736";
        String testSpanId = "00f067aa0ba902b7";

        when(tracer.currentSpan()).thenReturn(span);
        when(span.context()).thenReturn(traceContext);
        when(traceContext.traceId()).thenReturn(testTraceId);
        when(traceContext.spanId()).thenReturn(testSpanId);

        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/v1/accounts");
        request.addHeader("X-Request-Id", "REQ-999-XYZ");
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(request, response, filterChain);

        verify(span).tag("custom.request_id", "REQ-999-XYZ");
        assertThat(response.getHeader("X-Trace-Id")).isEqualTo(testTraceId);
    }
}
