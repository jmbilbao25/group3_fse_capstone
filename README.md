# FSE Capstone: Core Retail Ledger & Balance Mutation Platform

Group 3 Engineering Repository: Definitive Architecture, Schemas, and Developer Source of Truth.

---

## 1. System Architecture & Topology

The platform provides a high-throughput, event-driven, dual-storage retail banking system with Maker-Checker transaction verification, optimistic and pessimistic locking, and immutable audit logging.

<img width="2198" height="1142" alt="image" src="https://github.com/user-attachments/assets/cd50822f-6c14-4d43-9a2f-01e3f62adff3" />


### Architectural Principles
- **Dual-Storage Isolation**: Oracle XE 21c handles operational state and row locking (`SELECT ... FOR UPDATE`), while PostgreSQL 16 serves exclusively as an immutable, append-only compliance audit vault.
- **Strict Financial Precision**: All currency amounts across databases and APIs use eighteen total digits with four decimal places (`NUMBER(18, 4)` and `NUMERIC(18, 4)`). Floating-point types are strictly forbidden.
- **Pool Isolation**: In services communicating with multiple databases, each datasource maintains an isolated HikariCP connection pool sized to 30 maximum connections and 5 minimum idle connections.
- **Idempotency & Concurrency**: Double-spend attempts are blocked in memory via Redis idempotency keys (`SET NX EX 60`) and serialized at the database tier via pessimistic write locks.

---

## 2. Complete Networking & Port Allocation Matrix

Every container attaches to the bridge network `banking-net`. Host and internal port allocations are deterministic:

| Service / Container | Container Name | Host Port | Internal Port | Protocol | Purpose |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **Frontend SPA** | `banking-frontend` | `3000` | `80` / `3000` | HTTP | React 18 customer, teller, and admin portals |
| **API Gateway** | `gateway-service` | `8080` | `8080` | HTTP / REST | Perimeter routing, JWT validation, rate limiting |
| **Account Service** | `account-service` | `8081` | `8081` | HTTP / REST | KYC onboarding, user profiles, account creation |
| **Ledger Engine** | `ledger-mutation-engine`| `8082` | `8082` | HTTP / REST | Concurrency locks, balance mutations, outbox relay |
| **Notification Service** | `notification-service` | `8083` | `8083` | HTTP / REST | Event consumer, push alerts, transaction receipts |
| **Redis Cache** | `redis-cache` | `6379` | `6379` | RESP / TCP | Token blacklist, idempotency locks, session store |
| **Oracle Database XE** | `oracle-xe-master` | `1521` | `1521` | Oracle TNS | Operational relational state (`XEPDB1`) |
| **PostgreSQL Audit** | `postgres-audit-vault`| `5432` | `5432` | PostgreSQL | Dedicated append-only audit trail (`banking_audit`) |
| **Kafka Broker** | `kafka-broker` | `9092` | `9092` | PLAINTEXT | Event commit log in KRaft mode |
| **Kafka UI** | `kafka-ui` | `8085` | `8080` | HTTP | Web console for topics and consumer lag inspection |
| **Adminer Web GUI** | `db-adminer` | `8088` | `8080` | HTTP | Web database management console for visual table inspection |

---

## 3. Database Schemas & Data Model

### A. Master Operational Database (Oracle Database XE 21c)
Host: `localhost:1521`, Pluggable Database: `XEPDB1`, User: `fse_user`

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

-- 4. Credit Assessments Table
CREATE TABLE credit_assessments (
    assessment_id              VARCHAR2(64) PRIMARY KEY,
    account_id                 VARCHAR2(64) NOT NULL,
    user_id                    VARCHAR2(64) NOT NULL,
    collateral_type            VARCHAR2(50) NOT NULL CHECK (collateral_type IN ('REAL_ESTATE', 'VEHICLE', 'TIME_DEPOSIT')),
    collateral_description     CLOB NOT NULL,
    collateral_market_value    NUMBER(18, 4) NOT NULL,
    collateral_appraised_value NUMBER(18, 4) NOT NULL,
    credit_score               NUMBER(4) NOT NULL CHECK (credit_score BETWEEN 300 AND 850),
    approved_credit_limit      NUMBER(18, 4) NOT NULL,
    risk_tier                  VARCHAR2(20) NOT NULL CHECK (risk_tier IN ('LOW_RISK', 'MEDIUM_RISK', 'HIGH_RISK')),
    assessed_by_teller_id      VARCHAR2(64) NOT NULL,
    status                     VARCHAR2(20) DEFAULT 'PENDING' NOT NULL CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    created_at                 TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at                 TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_ca_account FOREIGN KEY (account_id) REFERENCES accounts(account_id),
    CONSTRAINT fk_ca_user FOREIGN KEY (user_id) REFERENCES users(user_id),
    CONSTRAINT fk_ca_teller FOREIGN KEY (assessed_by_teller_id) REFERENCES users(user_id)
);

