# Core Ledger Mutation Engine

The core financial ledger, double-entry accounting, and atomic balance mutation service for the retail banking platform.

## 1. Overview and purpose

The Ledger Mutation Engine is the authoritative system of record for account balances and financial transactions. It enforces double-entry accounting invariants, executes atomic balance mutations with pessimistic database row locks, orchestrates funds transfers with the Python risk engine, and interfaces with simulated core banking systems (Temenos T24).

It runs on port 8082, accessible internally from `gateway-service` on port 8080.

## 2. Tech stack

* Runtime: Java 21 LTS
* Framework: Spring Boot 3.3.x, Spring Data JPA
* Master datastore: Oracle XE 21c (local profile) or Azure SQL Database with Ledger tables (cloud profile)
* Read replica: PostgreSQL 16 (for analytical reads and statement generation)
* Connection pooling: HikariCP with isolated read and write datasource configurations
* Event streaming: Apache Kafka (producing to `ledger.mutations` and `account.events`)
* Core banking interface: Temenos T24 Core Banking Simulation API
* Distributed tracing: OpenTelemetry with W3C Trace Context propagation
* Build tool: Apache Maven 3.9+

## 3. Scope and boundaries

### In scope
* Atomic debit, credit, transfer, and reversal mutations.
* Double-entry ledger journal entries (`ledger_entries` table).
* Pessimistic row locking on balances (`SELECT ... FOR UPDATE`) with deterministic ordering to prevent deadlocks.
* Idempotent transaction execution via unique transaction and idempotency keys.
* Synchronous risk engine invocation against `risk-service:8084` before fund reservation.
* Temenos T24 Core Banking integration for interbank funds transfers and reversals (`/api/v1/t24/**`).
* Outbox event publishing to Apache Kafka upon committed transactions.

### Out of scope
* User credentials and KYC verification: Handled by `account-service`.
* ML tabular scoring and NLP threat synthesis: Evaluated by `risk-service`.
* Email, SMS, and WebSocket alert delivery: Dispatched by `notification-service`.

## 4. Key API routes

| Method | Path | Description |
| :--- | :--- | :--- |
| `POST` | `/api/v1/ledger/mutate` | Executes low-level balance mutation (DEBIT, CREDIT, REVERSAL). |
| `POST` | `/api/v1/ledger/transfers` | Initiates end-to-end retail transfer with risk evaluation and locking. |
| `GET` | `/api/v1/ledger/balance/{accountId}` | Reads current cleared and available balance. |
| `GET` | `/api/v1/ledger/transactions/{accountId}` | Queries paginated historical transactions. |
| `POST` | `/api/v1/t24/funds-transfer` | Simulates Temenos T24 Core Banking funds transfer ingestion. |
| `POST` | `/api/v1/t24/reversal` | Simulates Temenos T24 transaction reversal. |
| `GET` | `/actuator/health` | Service health check and database readiness. |

## 5. Critical invariants for AI agents

1. Zero negative balances: A checking account must never drop below 0.00 currency units. If available balance minus amount is negative, the service throws `InsufficientBalanceException`.
2. Mathematical conservation: In every transfer, total debits must equal total credits. Money cannot be created or destroyed within internal transfers.
3. Deterministic lock ordering: When transferring funds between account A and account B, row locks MUST be acquired in sorted ascending order by account ID:
   ```java
   String firstLock = sourceId.compareTo(targetId) < 0 ? sourceId : targetId;
   String secondLock = sourceId.compareTo(targetId) < 0 ? targetId : sourceId;
   ```
   This prevents deadlocks when concurrent transfers occur between the same two accounts in opposite directions.
4. Risk engine gate enforcement:
   * If `risk-service` returns `BLOCK`, the transaction must abort immediately. Zero bypass or override is allowed.
   * If `risk-service` returns `ADVISORY_WARNING`, the friction modal response must pass back to the client.
   * If `risk-service` times out (1,500 ms limit), the system falls back safely to Stage A tabular rules.
5. Idempotency guarantees: Every mutation payload includes an `idempotencyKey`. If a duplicate key is presented, the service returns the previous result without repeating balance deductions.

## 6. Local development and testing

Run unit and integration tests:

```bash
cd backend/ledger-mutation-engine
mvn clean test
```

Start the service locally:

```bash
mvn spring-boot:run
```

Environment variables:
* `SPRING_PROFILES_ACTIVE`: `local` or `azure`
* `ORACLE_URL` / `AZURE_SQL_URL`: Master write database JDBC connection string
* `POSTGRES_URL`: Read replica JDBC connection string
* `KAFKA_BOOTSTRAP_SERVERS`: Kafka broker addresses (default: `localhost:9092`)
* `RISK_SERVICE_URL`: Risk service endpoint (default: `http://localhost:8084`)
