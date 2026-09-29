# FSE Capstone: Core Retail Ledger and Balance Mutation Platform

Group 3 Engineering Repository: Definitive Architecture, Schemas, and Developer Source of Truth.

---

## 1. System architecture and core principles

The platform is a high-throughput, event-driven, dual-storage retail banking system with customer email verification for high-value transfers, deterministic concurrency locking, transactional outbox relays to Kafka KRaft, and immutable audit logging.

```
                                  +-----------------------+
                                  |   Web SPA Frontend    |
                                  |      (Port 3000)      |
                                  +-----------+-----------+
                                              |
                                              v (HTTP / SSE)
                               +-------------------------------+
                               |      API Gateway Service      |
                               |   (Port 8080 / Redis Limiter) |
                               +---+-----------+-----------+---+
                                   |           |           |
           /api/v1/auth, /accounts |           |           | /api/v1/notifications
                                   v           |           v
            +--------------------------+       |   +--------------------------+
            |      Account Service     |       |   |   Notification Service   |
            |        (Port 8081)       |       |   |        (Port 8083)       |
            +------------+-------------+       |   +------------+-------------+
                         |                     |                |
          HikariCP (10)  v                     |                v SMTP
              +--------------------+           |        +--------------------+
              | Oracle XE Master   |           |        |    MailHog SMTP    |
              | (Operational State)|           |        |  (:8025 UI / :1025)|
              |    (Port 1521)     |           |        +--------------------+
              +--------------------+           |
                                               v /api/v1/ledger
                               +-------------------------------+
                               |    Ledger Mutation Engine     |
                               |          (Port 8082)          |
                               +---+---------------+-------+---+
                                   |               |       |
                    HikariCP (30)  v  HikariCP (30)v       v Transactional Outbox
                 +-------------------+   +--------------------+ (EVT-601 Relay)
                 | Oracle XE Master  |   | PostgreSQL Audit   |    |
                 | (Row Locks / CME) |   | (Append-Only Log)  |    |
                 |    (Port 1521)    |   | (Port 5433 -> 5432)|    |
                 +-------------------+   +--------------------+    |
                                                                   v
                                                     +---------------------------+
                                                     | Apache Kafka KRaft Broker |
                                                     |  banking.transfers.events |
                                                     |  banking.customer.otp     |
                                                     |        (Port 9092)        |
                                                     +-------------+-------------+
                                                                   |
                                                                   v Events
                                                     +---------------------------+
                                                     |   Notification Service    |
                                                     | (TransactionEventConsumer)|
                                                     +---------------------------+
```

### Architectural principles

1. **Dual-storage isolation**:
   - **Oracle XE 21c**: Houses operational state and concurrency via pessimistic row locking (`SELECT ... FOR UPDATE`).
   - **PostgreSQL 16**: Serves as a compliance audit vault. A database trigger rejects any SQL `UPDATE` or `DELETE` statements on `ledger_mutation_audit`.

2. **Strict financial precision**:
   All monetary amounts across databases, DTOs, and REST payloads use eighteen total digits with four decimal places (`NUMBER(18, 4)` in Oracle, `NUMERIC(18, 4)` in PostgreSQL, and `BigDecimal` with `RoundingMode.UNNECESSARY` in Java). Floating-point data types (`FLOAT`, `DOUBLE`) are strictly forbidden.

3. **Deterministic lock ordering (deadlock prevention)**:
   When moving funds between two accounts, the engine sorts account IDs lexicographically (`sourceId.compareTo(targetId) < 0 ? sourceId : targetId`). The account with the lower ID is always locked first, guaranteeing that concurrent opposing transfers (A to B and B to A) acquire locks in the exact same sequence.

4. **Customer email verification for transfers above PHP 50,000.00 (BSP compliance)**:
   - System accounts are divided into two distinct roles: `CUSTOMER` and `ADMIN`.
   - Transfers at or below PHP 50,000.00 execute immediate atomic settlement without secondary challenge.
   - Transfers exceeding PHP 50,000.00 require customer verification via email. The engine places a soft hold on the sender available balance and generates a 6-digit OTP delivered to the customer registered email address.
   - Once the customer submits and validates the OTP, the hold is released and the balance mutation executes immediately. No admin approval is involved.
   - Transfers at or above PHP 500,000.00 (AMLA covered) also require customer email verification and generate an automated Covered Transaction Report (CTR) regulatory notification.

