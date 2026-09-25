# Requirements Specification: OpenTelemetry Distributed Tracing

## 1. Domain Glossary

- **OpenTelemetry (OTel)**: Vendor-neutral, open-source observability framework providing APIs, SDKs, and tooling to capture distributed traces, metrics, and logs.
- **Trace**: A directed acyclic graph of Spans that represents the end-to-end journey of an execution flow or API request across microservices.
- **Span**: A single contiguous unit of work within a trace, containing a name, start/end timestamps, status, attributes, and context identifiers (`traceId`, `spanId`).
- **Trace Context**: Metadata propagated across network and thread boundaries, defined by the W3C Trace Context standard (`traceparent` and `tracestate`).
- **Trace ID**: A globally unique 16-byte (32-character hexadecimal) identifier identifying the entire distributed trace.
- **Span ID**: An 8-byte (16-character hexadecimal) identifier identifying a specific unit of work within the trace.
- **Trace Correlation Header**: HTTP response header (`X-Trace-Id` and `traceparent`) allowing clients to correlate HTTP responses with backend traces.
- **OTLP (OpenTelemetry Protocol)**: Protocol buffer and HTTP/gRPC standard for transporting telemetry data from application services to collectors or trace visualization backends (e.g., Jaeger).
- **Sampling Probability**: Configurable ratio governing what fraction of inbound transactions generate recorded trace spans (configured to 1.0 / 100% for full coverage).

---

## 2. Scope Boundaries

- **In-Scope**:
  - OpenTelemetry integration into Spring Boot 3 microservices (`account-service` and `ledger-mutation-engine`) via Micrometer Tracing OpenTelemetry Bridge.
  - Automatic tracing of 100% of inbound HTTP API requests (`ServerHttpObservationFilter`).
  - Trace context extraction and propagation conforming to W3C Trace Context specification (`traceparent`).
  - HTTP trace correlation response headers (`X-Trace-Id` and `traceparent`) injected on all API responses (success and error).
  - Trace ID enrichment in RFC-7807 `ProblemDetails` error payloads for root-cause correlation.
  - MDC (Mapped Diagnostic Context) log enrichment including `traceId` and `spanId`.
  - Configurable OTLP HTTP trace exporter targeting local Jaeger / OpenTelemetry collector.
  - Jaeger all-in-one tracing service defined in `infrastructure/docker-compose.yml`.
  - Automated integration and slice tests validating trace generation, context propagation, header presence, and error payload correlation.
- **Deferred / Out-of-Scope**:
  - Custom spans for third-party external payment gateway calls (Sprint 2).
  - Production multi-region OpenTelemetry Collector cluster deployment with tail-based sampling.

---

## 3. Structured Requirements & EARS Acceptance Criteria

### Requirement 1: Comprehensive Inbound API Request Tracing
**User Story**: As a platform observability engineer, I want every API request in the banking services automatically traced with OpenTelemetry so that end-to-end request lifecycles, latency bottlenecks, and service dependencies are completely visible.

- **Ubiquitous Criteria**:
  - `REQ-OTEL-1.1`: THE banking service SHALL instrument every incoming HTTP API request with an OpenTelemetry trace span capturing HTTP method, URI template, status code, and latency.
  - `REQ-OTEL-1.2`: THE tracing subsystem SHALL default to a sampling probability of `1.0` (100% sampling) to ensure every transaction is recorded.
  - `REQ-OTEL-1.3`: THE tracing subsystem SHALL generate a valid 32-character hexadecimal `traceId` and a valid 16-character hexadecimal `spanId` for every un-parented inbound request.
- **Event-Driven Criteria**:
  - `REQ-OTEL-1.4`: WHEN an HTTP request is received with a valid W3C `traceparent` header, THE service SHALL extract and adopt the supplied `traceId` into the active trace context.
  - `REQ-OTEL-1.5`: WHEN an HTTP request completes (whether successful or with an error), THE service SHALL export the completed span via OTLP to the configured collector endpoint.
- **Unwanted Behavior Criteria**:
  - `REQ-OTEL-1.6`: IF the OTLP collector is temporarily unreachable or offline, THEN THE tracing subsystem SHALL handle the export failure asynchronously without blocking or failing the HTTP transaction.

### Requirement 2: Response Header Trace Correlation
**User Story**: As a frontend or API client developer, I want every HTTP response to include the trace identifier so that any issue reported by clients can be traced back to its root cause in telemetry.

- **Ubiquitous Criteria**:
  - `REQ-OTEL-2.1`: THE service SHALL include an `X-Trace-Id` HTTP header in every API response matching the active 32-character hexadecimal `traceId`.
  - `REQ-OTEL-2.2`: THE service SHALL include a standard W3C `traceparent` HTTP header in every API response formatted as `00-{traceId}-{spanId}-01`.
- **State-Driven Criteria**:
  - `REQ-OTEL-2.3`: WHILE processing an error response (HTTP 4xx or 5xx), THE service SHALL preserve and return the `X-Trace-Id` header on the response.

### Requirement 3: RFC-7807 Error Payload Correlation
**User Story**: As an API consumer, I want error responses to contain the trace ID in their JSON payload so that I can provide the ID to support teams for immediate incident triaging.

- **Ubiquitous Criteria**:
  - `REQ-OTEL-3.1`: THE RFC-7807 `ProblemDetails` schema SHALL include an optional `trace_id` property.
- **Event-Driven Criteria**:
  - `REQ-OTEL-3.2`: WHEN `GlobalExceptionHandler` handles any exception (business, validation, unreadable payload, or unhandled 500), THE handler SHALL populate the `trace_id` field of `ProblemDetails` with the active trace ID.

### Requirement 4: MDC Log Correlation
**User Story**: As a site reliability engineer, I want application log lines to contain the active `traceId` and `spanId` so that logs and traces can be correlated in log aggregators.

- **Ubiquitous Criteria**:
  - `REQ-OTEL-4.1`: THE service logging pattern SHALL format log levels with `[service-name,traceId,spanId]` using SLF4J MDC keys.
- **State-Driven Criteria**:
  - `REQ-OTEL-4.2`: WHILE an API request is executing, ANY log message emitted SHALL include the non-empty active `traceId` and `spanId` in its MDC context.

### Requirement 5: Local Telemetry Infrastructure
**User Story**: As a local software engineer, I want a local tracing backend and visualization UI so that I can inspect traces locally during development and debugging.

- **Ubiquitous Criteria**:
  - `REQ-OTEL-5.1`: THE `infrastructure/docker-compose.yml` SHALL define a Jaeger all-in-one container exposing the OTLP HTTP receiver on port 4318, OTLP gRPC receiver on port 4317, and Jaeger Query UI on port 16686.