-- 5. Transactions Table
CREATE TABLE transactions (
    transaction_id         VARCHAR2(64) PRIMARY KEY,
    from_account_id        VARCHAR2(64) NOT NULL,
    to_account_id          VARCHAR2(64),
    type                   VARCHAR2(30) NOT NULL CHECK (type IN ('DEPOSIT', 'WITHDRAWAL', 'TRANSFER', 'CREDIT_DRAW')),
    amount                 NUMBER(18, 4) NOT NULL CHECK (amount > 0),
    before_balance         NUMBER(18, 4) NOT NULL,
    after_balance          NUMBER(18, 4) NOT NULL,
    status                 VARCHAR2(30) NOT NULL CHECK (status IN ('PENDING_APPROVAL', 'COMMITTED', 'FAILED')),
    requires_maker_checker NUMBER(1) DEFAULT 0 NOT NULL CHECK (requires_maker_checker IN (0, 1)),
    approved_by_user_id    VARCHAR2(64),
    created_at             TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at             TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_tx_from_acc FOREIGN KEY (from_account_id) REFERENCES accounts(account_id),
    CONSTRAINT fk_tx_to_acc FOREIGN KEY (to_account_id) REFERENCES accounts(account_id),
    CONSTRAINT fk_tx_approver FOREIGN KEY (approved_by_user_id) REFERENCES users(user_id)
);

-- 6. Outbox Events Table (Transactional Outbox Pattern)
CREATE TABLE outbox_events (
    event_id       VARCHAR2(64) PRIMARY KEY,
    aggregate_type VARCHAR2(50) NOT NULL CHECK (aggregate_type IN ('TRANSACTION', 'MAKER_CHECKER', 'BALANCE_MUTATION')),
    aggregate_id   VARCHAR2(64) NOT NULL,
    event_type     VARCHAR2(50) NOT NULL CHECK (event_type IN ('MAKER_PENDING', 'CHECKER_APPROVED', 'MUTATION_COMMITTED')),
    kafka_topic    VARCHAR2(100) NOT NULL,
    payload        CLOB NOT NULL,
    status         VARCHAR2(20) DEFAULT 'PENDING' NOT NULL CHECK (status IN ('PENDING', 'PUBLISHED', 'FAILED')),
    retry_count    NUMBER(4) DEFAULT 0 NOT NULL,
    created_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    published_at   TIMESTAMP WITH TIME ZONE,
    CONSTRAINT fk_oe_aggregate FOREIGN KEY (aggregate_id) REFERENCES transactions(transaction_id)
);

