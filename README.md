# FSE Capstone: Core Retail Ledger and Balance Mutation Platform

Group 3 Engineering Repository: Definitive Architecture, Schemas, and Developer Source of Truth.

---

## 1. System architecture and core principles

The platform is a high-throughput, event-driven, dual-storage retail banking system with Maker-Checker transaction verification, deterministic concurrency locking, transactional outbox relays to Kafka KRaft, and immutable audit logging.

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
                                                     |  banking.makerchecker.pen |
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

4. **Maker-checker dual control (BSP compliance)**:
   - Transfers at or below PHP 50,000.00 execute immediate atomic settlement.
   - Transfers exceeding PHP 50,000.00 place a soft hold on the sender available balance and enter `PENDING_APPROVAL`.
   - A distinct authorized officer (teller or manager) must review and approve or reject the request. The initiator (maker) cannot approve or reject their own transaction.

5. **Transactional outbox pattern (EVT-601)**:
   Financial mutations write the state update and an outbox event within the exact same relational transaction. A dedicated polling worker (`OutboxRelayScheduler`) runs every 2 seconds, publishing pending events to Apache Kafka and guaranteeing at-least-once message delivery without two-phase commit overhead.

6. **Dual email advices and circuit resiliency**:
   Upon transfer settlement, debit advices are sent to the sender and credit advices (`inward-credit-advice.html`) are sent to the beneficiary. If the SMTP transport fails, messages enter an in-memory circuit spool buffer to protect against message loss until flushed.

7. **Observability, APM request tracing, and logs (Datadog)**:
   Every HTTP request carries W3C trace context headers (`traceparent`). Traces are exported over OTLP directly to the Datadog Agent container at `http://localhost:4318/v1/traces` (or port `8126` for native APM), feeding live request waterfall graphs, latency percentiles, and unified container logs in the Datadog dashboard.

---

## 2. Networking and port allocation matrix

Every container attaches to the bridge network `banking-net`. Host and internal port allocations are configured as follows:

| Service or Container | Container Name | Host Port | Internal Port | Protocol | Purpose |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **Frontend Web SPA** | `frontend` | `3000` | `3000` | HTTP | React 18 + Vite Retail Banking Portal |
| **API Gateway** | `gateway-service` | `8080` | `8080` | HTTP / REST | Perimeter routing, JWT signature validation, Redis rate limiting |
| **Account Service** | `account-service` | `8081` | `8081` | HTTP / REST | KYC onboarding, user profiles, account creation, token rotation |
| **Ledger Engine** | `ledger-mutation-engine`| `8082` | `8082` | HTTP / REST | Concurrency locks, balance mutations, maker-checker, outbox worker |
| **Notification Service** | `notification-service` | `8083` | `8083` | HTTP / REST | Kafka listener, receipt generation, manager alerts, email dispatch |
| **MailHog Mock SMTP** | `mailhog-smtp` | `8025` / `1025` | `8025` / `1025` | HTTP / SMTP | Mock email testing inbox UI (`:8025`) and SMTP receiver (`:1025`) |
| **Oracle Database XE** | `oracle-xe-master` | `1521` | `1521` | Oracle TNS | Operational relational state (`XEPDB1`) |
| **PostgreSQL Audit** | `postgres-audit-vault`| `5433` | `5432` | PostgreSQL | Dedicated append-only audit vault (`banking_audit`) |
| **Redis Cache** | `redis-cache` | `6379` | `6379` | RESP / TCP | Token blacklist, session cache, Redis rate limiting counters |
| **Kafka Broker** | `kafka-broker` | `9092` | `9092` | PLAINTEXT | Apache Kafka KRaft cluster event commit log |
| **Kafka UI** | `kafka-ui` | `8085` | `8080` | HTTP | Web console for topics, consumer groups, and message inspection |
| **Adminer Web GUI** | `db-adminer` | `8088` | `8080` | HTTP | Web database management console for Oracle and PostgreSQL |
| **Datadog Agent** | `dd-agent` | `8126` / `4318` / `8125` | `8126` / `4318` / `8125` | HTTP / UDP | Full-stack observability: APM trace waterfalls (`:8126`/`:4318`), DogStatsD metrics (`:8125`), and container logs |

---

## 3. Database schemas and data models

### A. Master operational database (Oracle Database XE 21c)
Host: `localhost:1521`, Pluggable Database: `XEPDB1`, User: `fse_user`, Password: `fse_password`