5. **Transactional outbox pattern (EVT-601)**:
   Financial mutations write the state update and an outbox event within the exact same relational transaction. A dedicated polling worker (`OutboxRelayScheduler`) runs every 2 seconds, publishing pending events to Apache Kafka and guaranteeing at-least-once message delivery without two-phase commit overhead.

6. **Dual email advices and circuit resiliency**:
   Upon transfer settlement, debit advices are sent to the sender and credit advices (`inward-credit-advice.html`) are sent to the beneficiary. If the SMTP transport fails, messages enter an in-memory circuit spool buffer to protect against message loss until flushed.

7. **Two-factor authentication via email service**:
   Authentication and high-value transactions use an email-based two-factor authentication (2FA) workflow. Rather than relying on SMS gateways, hardware authenticators, or biometric scanners, the system generates time-sensitive, single-use 6-digit verification codes. These codes are dispatched directly to the user registered email address through the Notification Service and SMTP (MailHog), and validated against Redis with a 5-minute time-to-live.

8. **Observability, APM request tracing, and logs (Datadog)**:
   Every HTTP request carries W3C trace context headers (`traceparent`). Traces are exported over OTLP directly to the Datadog Agent container at `http://localhost:4318/v1/traces` (or port `8126` for native APM), feeding live request waterfall graphs, latency percentiles, and unified container logs in the Datadog dashboard.

---

## 2. Networking and port allocation matrix

Every container attaches to the bridge network `banking-net`. Host and internal port allocations are configured as follows:

| Service or Container | Container Name | Host Port | Internal Port | Protocol | Purpose |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **Frontend Web SPA** | `banking-frontend` | `3000` | `80` | HTTP | React 18 + Vite Retail Banking Portal (Nginx Reverse Proxy) |
| **API Gateway** | `gateway-service` | `8080` | `8080` | HTTP / REST | Perimeter routing, JWT signature validation, Redis rate limiting |
| **Account Service** | `account-service` | `8081` | `8081` | HTTP / REST | KYC onboarding, user profiles, account creation, token rotation |
| **Ledger Engine** | `ledger-mutation-engine`| `8082` | `8082` | HTTP / REST | Concurrency locks, balance mutations, email 2FA verification, outbox worker |
| **Notification Service** | `notification-service` | `8083` | `8083` | HTTP / REST | Kafka listener, receipt generation, admin alerts, email 2FA dispatch |
| **MailHog Mock SMTP** | `mailhog-smtp` | `8025` / `1025` | `8025` / `1025` | HTTP / SMTP | Mock email testing inbox UI (`:8025`) and SMTP receiver (`:1025`) |
| **Oracle Database XE** | `oracle-xe-master` | `1521` | `1521` | Oracle TNS | Operational relational state (`XEPDB1`) |
| **PostgreSQL Audit** | `postgres-audit-vault`| `5433` | `5432` | PostgreSQL | Dedicated append-only audit vault (`banking_audit`) |
| **Redis Cache** | `redis-cache` | `6379` | `6379` | RESP / TCP | Token blacklist, session cache, 2FA OTP cache, rate limiting counters |
| **Kafka Broker** | `kafka-broker` | `9092` | `9092` | PLAINTEXT | Apache Kafka KRaft cluster event commit log |
| **Kafka UI` | `kafka-ui` | `8085` | `8080` | HTTP | Web console for topics, consumer groups, and message inspection |
| **Adminer Web GUI** | `db-adminer` | `8088` | `8080` | HTTP | Web database management console for Oracle and PostgreSQL |
| **Jaeger Tracing** | `jaeger-tracing` | `16686` / `4317` / `4318` | `16686` / `4317` / `4318` | HTTP / gRPC | Distributed tracing visualization and OTLP trace collection |
| **Prometheus Metrics**| `prometheus-engine`| `9090` | `9090` | HTTP | Time-series metrics collection and alert evaluation |
| **Grafana Dashboard** | `grafana-dashboard`| `3001` | `3000` | HTTP | Telemetry visualization and system performance dashboards |
| **Datadog Agent** | `dd-agent` | `8126` / `8125` | `8126` / `8125` | HTTP / UDP | APM trace waterfalls (`:8126`), DogStatsD metrics (`:8125`), container logs |

---

## 3. Database schemas and data models

### A. Master operational database (Oracle Database XE 21c)

Operational state, accounts, balances, and transactional outbox events are stored in Oracle Database Express Edition 21c.

| Parameter | Host Connection | Internal Docker Connection |
| :--- | :--- | :--- |
| Host | `localhost` | `oracle-xe-master` |
| Port | `1521` | `1521` |
| Service Name / PDB | `XEPDB1` | `XEPDB1` |
| Application User | `fse_user` | `fse_user` |
| Application Password | `fse_password` | `fse_password` |
| System / DBA User | `system` (or `sys as sysdba`) | `system` |
| System Password | `Password123#` | `Password123#` |
| JDBC URL | `jdbc:oracle:thin:@localhost:1521/XEPDB1` | `jdbc:oracle:thin:@oracle-xe-master:1521/XEPDB1` |


