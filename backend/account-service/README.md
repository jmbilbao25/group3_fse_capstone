# Account and Identity Service

Retail customer account management, authentication, and Know Your Customer (KYC) identity lifecycle service for the retail banking platform.

## 1. Overview and purpose

The Account Service manages the lifecycle of retail banking customers. It handles initial onboarding registration, identity document submission, customer identity tiering, credential verification, and session token issuance.

All incoming client traffic routes through the API Gateway on port 8080. The Account Service runs internally on port 8081 within the container network.

## 2. Tech stack

* Runtime: Java 21 LTS
* Framework: Spring Boot 3.3.x, Spring Security, Spring Data JPA
* Connection pool: HikariCP (`HikariPool-AccountService`, 15 max connections, 5 min idle)
* Primary datastore: Oracle XE 21c (local profile) or Azure Database for PostgreSQL (cloud profile)
* Caching and session store: Redis 7 (refresh token family sets and JWT blacklists)
* Distributed tracing: OpenTelemetry with W3C Trace Context propagation
* Build tool: Apache Maven 3.9+

## 3. Scope and boundaries

### In scope
* Customer registration with JSR-380 input validation.
* Secure password management using BCrypt with salt rounds of 12.
* Session creation issuing short-lived access JWTs (15-minute TTL) and opaque refresh tokens.
* Refresh Token Rotation (RTR) with family breach detection in Redis.
* KYC document metadata ingestion and tier evaluation (Tier 1 Basic, Tier 2 Standard, Tier 3 Fully Verified).
* Customer account profile lookups and status toggles (ACTIVE, SUSPENDED, FROZEN).

### Out of scope
* Balance mutations and ledger entries: Strictly managed by `ledger-mutation-engine`.
* Transfer risk scoring: Strictly evaluated by `risk-service`.
* Notification dispatch: Handled by `notification-service`.
* Edge rate limiting and perimeter token blacklisting: Handled at `gateway-service`.

## 4. Key API routes

| Method | Path | Access | Description |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/auth/register` | Public | Registers a new customer profile. |
| `POST` | `/api/v1/auth/login` | Public | Authenticates credentials and returns access token plus refresh token. |
| `POST` | `/api/v1/auth/refresh` | Public | Rotates single-use refresh token and issues a new access token. |
| `POST` | `/api/v1/auth/logout` | Authenticated | Blacklists active access token JTI in Redis. |
| `GET` | `/api/v1/accounts/me` | Authenticated | Retrieves profile and account identifiers for authenticated user. |
| `GET` | `/api/v1/accounts/{accountId}` | Authenticated | Looks up specific account status and currency metadata. |
| `POST` | `/api/v1/kyc/upload` | Authenticated | Submits verification document identifiers for KYC review. |
| `GET` | `/api/v1/kyc/status` | Authenticated | Retrieves current KYC verification tier. |
| `GET` | `/actuator/health` | Public | Service health check and readiness status. |

## 5. Critical invariants for AI agents

1. Zero SMS OTP policy: Under BSP Circular 1213, this service never generates or validates SMS one-time passwords for authentication. Session verification uses cryptographic credentials and bound devices.
2. Refresh token reuse detection: Refresh tokens are strictly single-use. If a revoked token is presented to `/api/v1/auth/refresh`, Redis triggers `purgeEntireTokenFamily`, invalidating all sessions for that user family immediately.
3. No balance modifications: Never add balance update logic to this service. Account balances and transaction mutations belong exclusively to `ledger-mutation-engine`.
4. Password handling: Passwords must never be logged, cached in Redis, or returned in response DTOs.
5. Database migrations: Local schema structures are managed through SQL scripts in `infrastructure/oracle/` or `infrastructure/postgres/`.

## 6. Local development and testing

Run the service locally:

```bash
cd backend/account-service
mvn clean test
mvn spring-boot:run
```

Environment variables:
* `SPRING_PROFILES_ACTIVE`: `local` or `azure`
* `ORACLE_URL` / `DATASOURCE_URL`: JDBC connection string
* `REDIS_HOST`: Redis instance hostname (default: `localhost`)
* `REDIS_PORT`: Redis instance port (default: `6379`)
* `JWT_SECRET`: Minimum 256-bit HMAC secret string
