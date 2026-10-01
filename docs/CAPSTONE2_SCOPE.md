# Integrated Capstone: Project Scope Document (Architecture & Service Boundaries)

## 1. Project Overview & System Purpose

The platform is an omnichannel, real-time peer-to-peer (P2P) remittance pipeline with hardened edge perimeter security, asynchronous fraud risk screening, simulated core banking settlement, and dual-storage ledger auditing. 

Customers initiate transfers through a unified **Flutter multiplatform client** running on mobile (iOS and Android with hardware-backed KeyStore/Keychain credential protection) or web (Flutter Web with identical design tokens and UI parity). Every transfer is scrubbed at the perimeter gateway, evaluated by an asynchronous Python risk engine, and routed through strict business thresholds (including email OTP verification for high-value transfers) before acquiring deterministic row locks and appending immutable audit records.

In local development, the platform runs via Docker Compose with Oracle XE and PostgreSQL. In cloud production, the architecture deploys natively to Microsoft Azure using **Azure Kubernetes Service (AKS)**, **Azure SQL Database with Ledger tables**, **Azure Container Registry (ACR)**, **Azure Event Hubs**, and an automated **GitHub Actions CI/CD pipeline**.

---

## 2. In-Depth Redis Data Architecture & Storage Contracts

Redis serves as the platform's high-speed in-memory state engine. Rather than acting as a simple generic cache, Redis manages **six mission-critical security and transaction namespaces**:

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   REDIS IN-MEMORY NAMESPACES                                     │
├─────────────────────────┬─────────────────────────────┬─────────────┬────────────────────────────┤
│ Namespace / Key Pattern │ Purpose & Security Function │ Data Type   │ TTL (Time-To-Live)         │
├─────────────────────────┼─────────────────────────────┼─────────────┼────────────────────────────┤
│ blacklist:jti:<jti>     │ Access Token Blacklist      │ String      │ Remaining JWT TTL (<=15m)  │
│ refresh_token:<tokenId> │ RTR Refresh Token Metadata  │ Hash / JSON │ 7 Days                     │
│ token_family:<sessId>   │ Token Family Member Set     │ Set         │ 7 Days                     │
│ auth:user-sessions:<id> │ Active User Sessions        │ Set         │ 7 Days                     │
│ otp:<transferId>        │ 2FA Verification Codes      │ String      │ 5 Minutes (300 seconds)    │
│ account:balance:<accId> │ Read-Through Balance Cache  │ String/JSON │ 30 Seconds                 │
│ request_rate_limiter.*  │ Token-Bucket Rate Limiter   │ Hash / Lua  │ Dynamic Token Window       │
└─────────────────────────┴─────────────────────────────┴─────────────┴────────────────────────────┘
```

### Detailed Breakdown of Redis State Engines:

#### A. Refresh Token Rotation (RTR) & Breach Containment (`refresh_token:*` & `token_family:*`)
* **Single-Use Refresh Tokens:** When a user logs in, a cryptographically random, opaque refresh token ID (`rt_<uuid>`) is generated and saved under `refresh_token:<tokenId>` containing session metadata (user ID, session ID, role, status `ACTIVE`, and parent token ID).
* **Token Rotation Cycle:** When the Flutter client calls `POST /api/v1/auth/refresh`, the presented token is immediately marked `REVOKED` in Redis, and a brand-new refresh token is issued and added to the session's token family set (`token_family:<sessionId>`).
* **Automated Breach Detection & Family Purge:** If a stolen or replayed refresh token (one already marked `REVOKED`) is presented, Redis triggers an immediate security purge (`purgeEntireTokenFamily`). The system identifies that a token leak has occurred, instantly deletes all refresh tokens in that family from Redis, evicts the user's active session, and rejects the caller with a `TokenBreachException` (HTTP 401).

#### B. Access Token Blacklisting & Immediate Session Termination (`blacklist:jti:*` & `auth:blacklist:*`)
* **Stateless JWT Revocation:** Standard JWT access tokens are stateless and expire after 15 minutes. To allow immediate user logout or administrative session termination before the 15-minute window expires, the system records the unique JWT ID (`jti`) into Redis under `blacklist:jti:<jti>` with a TTL equal to the token's remaining lifespan.
* **Gateway Perimeter Enforcement:** The Spring Cloud Gateway inspects this Redis key for every incoming API request. If the `jti` exists in the blacklist, the Gateway drops the request with an immediate HTTP 401 Unauthorized status before it can reach internal microservices.
* **Concurrent Session Limits:** User sessions are tracked under `auth:user-sessions:<userId>`. When a customer logs into a new device and exceeds the maximum allowed concurrent sessions, the oldest session's `jti` is popped from the Redis set and placed directly onto the blacklist.

#### C. High-Value 2FA OTP Temporary Store (`otp:*` & `otp:sent:*`)
* **Cryptographic OTP Generation:** When a transfer exceeds PHP 50,000.00, a secure 6-digit OTP code is generated and stored in Redis under `otp:<transferId>` with a strict 300-second (5-minute) TTL.
* **Anti-Spam Dispatch Locks:** A secondary key `otp:sent:<transferId>` with a 15-second TTL prevents duplicate message firing while the Notification Service sends the advice email through MailHog.
* **Atomic Verification:** Upon customer submission, the code is validated and evicted atomically. Expired keys naturally drop out of Redis memory, preventing stale verification attempts.

#### D. Read-Through Balance Cache (`account:balance:*`)
* **Relational Offload:** Frequently polled balance inquiries hit Redis first. If found, the balance payload returns in sub-millisecond time (`cached: true`).
* **Cache Invalidation:** The cache expires automatically after 30 seconds. Furthermore, whenever the Orchestration Engine commits a mutation in Oracle XE or Azure SQL, an explicit cache eviction hook (`evictCachedBalance`) purges the key, guaranteeing zero dirty reads.

#### E. Edge Rate Limiting (`request_rate_limiter.*`)
* **Token-Bucket Filter:** Backed by Redis Lua scripts running inside Spring Cloud Gateway. Tracks client request frequency based on API key or IP address (`replenishRate: 10`, `burstCapacity: 20`). Malicious clients exceeding 10 req/sec are dropped with HTTP 429 Too Many Requests.

---

## 3. Flutter Client Architecture & Parity Strategy

Building both mobile and web applications in **Flutter** ensures 100% visual, functional, and security parity across platforms:

```
┌────────────────────────────────────────────────────────────────────────┐
│                    UNIFIED FLUTTER CLIENT ARCHITECTURE                 │
├───────────────────────────────────┬────────────────────────────────────┤
│ Flutter Mobile (iOS / Android)    │ Flutter Web (CanvasKit / Wasm)     │
├───────────────────────────────────┼────────────────────────────────────┤
│ • Native KeyStore / Keychain      │ • Secure local storage abstraction │
│ • Client circuit breaker UI       │ • Identical client circuit breaker │
│ • Touch/Biometric UX              │ • Desktop responsive layouts       │
│ • Hardware token encryption       │ • Shared Riverpod / BLoC state     │
└───────────────────────────────────┴────────────────────────────────────┘
                                    │
                                    ▼
       Shared Design System & Financial Precision Form Validations
