# FSE Capstone: Core Retail Ledger & Balance Mutation Platform

Group 3 Engineering Repository: Definitive Architecture, Schemas, and Developer Source of Truth.

---

## 1. System Architecture and Core Principles

The platform is a high-throughput, event-driven, dual-storage retail banking system with Maker-Checker transaction verification, deterministic concurrency locking, Kafka KRaft event streaming, and immutable audit logging.

<img width="2151" height="887" alt="image" src="https://github.com/user-attachments/assets/b97a1f35-c952-4e9a-8b2c-d638de9deff5" />

```
                                  +-----------------------+
                                  |   Web SPA Frontend    |
                                  |      (Port 3000)      |
                                  +-----------+-----------+
                                              |
                                              v
                              +-------------------------------+
                              |      API Gateway Service      |
                              |   (Port 8080 / Redis Limiter) |
                              +-------+---------------+-------+
                                      |               |
              /api/v1/auth, /accounts |               | /api/v1/ledger, /notifications
                                      v               v
               +--------------------------+       +------------------------------+
               |      Account Service     |       |   Ledger Mutation Engine     |
               |        (Port 8081)       |       |        (Port 8082)           |
               +------------+-------------+       +-------+--------------+-------+
                            |                             |              |
             HikariCP       v              HikariCP (30)  v              v HikariCP (30)
                 +--------------------+     +-------------------+   +--------------------+
                 | Oracle XE Master   |     | Oracle XE Master  |   | PostgreSQL Audit   |
                 | (Operational State)|     | (Row Locks / CME) |   | (Append-Only Log)  |
                 |    (Port 1521)     |     |    (Port 1521)    |   |    (Port 5432)     |
                 +--------------------+     +-------------------+   +--------------------+
                                                          |
                                                 Kafka    v Event Streaming
                                            +---------------------------+
                                            | Apache Kafka KRaft Broker |
                                            |   Topics: transactions,   |
                                            |    alerts, audit-events   |
                                            |        (Port 9092)        |
                                            +---------------------------+
                                                          |
                                                          v
                                            +---------------------------+
                                            |   Notification Service    |
                                            |        (Port 8083)        |
                                            +---------------------------+
```

### Architectural Principles

1. **Dual-Storage Isolation**:
   - **Oracle XE 21c**: Manages operational state and concurrency via pessimistic row locking (`SELECT ... FOR UPDATE`).
   - **PostgreSQL 16**: Serves as a compliance audit vault. A database trigger rejects any SQL `UPDATE` or `DELETE` statements on `ledger_mutation_audit`.

2. **Strict Financial Precision**:
   All monetary amounts across databases, DTOs, and REST payloads use eighteen total digits with four decimal places (`NUMBER(18, 4)` in Oracle, `NUMERIC(18, 4)` in PostgreSQL, and `BigDecimal` with `RoundingMode.UNNECESSARY` in Java). Floating-point data types (`FLOAT`, `DOUBLE`) are strictly forbidden.

3. **Deterministic Lock Ordering (Deadlock Prevention)**:
   When moving funds between two accounts, the engine sorts account IDs lexicographically (`sourceId.compareTo(targetId) < 0 ? sourceId : targetId`). The account with the lower ID is always locked first, guaranteeing that concurrent opposing transfers (A to B and B to A) acquire locks in the exact same sequence.

4. **Maker-Checker Dual Control (BSP Compliance)**:
   - Transfers at or below PHP 50,000.00 execute immediate atomic settlement.
   - Transfers exceeding PHP 50,000.00 place a soft hold on the sender's available balance and enter `PENDING_APPROVAL`.
   - A distinct authorized officer (teller or manager) must review and approve or reject the request. The initiator (maker) cannot approve or reject their own transaction.

5. **Event-Driven Asynchronous Streaming**:
   Committed transfers and alerts emit events to Apache Kafka in KRaft mode, allowing downstream processors to dispatch push alerts without delaying transaction response times.

6. **Observability and Distributed Tracing**:
   Every HTTP request carries W3C trace context headers (`traceparent`). Traces are exported over OTLP to Jaeger, and metrics are scraped by Prometheus to populate a Grafana operational dashboard.

---

## 2. Networking and Port Allocation Matrix

Every container attaches to the bridge network `banking-net`. Host and internal port allocations are configured as follows:

