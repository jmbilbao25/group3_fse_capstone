# Architecture Diagrams: Retail Ledger & Balance Mutation Engine

This document provides visual architectural models for the retail banking platform. It formalizes the system across the C4 model hierarchy (Context, Container, Component, and Sequence) and documents the dual-endpoint Temenos T24 Core Banking System (CBS) integration.

Interactive standalone HTML diagrams:
* Interactive C1–C4 Zoom-in Explorer: [`c_model_explorer.html`](file:///c:/Users/JLB83807/The%20Vault/workspaces/FSE-Capstone/c_model_explorer.html)
* C1 System Context Diagram: [`c1_system_context.html`](file:///c:/Users/JLB83807/The%20Vault/workspaces/FSE-Capstone/c1_system_context.html)
* C2 Container Diagram: [`c2_container.html`](file:///c:/Users/JLB83807/The%20Vault/workspaces/FSE-Capstone/c2_container.html)
* C3 Component Diagram: [`c3_component.html`](file:///c:/Users/JLB83807/The%20Vault/workspaces/FSE-Capstone/c3_component.html)
* C4 Sequence Diagram: [`c4_sequence.html`](file:///c:/Users/JLB83807/The%20Vault/workspaces/FSE-Capstone/c4_sequence.html)
* Primary System Showcase: [`architecture.html`](file:///c:/Users/JLB83807/The%20Vault/workspaces/FSE-Capstone/architecture.html)

---

## 1. System Context Diagram (C4 Level 1)

The system context diagram shows the core banking platform, user personas, external clearing networks, and the core Temenos T24 CBS with dual endpoints.

```mermaid
flowchart TD
    subgraph Users["User Personas"]
        Customer["Retail Customer<br/>(Web & Mobile Apps)"]
        Teller["Back-Office Operator<br/>(Telemetry & Audit Inspector)"]
        Admin["Compliance Admin<br/>(KYC & Policy Officer)"]
    end

    subgraph BankingSystem["Retail Banking Platform Boundary"]
        CorePlatform["FSE Retail Banking Platform<br/>(Gateway, Account Svc, Transfer Orchestrator)"]
    end

    subgraph CoreBanking["Core Banking System (CBS)"]
        T24CBS["Temenos T24 Core Banking System<br/>(Port :9100)"]
        T24_EP1["Endpoint 1: Funds Transfer<br/>POST /api/v1/t24/funds-transfer<br/>(OFS FUNDS.TRANSFER,AUTH)"]
        T24_EP2["Endpoint 2: Reversal<br/>POST /api/v1/t24/reversal<br/>(OFS FUNDS.TRANSFER,REVERSE)"]
        CBS_DB[("CBS Master Ledger DB<br/>Azure SQL Database :1433<br/>(Pessimistic balance locks)")]

        T24CBS --- T24_EP1
        T24CBS --- T24_EP2
        T24CBS <-->|"ACID postings & lock engine"| CBS_DB
    end

    subgraph ExternalSystems["External Integration Providers"]
        ClearingHouse["Inter-bank Clearing Network<br/>(InstaPay / PESONet)"]
        NotificationProviders["Email / SMS Gateways<br/>(MailHog / SendGrid / Twilio)"]
    end

    Customer -->|"Submits transfers & executes payments (HTTPS)"| CorePlatform
    Teller -->|"Monitors real-time telemetry & traces (HTTPS)"| CorePlatform
    Admin -->|"Reviews compliance & KYC audits (HTTPS)"| CorePlatform

    CorePlatform -->|"1. Dispatches debit/credit settlement"| T24_EP1
    CorePlatform -->|"2. Dispatches compensating reversal on failure"| T24_EP2

    CorePlatform -->|"Routes external settlements"| ClearingHouse
    CorePlatform -->|"Sends 2FA OTP codes & HTML transaction receipts"| NotificationProviders
```

---

## 2. Container Topology & Networking Architecture (C4 Level 2)

All containers run inside the dedicated Docker Compose bridge network (`banking-net`). External browser traffic enters through host port mappings, while inter-service communication uses internal container DNS names.

```mermaid
flowchart TD
    subgraph ClientTier["Presentation Tier"]
        ClientSPA["banking-frontend<br/>React 18, TypeScript, Vite<br/>Host: :3000 | Container: :80"]
    end

    subgraph PerimeterTier["Perimeter Security & Routing Tier"]
        Gateway["gateway-service<br/>Spring Cloud Gateway, Spring Security 6<br/>Host: :8080 | Container: :8080"]
        Redis["redis-cache<br/>Redis 7 Alpine<br/>Host: :6379 | Container: :6379"]
    end

    subgraph ServiceTier["Application Microservices Tier"]
        AccountSvc["account-service<br/>Spring Boot 3, Spring Data JPA<br/>Host: :8081 | Container: :8081"]
        Orchestrator["transfer-orchestrator<br/>Spring Boot 3, Saga Engine<br/>Host: :8082 | Container: :8082"]
        NotifSvc["notification-service<br/>Spring Boot 3, Kafka Consumer<br/>Host: :8083 | Container: :8083"]
    end

    subgraph CBSTier["Temenos T24 Core Banking System (:9100)"]
        T24CBS["temenos-t24-cbs<br/>Dual-Endpoint Core Banking Kernel"]
        T24EP1["EP1: /api/v1/t24/funds-transfer<br/>(Settlement)"]
        T24EP2["EP2: /api/v1/t24/reversal<br/>(Compensation)"]
        T24CBS --- T24EP1
        T24CBS --- T24EP2
    end

    subgraph StorageTier["Persistence & Ledger Data Tier"]
        AzureSQL[("azure-sql-db<br/>Azure SQL Database<br/>Host: :1433 | Port: :1433<br/>(CBS Master Ledger DB)")]
        AzurePostgres[("azure-postgres-vault<br/>PostgreSQL 16 Alpine<br/>Host: :5432 | Port: :5432<br/>(Immutable Audit Vault)")]
    end

    subgraph MessagingTier["Event Streaming Tier"]
        Kafka["kafka-broker<br/>Apache Kafka 3.7+ (KRaft)<br/>Host: :9092 | Container: :9092"]
        MailHog["mailhog-smtp<br/>Mock SMTP & Web Inbox<br/>Host: :8025 / :1025"]
    end

    ClientSPA -->|"HTTPS / REST Bearer JWT"| Gateway

    Gateway -->|"Blacklist checks & rate limiting"| Redis
    Gateway -->|"Route /api/v1/auth/**, /accounts/**"| AccountSvc
    Gateway -->|"Route /api/v1/transfers/**"| Orchestrator

    AccountSvc -->|"Read-cache & RTR token families"| Redis
    AccountSvc -->|"Customer credentials & KYC"| AzurePostgres

    Orchestrator -->|"Idempotency keys (SET NX EX)"| Redis
    Orchestrator -->|"1. Funds Transfer (OFS AUTH)"| T24EP1
    Orchestrator -->|"2. Reversal on Failure (OFS REVERSE)"| T24EP2
    Orchestrator -->|"Publish transfer state events"| Kafka

    T24CBS <-->|"Row locks (UPDLOCK, ROWLOCK)"| AzureSQL

    Kafka -->|"Consume transfer events"| NotifSvc
    Kafka -->|"Consume transfer events"| AzurePostgres

    NotifSvc -->|"Deliver 2FA OTP & HTML receipts"| MailHog
```
```

---

## 3. Microservice Component Architecture (C4 Level 3)

This diagram details the internal modules, service boundaries, and adapters inside each microservice, emphasizing the Transfer Orchestrator and Temenos T24 CBS dual endpoints.

```mermaid
flowchart LR
    subgraph GatewayBoundary["gateway-service (:8080)"]
        direction TB
        JWTFilter["JwtAuthenticationFilter<br/>(HMAC-SHA256, 15m lifetime)"]
        BlacklistFilter["TokenBlacklistFilter<br/>(Checks blacklist:jti in Redis)"]
        RateLimiter["RedisRateLimiter<br/>(Token Bucket: 100 req/s)"]
        RouteConfig["Gateway Routing Engine<br/>(Path-based proxy)"]
        JWTFilter --> BlacklistFilter --> RateLimiter --> RouteConfig
    end

    subgraph OrchestratorBoundary["transfer-orchestrator (:8082)"]
        direction TB
        TxCtrl["TransferController<br/>/api/v1/transfers"]
        RiskCoord["RiskEngineCoordinator<br/>(200ms WebClient SLA)"]
        ChallengeCoord["StepUpChallengeCoordinator<br/>(Email OTP for > 50k PHP)"]
        SagaCoord["SagaCompensationCoordinator<br/>(Rollback on Downstream Timeout)"]
        T24EP1Client["T24TransferClient<br/>POST /api/v1/t24/funds-transfer"]
        T24EP2Client["T24ReversalClient<br/>POST /api/v1/t24/reversal"]
        EventProducer["TransferEventProducer<br/>(Kafka banking.transfers.events)"]

        TxCtrl --> RiskCoord --> ChallengeCoord --> SagaCoord
        SagaCoord -->|"1. Primary Settlement"| T24EP1Client
        SagaCoord -->|"2. Compensating Rollback"| T24EP2Client
        SagaCoord --> EventProducer
    end

    subgraph T24Boundary["temenos-t24-cbs (:9100)"]
        direction TB
        EP1Handler["FundsTransferHandler<br/>(OFS FUNDS.TRANSFER,AUTH)"]
        EP2Handler["ReversalHandler<br/>(OFS FUNDS.TRANSFER,REVERSE)"]
        AccountingKernel["Double-Entry Accounting Kernel<br/>(Debit/Credit Postings, Tariff Rules)"]
        SqlLockAdapter["Azure SQL Lock Adapter<br/>(SELECT ... WITH UPDLOCK, ROWLOCK)"]

        EP1Handler --> AccountingKernel
        EP2Handler --> AccountingKernel
        AccountingKernel --> SqlLockAdapter
    end

    subgraph NotifBoundary["notification-service (:8083)"]
        direction TB
        KafkaConsumer["TransactionEventConsumer<br/>(@KafkaListener Events)"]
        ReceiptFmt["ReceiptFormatter<br/>(4-decimal Currency & Audit ID)"]
        MailDispatcher["MailAlertDispatcher<br/>(Mock SMTP :1025)"]

        KafkaConsumer --> ReceiptFmt --> MailDispatcher
    end

    RouteConfig -->|"Routes /api/v1/transfers/**"| TxCtrl
```

---

## 4. Saga Execution & Dual-Endpoint Reversal Pipeline (C4 Level 4)

This diagram details the sequence flow of a transfer, including execution on Temenos T24 Endpoint 1 (Funds Transfer) followed by an automated compensating rollback on Temenos T24 Endpoint 2 (Reversal) upon downstream notification failure.

```mermaid
sequenceDiagram
    autonumber
    actor Customer as Retail Customer
    participant Gateway as gateway-service (:8080)
    participant Orchestrator as transfer-orchestrator (:8082)
    participant T24 as temenos-t24-cbs (:9100)
    participant CBSDB as azure-sql-db (:1433)
    participant Kafka as kafka-broker (:9092)
    participant Notif as notification-service (:8083)

    Note over Customer,Orchestrator: Phase 1: Ingestion & Primary Settlement (Endpoint 1)
    Customer->>Gateway: POST /api/v1/transfers { amount: 15000.0000, recipient: ACC-992 }
    Gateway->>Orchestrator: Forward validated transfer request
    Orchestrator->>T24: POST /api/v1/t24/funds-transfer (OFS: FUNDS.TRANSFER,AUTH/I/PROCESS)
    T24->>CBSDB: SELECT ... WITH (UPDLOCK, ROWLOCK) ON balance_master
    T24->>CBSDB: UPDATE balance_master (debit source, credit dest)
    CBSDB-->>T24: Row Locks Released & Transaction Committed
    T24-->>Orchestrator: HTTP 200 OK (txn_ref: T24-FT-9901, status: SETTLED)

    Note over Orchestrator,Kafka: Phase 2: Downstream Delivery & Timeout
    Orchestrator->>Kafka: Produce TransferExecuted event
    Kafka-->>Notif: Deliver event to notification-workers
    Note over Notif: Timeout / SMTP Connection Drop (> 3000ms SLA)
    Notif--x Orchestrator: Circuit Breaker Opens / Delivery Timeout Alert

    Note over Orchestrator,CBSDB: Phase 3: Saga Compensating Reversal (Endpoint 2)
    Orchestrator->>T24: POST /api/v1/t24/reversal (OFS: FUNDS.TRANSFER,REVERSE/I/PROCESS, original_ref: T24-FT-9901)
    T24->>CBSDB: Reverse debit/credit entries, restore source balance
    CBSDB-->>T24: Reversal Committed
    T24-->>Orchestrator: HTTP 200 OK (reversal_ref: T24-REV-0012, status: REVERSED)

    Note over Orchestrator,Customer: Phase 4: State Reversal & Client Notification
    Orchestrator->>Kafka: Produce TransferReversed event
    Orchestrator-->>Gateway: Problem Details (HTTP 500 / REVERSED)
    Gateway-->>Customer: HTTP 500 (Status: REVERSED, Balance Restored)
```

---

## 5. Dual-Storage Persistence Topology: CBS Master Ledger vs PostgreSQL Audit Vault

This diagram illustrates the architectural separation between the live operational transactional state in Azure SQL and the append-only regulatory audit vault in PostgreSQL.

```mermaid
flowchart LR
    subgraph OperationalStore["Master Operational State (Azure SQL :1433)"]
        direction TB
        AccountTable[("account_master<br/>12-digit account numbers,<br/>SAVINGS, CHECKING, CREDIT")]
        BalanceTable[("balance_master<br/>balance_amount, hold_amount,<br/>available_balance (NUMBER 18, 4)<br/>Row-locked via UPDLOCK, ROWLOCK")]
        GLJournal[("gl_journal_entries<br/>Double-entry financial journal lines,<br/>EOD rollups and reconciliations")]

        AccountTable --- BalanceTable --- GLJournal
    end

    subgraph CoreCBS["Core Banking System (:9100)"]
        T24Kernel["Temenos T24 CBS Kernel<br/>Handles debit, credit, fee tariffs,<br/>and pessimistic row locking"]
    end

    subgraph EventStream["Kafka Commit Log (:9092)"]
        EventsTopic["Topic: banking.transfers.events<br/>Carries immutable state change events"]
    end

    subgraph AuditStore["Immutable Audit Vault (PostgreSQL 16 :5432)"]
        direction TB
        AuditLog[("ledger_mutation_audit<br/>audit_id (BIGSERIAL PK)<br/>transaction_id, account_id<br/>mutation_type, amount, balance_after<br/>operator_id, terminal_ip, timestamp")]
        TriggerBlock["PostgreSQL Database Trigger:<br/>trg_no_update_delete_mutation_audit<br/>(Strictly rejects UPDATE & DELETE)"]
        AuditLog --- TriggerBlock
    end

    subgraph AuditorAccess["Auditor API & Portal"]
        AuditorEndpoint["GET /api/v1/audit/account/{id}<br/>Fast B-Tree Index: (account_id, created_at)<br/>Sub-5ms query response time"]
    end

    T24Kernel <-->|"ACID Transactions & Row Locks"| OperationalStore
    T24Kernel -->|"Emits state events"| EventStream
    EventStream -->|"Asynchronous consumer projection"| AuditLog
    AuditorEndpoint -->|"Read-only compliance queries"| AuditLog
```

---

## 6. High-Value Customer 2FA Verification State Transition Model

Transactions exceeding PHP 50,000.00 require customer multi-factor verification via email OTP before settlement is dispatched to Temenos T24.

```mermaid
stateDiagram-v2
    [*] --> INITIATED: Customer submits transfer request

    state INITIATED {
        [*] --> CheckValue
        CheckValue --> DirectSTP: Amount <= 50,000.0000 PHP
        CheckValue --> Requires2FA: Amount > 50,000.0000 PHP
    }

    DirectSTP --> DISPATCHED_T24: Direct dispatch to T24 Endpoint 1

    Requires2FA --> PENDING_VERIFICATION: 6-digit OTP generated & cached in Redis (TTL 300s)

    state PENDING_VERIFICATION {
        [*] --> EmailDispatched: Notification service sends OTP email via MailHog
        EmailDispatched --> WaitingForInput: Customer enters OTP in frontend modal
        WaitingForInput --> OTPValidated: Code matched in Redis
    }

    OTPValidated --> DISPATCHED_T24: Verified; dispatch to T24 Endpoint 1

    DISPATCHED_T24 --> EXECUTED: T24 returns 200 OK (Settled)

    DISPATCHED_T24 --> REVERSED: Downstream failure triggers T24 Endpoint 2 (Reversed)

    EXECUTED --> AUDITED: Event emitted to Kafka; appended to PostgreSQL Audit Vault
    REVERSED --> AUDITED: Compensation recorded in Audit Vault

    AUDITED --> [*]
```

---

## 7. Refresh Token Rotation (RTR) & Breach Detection Flow

The system protects against stolen refresh tokens by rotating tokens on each refresh call and revoking the entire token family if a retired token is presented.

```mermaid
sequenceDiagram
    autonumber
    actor User as Client Browser
    participant Gateway as API Gateway (:8080)
    participant AccountSvc as Account Service (:8081)
    participant Redis as Redis Cache (:6379)

    Note over User,Redis: Normal Refresh Token Rotation (RTR)
    User->>Gateway: POST /api/v1/auth/refresh (Cookie: refresh_token=RT-1)
    Gateway->>AccountSvc: Forward request
    AccountSvc->>Redis: GET refresh_token:RT-1
    Redis-->>AccountSvc: Metadata { status: ACTIVE, sessionId: SESS-01, userId: USR-101 }
    AccountSvc->>Redis: SET refresh_token:RT-1 status=REVOKED (7-day TTL)
    AccountSvc->>Redis: SET refresh_token:RT-2 status=ACTIVE, parent=RT-1 (7-day TTL)
    AccountSvc->>Redis: SADD token_family:SESS-01 RT-2
    AccountSvc-->>Gateway: 200 OK + new Access Token + Set-Cookie: refresh_token=RT-2
    Gateway-->>User: 200 OK (New Access Token 15m, New Refresh Cookie 7d)

    Note over User,Redis: Replay Attack Detected (Attacker presents stolen RT-1)
    User->>Gateway: POST /api/v1/auth/refresh (Cookie: refresh_token=RT-1)
    Gateway->>AccountSvc: Forward request
    AccountSvc->>Redis: GET refresh_token:RT-1
    Redis-->>AccountSvc: Metadata { status: REVOKED, sessionId: SESS-01 }
    Note over AccountSvc,Redis: Breach detected: Revoked token was used
    AccountSvc->>Redis: SMEMBERS token_family:SESS-01
    Redis-->>AccountSvc: [RT-1, RT-2]
    AccountSvc->>Redis: DEL refresh_token:RT-1 refresh_token:RT-2
    AccountSvc->>Redis: DEL token_family:SESS-01 session:USR-101:SESS-01
    AccountSvc-->>Gateway: 401 Unauthorized (Token Breach Detected)
    Gateway-->>User: 401 Unauthorized (Invalidate all sessions, force re-login)
```

---

## 8. Network Ports and Protocols Reference

| Container | Host Port | Internal Port | Protocol | Scope | Role |
| :--- | :---: | :---: | :--- | :--- | :--- |
| `banking-frontend` | `3000` | `80` | HTTP / Web | Public | React 18 Single Page Application |
| `gateway-service` | `8080` | `8080` | HTTP / REST | Public | Perimeter security, rate limiting, and routing |
| `account-service` | `8081` | `8081` | HTTP / REST | Internal | Customer onboarding, KYC, account provisioning |
| `transfer-orchestrator` | `8082` | `8082` | HTTP / REST | Internal | Transfer lifecycle, Risk Engine, Saga compensation |
| `temenos-t24-cbs` | `9100` | `9100` | HTTP / OFS | Internal | Core Banking System: EP1 Funds Transfer & EP2 Reversal |
| `notification-service` | `8083` | `8083` | HTTP / REST | Internal | Asynchronous alert dispatching and 2FA email generation |
| `mailhog-smtp` | `8025` / `1025` | `8025` / `1025` | HTTP / SMTP | Public / Host | Mock email web inbox (:8025) and SMTP server (:1025) |
| `redis-cache` | `6379` | `6379` | RESP / TCP | Internal | Token blacklists, idempotency locks, 2FA OTP cache |
| `azure-sql-db` | `1433` | `1433` | TDS / SQL | Internal | Temenos T24 Master Ledger DB (pessimistic row locks) |
| `azure-postgres-vault`| `5432` | `5432` | PostgreSQL | Internal | Append-only immutable regulatory audit vault |
| `kafka-broker` | `9092` | `9092` | PLAINTEXT | Internal | Event streaming commit log (KRaft mode) |
| `kafka-ui` | `8085` | `8080` | HTTP / Web | Host Browser | Kafka partition, message, and consumer management |
| `dd-agent` | `8126` / `8125` | `8126` / `8125` | APM / StatsD | Host / Internal | Enterprise Observability: APM traces, DogStatsD metrics |
| `jaeger-tracing` | `16686` / `4317` | `16686` / `4317` | HTTP / gRPC | Host Browser | OpenTelemetry distributed trace visualizer (:16686) |

---

## 9. C1–C4 Archify Diagrams & Interactive Zoom Explorer

The architecture is rendered as standalone interactive HTML artifacts compiled with Archify v3:

* **Interactive Zoom & Drill-Down Explorer**: [`c_model_explorer.html`](file:///c:/Users/JLB83807/The%20Vault/workspaces/FSE-Capstone/c_model_explorer.html)
  Allows clicking any component node to smoothly zoom in from high-level C1 System Context down to C2 Containers, C3 Components, and C4 Sequence execution flows.
* **C1 System Context Diagram**: [`c1_system_context.html`](file:///c:/Users/JLB83807/The%20Vault/workspaces/FSE-Capstone/c1_system_context.html)
* **C2 Container Diagram**: [`c2_container.html`](file:///c:/Users/JLB83807/The%20Vault/workspaces/FSE-Capstone/c2_container.html)
* **C3 Component Diagram**: [`c3_component.html`](file:///c:/Users/JLB83807/The%20Vault/workspaces/FSE-Capstone/c3_component.html)
* **C4 Sequence Diagram**: [`c4_sequence.html`](file:///c:/Users/JLB83807/The%20Vault/workspaces/FSE-Capstone/c4_sequence.html)
* **Full Primary System Architecture**: [`architecture.html`](file:///c:/Users/JLB83807/The%20Vault/workspaces/FSE-Capstone/architecture.html)