```

* **Single Codebase Parity:** Mobile (iOS/Android) and Web share identical widget trees, business logic components, and data transfer objects (DTOs), eliminating synchronization drift between web and mobile releases.
* **Hardware Credential Hardening:** Uses `flutter_secure_storage` to store JWT tokens in native hardware-backed keystores: Android KeyStore (AES-256) on Android, iOS Keychain on Apple devices, and secure storage mechanisms on web.
* **Client-Side Fail-Fast Circuit Breaker:** Implemented uniformly in Dart via an HTTP interceptor. If the Gateway drops offline or times out repeatedly, both web and mobile instantly display an active "Service Temporarily Unavailable" screen instead of freezing the UI.

---

## 4. Complete Service-by-Service Scope Matrix

| Service | Primary Responsibility | In-Scope Deliverables | Explicitly Out-of-Scope |
| :--- | :--- | :--- | :--- |
| **Flutter Mobile App** | Omnichannel native mobile interface | • Built in Flutter (Dart) for iOS and Android<br>• Secure credential storage using native hardware encryption (iOS Keychain / Android KeyStore via `flutter_secure_storage`)<br>• Client-side fail-fast circuit breaker (displays active "Service Temporarily Unavailable" screen on gateway timeout)<br>• Transfer submission, balance cards & 2FA OTP verification screens<br>• 100% UI and business logic parity with Flutter Web | • Publishing to Apple App Store or Google Play Store<br>• Push notifications via APNs / Firebase<br>• Real facial recognition / camera biometrics |
| **Flutter Web App** | Omnichannel browser portal | • Built in Flutter Web (CanvasKit / Wasm on port 3000)<br>• Identical design tokens, components, and layout parity with mobile client<br>• Customer transfer initiation and real-time balance inquiries<br>• Admin / Teller compliance view for inspecting audit records and pending transfers<br>• Client-side financial numeric validation (`NUMBER(18, 4)`) | • Server-side rendering (SSR)<br>• Multi-language localization beyond English |
| **API Gateway** | Edge perimeter & reverse proxy | • Spring Cloud Gateway running on port 8080 (or AKS pod)<br>• Stateless JWT signature verification and role inspection<br>• Redis token-bucket rate limiter (>10 req/s drops with HTTP 429)<br>• Redis access token blacklist verification (`blacklist:jti:*`)<br>• W3C trace header injection (`traceparent`) for Datadog APM<br>• RFC-7807 standardized problem details error formatting | • Dynamic GraphQL schema stitching<br>• Client-side mTLS certificate validation for mobile users |
| **Account & Auth Service** | Identity, authentication & token issuance | • Spring Boot microservice running on port 8081 (or AKS pod)<br>• User registration (`POST /api/v1/auth/register`) with KYC tier assignment<br>• User login (`POST /api/v1/auth/login`) generating signed HMAC-SHA256 JWT access tokens (15m TTL) and secure HTTP-only refresh token cookies (7-day TTL)<br>• Refresh Token Rotation (`POST /api/v1/auth/refresh`) with automatic replay breach detection and token family purging<br>• User logout (`POST /api/v1/auth/logout`) blacklisting JWT `jti` in Redis<br>• User account management and balance query caching (`account:balance:<accountId>`) | • Third-party OAuth2 social logins (Google, Apple)<br>• Hardware U2F / YubiKey physical fobs |
| **Redis Cache** | In-memory security & caching state | • Refresh Token Rotation (RTR) metadata store (7-day TTL)<br>• Token family tracking and replay breach purge<br>• JWT access token revocation blacklist (`jti`)<br>• 2FA OTP codes with strict 5-minute TTL<br>• High-throughput balance read cache (30s TTL)<br>• Token-bucket rate limiting counters | • Multi-region active-active Redis Enterprise clustering<br>• Use as primary relational ledger |
| **Fraud Risk Engine** | Real-time risk analytics | • Lightning-fast Python service built with FastAPI and `asyncio`<br>• Running on port 8084 inside protected container mesh (or AKS pod)<br>• Evaluates transfer velocity, amount limits, and account history<br>• Generates normalized risk score between 0.00 and 1.00<br>• Enforces hard threshold: scores > 0.85 mandate immediate transfer rejection<br>• Strict ≤ 200 ms SLA execution window | • GPU-accelerated deep neural network model training in real time<br>• External credit bureau integrations (TransUnion, Equifax) |
| **Orchestration Engine** | Transaction flow & ledger coordinator | • Spring Boot service on port 8082 (or AKS pod)<br>• Holds relational database transaction while calling Risk Engine via non-blocking HTTP (`WebClient`)<br>• SLA timeout enforcement: cleanly aborts transfer if Risk Engine takes >200ms or fails<br>• Evaluates high-value threshold: if > PHP 50,000.00, places soft hold on available balance and triggers OTP<br>• Deterministic lock ordering (sorts account IDs, locks lower ID first) with `SELECT FOR UPDATE` / `UPDLOCK, ROWLOCK`<br>• Transactional outbox pattern: writes balance mutation and outbox event in same atomic commit | • Real FX currency exchange trading<br>• Cash deposit ATM hardware protocols |
| **Temenos T24 Simulator** | Core banking simulation hook | • Serializes approved transactions into raw OFSCore strings:<br>`FUNDS.TRANSFER,AUTH/I/PROCESS,//PH100223,TXN.REF=...,DEBIT.ACCT=...`<br>• Transmits OFS string over local loopback lines to mock socket / listener<br>• Validates and logs core banking protocol formatting<br>• Returns simulated core confirmation (`TXN-XXXX//1/SUCCESS`) | • Connecting to a real, licensed Temenos T24 core banking mainframe<br>• T24 End-of-Day (EOD) interest accrual batch jobs |
| **Core Database (Local: Oracle XE / Cloud: Azure SQL)** | Operational state & ACID kernel | • Local: Oracle Database Express Edition 21c on port 1521<br>• Cloud: Azure SQL Database with `SELECT ... WITH (UPDLOCK, ROWLOCK)`<br>• Stores user profiles, accounts, balances, transactions, and outbox records<br>• Strict financial numeric precision (`NUMBER(18, 4)` / `DECIMAL(18, 4)`)<br>• Pessimistic row locking preventing overdrafts<br>• HikariCP connection pool capped at 30 connections to prevent resource exhaustion | • Oracle RAC multi-node clustering<br>• Oracle GoldenGate external replication |
| **Event Broker (Local: Kafka / Cloud: Event Hubs)** | Asynchronous event bus | • Local: Apache Kafka in KRaft mode (no ZooKeeper) on port 9092<br>• Cloud: Azure Event Hubs (Kafka protocol endpoint on port 9093)<br>• Decouples fast transaction path from slow downstream operations<br>• Topic `banking.transfers.events`: transaction settlement and receipt alerts<br>• Topic `banking.customer.otp`: high-value 2FA verification code dispatch<br>• Partitioning by `source_account_id` to guarantee per-account chronological ordering | • Schema Registry cluster (Avro/Protobuf servers; JSON contracts are used)<br>• Kafka Connect connectors to external data warehouses |
| **Notification Service** | Customer communications & alerts | • Spring Boot service on port 8083 (or AKS pod)<br>• Consumes Kafka/Event Hubs events for completed transfers and OTP verification requests<br>• Generates 6-digit OTP codes, writes them to Redis with 5-minute TTL, and dispatches email via MailHog / SMTP<br>• Dispatches dual HTML transaction receipts (debit advice to sender, credit advice to beneficiary)<br>• In-memory circuit spool buffer to protect against message loss if SMTP server drops | • Real cellular SMS gateway contracts (Twilio, Globe, Smart)<br>• Interactive Voice Response (IVR) phone calls |
| **Compliance Vault (Local: Postgres / Cloud: Azure SQL Ledger)** | Immutable compliance ledger | • Local: PostgreSQL 16 on port 5432 with `trg_no_update_delete` anti-tamper trigger<br>• Cloud: Azure SQL Ledger append-only table (`LEDGER = ON (APPEND_ONLY = ON)`) with SHA-256 block hashing and Azure Confidential Ledger digests<br>• Houses append-only mutation journal (`ledger_mutation_audit`)<br>• Enforces strict segregation of duties between operational accounts and audit logs | • Write-Once Read-Many (WORM) optical storage appliances<br>• Automated real-time reporting to central bank (BSP API) |
| **Datadog APM Agent** | Centralized observability | • Local: Datadog Agent container running on port 8126 (APM) and 4318 (OTLP)<br>• Cloud: Datadog Agent Kubernetes DaemonSet on all AKS worker nodes<br>• Correlates end-to-end W3C distributed trace context (`traceparent`) across Gateway, Orchestrator, and Risk Engine<br>• Real-time request waterfalls, latency percentiles (p50, p95, p99), and JVM metrics<br>• Centralized container log ingestion | • Real-User Monitoring (RUM) video session replays<br>• Paid automated synthetic global testing agents |