| Service / Container | Container Name | Host Port | Internal Port | Protocol | Purpose |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **Frontend Web SPA** | `frontend` | `3000` | `3000` | HTTP | React 18 + Vite Retail Banking Portal |
| **API Gateway** | `gateway-service` | `8080` | `8080` | HTTP / REST | Perimeter routing, JWT signature validation, Redis rate limiting |
| **Account Service** | `account-service` | `8081` | `8081` | HTTP / REST | KYC onboarding, user profiles, account creation, token rotation |
| **Ledger Engine** | `ledger-mutation-engine`| `8082` | `8082` | HTTP / REST | Concurrency locks, balance mutations, maker-checker, Kafka producer |
| **Notification Service** | `notification-service` | `8083` | `8083` | HTTP / REST | Kafka listener, receipt generation, manager alerts, email dispatch |
| **MailHog Mock SMTP** | `mailhog-smtp` | `8025` / `1025` | `8025` / `1025` | HTTP / SMTP | Mock email testing inbox UI (`:8025`) and SMTP receiver (`:1025`) |
| **Oracle Database XE** | `oracle-xe-master` | `1521` | `1521` | Oracle TNS | Operational relational state (`XEPDB1`) |
| **PostgreSQL Audit** | `postgres-audit-vault`| `5433` | `5432` | PostgreSQL | Dedicated append-only audit vault (`banking_audit`) |
| **Redis Cache** | `redis-cache` | `6379` | `6379` | RESP / TCP | Token blacklist, session cache, Redis rate limiting counters |
| **Kafka Broker** | `kafka-broker` | `9092` | `9092` | PLAINTEXT | Apache Kafka KRaft cluster event commit log |
| **Kafka UI** | `kafka-ui` | `8085` | `8080` | HTTP | Web console for topics, consumer groups, and message inspection |
| **Adminer Web GUI** | `db-adminer` | `8088` | `8080` | HTTP | Web database management console for Oracle and PostgreSQL |
| **Jaeger Tracing** | `jaeger-tracing` | `16686` | `16686` | HTTP | Distributed trace visualization UI (OTLP receiver on `:4318`) |
| **Prometheus** | `prometheus-engine` | `9090` | `9090` | HTTP | Time-series scraper collecting `/actuator/prometheus` metrics |
| **Grafana** | `grafana-dashboard` | `3001` | `3000` | HTTP | Operational telemetry dashboards and KPI visualizations |

---

## 3. Database Schemas and Data Models