```sql
-- 1. Users Table (Customer and Admin Accounts Only)
CREATE TABLE users (
    user_id                 VARCHAR2(64) PRIMARY KEY,
    first_name              VARCHAR2(100) NOT NULL,
    middle_name             VARCHAR2(100),
    last_name               VARCHAR2(100) NOT NULL,
    email                   VARCHAR2(255) NOT NULL UNIQUE,
    phone_number            VARCHAR2(30) NOT NULL UNIQUE,
    dob                     DATE NOT NULL,
    government_id           VARCHAR2(100) NOT NULL,
    role                    VARCHAR2(20) NOT NULL CHECK (role IN ('CUSTOMER', 'ADMIN')),
    password_hash           VARCHAR2(255) NOT NULL,
    pin_hash                VARCHAR2(255),
    max_concurrent_sessions NUMBER(3) DEFAULT 3 NOT NULL,
    failed_login_attempts   NUMBER(3) DEFAULT 0 NOT NULL,
    status                  VARCHAR2(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'LOCKED', 'SUSPENDED')),
    created_at              TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at              TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Note on Account Roles and 2FA:
-- - The system supports strictly two account types: CUSTOMER (retail banking clients) and ADMIN (system operators and telemetry monitors).
-- - Transfers exceeding PHP 50,000.00 require customer verification via email OTP. Once verified, the transaction settles immediately without admin approval.
-- - Two-factor authentication (2FA) is executed via the email service. A cryptographically random 6-digit OTP is generated and cached in Redis (5-minute TTL), then dispatched to the customer registered email address via the Notification Service and local SMTP. Biometric authenticators and SMS OTPs are omitted.

-- 2. Accounts Table
CREATE TABLE accounts (
    account_id     VARCHAR2(64) PRIMARY KEY,
    user_id        VARCHAR2(64) NOT NULL,
    account_number VARCHAR2(32) NOT NULL UNIQUE,
    account_type   VARCHAR2(20) NOT NULL CHECK (account_type IN ('SAVINGS', 'CREDIT')),
    status         VARCHAR2(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'LOCKED', 'PENDING_APPROVAL')),
    credit_limit   NUMBER(18, 4) DEFAULT 0.0000 NOT NULL CHECK (credit_limit >= 0),
    created_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_acc_user FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- 3. Balance Master Table (Locked via SELECT ... FOR UPDATE)
CREATE TABLE balance_master (
    account_id        VARCHAR2(64) PRIMARY KEY,
    balance_amount    NUMBER(18, 4) DEFAULT 0.0000 NOT NULL CHECK (balance_amount >= 0),
    hold_amount       NUMBER(18, 4) DEFAULT 0.0000 NOT NULL CHECK (hold_amount >= 0),
    available_balance NUMBER(18, 4) DEFAULT 0.0000 NOT NULL,
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_bm_account FOREIGN KEY (account_id) REFERENCES accounts(account_id),
    CONSTRAINT chk_bm_solvency CHECK (balance_amount >= hold_amount)
);

-- 4. Transactions Table (Includes Customer Verification Metadata)
CREATE TABLE transactions (
    transaction_id         VARCHAR2(64) PRIMARY KEY,
    from_account_id        VARCHAR2(64) NOT NULL,
    to_account_id          VARCHAR2(64),
    type                   VARCHAR2(30) NOT NULL,
    amount                 NUMBER(18, 4) NOT NULL CHECK (amount > 0),
    before_balance         NUMBER(18, 4) NOT NULL,
    after_balance          NUMBER(18, 4) NOT NULL,
    status                 VARCHAR2(30) NOT NULL CHECK (status IN ('PENDING_APPROVAL', 'COMMITTED', 'FAILED')),
    requires_maker_checker NUMBER(1) DEFAULT 0 NOT NULL, -- Flag indicates email OTP verification required (> PHP 50,000.00)
    approved_by_user_id    VARCHAR2(64),
    created_at             TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at             TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_tx_from_acc FOREIGN KEY (from_account_id) REFERENCES accounts(account_id)
);

-- 5. Outbox Events Table (EVT-601: Transactional Outbox Pattern)
CREATE TABLE outbox_events (
    event_id       VARCHAR2(64) PRIMARY KEY,
    aggregate_type VARCHAR2(50) NOT NULL,
    aggregate_id   VARCHAR2(64) NOT NULL,
    event_type     VARCHAR2(50) NOT NULL,
    kafka_topic    VARCHAR2(100) NOT NULL,
    payload        CLOB NOT NULL,
    status         VARCHAR2(20) DEFAULT 'PENDING' NOT NULL,
    retry_count    NUMBER(4) DEFAULT 0 NOT NULL,
    created_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    published_at   TIMESTAMP WITH TIME ZONE,
    CONSTRAINT fk_oe_aggregate FOREIGN KEY (aggregate_id) REFERENCES transactions(transaction_id),
    CONSTRAINT chk_oe_aggregate_type CHECK (aggregate_type IN ('TRANSACTION', 'CUSTOMER_VERIFICATION', 'BALANCE_MUTATION')),
    CONSTRAINT chk_oe_event_type CHECK (event_type IN ('MAKER_PENDING', 'CHECKER_APPROVED', 'MUTATION_COMMITTED', 'TRANSFER_PENDING_APPROVAL', 'TRANSFER_EXECUTED')),
    CONSTRAINT chk_oe_status CHECK (status IN ('PENDING', 'PUBLISHED', 'FAILED'))
);

-- 6. Notifications Table (Historical Delivery Audit)
CREATE TABLE notifications (
    notification_id VARCHAR2(64) PRIMARY KEY,
    user_id         VARCHAR2(64) NOT NULL,
    type            VARCHAR2(50) NOT NULL,
    message         VARCHAR2(500) NOT NULL,
    sent_at         TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES users(user_id)
);
```