```sql
-- 1. Users Table
CREATE TABLE users (
    user_id                 VARCHAR2(64) PRIMARY KEY,
    first_name              VARCHAR2(100) NOT NULL,
    middle_name             VARCHAR2(100),
    last_name               VARCHAR2(100) NOT NULL,
    email                   VARCHAR2(255) NOT NULL UNIQUE,
    phone_number            VARCHAR2(30) NOT NULL UNIQUE,
    dob                     DATE NOT NULL,
    government_id           VARCHAR2(100) NOT NULL,
    role                    VARCHAR2(20) NOT NULL CHECK (role IN ('CUSTOMER', 'TELLER', 'ADMIN')),
    password_hash           VARCHAR2(255) NOT NULL,
    pin_hash                VARCHAR2(255),
    max_concurrent_sessions NUMBER(3) DEFAULT 3 NOT NULL,
    failed_login_attempts   NUMBER(3) DEFAULT 0 NOT NULL,
    status                  VARCHAR2(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'LOCKED', 'SUSPENDED')),
    created_at              TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at              TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

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

-- 4. Transactions Table (Includes Dual-Control Metadata)
CREATE TABLE transactions (
    transaction_id         VARCHAR2(64) PRIMARY KEY,
    from_account_id        VARCHAR2(64) NOT NULL,
    to_account_id          VARCHAR2(64),
    type                   VARCHAR2(30) NOT NULL,
    amount                 NUMBER(18, 4) NOT NULL CHECK (amount > 0),
    before_balance         NUMBER(18, 4) NOT NULL,
    after_balance          NUMBER(18, 4) NOT NULL,
    status                 VARCHAR2(30) NOT NULL CHECK (status IN ('PENDING_APPROVAL', 'COMMITTED', 'FAILED')),
    requires_maker_checker NUMBER(1) DEFAULT 0 NOT NULL,
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
    CONSTRAINT chk_oe_aggregate_type CHECK (aggregate_type IN ('TRANSACTION', 'MAKER_CHECKER', 'BALANCE_MUTATION')),
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
Host: `localhost:5433` (container port `5432`), Database: `banking_audit`, User: `audit_user`, Password: `audit_password`

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

---

## 4. Core Balance Mutation Engine (CME) and dual control

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
           +---------------------------------------+
           |                                       |
Amount <= 50,000 PHP                     Amount > 50,000 PHP
(Normal Transfer)                        (High-Value Dual Control)
           |                                       |
           v                                       v
[Atomic Immediate Settlement]            [Place Soft Hold on Sender]
- Deduct sender balance & avail          - hold_amount += amount
- Credit receiver balance & avail        - available_balance -= amount
- Tx status: COMMITTED                   - balance_amount untouched
- Write outbox: banking.transfers.events - Tx status: PENDING_APPROVAL
- Write Postgres audit log               - Write outbox: banking.makerchecker.pending
                                                   |
                                                   v
                                        [Teller / Checker Review]
                                                   |
                         +-------------------------+-------------------------+
                         |                                                   |
                     [Approve]                                           [Reject]
                         |                                                   |
           [Enforce Segregation of Duties]                     [Enforce Segregation of Duties]
           (checkerUserId != makerUserId)                      (checkerUserId != makerUserId)
                         |                                                   |
                         v                                                   v
           [Release Hold & Commit Settlement]                  [Release Hold & Restore Available]
           - sender hold_amount -= amount                      - sender hold_amount -= amount
           - sender balance_amount -= amount                   - sender available_balance += amount
           - receiver balance_amount += amount                 - Tx status: FAILED
           - receiver available_balance += amount              - Tx status: REJECTED
           - Tx status: COMMITTED
           - Write outbox: banking.transfers.events
           - Write Postgres audit log
```

### Key API endpoints

1. **Initiate mutation or transfer**:
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

2. **Approve high-value transfer**:
   `POST /api/v1/ledger/approve`
   ```json
   {
     "transactionId": "TX-100293",
     "checkerUserId": "usr-1003-tel-001",
     "remarks": "Verified customer identity and source of funds"
   }
   ```

3. **Reject high-value transfer**:
   `POST /api/v1/ledger/reject`
   ```json
   {
     "transactionId": "TX-100293",
     "checkerUserId": "usr-1003-tel-001",
     "remarks": "Signature mismatch"
   }
   ```

4. **Query pending maker-checker queue**:
   `GET /api/v1/ledger/pending`

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

2. **`banking.makerchecker.pending`** (3 partitions, replication factor 1):
   - Key: `transactionId`.
   - Payload: Pending transaction metadata requiring secondary checker approval.

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
   - Straight-Through Processing (STP) with no manager review required.
   - Dual email delivery: Inward debit receipt sent to sender, outward credit advice (`inward-credit-advice.html`) sent to beneficiary.
   - Real-time browser toast delivered over Server-Sent Events (SSE).

2. **Tier 2 (Dual-control hold, PHP 50,000.01 to PHP 499,999.99)**:
   - Requires Branch Operations Officer (Level 1) approval.
   - Manager compliance alert email (`maker-checker-alert.html`) dispatched.
   - Hold notification pushed to customer browser.

3. **Tier 3 (AMLA covered, >= PHP 500,000.00)**:
   - Covered transaction under AMLA regulations. Requires Covered Transaction Report (CTR) filing and dual manager authorization.
   - High-value advisory sent to Compliance Officer inbox (`compliance-officer@corebank.ph`).

### Resilient offline spooling
If the SMTP server is unavailable, messages are automatically buffered in an in-memory circuit spool buffer. Once connectivity is restored, calling `POST /api/v1/notifications/flush-spool` drains the buffer and delivers all queued notices.

---

## 7. Frontend web application (React 18 + Vite)

