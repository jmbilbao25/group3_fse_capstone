# Architecture Diagrams: Retail Ledger & Balance Mutation Engine

This document provides visual architectural models for the retail banking platform. It includes system context, container topology, component internals, dual-storage pipelines, and state machines.

---

## 1. System Context Diagram (C4 Level 1)

The system context diagram shows the core banking platform, user personas, and external third-party integration boundaries.

```mermaid
flowchart TD
    subgraph Users["User Personas"]
        Customer["Retail Customer<br/>(Web & Mobile Browser)"]
        Teller["Bank Teller / Operator<br/>(Maker-Checker Reviewer)"]
        Admin["Compliance Admin<br/>(KYC & Account Provisioner)"]
        Auditor["Regulatory Auditor<br/>(Immutable Log Inspector)"]
    end

    subgraph BankingSystem["Retail Ledger & Balance Mutation Engine"]
        CorePlatform["Core Banking Platform<br/>(Docker Container Network: banking-net)"]
    end

    subgraph ExternalSystems["External Systems & Service Providers"]
        ClearingHouse["External Clearing Network<br/>(InstaPay / PESONet)"]
        NotificationProviders["SMS & Email Gateways<br/>(Twilio / SendGrid)"]
        CreditBureau["Credit Bureau & Collateral Services"]
    end

    Customer -->|"Manages accounts, views balances,<br/>initiates funds transfers (HTTPS)"| CorePlatform
    Teller -->|"Reviews high-value transfers > 10M PHP,<br/>approves or rejects transactions (HTTPS)"| CorePlatform
    Admin -->|"Verifies customer KYC profiles,<br/>provisions bank accounts (HTTPS)"| CorePlatform
    Auditor -->|"Queries append-only audit trail<br/>for compliance audits (HTTPS)"| CorePlatform

    CorePlatform -->|"Dispatches inter-bank settlements"| ClearingHouse
    CorePlatform -->|"Sends transaction alerts & receipts"| NotificationProviders
    CorePlatform -->|"Verifies credit records & collateral"| CreditBureau
```

---

## 2. Container Topology & Networking Architecture (C4 Level 2)

All containers run inside the dedicated Docker Compose bridge network (`banking-net`). External browser traffic enters through host port mappings, while inter-service communication uses internal container DNS names.