-- 7. Notifications Table
CREATE TABLE notifications (
    notification_id VARCHAR2(64) PRIMARY KEY,
    user_id         VARCHAR2(64) NOT NULL,
    type            VARCHAR2(50) NOT NULL CHECK (type IN ('TRANSACTION_ALERT', 'SECURITY_ALERT', 'MAKER_CHECKER_ALERT')),
    message         CLOB NOT NULL,
    sent_at         TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- Note: Authentication session tokens, concurrent limits, and token revocation blacklists
-- are managed in Redis (redis-cache) rather than relational tables.
```

### B. Dedicated Immutable Audit Vault (PostgreSQL 16)
Host: `localhost:5432`, Database: `banking_audit`, User: `audit_user`

```sql
CREATE TABLE ledger_mutation_audit (
    audit_id             BIGSERIAL PRIMARY KEY,
    transaction_id       VARCHAR(64) UNIQUE NOT NULL,
    account_id           VARCHAR(64) NOT NULL,
    mutation_type        VARCHAR(20) NOT NULL CHECK (mutation_type IN ('DEBIT', 'CREDIT', 'HOLD', 'RELEASE')),
    mutation_amount      NUMERIC(18, 4) NOT NULL CHECK (mutation_amount > 0),
    before_balance       NUMERIC(18, 4) NOT NULL CHECK (before_balance >= 0),
    after_balance        NUMERIC(18, 4) NOT NULL CHECK (after_balance >= 0),
    initiator_user_id    VARCHAR(64) NOT NULL,
    approved_by_user_id  VARCHAR(64),
    status               VARCHAR(20) DEFAULT 'COMMITTED' NOT NULL CHECK (status IN ('COMMITTED', 'FAILED', 'ROLLED_BACK')),
    created_at           TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Native trigger strictly rejecting UPDATE and DELETE
CREATE OR REPLACE FUNCTION prevent_audit_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Compliance Violation: ledger_mutation_audit is strictly append-only. UPDATE and DELETE operations are forbidden.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_no_update_delete_mutation_audit
BEFORE UPDATE OR DELETE ON ledger_mutation_audit
FOR EACH ROW EXECUTE FUNCTION prevent_audit_modification();
```

---

## 4. Connection Pooling Standards (HikariCP)

In `backend/ledger-mutation-engine/src/main/resources/application.properties`, two isolated connection pools operate side by side:

```properties
# ==============================================================================
# PRIMARY POOL: ORACLE MASTER OPERATIONAL STATE
# ==============================================================================
spring.datasource.oracle.jdbc-url=jdbc:oracle:thin:@//localhost:1521/XEPDB1
spring.datasource.oracle.username=fse_user
spring.datasource.oracle.password=fse_password
spring.datasource.oracle.driver-class-name=oracle.jdbc.OracleDriver

spring.datasource.oracle.hikari.pool-name=OracleMasterHikariPool
spring.datasource.oracle.hikari.maximum-pool-size=30
spring.datasource.oracle.hikari.minimum-idle=5
spring.datasource.oracle.hikari.idle-timeout=300000
spring.datasource.oracle.hikari.connection-timeout=20000
spring.datasource.oracle.hikari.max-lifetime=1200000
spring.datasource.oracle.hikari.auto-commit=false
spring.datasource.oracle.hikari.connection-test-query=SELECT 1 FROM DUAL

# ==============================================================================
# SECONDARY POOL: POSTGRESQL IMMUTABLE AUDIT VAULT
# ==============================================================================
spring.datasource.postgres.jdbc-url=jdbc:postgresql://localhost:5432/banking_audit
spring.datasource.postgres.username=audit_user
spring.datasource.postgres.password=audit_password
spring.datasource.postgres.driver-class-name=org.postgresql.Driver

spring.datasource.postgres.hikari.pool-name=PostgresAuditHikariPool
spring.datasource.postgres.hikari.maximum-pool-size=30
spring.datasource.postgres.hikari.minimum-idle=5
spring.datasource.postgres.hikari.idle-timeout=300000
spring.datasource.postgres.hikari.connection-timeout=20000
spring.datasource.postgres.hikari.max-lifetime=1200000
spring.datasource.postgres.hikari.auto-commit=false
spring.datasource.postgres.hikari.connection-test-query=SELECT 1
```

### Operational Invariants
- `maximum-pool-size=30`: Caps active database connections to avoid exhausting database system memory during high-volume spikes.
- `minimum-idle=5`: Maintains 5 warm connections at all times for sub-millisecond checkout latency.
- `connection-timeout=20000`: Protects worker threads from hanging indefinitely when pools are saturated.

---

## 5. Local Setup & Quick Start Guide

### Prerequisites
1. **Docker Desktop** (version 4.25+, WSL2 engine enabled on Windows).
2. **Git** (configured with your name and email).
3. **Java 21 JDK** (for running backend Spring Boot services).
4. **Node.js 18+ and npm** (for running the React frontend).

### Corporate Proxy / SSL Inspection Resolution
If running behind a corporate proxy or next-generation firewall (such as Bluecoat or Zscaler), `docker pull` commands might fail with a TLS handshake error. To fix this:
1. Export your root CA certificate from the Windows Certificate Store in Base64 PEM format.
2. Place the file at `%USERPROFILE%\.docker\certs.d\registry-1.docker.io\ca.crt` and `%USERPROFILE%\.docker\certs.d\auth.docker.io\ca.crt`.
3. Restart Docker Desktop.

### Step-by-Step Quick Start Tutorial

#### Step 1: Ensure Your Branch Is Up to Date
```powershell
git checkout jm-branch
git pull origin jm-branch
```

#### Step 2: Start All Infrastructure Services
Run this command from the repository root:

```powershell
# Start Oracle XE 21c, PostgreSQL 16, Redis 7, and Adminer Web Console
docker compose -f infrastructure/docker-compose.yml up -d --build
```

> [!NOTE]
> The `--build` flag automatically compiles the custom Adminer image with Oracle Instant Client 21 and the PHP `oci8` driver locally from `infrastructure/adminer/Dockerfile`. Team members do not need to pull any external custom images or install C libraries manually.

#### Step 3: Verify Running Container Health
```powershell
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Expected healthy output (all 4 containers active):
```text
NAMES                  STATUS                    PORTS
oracle-xe-master       Up 2 minutes (healthy)    0.0.0.0:1521->1521/tcp
postgres-audit-vault   Up 2 minutes (healthy)    0.0.0.0:5432->5432/tcp
redis-cache            Up 2 minutes              0.0.0.0:6379->6379/tcp
db-adminer             Up 2 minutes              0.0.0.0:8088->8080/tcp
```

#### Step 4: Open Adminer Web Console in Your Browser
Open your browser and navigate to:
👉 **[http://localhost:8088](http://localhost:8088)**

* **Oracle XE 21c (Master Operational Store)**:
  * Direct URL: **[http://localhost:8088/?oracle=](http://localhost:8088/?oracle=)**
  * System: `Oracle beta`
  * Server: `oracle-xe-master:1521/XEPDB1`
  * Username: `fse_user`
  * Password: `fse_password`
  * Database: Leave blank (or enter `USERS`)
  * *Navigation*: In the left sidebar, change **DB** from `XEPDB1` to **`USERS`**, then set **Schema** to **`FSE_USER`** to browse all 7 tables (`USERS`, `ACCOUNTS`, `BALANCE_MASTER`, `CREDIT_ASSESSMENTS`, `TRANSACTIONS`, `OUTBOX_EVENTS`, `NOTIFICATIONS`).

* **PostgreSQL 16 (Immutable Audit Vault)**:
  * Direct URL: **[http://localhost:8088/?pgsql=](http://localhost:8088/?pgsql=)**
  * System: `PostgreSQL`
  * Server: `postgres-audit-vault`
  * Username: `audit_user`
  * Password: `audit_password`
  * Database: `banking_audit`
  * *Navigation*: Select the `public` schema and click `ledger_mutation_audit`.

#### Step 5: (Optional) Re-execute Schemas & Seed Scripts
If containers were deleted or volumes wiped, the databases automatically seed from `init.sql`. To manually re-apply them:

```powershell
# Oracle XE 21c Pluggable Database (XEPDB1)
Get-Content infrastructure/oracle/init.sql | docker exec -i oracle-xe-master sqlplus fse_user/fse_password@//localhost:1521/XEPDB1

# PostgreSQL Audit Database (banking_audit)
Get-Content infrastructure/postgres/init.sql | docker exec -i postgres-audit-vault psql -U audit_user -d banking_audit
```

### Current Capstone Phase (Day 32)
This milestone delivers the complete architectural design, containerized dual-database infrastructure, strict schema DDL with mathematical sanity constraints, seeded test datasets, HikariCP connection pool configurations, and multi-module directory skeletons. Application feature code will be developed in subsequent implementation sprints.

---

## 6. Database Connection Reference

### Adminer Web Console (Unified Browser GUI)
- **Base URL**: [http://localhost:8088](http://localhost:8088)
- **Container**: `db-adminer` (Built from custom Dockerfile with Oracle Instant Client 21 and PHP OCI8)

#### Connecting to Oracle XE 21c (Master Operational Store)
- **Direct Login URL**: [http://localhost:8088/?oracle=](http://localhost:8088/?oracle=)
- **System**: `Oracle beta`
- **Server**: `oracle-xe-master:1521/XEPDB1`
- **Username**: `fse_user`
- **Password**: `fse_password`
- **Database**: Leave blank (or enter `USERS`)
- **Browsing Records**:
  1. Once logged in, locate the left sidebar navigation.
  2. Set **DB** to `USERS` (the tablespace holding your application data).
  3. Set **Schema** to `FSE_USER`.
  4. All 7 tables will appear: `USERS`, `ACCOUNTS`, `BALANCE_MASTER`, `CREDIT_ASSESSMENTS`, `TRANSACTIONS`, `OUTBOX_EVENTS`, and `NOTIFICATIONS`.
  5. Click **select** next to any table to view records, or click **SQL command** to run custom queries.

> [!NOTE]
> Always verify that the **System** dropdown is set to `Oracle beta` (or use `http://localhost:8088/?oracle=`). If the URL retains `?server=`, Adminer defaults to MySQL mode and will hang waiting for a MySQL handshake. Also ensure the service name is `XEPDB1` (the pluggable database), not `XE`.

#### Connecting to PostgreSQL 16 (Audit Vault)
- **Direct Login URL**: [http://localhost:8088/?pgsql=](http://localhost:8088/?pgsql=)
- **System**: `PostgreSQL`
- **Server**: `postgres-audit-vault` (or `postgres-audit-vault:5432`)
- **Username**: `audit_user`
- **Password**: `audit_password`
- **Database**: `banking_audit`
- **Browsing Records**:
  1. Once logged in, select the `public` schema.
  2. Click **select** on `ledger_mutation_audit` to inspect immutable audit events and trigger protection.

### PostgreSQL (Audit Vault CLI & External GUI)
- **CLI via Docker**:
  ```powershell
  docker exec -it postgres-audit-vault psql -U audit_user -d banking_audit
  ```
- **GUI Tools (DBeaver / DataGrip / pgAdmin)**:
  - Host: `localhost`
  - Port: `5432`
  - Database: `banking_audit`
  - Username: `audit_user`
  - Password: `audit_password`
  - JDBC URL: `jdbc:postgresql://localhost:5432/banking_audit`

### Oracle Database XE 21c (Master Store CLI & External GUI)
- **CLI via Docker (SQL\*Plus)**:
  ```powershell
  docker exec -it oracle-xe-master sqlplus fse_user/fse_password@//localhost:1521/XEPDB1
  ```
- **GUI Tools (DBeaver / SQL Developer / DataGrip)**:
  - Host: `localhost`
  - Port: `1521`
  - Connection Type: Service Name
  - Service Name: `XEPDB1`
  - Username: `fse_user` (or `system`)
  - Password: `fse_password` (or `Password123#`)
  - JDBC URL: `jdbc:oracle:thin:@//localhost:1521/XEPDB1`

---

## 7. Repository Structure

```text
.
├── .gitignore                          # Global exclusions (target, node_modules, logs)
├── README.md                           # Master source of truth and team onboarding guide
├── ARCHITECTURE.md                     # Comprehensive architecture and component specifications
├── architecture.html                   # Interactive standalone HTML architecture diagram
├── API_SPECIFICATION.md                # REST API specifications, DTOs, and error codes
├── api_sequence.html                   # Interactive sequence flow diagram
├── ERD.md                              # Entity-Relationship specifications and data dictionary
├── JIRA_BACKLOG.md                     # Sprint backlog, epic breakdowns, and EARS criteria
├── jira_backlog_fse_capstone.xlsx      # Sprint estimation spreadsheet
├── PROJECT_LAYOUT.md                   # Multi-module package and service directory guide
├── infrastructure/
│   ├── docker-compose.yml              # Container orchestration (Oracle, Postgres, Redis, Adminer)
│   ├── adminer/
│   │   └── Dockerfile                  # Custom Adminer image with Oracle Instant Client & OCI8
│   ├── oracle/
│   │   └── init.sql                    # Oracle XE 21c DDL, constraints, and seed records
│   └── postgres/
│       └── init.sql                    # PostgreSQL audit DDL, trigger, and seed records
├── backend/
│   ├── pom.xml                         # Aggregator POM (Spring Boot 3.3, Java 21)
│   ├── common-contracts/               # Shared DTOs, enums, and exceptions
│   ├── account-service/                # KYC, onboarding, and account management service
│   │   └── src/main/resources/application.properties
│   └── ledger-mutation-engine/         # Concurrency engine, dual-write service, HikariCP pools
│       └── src/main/resources/application.properties
├── frontend/                           # React 18 + Vite Retail Banking SPA
│   ├── package.json
│   ├── vite.config.js
│   └── src/                            # Portals: Customer, Teller, Administrator
└── specs/                              # Spec-Driven Development (SDD) requirements & designs
    ├── day32_requirements.md
    ├── day32_design.md
    └── day32_tasks.md
```

---

## 8. Team Contribution & Branching Strategy

1. Work on dedicated feature branches branched off `main` (for example, `jm-branch`).
2. Keep commit messages clear following conventional commits: `feat:`, `fix:`, `refactor:`, `chore:`.
3. Never bypass financial check constraints or modify the PostgreSQL audit trigger.
4. Ensure all unit and integration tests pass before submitting pull requests to `main`.