The Single-Page Application (`frontend/`) provides an interactive interface for customers, branch staff, and system administrators:

- **Customer Terminal**: Real-time balance cards, quick preset transfer amounts, regulatory tier calculation, and instant mutation responses.
- **Branch Teller Terminal**: Pending Maker-Checker queue, segregation of duties validator, secondary checker authorization actions, and scenario simulators.
- **Admin & Telemetry Grid**: 10-service health monitor, circuit spool recovery controls, and Oracle notification audit viewer.
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

### Step 1: Start infrastructure containers
Run from the repository root:

```powershell
docker compose -f infrastructure/docker-compose.yml up -d
```

This starts:
- Oracle XE 21c (`localhost:1521`)
- PostgreSQL 16 Audit Vault (`localhost:5433`)
- Redis 7 (`localhost:6379`)
- Apache Kafka KRaft (`localhost:9092`)
- Kafka UI (`localhost:8085`)
- MailHog Mock SMTP (`localhost:8025` UI, `localhost:1025` SMTP)
- Adminer Database Console (`localhost:8088`)
- Datadog Agent 7 (`localhost:8126` APM / `localhost:4318` OTLP / `localhost:8125` DogStatsD)

### Step 2: Build and test backend microservices
Run from the `backend/` directory:

```powershell
cd backend
.\mvnw.cmd clean test
```

Expected result:
```text
[INFO] Reactor Summary for Core Retail Ledger & Balance Mutation Engine (Parent) 1.0.0-SNAPSHOT:
[INFO] 
[INFO] Core Retail Ledger & Balance Mutation Engine (Parent) SUCCESS
[INFO] Common Contracts & DTOs ............................ SUCCESS
[INFO] Ledger Mutation Engine ............................. SUCCESS
[INFO] Account Service .................................... SUCCESS
[INFO] gateway-service .................................... SUCCESS
[INFO] Notification & Alert Service ....................... SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
```

### Step 3: Run backend microservices locally

Start services in separate terminal windows:

```powershell
# Window 1: API Gateway Service (:8080)
cd backend/gateway-service
..\mvnw.cmd spring-boot:run

# Window 2: Account Service (:8081)
cd backend/account-service
..\mvnw.cmd spring-boot:run

# Window 3: Ledger Mutation Engine (:8082)
cd backend/ledger-mutation-engine
..\mvnw.cmd spring-boot:run

# Window 4: Notification Service (:8083)
cd backend/notification-service
..\mvnw.cmd spring-boot:run
```

### Step 4: Run frontend application

Run from the `frontend/` directory:

```powershell
cd frontend
npm install
npm run dev
```

Access the application in your browser at **[http://localhost:3000](http://localhost:3000)**.

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
│   ├── docker-compose.yml              # Multi-container orchestration (10 containers)
│   ├── adminer/
│   │   ├── Dockerfile                  # Adminer with Oracle Instant Client 21 & OCI8
│   │   ├── basic_lite.zip              # Pre-bundled Oracle Instant Client package
│   │   └── oci8.so                     # Pre-compiled PHP OCI8 module
│   ├── oracle/
│   │   └── init.sql                    # Oracle XE 21c DDL, outbox table, and seed data
│   ├── postgres/
│   │   └── init.sql                    # PostgreSQL audit DDL, trigger, and seed data
│   └── datadog/                        # Datadog Agent 7 configuration (APM, OTLP traces, logs)
├── frontend/                           # React 18 + Vite Web SPA
│   ├── package.json                    # Frontend dependencies & scripts
│   ├── vite.config.js                  # Vite server & Gateway proxy configuration
│   ├── tailwind.config.js              # Tailwind utility classes & theme
│   └── src/
│       ├── api/
│       │   └── client.js               # Axios services for CME & Notification APIs
│       └── components/
│           ├── Header.jsx              # Navigation header, role switcher & SSE badge
│           ├── CustomerPortal.jsx      # Customer transfer terminal & balance cards
│           ├── TellerPortal.jsx        # Dual-control approvals & simulation triggers
│           └── AdminPortal.jsx         # Service health matrix & spool buffer monitor
└── backend/
    ├── pom.xml                         # Aggregator POM (Spring Boot 3.3.5, Java 21)
    ├── common-contracts/               # Shared DTOs, enums, events, and exceptions
    ├── gateway-service/                # Spring Cloud Gateway, JWT verification, rate limiter
    ├── account-service/                # KYC onboarding, account provisioning, token rotation
    ├── ledger-mutation-engine/         # Core Mutation Engine (CME), locks, outbox worker
    └── notification-service/           # Kafka consumer, dual advices, spool buffer, SSE
```

---

## 11. Team contribution and branching guidelines

1. Work on dedicated feature branches branched off `main` (for example, `jm-branch`, `zel-branch`).
2. Commit messages should follow conventional commits: `feat:`, `fix:`, `refactor:`, `chore:`.
3. Never bypass financial check constraints or tamper with the append-only PostgreSQL trigger.
4. Ensure all unit and integration tests pass before submitting pull requests to `main`.