```mermaid
flowchart TD
    subgraph ClientTier["Presentation Tier"]
        ClientSPA["banking-frontend<br/>React 19, TypeScript, Vite<br/>Host: :3000 | Container: :80"]
    end

    subgraph PerimeterTier["Perimeter Security & Routing Tier"]
        Gateway["gateway-service<br/>Spring Cloud Gateway, Spring Security 6<br/>Host: :8080 | Container: :8080"]
        Redis["redis-cache<br/>Redis 7 Alpine<br/>Host: :6379 | Container: :6379"]
    end

    subgraph ServiceTier["Application Microservices Tier"]
        AccountSvc["account-service<br/>Spring Boot 3, Spring Data JPA<br/>Host: :8081 | Container: :8081"]
        LedgerEngine["ledger-mutation-engine<br/>Spring Boot 3, Concurrency Kernel<br/>Host: :8082 | Container: :8082"]
        NotifSvc["notification-service<br/>Spring Boot 3, Kafka Consumer<br/>Host: :8083 | Container: :8083"]
    end

    subgraph StorageTier["Persistence & Data Tier"]
        OracleDB[("oracle-xe-master<br/>Oracle Database 21c XE<br/>Host: :1521 | Container: :1521")]
        PostgresAudit[("postgres-audit-vault<br/>PostgreSQL 16 Alpine<br/>Host: :5432 | Container: :5432")]
    end

    subgraph MessagingTier["Event Streaming Tier"]
        Kafka["kafka-broker<br/>Apache Kafka 3.7+ (KRaft)<br/>Host: :9092 | Container: :9092"]
        KafkaUI["kafka-ui<br/>Kafka Web Console<br/>Host: :8085 | Container: :8080"]
    end

    subgraph ObservabilityTier["Telemetry & Observability Tier"]
        Datadog["dd-agent<br/>Datadog Agent 7<br/>Host: :8126 (APM) | :8125 (StatsD)"]
    end

    ClientSPA -->|"HTTPS / REST<br/>Bearer JWT"| Gateway

    Gateway -->|"Blacklist checks & rate limiting<br/>(sub-5ms RESP)"| Redis
    Gateway -->|"Route /api/v1/auth/**<br/>Route /api/v1/accounts/**<br/>Route /api/v1/kyc/**"| AccountSvc
    Gateway -->|"Route /api/v1/ledger/**<br/>Route /api/v1/transfers/**"| LedgerEngine

    AccountSvc -->|"Read-cache & RTR token families"| Redis
    AccountSvc -->|"JPA / SQL (Port 1521)<br/>users, accounts, balance_master"| OracleDB

    LedgerEngine -->|"Idempotency locks & cache eviction"| Redis
    LedgerEngine -->|"Pessimistic row locks & outbox<br/>SELECT FOR UPDATE (Port 1521)"| OracleDB
    LedgerEngine -->|"Publish command & event partitions<br/>(PLAINTEXT Port 9092)"| Kafka

    Kafka -->|"Consume transfer commands<br/>(Partitioned by source_account_id)"| LedgerEngine
    Kafka -->|"Consume transfer events<br/>(audit-vault-workers)"| PostgresAudit
    Kafka -->|"Consume transfer events<br/>(notification-workers)"| NotifSvc

    KafkaUI -->|"Topic & partition monitoring"| Kafka

    AccountSvc -->|"APM traces & DogStatsD metrics"| Datadog
    LedgerEngine -->|"APM traces & DogStatsD metrics"| Datadog
    Gateway -->|"APM traces & DogStatsD metrics"| Datadog
    NotifSvc -->|"APM traces & DogStatsD metrics"| Datadog
```

---

## 3. Microservice Component Architecture (C4 Level 3)

