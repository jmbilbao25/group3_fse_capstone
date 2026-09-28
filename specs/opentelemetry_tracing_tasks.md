# Tasks: OpenTelemetry Distributed Tracing Integration

This document defines actionable, sequential implementation steps for integrating OpenTelemetry distributed tracing across the banking platform microservices.

---

## Task Checklist

- [x] **Task 1: Add OpenTelemetry and Tracing Dependencies**
  - Path: `backend/pom.xml`, `backend/account-service/pom.xml`, `backend/ledger-mutation-engine/pom.xml`
  - Subtasks:
    - Add OpenTelemetry Tracing bridge (`io.micrometer:micrometer-tracing-bridge-otel`) and OTLP exporter (`io.opentelemetry:opentelemetry-exporter-otlp`) to `account-service/pom.xml` and `ledger-mutation-engine/pom.xml`.
    - Verify clean compilation across all modules.
  - _Requirements: REQ-OTEL-1.1, REQ-OTEL-1.5; Design: Section 1, Section 2.4_

- [x] **Task 2: Configure Tracing Properties & MDC Logging**
  - Path: `backend/account-service/src/main/resources/application.properties`, `backend/account-service/src/test/resources/application-test.properties`, `backend/ledger-mutation-engine/src/main/resources/application.properties`
  - Subtasks:
    - Set `management.tracing.sampling.probability=1.0` (100% sampling).
    - Set `management.tracing.propagation.type=W3C`.
    - Set `management.otlp.tracing.endpoint=${OTEL_EXPORTER_OTLP_ENDPOINT:http://localhost:4318/v1/traces}`.
    - Set `management.otlp.tracing.transport=http`.
    - Configure MDC logging pattern: `logging.pattern.level=%5p [${spring.application.name:},%X{traceId:-},%X{spanId:-}]`.
  - _Requirements: REQ-OTEL-1.2, REQ-OTEL-4.1; Design: Section 2.3_

- [x] **Task 3: Enrich ProblemDetails and GlobalExceptionHandler with Trace ID**
  - Path: `backend/common-contracts/src/main/java/com/fse/banking/common/dto/ProblemDetails.java`, `backend/account-service/src/main/java/com/fse/banking/account/exception/GlobalExceptionHandler.java`
  - Subtasks:
    - Add `traceId` property to `ProblemDetails` with `@JsonProperty("trace_id")`.
    - Update `GlobalExceptionHandler` to inject `tracer.currentSpan().context().traceId()` (or fallback to `MDC` / request attribute) into every constructed `ProblemDetails` instance.
  - _Requirements: REQ-OTEL-3.1, REQ-OTEL-3.2; Design: Section 2.2_

- [x] **Task 4: Implement TraceCorrelationFilter for Inbound and Outbound Traces**
  - Path: `backend/account-service/src/main/java/com/fse/banking/account/config/TraceCorrelationFilter.java`, `backend/account-service/src/main/java/com/fse/banking/account/config/OpenTelemetryConfig.java`
  - Subtasks:
    - Create `TraceCorrelationFilter` extending `OncePerRequestFilter`.
    - Extract active span trace context from `io.micrometer.tracing.Tracer`.
    - Set response headers `X-Trace-Id` and `traceparent`.
    - Support upstream `traceparent` propagation and optional `X-Request-Id` span tagging.
    - Register standard W3C trace context and baggage propagators in `OpenTelemetryConfig`.
  - _Requirements: REQ-OTEL-1.3, REQ-OTEL-1.4, REQ-OTEL-2.1, REQ-OTEL-2.2, REQ-OTEL-2.3; Design: Section 2.1_

- [x] **Task 5: Update Infrastructure Docker Compose with Jaeger All-In-One**
  - Path: `infrastructure/docker-compose.yml`
  - Subtasks:
    - Add `jaeger-tracing` container based on `jaegertracing/all-in-one:latest`.
    - Expose ports `4317` (OTLP gRPC), `4318` (OTLP HTTP), and `16686` (Web UI).
    - Attach to `banking-net`.
  - _Requirements: REQ-OTEL-5.1; Design: Section 1_

- [x] **Task 6: Implement Comprehensive Automated Tracing Test Suite**
  - Path: `backend/account-service/src/test/java/com/fse/banking/account/tracing/TraceCorrelationWebTest.java`
  - Subtasks:
    - Test 1: Verify standard API request receives active OpenTelemetry trace and `X-Trace-Id` header.
    - Test 2: Verify W3C `traceparent` context propagation from caller is adopted.
    - Test 3: Verify error responses (400 validation, 401 unauthorized, 404 not found) include `X-Trace-Id` and `ProblemDetails.trace_id`.
    - Test 4: Verify MDC logging context contains active `traceId`.
    - Run the entire test suite and verify 100% pass rate.
  - _Requirements: REQ-OTEL-1.1 through REQ-OTEL-4.2; Design: Section 3_