---

## 5. Transfer Value Business Rules Matrix

| Transfer Amount Range | Risk Requirement | Verification Requirement | Settlement Mechanics |
| :--- | :--- | :--- | :--- |
| **PHP 0.01 to PHP 50,000.00** | Python score ≤ 0.85 in ≤200ms | Standard JWT token authentication | Immediate atomic settlement; balances updated in single database transaction. |
| **PHP 50,000.01 to PHP 499,999.99** | Python score ≤ 0.85 in ≤200ms | 2FA Email OTP Verification | Soft hold placed on available balance; 6-digit OTP stored in Redis (5-min TTL); settles upon OTP validation. |
| **PHP 500,000.00 and above** | Python score ≤ 0.85 in ≤200ms | 2FA Email OTP + AMLA Logging | Soft hold & 2FA OTP flow, plus automated generation of Covered Transaction Report (CTR) regulatory notification. |

---

## 6. Chaos Engineering Protocols (Evaluation Defense)

| Protocol | Chaos Injection Action | Expected System Defense & SLA | Proof of Correctness |
| :--- | :--- | :--- | :--- |
| **1. Database Degradation Recovery** | Use Docker / network throttling to inject 3000ms latency or choke database connection pool. | Resilience4j circuit breaker on API Gateway / Orchestrator trips from CLOSED to OPEN; client traffic gracefully falls back to Redis cached balances (`account:balance:*`). | Client receives cached balance within 20ms with `cached: true` header instead of an HTTP 500 server crash. |
| **2. Risk Engine Interruption** | Manually stop/kill the Python Risk Engine container (`docker stop risk-engine`) during active transfer execution. | Spring Boot Orchestration Engine identifies connection loss within the strict **≤ 200 ms SLA window**, trips its internal fallback, and cleanly aborts the transfer. | Transaction is rejected with HTTP 503 / 422; ledger in database remains untouched (zero partial commits or orphaned debits). |
| **3. Perimeter Rejection Check** | Launch automated curl / penetration test scripts directly targeting internal microservice ports (`:8081`, `:8082`, `:8083`, `:8084`, `:1521`, `:5432`) from outside the Docker host network. | Hardened Docker bridge (`banking-net`) or AKS network policy blocks all direct connection attempts; only port 8080 (or Application Gateway) is reachable from external callers. | External calls directly to internal ports receive `Connection refused` or timeout, proving all traffic must pass through the security gateway. |