This diagram details the internal modules, service boundaries, and adapters inside each microservice.

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

    subgraph AccountBoundary["account-service (:8081)"]
        direction TB
        subgraph AccountControllers["Web Controllers"]
            AuthCtrl["AuthController<br/>/api/v1/auth"]
            AccCtrl["AccountController<br/>/api/v1/accounts"]
            KycCtrl["KycController<br/>/api/v1/kyc"]
        end
        subgraph AccountServices["Business Services"]
            AuthSvc["AuthService<br/>(Registration & Login)"]
            TokenRotSvc["TokenRotationService<br/>(RTR & Breach Detection)"]
            AccProvSvc["AccountProvisioningService<br/>(12-digit Number Generation)"]
            BalInqSvc["BalanceInquiryService<br/>(30s Read-Cache)"]
            KycSvc["KycService<br/>(Approval Workflow)"]
        end
        subgraph AccountAdapters["Security & Storage Adapters"]
            JwtProv["JwtProvider<br/>(JJWT HMAC-SHA256)"]
            RedisStore["RedisSessionStore<br/>(Token Families & Sessions)"]
            UserRepo["UserRepository<br/>(Spring Data JPA)"]
            AccRepo["AccountRepository<br/>(Spring Data JPA)"]
            BalRepo["BalanceMasterRepository<br/>(Spring Data JPA)"]
        end

        AuthCtrl --> AuthSvc
        AuthCtrl --> TokenRotSvc
        AccCtrl --> AccProvSvc
        AccCtrl --> BalInqSvc
        KycCtrl --> KycSvc

        AuthSvc --> JwtProv
        AuthSvc --> RedisStore
        AuthSvc --> UserRepo

        TokenRotSvc --> RedisStore
        TokenRotSvc --> JwtProv

        AccProvSvc --> AccRepo
        AccProvSvc --> BalRepo
        AccProvSvc --> RedisStore

        BalInqSvc --> RedisStore
        BalInqSvc --> BalRepo
        BalInqSvc --> AccRepo

        KycSvc --> UserRepo
    end

    subgraph LedgerBoundary["ledger-mutation-engine (:8082)"]
        direction TB
        subgraph LedgerControllers["Web Controllers"]
            MutCtrl["MutationController<br/>/api/v1/ledger/mutate"]
            TxCtrl["TransferController<br/>/api/v1/transfers"]
            MakerCtrl["MakerCheckerController<br/>/api/v1/transfers/{id}/approve"]
        end
        subgraph LedgerServices["Core Concurrency & Outbox Engine"]
            IdempInterceptor["IdempotencyInterceptor<br/>(X-Idempotency-Key in Redis)"]
            TxOutboxSvc["TransactionalOutboxService<br/>(Local DB Outbox Writer)"]
            BalMutSvc["BalanceMutationService<br/>(PESSIMISTIC_WRITE Lock)"]
            MakerCheckerSvc["MakerCheckerWorkflowService<br/>(Threshold > 10M PHP)"]
            OutboxWorker["OutboxPublisherWorker<br/>(SKIP LOCKED Poller)"]
            SagaConsumer["TransferSagaConsumer<br/>(@KafkaListener Commands)"]
        end
        subgraph LedgerAdapters["Persistence & Messaging"]
            OracleLockRepo["BalanceMasterRepository<br/>(@Lock PESSIMISTIC_WRITE)"]
            OutboxRepo["OutboxEventRepository<br/>(Spring Data JPA)"]
            KafkaProducer["KafkaEventProducer<br/>(Commands & Events)"]
        end

        TxCtrl --> IdempInterceptor --> TxOutboxSvc
        MutCtrl --> BalMutSvc
        MakerCtrl --> MakerCheckerSvc

        TxOutboxSvc --> OutboxRepo
        OutboxWorker --> OutboxRepo
        OutboxWorker --> KafkaProducer

        SagaConsumer --> BalMutSvc
        BalMutSvc --> OracleLockRepo
        MakerCheckerSvc --> OracleLockRepo
        SagaConsumer --> KafkaProducer
    end

    subgraph NotifBoundary["notification-service (:8083)"]
        direction TB
        KafkaListener["TransactionEventConsumer<br/>(@KafkaListener Events)"]
        ReceiptFmt["ReceiptFormatter<br/>(4-decimal Currency & Audit ID)"]
        PushDispatcher["PushAlertDispatcher<br/>(Customer App Notifications)"]
        TellerDispatcher["TellerAlertDispatcher<br/>(High-Value Alert Queue)"]

        KafkaListener --> ReceiptFmt
        ReceiptFmt --> PushDispatcher
        ReceiptFmt --> TellerDispatcher
    end
