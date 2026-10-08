# Edge API Gateway Service

Perimeter reverse proxy, token rate limiter, and authentication gateway for the retail banking platform.

## 1. Overview and purpose

The API Gateway is the single public entry point for all frontend and external API traffic. Running on port 8080, it isolates internal microservices from direct public exposure, enforces perimeter rate limits, verifies JWT claims, checks revoked token blacklists, and distributes requests to backend services.

## 2. Tech stack

* Runtime: Java 21 LTS
* Framework: Spring Boot 3.3.x, Spring Cloud Gateway
* Engine: Non-blocking reactive Netty (Project Reactor)
* Rate limiting: Spring Data Reactive Redis with Redis Token Bucket filter
* Security: Reactive JWT validation filter (`JwtAuthenticationFilter`)
* Tracing: OpenTelemetry W3C Trace Context propagation
* Build tool: Apache Maven 3.9+

## 3. Scope and boundaries

### In scope
* Perimeter routing and reverse proxying to internal backend services.
* Reactive JWT signature validation and claims extraction.
* Instant session revocation: Edge checks against Redis key `blacklist:jti:<jti>`.
* Token-bucket rate limiting via Redis (`RequestRateLimiter`).
* Request path rewriting (for example, `/api/v1/transfers/**` mapped to `/api/v1/ledger/transfers/**`).
* Perimeter Cross-Origin Resource Sharing (CORS) enforcement.

### Out of scope
* User database lookups: Handled by `account-service`.
* Financial transaction processing: Handled by `ledger-mutation-engine`.
* Fraud scoring: Handled by `risk-service`.
* Business logic validation: Microservices validate their own payloads.

## 4. Routing table

All external clients connect through `http://localhost:8080`. Internal destinations resolve over the Docker network:

| Route ID | External Path Predicate | Internal Target | Rate Limit (Replenish / Burst) |
| :--- | :--- | :--- | :--- |
| `account-service` | `/api/v1/accounts/**`, `/api/v1/auth/**`, `/api/v1/kyc/**` | `http://account-service:8081` | 10 req/s / 20 burst |
| `ledger-mutation-engine` | `/api/v1/transactions/**`, `/api/v1/ledger/**`, `/api/v1/t24/**` | `http://ledger-mutation-engine:8082` | 10 req/s / 20 burst |
| `ledger-transfers` | `/api/v1/transfers/**` (rewritten to `/api/v1/ledger/transfers/**`) | `http://ledger-mutation-engine:8082` | 10 req/s / 20 burst |
| `notification-service` | `/api/v1/notifications/**`, `/ws/**` | `http://notification-service:8083` | 20 req/s / 40 burst |

## 5. Critical invariants for AI agents

1. Reactive runtime only: This service runs on Spring Cloud Gateway and Netty. Do not add blocking Spring MVC controllers, blocking filters, or blocking JDBC dependencies. Everything must be non-blocking (`Mono`, `Flux`).
2. Blacklist verification: The `JwtAuthenticationFilter` checks Redis for blacklisted tokens before forwarding any authenticated request. If the token JTI exists in Redis, it returns HTTP 401 Unauthorized immediately.
3. User key resolution: The `userKeyResolver` extracts user identity from the JWT for rate limiting. Unauthenticated public endpoints (such as login) fall back to client IP address.
4. Header preservation: W3C trace headers (`traceparent`, `tracestate`) must pass untouched to downstream services.

## 6. Local development and testing

Run the gateway locally:

```bash
cd backend/gateway-service
mvn clean test
mvn spring-boot:run
```

Environment variables:
* `SERVER_PORT`: Gateway listening port (default: `8080`)
* `REDIS_HOST`: Redis instance hostname (default: `localhost`)
* `REDIS_PORT`: Redis instance port (default: `6379`)
* `ACCOUNT_SERVICE_URI`: Account service target URI (default: `http://localhost:8081`)
* `LEDGER_ENGINE_URI`: Ledger mutation engine target URI (default: `http://localhost:8082`)
* `NOTIFICATION_SERVICE_URI`: Notification service target URI (default: `http://localhost:8083`)
* `JWT_SECRET`: Minimum 256-bit HMAC secret string matching `account-service`