---

## 7. Cloud Deployment Architecture (Microsoft Azure Native AKS + Azure SQL)

### Why Azure SQL Database with Ledger Replaces Oracle VM & PostgreSQL in Cloud Production

* **Unified Relational & Ledger Engine:** In local development, the platform uses Oracle XE 21c (operational ledger) and PostgreSQL 16 (audit vault). In Azure cloud production, both roles are unified into **Azure SQL Database with Ledger tables**, eliminating the high compute cost and operational overhead of running an unmanaged Oracle Linux VM and a separate PostgreSQL Flexible Server.
* **Deterministic Concurrency & Balance Locking:** Operational mutations acquire strict row-level pessimistic locks using `SELECT ... WITH (UPDLOCK, ROWLOCK)` within Spring Boot transactions (`DECIMAL(18, 4)` precision), guaranteeing absolute balance consistency and preventing overdrafts under concurrent transfers.
* **Cryptographic Tamper-Evidence:** The audit journal table (`ledger_mutation_audit`) is created as an **Azure SQL Ledger append-only table** (`LEDGER = ON (APPEND_ONLY = ON)`). The Azure SQL engine mathematically blocks all SQL `UPDATE`, `DELETE`, and schema modification attempts. Every transaction is cryptographically linked using SHA-256 block hashing, and database digest blocks are periodically anchored in Azure Confidential Ledger for third-party regulatory verification.