### B. Immutable audit vault (PostgreSQL 16)

The immutable audit log for balance mutations is housed in PostgreSQL 16 Alpine.

| Parameter | Host Connection | Internal Docker Connection |
| :--- | :--- | :--- |
| Host | `localhost` | `postgres-audit-vault` |
| Port | `5433` | `5432` |
| Database | `banking_audit` | `banking_audit` |
| Username | `audit_user` | `audit_user` |
| Password | `audit_password` | `audit_password` |
| Superuser | `postgres` (or `audit_user`) | `postgres` |
| JDBC URL | `jdbc:postgresql://localhost:5433/banking_audit` | `jdbc:postgresql://postgres-audit-vault:5432/banking_audit` |

```sql
CREATE TABLE ledger_mutation_audit (
    audit_id             BIGSERIAL PRIMARY KEY,
    transaction_id       VARCHAR(64) UNIQUE NOT NULL,
    account_id           VARCHAR(64) NOT NULL,
    mutation_type        VARCHAR(20) NOT NULL CHECK (mutation_type IN ('TRANSFER', 'DEBIT', 'CREDIT', 'HOLD', 'RELEASE')),
    mutation_amount      NUMERIC(18, 4) NOT NULL CHECK (mutation_amount > 0),
    before_balance       NUMERIC(18, 4) NOT NULL CHECK (before_balance >= 0),
    after_balance        NUMERIC(18, 4) NOT NULL CHECK (after_balance >= 0),
    initiator_user_id    VARCHAR(64) NOT NULL,
    approved_by_user_id  VARCHAR(64),
    status               VARCHAR(20) DEFAULT 'COMMITTED' NOT NULL CHECK (status IN ('COMMITTED', 'FAILED', 'ROLLED_BACK')),
    created_at           TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Trigger: Rejects any UPDATE or DELETE operations
CREATE OR REPLACE FUNCTION prevent_audit_tampering()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Compliance Violation: ledger_mutation_audit is append-only.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_protect_audit_log
BEFORE UPDATE OR DELETE ON ledger_mutation_audit
FOR EACH ROW EXECUTE FUNCTION prevent_audit_tampering();
```

### C. Database management with Adminer Web GUI

Adminer provides a lightweight browser-based SQL console configured with both PostgreSQL drivers and Oracle Instant Client 21 (OCI8 extension).

