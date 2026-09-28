package com.fse.banking.account.config;

import io.micrometer.tracing.Span;
import io.micrometer.tracing.Tracer;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.MDC;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.UUID;

/**
 * Servlet filter ensuring every incoming and outgoing API request is correlated
 * with OpenTelemetry distributed tracing context.
 *
 * <p>Executes with high precedence within the observation scope started by
 * Spring Boot Actuator's {@code ServerHttpObservationFilter}.</p>
 */
@Slf4j
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 5)
public class TraceCorrelationFilter extends OncePerRequestFilter {

    public static final String TRACE_ID_HEADER = "X-Trace-Id";
    public static final String TRACEPARENT_HEADER = "traceparent";
    public static final String REQUEST_ID_HEADER = "X-Request-Id";
    public static final String TRACE_ID_ATTRIBUTE = "com.fse.banking.traceId";

    private final Tracer tracer;

    @Autowired
    public TraceCorrelationFilter(@Autowired(required = false) Tracer tracer) {
        this.tracer = tracer;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {

        // 1. Resolve or extract active trace identifiers
        String traceId = resolveCurrentTraceId();
        String spanId = resolveCurrentSpanId();

        // Fallback: If not yet in an active span, inspect incoming traceparent header
        if (traceId == null || traceId.isBlank()) {
            String incomingTraceparent = request.getHeader(TRACEPARENT_HEADER);
            if (incomingTraceparent != null && incomingTraceparent.startsWith("00-")) {
                String[] parts = incomingTraceparent.split("-");
                if (parts.length >= 3 && parts[1].length() == 32) {
                    traceId = parts[1];
                    spanId = parts[2];
                }
            }
        }

        // Fallback: Check MDC
        if (traceId == null || traceId.isBlank()) {
            traceId = MDC.get("traceId");
            spanId = MDC.get("spanId");
        }

        // 2. Tag custom request ID if provided
        String requestId = request.getHeader(REQUEST_ID_HEADER);
        if (requestId != null && !requestId.isBlank() && tracer != null && tracer.currentSpan() != null) {
            tracer.currentSpan().tag("custom.request_id", requestId);
        }

        // 3. Inject trace correlation headers early before response is committed
        if (traceId != null && !traceId.isBlank()) {
            response.setHeader(TRACE_ID_HEADER, traceId);
            request.setAttribute(TRACE_ID_ATTRIBUTE, traceId);
            if (spanId != null && !spanId.isBlank()) {
                response.setHeader(TRACEPARENT_HEADER, "00-" + traceId + "-" + spanId + "-01");
            }
        }

        try {
            filterChain.doFilter(request, response);
        } finally {
            // Post-execution safeguard: If headers were not yet committed, ensure they exist
            if (!response.isCommitted() && !response.containsHeader(TRACE_ID_HEADER)) {
                String finalTraceId = resolveCurrentTraceId();
                if (finalTraceId != null && !finalTraceId.isBlank()) {
                    response.setHeader(TRACE_ID_HEADER, finalTraceId);
                    String finalSpanId = resolveCurrentSpanId();
                    if (finalSpanId != null && !finalSpanId.isBlank()) {
                        response.setHeader(TRACEPARENT_HEADER, "00-" + finalTraceId + "-" + finalSpanId + "-01");
                    }
                }
            }
        }
    }

    private String resolveCurrentTraceId() {
        if (tracer != null) {
            Span currentSpan = tracer.currentSpan();
            if (currentSpan != null && currentSpan.context() != null) {
                return currentSpan.context().traceId();
            }
        }
        return null;
    }

    private String resolveCurrentSpanId() {
        if (tracer != null) {
            Span currentSpan = tracer.currentSpan();
            if (currentSpan != null && currentSpan.context() != null) {
                return currentSpan.context().spanId();
            }
        }
        return null;
    }
}