```

---

## 4. Dual-Storage & Transactional Outbox Pipeline

The Transactional Outbox pattern guarantees that database writes and message broker events never fall out of sync, even if network failures occur.

```mermaid
flowchart TD
    subgraph Step1["Step 1: Rapid Ingestion & Local Transaction"]
        ClientReq["Customer Transfer Request<br/>POST /api/v1/transfers"] --> GatewayCheck["API Gateway verifies JWT &<br/>checks Redis Idempotency Key"]
        GatewayCheck --> LedgerIngest["Ledger Engine creates Transfer<br/>status: INITIATED"]
        LedgerIngest --> DBTransaction["Atomic Database Transaction<br/>(Oracle XE 21c)"]

        subgraph LocalCommit["Single Local Transaction Boundary"]
            InsertTx["INSERT INTO transactions<br/>status: INITIATED"]
            InsertOutbox["INSERT INTO outbox_events<br/>status: PENDING"]
        end
        DBTransaction --> InsertTx
        DBTransaction --> InsertOutbox
    end

    subgraph Step2["Step 2: Immediate Acknowledgment"]
        DBTransaction -->|"Commit OK in < 15ms"| Response202["HTTP 202 Accepted<br/>transfer_id: TRX-101<br/>status_url: /api/v1/transfers/TRX-101"]
    end

    subgraph Step3["Step 3: Reliable Outbox Polling & Publishing"]
        OutboxPoller["OutboxPublisherWorker<br/>SELECT ... FOR UPDATE SKIP LOCKED"] --> ReadPending["Read PENDING outbox_events"]
        ReadPending --> KafkaPublish["Publish to Kafka Topic<br/>banking.transfers.commands<br/>Key: source_account_id"]
        KafkaPublish -->|"Ack received (acks=all)"| MarkPublished["UPDATE outbox_events<br/>status: PUBLISHED"]
    end

    subgraph Step4["Step 4: Ordered Partition Consumption & Settlement"]
        KafkaPartition["Kafka Command Partition<br/>(Strict FIFO per source_account_id)"] --> SagaWorker["TransferSagaConsumer<br/>(consumer-group: ledger-workers)"]
        SagaWorker --> RowLock["Acquire Pessimistic Lock<br/>SELECT ... FOR UPDATE<br/>on balance_master"]

        RowLock --> EvaluateThreshold{"Amount > 10M PHP?"}

        EvaluateThreshold -->|"Yes: High-Value"| SoftHold["Apply Soft Hold<br/>hold_amount += amount<br/>status: PENDING_APPROVAL"]
        EvaluateThreshold -->|"No: Standard"| DebitCredit["Atomic Balance Mutation<br/>source -= amount<br/>dest += amount<br/>status: EXECUTED"]

        SoftHold --> PublishHoldEvent["Produce TransferPendingApproval<br/>to banking.transfers.events"]
        DebitCredit --> PublishExecEvent["Produce TransferExecuted<br/>to banking.transfers.events"]
    end

    subgraph Step5["Step 5: Fan-Out to Asynchronous Consumers"]
        PublishExecEvent --> AuditConsumer["PostgreSQL Audit Consumer<br/>(consumer-group: audit-vault-workers)"]
        PublishExecEvent --> NotifConsumer["Notification Consumer<br/>(consumer-group: notification-workers)"]

        AuditConsumer --> PostgresAppend["INSERT INTO ledger_mutation_audit<br/>(PostgreSQL 16 Vault)<br/>Trigger blocks UPDATE and DELETE"]
        NotifConsumer --> SendAlerts["Format Receipt & Dispatch<br/>SMS, Email, and Push Notifications"]
    end
```

---

## 5. Dual-Storage Ledger vs Audit Vault Topology

This diagram illustrates the architectural separation between the live operational transactional state in Oracle XE and the append-only regulatory audit vault in PostgreSQL.

```mermaid
flowchart LR
    subgraph OperationalStore["Master Operational State (Oracle XE 21c)"]
        direction TB
        OracleUsers[("users<br/>Customer profiles, credentials,<br/>KYC status, session limits")]
        OracleAccounts[("accounts<br/>12-digit account numbers,<br/>SAVINGS, CHECKING, CREDIT")]
        OracleBalance[("balance_master<br/>balance_amount, hold_amount,<br/>available_balance (NUMBER 18, 4)<br/>Row-locked via SELECT FOR UPDATE")]
        OracleTx[("transactions<br/>Transfer state, maker-checker flags,<br/>approval references")]
        OracleOutbox[("outbox_events<br/>Transactional outbox staging table")]
    end

    subgraph LiveTransactions["Transactional Core (:8082)"]
        LedgerCore["Ledger Mutation Engine<br/>Handles debit, credit, soft holds,<br/>and high-concurrency locking"]
    end

    subgraph EventStream["Kafka Commit Log (:9092)"]
        EventsTopic["Topic: banking.transfers.events<br/>Carries immutable state change events"]
    end

    subgraph AuditStore["Immutable Audit Vault (PostgreSQL 16)"]
        direction TB
        AuditLog[("ledger_mutation_audit<br/>audit_id (BIGSERIAL PK)<br/>transaction_id, account_id<br/>mutation_type, amount, balance_after<br/>operator_id, terminal_ip, timestamp")]
        TriggerBlock["PostgreSQL Database Trigger:<br/>trg_no_update_delete_mutation_audit<br/>(Strictly rejects UPDATE & DELETE)"]
        AuditLog --- TriggerBlock
    end

    subgraph AuditorAccess["Auditor API & Portal"]
        AuditorEndpoint["GET /api/v1/audit/account/{id}<br/>Fast B-Tree Index: (account_id, created_at)<br/>Sub-5ms query response time"]
    end

    LedgerCore <-->|"ACID Transactions & Row Locks"| OperationalStore
    LedgerCore -->|"Publishes state events"| EventStream
    EventStream -->|"Asynchronous consumer projection"| AuditLog
    AuditorEndpoint -->|"Read-only compliance queries"| AuditLog