- Web UI URL: [http://localhost:8088](http://localhost:8088)
- Container Name: `db-adminer`
- Internal Port: `8080` (mapped to host port `8088`)

Because Adminer runs inside the Docker bridge network `banking-net`, connection forms must use the internal container service names rather than `localhost`.

#### Connecting to Oracle XE 21c via Adminer

| Adminer Field | Value to Enter |
| :--- | :--- |
| System | `Oracle` |
| Server | `oracle-xe-master:1521/XEPDB1` |
| Username | `fse_user` (or `system` for administrative access) |
| Password | `fse_password` (or `Password123#` for system) |
| Database | `XEPDB1` (optional if included in Server) |

#### Connecting to PostgreSQL 16 via Adminer

| Adminer Field | Value to Enter |
| :--- | :--- |
| System | `PostgreSQL` |
| Server | `postgres-audit-vault` |
| Username | `audit_user` |
| Password | `audit_password` |
| Database | `banking_audit` |

#### Quick credential reference table

| Target Database | Adminer System | Server (within Adminer) | External Host:Port | Username | Password | Database / Service |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Oracle XE (App) | `Oracle` | `oracle-xe-master:1521/XEPDB1` | `localhost:1521` | `fse_user` | `fse_password` | `XEPDB1` |
| Oracle XE (DBA) | `Oracle` | `oracle-xe-master:1521/XEPDB1` | `localhost:1521` | `system` | `Password123#` | `XEPDB1` |
| PostgreSQL Audit | `PostgreSQL` | `postgres-audit-vault` | `localhost:5433` | `audit_user` | `audit_password` | `banking_audit` |


---

## 4. Core Balance Mutation Engine (CME) and customer email verification

The Balance Mutation Engine executes financial movements with deterministic safety controls:

```
[Incoming Transfer Request]
           |
           v
 [Sanity Check: source != target]
           |
           v
 [Deterministic Order: min(src, dst) locked, then max(src, dst)]
           |
           v
 [Solvency Check: available_balance >= amount]
           |
           +-------------------------------------------------------+
           |                                                       |
Amount <= 50,000 PHP                                     Amount > 50,000 PHP
(Normal STP Transfer)                                    (Customer Email Verification Required)
           |                                                       |
           v                                                       v
[Atomic Immediate Settlement]                            [Place Soft Hold on Sender]
- Deduct sender balance & available                      - hold_amount += amount
- Credit receiver balance & available                    - available_balance -= amount
- Tx status: COMMITTED                                   - balance_amount untouched
- Write outbox: banking.transfers.events                 - Tx status: PENDING_VERIFICATION
- Write Postgres audit log                               - Dispatch 6-digit OTP to customer email
                                                                   |
                                                                   v
                                                      [Customer Inputs Email OTP Code]
                                                                   |
                         +-----------------------------------------+-----------------------------------------+
                         |                                                                                   |
                 [OTP Code Valid]                                                            [OTP Expired / Cancelled]
                         |                                                                                   |
                         v                                                                                   v
           [Release Hold & Commit Settlement]                                                  [Release Hold & Restore Available]
           - sender hold_amount -= amount                                                      - sender hold_amount -= amount
           - sender balance_amount -= amount                                                   - sender available_balance += amount
           - receiver balance_amount += amount                                                 - Tx status: CANCELLED
           - receiver available_balance += amount                                              - Write Postgres audit log
           - Tx status: COMMITTED
           - Write outbox: banking.transfers.events
           - Write Postgres audit log
```

### Key API endpoints

1. **Initiate transfer mutation**:
   `POST /api/v1/ledger/mutate`
   ```json
   {
     "transaction_id": "TX-100293",
     "account_id": "acc-2001-sav-001",
     "target_account_id": "acc-2003-sav-002",
     "event_type": "TRANSFER",
     "mutation_type": "TRANSFER",
     "mutation_amount": 65000.0000,
     "initiator_user_id": "usr-1001-cst-001"
   }
   ```
   *For amounts exceeding PHP 50,000.00, the transfer enters `PENDING_VERIFICATION` status and triggers an email OTP challenge.*

2. **Request email verification code**:
   `POST /api/v1/auth/2fa/send-otp`
   ```json
   {
     "userId": "usr-1001-cst-001",
     "transactionId": "TX-100293",
     "action": "TRANSFER_VERIFICATION"
   }
   ```

3. **Verify email code and commit transfer**:
   `POST /api/v1/auth/2fa/verify-otp`
   ```json
   {
     "userId": "usr-1001-cst-001",
     "transactionId": "TX-100293",
     "otp": "492817"
   }
   ```
   *Response:*
   ```json
   {
     "status": "COMMITTED",
     "message": "Email verification confirmed. Funds transferred successfully."
   }
   ```

4. **Cancel pending transfer**:
   `POST /api/v1/transfers/TX-100293/cancel`
   *Releases the soft hold and restores the customer available balance immediately.*

---

## 5. Transactional outbox pattern and Kafka streaming

The platform employs the Transactional Outbox Pattern (EVT-601) to bridge relational database transactions and Kafka event streams with zero data loss:

### Outbox relay architecture

1. **Atomic insertion**: When `BalanceMutationService` mutates account balances, it saves a `TransactionNotificationEvent` JSON document into the Oracle `outbox_events` table within the same transaction.
2. **Asynchronous poller**: `OutboxRelayScheduler` polls `outbox_events` every 2000 milliseconds for records where `status = 'PENDING'`.
3. **Guaranteed publishing**: The worker sends each record to Kafka with `acks=all`. Upon acknowledgment, the outbox record is marked `PUBLISHED`. If errors occur, `retry_count` is incremented up to 3 times before transitioning to `FAILED`.

### Kafka topics

1. **`banking.transfers.events`** (3 partitions, replication factor 1):
   - Key: `sourceAccountId` or `transactionId`.
   - Payload: `TransactionNotificationEvent` (transfer ID, source/destination accounts, amount, balances before/after, status, maker user ID, timestamp).
   - Consumers: `notification-service` (`TransactionEventConsumer`).

2. **`banking.customer.otp`** (3 partitions, replication factor 1):
   - Key: `userId` or `transactionId`.
   - Payload: Customer email OTP verification event for transfers exceeding PHP 50,000.00.

3. **`transaction-events`** (3 partitions, replication factor 1):
   - Internal ledger audit stream.

4. **`notification-alerts`** (3 partitions, replication factor 1):
   - Real-time customer push notification events.

### Kafka Web UI
Navigate to **[http://localhost:8085](http://localhost:8085)** to inspect topics, partitions, consumer lag, and live message payloads.

---

## 6. Notification Service and advisory system

The Notification Service (`:8083`) processes financial events from Kafka and delivers customer notices through email and browser push streams:

### Regulatory compliance tiers

1. **Tier 1 (Normal retail transfer, <= PHP 50,000.00)**:
   - Straight-Through Processing (STP) with no verification challenge.
   - Dual email delivery: Inward debit receipt sent to sender, outward credit advice (`inward-credit-advice.html`) sent to beneficiary.
   - Real-time browser toast delivered over Server-Sent Events (SSE).

2. **Tier 2 (Customer email OTP verification, PHP 50,000.01 to PHP 499,999.99)**:
   - Requires customer email verification.
   - Temporary soft hold placed on sender available balance.
   - Single-use 6-digit OTP dispatched to customer registered email address (`email-2fa-otp.html`).
   - Customer submits the OTP in the frontend modal to release the hold and execute immediate settlement. No admin approval is required.

3. **Tier 3 (AMLA covered transfer, >= PHP 500,000.00)**:
   - Covered transaction under AMLA regulations.
   - Requires customer email verification via OTP.
   - Automated Covered Transaction Report (CTR) compliance advisory dispatched to Compliance Officer inbox (`compliance-officer@corebank.ph`) for regulatory records. No admin approval is required.

### Two-factor authentication (2FA) via email service
- **No biometrics or SMS tokens**: The platform intentionally avoids third-party SMS aggregator dependencies and client-side biometric sensors.
- **Email OTP dispatch**: When a customer initiates a transfer above PHP 50,000.00 or signs in, the Notification Service dispatches a 6-digit numeric pass code formatted in `email-2fa-otp.html`.
- **In-memory cache validation**: The OTP is stored in Redis under the key `2fa:otp:{userId}` with a 300-second (5-minute) time-to-live.
- **Immediate settlement**: Upon successful OTP entry, the transaction is committed directly to the ledger without manual administrative review.

### Resilient offline spooling
If the SMTP server is unavailable, messages are automatically buffered in an in-memory circuit spool buffer. Once connectivity is restored, calling `POST /api/v1/notifications/flush-spool` drains the buffer and delivers all queued notices.

---

## 7. Frontend web application (React 18 + Vite)

The Single-Page Application (`frontend/`) provides an interactive interface partitioned into two distinct user experiences:

- **Customer Portal**: Real-time balance cards, quick preset transfer amounts, regulatory tier calculation, email OTP verification dialog for transfers exceeding PHP 50,000.00, and transaction receipt viewer.
- **Admin Portal**: System telemetry grid, 16-container health status, circuit spool buffer controls, database connection inspector, and audit log viewer. (Admins do not approve transfers; transfers are authorized directly by customers via email).
- **Live SSE Indicator**: Real-time connection badge with automatic reconnection and interactive floating toast notifications.

---

## 8. Observability, metrics, and APM request tracing (Datadog)

The entire microservices ecosystem is unified under **Datadog Agent 7** for end-to-end distributed tracing, APM request waterfall graphs, DogStatsD metrics, and container logs.

### APM request tracing and waterfall graphs
- Every Spring Boot microservice imports `micrometer-tracing-bridge-otel` and `opentelemetry-exporter-otlp`.
- Inbound and outbound requests propagate standard W3C `traceparent` headers across the API Gateway, Account Service, Ledger Mutation Engine, and Notification Service.
- OpenTelemetry traces are exported over HTTP directly to the Datadog Agent OTLP receiver at `http://localhost:4318/v1/traces` (or port `8126` for native Datadog trace clients).
- In the Datadog APM dashboard (**[https://app.datadoghq.com/apm/traces](https://app.datadoghq.com/apm/traces)**), each API request produces a complete waterfall span breakdown:
  - Gateway perimeter routing, JWT verification, and Redis rate-limiting latency.
  - CME lock ordering, Oracle `SELECT ... FOR UPDATE` acquisition duration, and Postgres audit persistence.
  - Transactional Outbox Kafka event emission and downstream notification worker consumption.

### Log collection and correlation
- The Datadog Agent container tails Docker container stdout/stderr streams (`DD_LOGS_ENABLED=true`, `DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true`).
- Spring Boot log messages include MDC correlation tags (`traceId`, `spanId`, `applicationName`), enabling direct click-through from Datadog logs into the corresponding APM waterfall trace.

### Infrastructure and JVM metrics
- Live host and container CPU, memory, network I/O, and disk usage are tracked in real-time.
- DogStatsD is exposed on UDP port `8125` for custom business metrics and counter submission.

---

## 9. Developer quick start guide

### Prerequisites
1. **Docker Desktop** (version 4.25+).
2. **Java 21 JDK** (configured in your `PATH`).
3. **Node.js 18+ & npm** (for frontend development).
4. **Maven** (bundled `.\mvnw.cmd` included in the repository).

### Running the complete platform via Docker Compose

To launch all 16 containers including databases, message bus, backend microservices, frontend SPA, and observability stacks:

```powershell
# 1. Build backend service artifacts
cd backend
.\mvnw.cmd clean package -DskipTests
cd ..

# 2. Compile frontend static bundle
cd frontend
npm install
npm run build
cd ..

# 3. Spin up all containerized services
docker compose -f infrastructure/docker-compose.yml up -d --build
```

#### Container inventory and port references

| Container Name | Service | Host Port | Description |
| :--- | :--- | :---: | :--- |
| `banking-frontend` | React 18 SPA + Nginx | `3000` | Customer and Admin banking web portal |
| `gateway-service` | Spring Cloud Gateway | `8080` | Perimeter security, routing, Redis rate limiting |
| `account-service` | Account & Identity | `8081` | User profiles, account management, JWT authentication |
| `ledger-mutation-engine` | Core Ledger Engine | `8082` | Balance mutations, pessimistic locking, outbox worker |
| `notification-service` | Notification & 2FA | `8083` | Kafka consumer, email advices, 2FA OTP delivery |
| `oracle-xe-master` | Oracle Database 21c XE | `1521` | Master operational database (`XEPDB1`) |
| `postgres-audit-vault` | PostgreSQL 16 Alpine | `5433` | Compliance immutable audit vault (`banking_audit`) |
| `redis-cache` | Redis 7 Alpine | `6379` | Token blacklist, 2FA OTP cache, rate limit counters |
| `kafka-broker` | Apache Kafka 3.7 (KRaft) | `9092` | Event streaming commit log |
| `kafka-ui` | Kafka Web UI Console | `8085` | Topic and message inspection portal |
| `mailhog-smtp` | MailHog Mock SMTP | `8025` / `1025` | Web email inbox (`:8025`) and SMTP receiver (`:1025`) |
| `db-adminer` | Adminer DB Console | `8088` | Web SQL console for Oracle and PostgreSQL |
| `jaeger-tracing` | Jaeger All-In-One | `16686` | Distributed trace query and visualization UI |
| `prometheus-engine` | Prometheus v2.53 | `9090` | Time-series metrics scraper and alert engine |
| `grafana-dashboard` | Grafana v11.1 | `3001` | Infrastructure and transaction telemetry dashboards |
| `dd-agent` | Datadog Agent 7 | `8126` / `8125` | Datadog APM trace collector and DogStatsD receiver |

### Local development workflow

If you prefer running services directly on the host with live reloading:

#### 1. Start backing infrastructure
```powershell
docker compose -f infrastructure/docker-compose.yml up -d oracle-xe-master postgres-audit-vault redis-cache kafka-broker mailhog kafka-ui adminer
```

#### 2. Run backend microservices
Start each service in a separate terminal:
```powershell
# Terminal 1: API Gateway (:8080)
cd backend/gateway-service && ..\mvnw.cmd spring-boot:run

# Terminal 2: Account Service (:8081)
cd backend/account-service && ..\mvnw.cmd spring-boot:run

# Terminal 3: Ledger Mutation Engine (:8082)
cd backend/ledger-mutation-engine && ..\mvnw.cmd spring-boot:run

# Terminal 4: Notification Service (:8083)
cd backend/notification-service && ..\mvnw.cmd spring-boot:run
```

#### 3. Run frontend development server
```powershell
cd frontend
npm install
npm run dev
```
Open **[http://localhost:3000](http://localhost:3000)** in your browser.

---

## 10. Repository structure

```text
.
├── README.md                           # Master single source of truth
├── ARCHITECTURE.md                     # Architectural design specification
├── API_SPECIFICATION.md                # REST API payloads, headers, and error codes
├── ERD.md                              # Entity-Relationship diagram and data dictionary
├── JIRA_BACKLOG.md                     # Sprint user stories and EARS acceptance criteria
├── infrastructure/
│   ├── docker-compose.yml              # Complete orchestration (16 containerized services)
│   ├── adminer/
│   │   ├── Dockerfile                  # Adminer with Oracle Instant Client 21 & OCI8
│   │   ├── basic_lite.zip              # Pre-bundled Oracle Instant Client package
│   │   └── oci8.so                     # Pre-compiled PHP OCI8 module
│   ├── oracle/
│   │   └── init.sql                    # Oracle XE 21c DDL, outbox table, and seed data
│   ├── postgres/
│   │   └── init.sql                    # PostgreSQL audit DDL, trigger, and seed data
│   ├── prometheus/                     # Prometheus scraping rules and alert definitions
│   ├── grafana/                        # Auto-provisioned telemetry dashboards and datasources
│   └── datadog/                        # Datadog Agent 7 configuration (APM, OTLP traces, logs)
├── frontend/                           # React 18 + Vite Web SPA
│   ├── package.json                    # Frontend dependencies & scripts
│   ├── Dockerfile                      # Nginx production image configuration
│   ├── nginx.conf                      # Nginx reverse proxy and security headers
│   ├── vite.config.js                  # Vite server & Gateway proxy configuration
│   ├── tailwind.config.js              # Tailwind utility classes & theme
│   └── src/
│       ├── api/
│       │   └── client.js               # Axios services for CME & Notification APIs
│       └── components/
│           ├── Header.jsx              # Navigation header, role switcher & SSE badge
│           ├── CustomerPortal.jsx      # Customer transfer terminal, balances, email 2FA
│           └── AdminPortal.jsx         # System telemetry grid, circuit spool buffer monitor, audit viewer
└── backend/
    ├── pom.xml                         # Aggregator POM (Spring Boot 3.3.5, Java 21)
    ├── common-contracts/               # Shared DTOs, enums, events, and exceptions
    ├── gateway-service/                # Spring Cloud Gateway, JWT verification, rate limiter
    ├── account-service/                # KYC onboarding, account provisioning, token rotation
    ├── ledger-mutation-engine/         # Core Mutation Engine (CME), locks, outbox worker
    └── notification-service/           # Kafka consumer, dual advices, email 2FA OTP, spool buffer
```

---

## 11. Team contribution and branching guidelines

1. Work on dedicated feature branches branched off `main` (for example, `jm-branch`, `zel-branch`).
2. Commit messages should follow conventional commits: `feat:`, `fix:`, `refactor:`, `chore:`.
3. Never bypass financial check constraints or tamper with the append-only PostgreSQL trigger.
4. Ensure all unit and integration tests pass before submitting pull requests to `main`.