### A. Master Operational Database (Oracle Database XE 21c)
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
```

### B. Immutable Audit Vault (PostgreSQL 16)
Host: `localhost:5432`, Database: `banking_audit`, User: `audit_user`, Password: `audit_password`

```sql
CREATE TABLE ledger_mutation_audit (
    audit_id            BIGSERIAL PRIMARY KEY,
    transaction_id      VARCHAR(64) NOT NULL,
    account_id          VARCHAR(64) NOT NULL,
    mutation_type       VARCHAR(30) NOT NULL,
    mutation_amount     NUMERIC(18, 4) NOT NULL,
    before_balance      NUMERIC(18, 4) NOT NULL,
    after_balance       NUMERIC(18, 4) NOT NULL,
    initiator_user_id   VARCHAR(64) NOT NULL,
    approved_by_user_id VARCHAR(64),
    status              VARCHAR(30) NOT NULL,
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
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

## 4. Core Balance Mutation Engine (CME) and Dual Control

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
- Emit Kafka TransactionEvent            - Tx status: PENDING_APPROVAL
- Write Postgres audit log               - Emit Kafka Pending Alert
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
           - receiver available_balance += amount              - Emit Kafka Rejection Alert
           - Tx status: COMMITTED
           - Emit Kafka TransactionEvent
           - Write Postgres audit log
```

### Key API Endpoints

1. **Initiate Transfer**:
   `POST /api/v1/ledger/transfer`
   ```json
   {
     "transactionId": "TX-100293",
     "accountId": "acc-2001-sav-001",
     "targetAccountId": "acc-2003-sav-002",
     "eventType": "TRANSFER",
     "mutationType": "TRANSFER",
     "mutationAmount": 65000.0000,
     "initiatorUserId": "usr-1001-cst-001"
   }
   ```

2. **Approve High-Value Transfer**:
   `POST /api/v1/ledger/transfers/{transactionId}/approve`
   ```json
   {
     "checkerUserId": "usr-1003-tel-001",
     "remarks": "Verified customer identity and source of funds"
   }
   ```

3. **Reject High-Value Transfer**:
   `POST /api/v1/ledger/transfers/{transactionId}/reject`
   ```json
   {
     "checkerUserId": "usr-1003-tel-001",
     "remarks": "Signature mismatch"
   }
   ```

4. **Query Pending Maker-Checker Queue**:
   `GET /api/v1/ledger/transfers/pending`

---

## 5. Apache Kafka Event Streaming

The platform uses Apache Kafka 7.5 running in KRaft mode (ZooKeeper-free) for asynchronous event dispatch:

### Kafka Topics

1. **`transaction-events`** (3 partitions, replication factor 1):
   - Key: `sourceAccountId` (guarantees FIFO sequence for transactions per account).
   - Payload: `TransactionEvent` with transaction ID, accounts, amount, currency, status, and timestamp.

2. **`notification-alerts`** (3 partitions, replication factor 1):
   - Key: `recipientAccountId`.
   - Payload: `NotificationAlertEvent` with alert ID, user ID, account ID, alert type, and human-readable message.

3. **`audit-events`** (3 partitions, replication factor 1):
   - Key: `transactionId`.
   - Payload: Compliance event stream for downstream reporting.

### Kafka Web UI
Navigate to **[http://localhost:8085](http://localhost:8085)** to inspect topics, offsets, consumer lag, and live message payloads.

---

## 6. Observability, Metrics, and Distributed Tracing

### Distributed Tracing (OpenTelemetry and Jaeger)
- Every microservice imports `micrometer-tracing-bridge-otel` and `opentelemetry-exporter-otlp`.
- Inbound and outbound requests propagate standard W3C `traceparent` headers.
- Traces are exported to the Jaeger OTLP receiver at `http://localhost:4318/v1/traces`.
- View trace graphs and latency spans in the Jaeger UI at **[http://localhost:16686](http://localhost:16686)**.

### Metrics Collection (Prometheus)
- Each service exposes metrics at `/actuator/prometheus`.
- Prometheus scrapes metrics every 5 seconds.
- Access the Prometheus console at **[http://localhost:9090](http://localhost:9090)**.

### Operational Dashboard (Grafana)
Grafana automatically provisions Prometheus and Jaeger datasources on startup, loading the **FSE Core Retail Banking - Telemetry & Performance** dashboard.
- URL: **[http://localhost:3000](http://localhost:3000)** (Anonymous viewer enabled, or login with `admin` / `admin`).
- Panels include:
  - System Health status badges and global throughput (req/s).
  - HTTP 5xx error percentage and P95 latency.
  - Gateway ingress traffic by route and status code distribution.
  - Account Service and Ledger Mutation Engine endpoint throughput.
  - HikariCP active vs idle connections and connection acquire times.
  - JVM heap memory usage, garbage collection pause times, CPU percentage, and active threads.

---

## 7. Developer Quick Start Guide

### Prerequisites
1. **Docker Desktop** (version 4.25+).
2. **Java 21 JDK** (configured in your `PATH`).
3. **Maven** (bundled `.\mvnw.cmd` included in the repository).

### Step 1: Start All Infrastructure Services
Run from the repository root:

```powershell
docker compose -f infrastructure/docker-compose.yml up -d
```

This starts:
- Oracle XE 21c (`localhost:1521`)
- PostgreSQL 16 (`localhost:5432`)
- Redis 7 (`localhost:6379`)
- Apache Kafka KRaft (`localhost:9092`)
- Kafka UI (`localhost:8085`)
- Adminer Database Console (`localhost:8088`)
- Jaeger Distributed Tracing (`localhost:16686`)
- Prometheus Scraper (`localhost:9090`)
- Grafana Dashboard (`localhost:3000`)

### Step 2: Verify Container Health
```powershell
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Step 3: Build and Test All Backend Microservices
Run from the `backend/` directory:

```powershell
cd backend
.\mvnw.cmd clean test
```

Expected result:
```text
[INFO] Reactor Summary for Core Retail Ledger & Balance Mutation Engine (Parent) 1.0.0-SNAPSHOT:
[INFO] Core Retail Ledger & Balance Mutation Engine (Parent) SUCCESS
[INFO] Common Contracts & DTOs ............................ SUCCESS
[INFO] Ledger Mutation Engine ............................. SUCCESS
[INFO] Account Service .................................... SUCCESS
[INFO] gateway-service .................................... SUCCESS
[INFO] BUILD SUCCESS
```

### Step 4: Run Microservices Locally

Start services in separate terminal windows:

```powershell
# Window 1: API Gateway
cd backend/gateway-service
..\mvnw.cmd spring-boot:run

# Window 2: Account Service
cd backend/account-service
..\mvnw.cmd spring-boot:run

# Window 3: Ledger Mutation Engine
cd backend/ledger-mutation-engine
..\mvnw.cmd spring-boot:run
```

---

## 8. Repository Structure

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
│   │   └── init.sql                    # Oracle XE 21c DDL, constraints, and seed data
│   ├── postgres/
│   │   └── init.sql                    # PostgreSQL audit DDL, trigger, and seed data
│   ├── prometheus/
│   │   ├── prometheus.yml              # Prometheus scraper configuration (5s interval)
│   │   └── alert.rules.yml             # SLO alerting rules (5xx rate, latency, memory)
│   └── grafana/
│       ├── provisioning/
│       │   ├── datasources/datasources.yml # Auto-provisioned Prometheus & Jaeger datasources
│       │   └── dashboards/dashboards.yml   # Dashboard provider configuration
│       └── dashboards/
│           └── banking-core-observability.json # 20-panel telemetry dashboard
└── backend/
    ├── pom.xml                         # Aggregator POM (Spring Boot 3.3.5, Java 21)
    ├── common-contracts/               # Shared DTOs, enums, events, and exceptions
    ├── gateway-service/                # Spring Cloud Gateway, JWT verification, rate limiter
    ├── account-service/                # KYC onboarding, account provisioning, token rotation
    └── ledger-mutation-engine/         # Core Mutation Engine (CME), locks, Kafka, audit
```

---

## 9. Team Contribution and Branching Guidelines

1. Work on dedicated feature branches branched off `main` (for example, `jm-branch`, `zel-branch`).
2. Commit messages should follow conventional commits: `feat:`, `fix:`, `refactor:`, `chore:`.
3. Never bypass financial check constraints or tamper with the append-only PostgreSQL trigger.
4. Ensure all unit and integration tests pass before submitting pull requests to `main`.