```

---

## 6. High-Value Maker-Checker State Transition Model

Transactions exceeding 10,000,000.0000 PHP require two distinct banking operators: the Maker who initiates the transaction, and the Checker who reviews and releases the funds.

```mermaid
stateDiagram-v2
    [*] --> INITIATED: Customer submits transfer request

    state INITIATED {
        [*] --> CheckValue
        CheckValue --> DirectQueue: Amount <= 10,000,000.0000 PHP
        CheckValue --> MakerCheckerQueue: Amount > 10,000,000.0000 PHP
    }

    DirectQueue --> EXECUTED: Automatic debit & credit settled

    MakerCheckerQueue --> PENDING_APPROVAL: System applies soft hold<br/>(hold_amount += amount)

    state PENDING_APPROVAL {
        [*] --> AwaitingReview: Appears on Teller Dashboard
        AwaitingReview --> ValidatingChecker: Checker inspects documents
        ValidatingChecker --> SegregationCheck: Verify maker_id != checker_id
    }

    SegregationCheck --> EXECUTED: Checker Approves<br/>Soft hold released<br/>Source debited, Destination credited

    SegregationCheck --> FAILED: Checker Rejects<br/>Soft hold released<br/>hold_amount decremented

    EXECUTED --> AUDITED: Emitted to Kafka<br/>Recorded in PostgreSQL Audit Vault

    FAILED --> AUDITED: Rejection reason logged in Audit Vault

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
| `banking-frontend` | `3000` | `80` | HTTP / Web | Public | React 19 Single Page Application |
| `gateway-service` | `8080` | `8080` | HTTP / REST | Public | Perimeter security, rate limiting, and routing |
| `account-service` | `8081` | `8081` | HTTP / REST | Internal | Customer onboarding, KYC, account provisioning |
| `ledger-mutation-engine` | `8082` | `8082` | HTTP / REST | Internal | Concurrency row locking, balance mutations, outbox |
| `notification-service` | `8083` | `8083` | HTTP / REST | Internal | Asynchronous alert dispatching and receipt generation |
| `redis-cache` | `6379` | `6379` | RESP / TCP | Internal | Token blacklists, idempotency locks, balance read-cache |
| `oracle-xe-master` | `1521` | `1521` | Oracle TNS | Internal | Primary transactional state and pessimistic locking |
| `postgres-audit-vault` | `5432` | `5432` | PostgreSQL | Internal | Append-only immutable regulatory audit vault |
| `kafka-broker` | `9092` | `9092` | PLAINTEXT | Internal | Event streaming commit log (KRaft mode) |
| `kafka-ui` | `8085` | `8080` | HTTP / Web | Host Browser | Kafka partition, message, and consumer management |
| `dd-agent` | `8126` / `8125` | `8126` / `8125` | APM / StatsD | Host / Internal | Enterprise Observability: APM traces, DogStatsD metrics, container logs |
| `jaeger-tracing` | `16686` / `4317` | `16686` / `4317` | HTTP / gRPC | Host Browser | OpenTelemetry distributed trace visualizer (:16686) & OTLP receiver |