### Azure Kubernetes Service (AKS) & CI/CD Pipeline Architecture

* **Container Runtime (AKS):** Microservices run as containerized pods in Azure Kubernetes Service across dedicated system and user node pools. Workloads scale automatically via Kubernetes Horizontal Pod Autoscalers (HPA) based on CPU utilization and request rate.
* **Perimeter Ingress & WAF:** Azure Application Gateway v2 with Azure Web Application Firewall (WAF) acts as the ingress controller (AGIC), terminating TLS on port 443 and enforcing OWASP 3.2 protection rules.
* **Automated CI/CD Pipeline (GitHub Actions -> ACR -> AKS):**
  1. **Continuous Integration (CI):** On push or PR to `main`, GitHub Actions executes Maven compilation, unit test suites, Flake8 linting for Python, and Trivy container vulnerability scanning.
  2. **Image Registry (ACR):** Successful builds generate multi-arch OCI images tagged with commit SHA and push to Azure Container Registry.
  3. **Continuous Deployment (CD):** GitHub Actions utilizes Azure Workload Identity (OIDC) to deploy updated Helm charts and Kubernetes manifests to AKS with zero downtime.

### Azure Cloud Mapping Matrix

| Architectural Layer | Component | Azure Native Resource | Scaling Strategy | Scaling Trigger |
| :--- | :--- | :--- | :--- | :--- |
| **Client Layer** | Flutter Web & Mobile | Azure Static Web Apps / CDN & Native | Global CDN Distribution | Global edge traffic distribution |
| **Perimeter Ingress** | Edge WAF & SSL Termination | Azure Application Gateway v2 (AGIC) | Autoscaling (2 to 10 instances) | Inbound TLS connections & WAF load |
| **CI/CD Pipeline** | Automated Build & Deploy | GitHub Actions + Azure Container Registry | Parallel CI runners & OCI registry | Git push / merge events to main |
| **Cluster Compute** | Microservices Host | Azure Kubernetes Service (AKS Cluster) | Cluster Autoscaler (VM nodes) | Pod scheduling CPU/memory limits |
| **API Gateway Pods** | Spring Cloud Gateway (:8080) | AKS Deployment (`gateway-service`) | HPA (2 to 10 replicas) | CPU > 70% or concurrent RPS |
| **Account Pods** | Identity & Auth (:8081) | AKS Deployment (`account-service`) | HPA (2 to 6 replicas) | Inbound login / refresh RPS |
| **Orchestration Pods** | Core Remittance (:8082) | AKS Deployment (`ledger-mutation-engine`) | HPA (2 to 8 replicas) | SLA <= 200 ms and queue backlog |
| **Risk Engine Pods** | Python Fraud Analytics (:8084) | AKS Deployment (`risk-engine`) | HPA (2 to 6 replicas) | Evaluation request backlog depth |
| **Notification Pods** | Email & 2FA OTP (:8083) | AKS Deployment (`notification-service`) | KEDA (Event-Driven Autoscaler) | Event Hubs consumer topic lag |
| **Database & Ledger** | Operational State & Audit Vault | Azure SQL Database (Ledger Tables) | Compute Autoscale & Storage Autogrow | Transaction IOPS and ledger append rate |
| **In-Memory Cache** | RTR, Token Blacklist & OTP | Azure Cache for Redis (Standard C1 :6380) | Memory capacity scaling | Cache memory watermark (>75%) |
| **Event Streaming** | Outbox Async Message Bus | Azure Event Hubs (Kafka Head :9093) | Dedicated partition scaling | 6 dedicated chronological partitions |
| **Telemetry & APM** | Metrics, Traces & Logs | Datadog Agent DaemonSet (:8126 / :4318) | DaemonSet on every AKS node | Real-time APM span & log volume |

---

## 8. Explicit Out-of-Scope Exclusions (Scope Boundaries)

1. **Physical Temenos T24 Mainframe License:** Simulated via OFSCore loopback socket formatting and transaction logging.
2. **Paid Cellular SMS Telephony:** Replaced with authenticated HTML email delivery via MailHog/SMTP.
3. **External Card Rails & Interbank Switches:** BancNet, SWIFT, Visa, Mastercard, and InstaPay clearing APIs are excluded.
4. **Multi-Region Cloud Failover:** Architecture is deployed to a single Azure region VNet; active-active multi-continental disaster recovery is out of scope.
5. **App Store Publishing:** Native mobile client is demonstrated in local emulators and test devices without Apple/Google store listings.
6. **Government Biometric KYC APIs:** Real-world facial recognition and passport OCR are represented through administrative approval workflows.
7. **Production ML Model Training:** Risk engine uses rule-based heuristic calculations, avoiding live neural network GPU training.
