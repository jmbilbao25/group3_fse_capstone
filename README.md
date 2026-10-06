# Integrated Capstone: Omnichannel Real-Time Remittance & Fraud Screening

Definitive Architecture Specification, Engineering Decisions, and Developer Source of Truth.

---

## 1. System Architecture Overview

The platform is an enterprise-grade omnichannel remittance pipeline featuring perimeter edge routing, asynchronous fraud risk screening, simulated core banking settlement, dual-storage relational accounting, and distributed telemetry.

Customers submit transactions through a unified **Flutter multiplatform client** running on mobile (with hardware-backed KeyStore and Keychain encryption) or desktop web browsers (compiled via CanvasKit / Wasm for 100% visual and functional parity). Inbound traffic is scrubbed at the perimeter gateway, evaluated against real-time fraud heuristics in Python within a strict 200 ms SLA, routed through transaction value thresholds (including bound hardware biometrics or out-of-band push authorization under BSP Circular 1213), and committed under deterministic row locks before appending write-once compliance records.

In local development, the platform runs via Docker Compose with Oracle XE and PostgreSQL. In cloud production, the architecture deploys natively to Microsoft Azure using **Azure Kubernetes Service (AKS)**, **Azure SQL Database with Ledger tables** (consolidating live state and cryptographic audit trails into a single engine), **Azure Container Registry (ACR)**, **Azure Event Hubs**, and an automated **GitHub Actions CI/CD pipeline**.


<img width="2181" height="1027" alt="image" src="https://github.com/user-attachments/assets/98ad3672-4878-47b7-b4d8-a774faad1883" />


### Interactive Architecture Specifications
* **Local Docker Container Architecture:** Delivered at [`capstone2_architecture.html`](file:///c:/Users/JLB83807/The%20Vault/workspaces/FSE-Capstone/capstone2_architecture.html)
* **Azure Cloud Scaling & Multi-Tier Load Balancing:** Delivered at [`capstone2_azure_scaling.html`](file:///c:/Users/JLB83807/The%20Vault/workspaces/FSE-Capstone/capstone2_azure_scaling.html)

---

## 2. Core Architectural Decisions (ADRs)

### ADR-01: Omnichannel Flutter Client with Hardware Credential Hardening
* **Decision:** Replace disparate web and mobile stacks with a single cross-platform Flutter codebase targeting iOS, Android, and Web (CanvasKit / Wasm on port 3000).
* **Rationale:** Guarantees 100% UI layout and business logic parity between platforms. Eliminates synchronization lag for financial validations, currency inputs, and error states.
* **Security & Resilience:**
  * Uses `flutter_secure_storage` to store access JWTs and session tokens in native hardware-backed keystores (Android KeyStore with AES-256 GCM on Android; iOS Keychain on Apple devices).
  * Implements a client-side fail-fast circuit breaker via an HTTP interceptor. If the gateway times out or drops offline, the client app immediately renders an active "Service Temporarily Unavailable" screen instead of freezing the interface.

### ADR-02: Perimeter Edge Routing, Rate Limiting & Access Blacklisting
* **Decision:** All client traffic enters through Spring Cloud Gateway on port 8080. Internal microservices (ports 8081, 8082, 8083, 8084) are stripped of public host bindings and run on a private Docker bridge network (`banking-net`).
* **Rate Limiting:** Gateway integrates a Redis-backed token-bucket filter (`replenishRate: 10`, `burstCapacity: 20`). Clients firing more than 10 requests per second are dropped at the edge with HTTP 429 Too Many Requests.
* **Instant Logout & Blacklisting:** When a user logs out, the unique JWT identifier (`jti`) is written to Redis (`blacklist:jti:<jti>`) for the remainder of its 15-minute lifespan. The Gateway checks this key on every incoming request, revoking sessions instantly at the perimeter.

### ADR-03: Refresh Token Rotation (RTR) & Automated Breach Purge
* **Decision:** Single-use refresh tokens with family tracking inside Redis.
* **Mechanics:**
  * User login issues a short-lived access JWT (15-minute TTL) and an opaque refresh token (`rt_<uuid>`) stored in Redis with session metadata and a 7-day TTL.
  * Refresh calls (`POST /api/v1/auth/refresh`) revoke the presented refresh token immediately and issue a new pair, recording the rotation inside the session's token family set (`token_family:<sessionId>`).
  * If an attacker attempts to replay a previously revoked refresh token, Redis triggers immediate breach detection (`purgeEntireTokenFamily`). The system purges all active refresh tokens associated with that session family, terminates the compromised session, and returns HTTP 401 Unauthorized.

### ADR-04: Two-Stage Transfer Risk Engine (S2 Tabular and NanoJev Threat Synthesis)
* **Decision:** Deploy an independent Python risk microservice (`risk-service`) on port 8084 utilizing a two-stage evaluation pipeline:
  * **Stage A (Synchronous < 30 ms):** Evaluates deterministic Gate 0 rules (impossible travel velocity > 1,000 km/h, device tampering, mock location) and an XGBoost tabular model (S2) assessing 40+ behavioral and velocity features. Decisions (`ALLOW`, `ADVISORY_WARNING`, or `BLOCK`) return within a strict p99 < 200 ms SLA under load.
  * **Stage B (Synchronous-Bounded, 1500 ms Timeout):** When a transfer presents device threat telemetry (remote-access tools like AnyDesk, active voice call state, purpose-payee mismatch) or a user memo and is not blocked, the orchestrator triggers threat synthesis. A quantized language model (NanoJev, based on Qwen2.5-0.5B INT8 ONNX with calibrated temperature T*=7.12) synthesizes the threat narrative and assigns an advisory warning modal with customer friction options (Cancel, 10-Minute Hold, or Proceed).
  * **Escalate-Only Safety Invariant:** Enforced via `enforce_escalate_only()`, guaranteeing $\text{RiskTier}(a_1) \ge \text{RiskTier}(a_0)$ where `ALLOW` (0) < `ADVISORY_WARNING` (1) < `REQUIRE_2FA` (2) < `BLOCK` (3). The language model can escalate to friction or step-up authentication, but can never weaken an S2 decision or bypass security blocks.
  * **Asynchronous Audit & AMLC Reporting:** The orchestrator fires event records (`POST /risk/events`) asynchronously. The service logs immutable JSONL audit records, populates the analyst triage queue, and automatically drafts Suspicious Transaction Reports (STR/SAR) in Markdown for Anti-Money Laundering Council (AMLC) compliance review.

#### Orchestrator to Risk Engine Service Contract (`POST /risk/stage-a`)

To evaluate transfers, the orchestrator (`ledger-mutation-engine`) supplies transaction parameters, client telemetry, device binding identity, and threat indicators:

```json
{
  "transaction_id": "TX-1001",
  "user_id": "USR-1001",
  "account_id": "ACC-100001",
  "target_account_id": "ACC-200002",
  "amount": 15000.00,
  "currency": "PHP",
  "memo": "Payment for goods",
  "device_id": "DEV-IPHONE-01",
  "is_primary_device": true,

  "latitude": 14.5995,
  "longitude": 120.9842,
  "ip_address": "120.28.0.1",
  "remote_app_active": true,
  "active_call": true,

  "rooted": false,
  "hooking": false,
  "emulator": false,
  "mock_location": false,
  "is_vpn": false,

  "payee_age_days": 180.0,
  "new_payee": false
}
```

The Risk Engine returns:
- `decision_id`: Unique correlation reference string.
- `a0`: Base tabular decision (`ALLOW`, `ADVISORY_WARNING`, or `BLOCK`).
- `threat_context_present`: Boolean indicating whether remote tools, active calls, or mismatches were detected.
- `memo_check_required`: Boolean indicating whether Stage B threat evaluation should be invoked.
- `auth_method`: Assigned authorization method (`BIOMETRIC_PRIMARY`, `PUSH_NOTIFICATION_PRIMARY`, `STEP_UP_BIOMETRIC_PLUS_MPIN`, `STEP_UP_PUSH_PLUS_MPIN`, or `NONE_BLOCKED`).

Orchestrator integration rules:
1. When `a0 == "BLOCK"`, abort mutation immediately and reject the transfer with zero bypass permitted.
2. When `threat_context_present` or `memo_check_required` is true, invoke `POST /risk/stage-b`. If Stage B assigns `ADVISORY_WARNING`, render the contextual friction modal.
3. When `a0 == "ALLOW"` and context is clean, execute local hardware biometric verification on Primary Device (or push notification on Secondary Device) before ledger settlement.
4. On timeout (1,500 ms limit), fall back safely to Stage A action $a_0$ without dropping customer transactions.

### ADR-05: Regulatory Authentication Controls & Cryptographic Device Binding (BSP Circular 1213: Zero SMS OTP)
* **Decision:** Enforce multi-tier authentication with cryptographic device binding and strictly zero SMS OTP for transactions:
  * **Zero SMS OTP for Transactions:** In accordance with Bangko Sentral ng Pilipinas (BSP) Circular 1213, SMS OTP is restricted strictly to initial user onboarding and new device registration. No payment or risk decision may be verified or bypassed via SMS OTP.
  * **Primary Device Authorization:** Transfers initiated on the customer's cryptographically bound Primary Device require local hardware Biometrics (Face ID or Fingerprint via native KeyStore / Keychain).
  * **Secondary Device Authorization:** Transfers initiated on an unbound Secondary Device (Web Banking or Tablet) trigger an Out-of-Band (OOB) Push Notification to the registered Primary Device for biometric confirmation.
  * **Routine Transfers (PHP 0.01 to PHP 50,000.00):** Clean transfers (`ALLOW`) require local hardware biometric confirmation before committing the ledger mutation.
  * **Elevated Value / Step-Up (Above PHP 50,000.00):** Enforces step-up authentication requiring hardware biometric confirmation plus transaction MPIN.
  * **PHP 500,000.00 and above (AMLA Covered):** Same step-up flow, plus an automated Covered Transaction Report (CTR) regulatory notification generated for compliance records.

### ADR-06: Simulated Core Banking Hook (Temenos T24 OFSCore)
* **Decision:** Model legacy core banking mainframe interoperability by serializing approved transactions into authentic raw OFSCore protocol strings:
  `FUNDS.TRANSFER,AUTH/I/PROCESS,//PH100223,TXN.REF=...,DEBIT.ACCT=...,CREDIT.ACCT=...`
* **Execution:** Strings are transmitted across a local loopback line to a mock core listener. The mock verifies syntax parsing and returns simulated confirmations (`TXN-XXXX//1/SUCCESS`), proving mainframe compatibility without expensive licensing.

### ADR-07: Dual-Storage Ledger Architecture & Strict Financial Precision
* **Decision:** Segregate operational transaction throughput from immutable audit storage across two distinct database environments:
  * **Local Development Environment:**
    * **Oracle Database XE 21c (Master):** Stores live accounts, customer profiles, and balance mutations. Enforces strict financial precision using `NUMBER(18, 4)`. Concurrency is managed via pessimistic row locking (`@Lock(PESSIMISTIC_WRITE)`).
    * **PostgreSQL 16 (Audit Vault):** Houses the append-only journal (`ledger_mutation_audit`). A database trigger (`prevent_audit_tampering`) rejects all SQL `UPDATE` and `DELETE` commands, guaranteeing compliance with legal audit standards.
  * **Azure Native Cloud Environment:**
    * **Azure SQL Database with Ledger Tables:** Consolidates operational throughput and compliance auditing into a single enterprise Azure PaaS engine.
    * **Pessimistic Concurrency:** High-volume transaction mutations acquire row locks using `SELECT ... WITH (UPDLOCK, ROWLOCK)` and `DECIMAL(18, 4)` for strict financial precision, preventing overdrafts.
    * **Cryptographic Tamper-Evidence:** The compliance journal (`ledger_mutation_audit`) uses **Azure SQL Ledger append-only tables** (`LEDGER = ON (APPEND_ONLY = ON)`). Updates and deletes are blocked by the database engine, and transactions are cryptographically linked in SHA-256 blocks with verifiable database digests stored in Azure Confidential Ledger.
  * **Deadlock Prevention:** When moving funds between two accounts, account IDs are sorted lexicographically (`sourceId.compareTo(targetId) < 0 ? sourceId : targetId`). The account with the lower ID is always locked first, guaranteeing deadlock-free concurrency under high-volume load across both Oracle and Azure SQL.

### ADR-08: Transactional Outbox Pattern with Kafka Event Streaming
* **Decision:** Implement the Transactional Outbox pattern (EVT-601) to eliminate distributed transactions (2PC).
* **Mechanics:** Financial mutations write balance changes and outbox event records (`outbox_events`) within the exact same atomic database transaction. A dedicated polling worker (`OutboxRelayScheduler`) runs every 2 seconds, publishing pending events to Apache Kafka KRaft (:9092) or Azure Event Hubs (:9093) with `acks=all`. Downstream services (Notification Service, Audit Vault) consume asynchronously.

### ADR-09: Six In-Memory State Namespaces in Redis
* **Decision:** Redis operates as a multi-purpose security and session engine:
  1. `blacklist:jti:<jti>`: Blacklisted access tokens (TTL equal to remaining JWT lifetime).
  2. `refresh_token:<tokenId>`: RTR metadata with session details (7-day TTL).
  3. `token_family:<sessionId>`: Set of active tokens in a session family for breach purge.
  4. `auth:user-sessions:<userId>`: Set of concurrent user sessions.
  5. `otp:<transferId>`: 6-digit verification codes for transfers > PHP 50,000.00 (5-minute TTL).
  6. `account:balance:<accountId>`: Read-through cached balances (30-second TTL), evicted on mutation.
* **Cloud Strategy:** In Azure, Redis runs via **Azure Cache for Redis** (Standard C1 tier with TLS on port 6380) or as a containerized StatefulSet inside AKS with persistent volume claims, providing sub-5ms latency and full VNet private endpoint integration.

### ADR-10: End-to-End Observability with Datadog APM
* **Decision:** Instrument all microservices with OpenTelemetry and `micrometer-tracing-bridge-otel`.
* **Telemetry Flow:** Propagates W3C `traceparent` headers across Flutter clients, API Gateway, Account Service, Orchestrator, and Notification Service. Spans export over OTLP directly to the Datadog Agent container or Kubernetes DaemonSet (`:8126` APM and `:4318` OTLP), generating live request waterfall graphs, p95/p99 latency metrics, and correlated logs.

### ADR-11: Azure Native Cloud Architecture, AKS & GitHub Actions CI/CD Pipeline
* **Decision:** Cloud production deploys natively to Microsoft Azure using Azure Kubernetes Service (AKS), Azure Container Registry (ACR), Azure Application Gateway v2 with WAF, and an automated GitHub Actions CI/CD pipeline.
* **Cloud Infrastructure Seams:**
  * **Compute (AKS):** Microservices (`gateway-service`, `account-service`, `ledger-mutation-engine`, `notification-service`, `risk-engine`) run as containerized pods managed by Kubernetes Deployments with Horizontal Pod Autoscalers (HPA) configured for CPU (>70%) and request concurrency.
  * **Ingress & WAF:** Azure Application Gateway v2 with Azure Web Application Firewall (WAF) terminates SSL (:443) and routes traffic to Spring Cloud Gateway pods via Application Gateway Ingress Controller (AGIC).
  * **Event Streaming:** Azure Event Hubs provides managed Kafka API compatibility on port 9093 with zero code changes required in the outbox relay.
  * **Automated CI/CD Pipeline:** GitHub Actions automates the full path from code commit to cluster deployment:
    1. **Continuous Integration (CI):** On push or PR to `main`, runs Maven compilation, unit test suites, Flake8 linting for Python, and Trivy vulnerability scans.
    2. **Container Registry (ACR):** Multi-arch Docker images are built and pushed to private Azure Container Registry with commit SHA tagging.
    3. **Continuous Deployment (CD):** GitHub Actions utilizes Azure Workload Identity (OIDC federated credentials) to deploy updated Helm charts and Kubernetes manifests to the AKS cluster with zero downtime.

---

## 3. Chaos Engineering & Defense Protocols

Students must test and defend against three specific failure scenarios during evaluation:

| Protocol | Chaos Injection Scenario | Expected System Defense & SLA | Verification Proof |
| :--- | :--- | :--- | :--- |
| **1. Database Degradation** | Inject 3000ms latency or choke Oracle XE connection pool via Docker. | Resilience4j circuit breaker on API Gateway / Orchestrator trips from CLOSED to OPEN; client traffic falls back to Redis cached balances (`account:balance:*`). | Client receives cached balance in <20ms with `cached: true` header rather than an HTTP 500 error. |
| **2. Risk Engine Interruption** | Manually stop the Python Risk Engine container (`docker stop risk-engine`) during active transfer execution. | Spring Boot Orchestrator identifies connection loss within the strict **≤ 200 ms SLA window**, trips its internal fallback, and cleanly aborts the transfer. | Transaction is rejected cleanly with HTTP 503 / 422; ledger in Oracle XE remains untouched (zero partial writes). |
| **3. Perimeter Rejection Check** | Launch automated script attacks directly against internal microservice ports (`:8081`, `:8082`, `:8083`, `:8084`, `:1521`, `:5432`). | Hardened Docker bridge (`banking-net`) network isolation blocks all direct connection attempts; only port 8080 (the Gateway) is reachable from external callers. | External calls directly to internal ports receive `Connection refused`, proving traffic can only enter through the security proxy. |

---

## 4. Networking and Port Allocation Matrix

Every container attaches to the internal bridge network `banking-net`. Only perimeter and management consoles expose host ports:

| Service / Container | Container Name | Host Port | Internal Port | Protocol | Purpose & Architectural Role |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **Flutter Web Client** | `flutter-web-portal` | `3000` | `80` | HTTP | CanvasKit/Wasm web portal with 100% UI parity with mobile client |
| **API Gateway** | `gateway-service` | `8080` | `8080` | HTTP / REST | Single perimeter entry, token-bucket rate limiter, JWT validation |
| **Account Service** | `account-service` | *Internal* | `8081` | HTTP / REST | KYC onboarding, user profiles, JWT issuance, Refresh Token Rotation |
| **Orchestration Engine** | `ledger-mutation-engine`| *Internal* | `8082` | HTTP / REST | Transaction orchestration, row locks, soft holds, outbox relay |
| **Notification Service** | `notification-service` | *Internal* | `8083` | HTTP / REST | Kafka event listener, email receipts, 2FA OTP generation and dispatch |
| **Fraud Risk Engine** | `risk-service` | *Internal* | `8084` | HTTP / REST | Two-stage S2 XGBoost (Stage A) + NanoJev threat synthesis & advisory modal (Stage B) |
| **Redis Cache** | `redis-cache` | `6379` | `6379` | RESP / TCP | RTR token families, JWT blacklist, 5-minute OTP, rate limiting |
| **Oracle Database XE** | `oracle-xe-master` | `1521` | `1521` | Oracle TNS | Operational relational state (`XEPDB1`), row locks, outbox events |
| **PostgreSQL Audit** | `postgres-audit-vault`| `5433` | `5432` | PostgreSQL | Write-once append-only compliance audit journal (`banking_audit`) |
| **Apache Kafka** | `kafka-broker` | `9092` | `9092` | PLAINTEXT | KRaft cluster event commit log (`banking.transfers.events`) |
| **Kafka Web Console** | `kafka-ui` | `8085` | `8080` | HTTP | Web console for topics, consumer groups, and message inspection |
| **MailHog SMTP** | `mailhog-smtp` | `8025` / `1025` | `8025` / `1025` | HTTP / SMTP | Mock email testing inbox UI (`:8025`) and SMTP receiver (`:1025`) |
| **Adminer Web GUI** | `db-adminer` | `8088` | `8080` | HTTP | Web SQL console for Oracle XE and PostgreSQL databases |
| **Datadog Agent** | `dd-agent` | `8126` / `8125` | `8126` / `8125` | HTTP / UDP | APM trace waterfalls (`:8126`), DogStatsD metrics (`:8125`), container logs |

*Note: In the hardened production profile, host ports for internal backend microservices (`8081`, `8082`, `8083`, `8084`) are omitted, ensuring all external traffic enters via Gateway port `8080`.*

### Azure Native Cloud Service Mapping

| Layer / Role | Cloud Component | Azure Native Resource | Scaling & High-Availability Model |
| :--- | :--- | :--- | :--- |
| **Client Portal** | Flutter Web & Mobile | Azure Static Web Apps / CDN & Native | Globally distributed static asset edge caching |
| **Perimeter Ingress** | Edge WAF & SSL Termination | Azure Application Gateway v2 (AGIC) | Autoscaling 2 to 10 instances with OWASP 3.2 core rules |
| **CI/CD Pipeline** | Automated Build & Deploy | GitHub Actions + Azure Container Registry (ACR) | Multi-arch OCI image build, Trivy scan, OIDC deploy |
| **Cluster Compute** | Microservices Host | Azure Kubernetes Service (AKS Cluster) | System and user node pools with HPA autoscaling |
| **API Gateway Pods** | Spring Cloud Gateway (:8080) | AKS Deployment (`gateway-service`) | HPA: 2 to 10 pods on CPU > 70% or request rate |
| **Account Pods** | Identity & Auth (:8081) | AKS Deployment (`account-service`) | HPA: 2 to 6 pods with JWT/RTR key rotation |
| **Orchestration Pods** | Core Remittance (:8082) | AKS Deployment (`ledger-mutation-engine`) | HPA: 2 to 8 pods with SLA ≤ 200 ms timeout |
| **Risk Engine Pods** | Python Fraud Analytics (:8084) | AKS Deployment (`risk-service`) | HPA: 2 to 6 pods with two-stage S2 + NanoJev threat synthesis |
| **Notification Pods** | Email & 2FA OTP (:8083) | AKS Deployment (`notification-service`) | KEDA scaled by Event Hubs topic consumer lag |
| **Database & Ledger** | Operational State & Audit Vault | Azure SQL Database (General Purpose) | Pessimistic `UPDLOCK, ROWLOCK` + Azure SQL Ledger |
| **In-Memory Cache** | RTR, Token Blacklist & OTP | Azure Cache for Redis (Standard C1 :6380) | Managed TLS in-memory cache with sub-5ms latency |
| **Event Streaming** | Outbox Async Message Bus | Azure Event Hubs (Kafka Head :9093) | Dedicated partitioned event streaming with auto-inflate |
| **Telemetry & APM** | Metrics, Traces & Logs | Datadog Agent DaemonSet (:8126 / :4318) | DaemonSet on every AKS node streaming OTLP traces |

---

## 5. Team Engineering Ownership & Track Allocation

The project is executed across three official Capstone tracks mapped to a 100-point evaluation model:

| Member | Track & Specialization | Key Codebase Ownership & Deliverables | Evaluation Pillar |
| :--- | :--- | :--- | :--- |
| **Zel** | Technical Lead, Core Mutation Engine & Ledger Testing | `BalanceMutationService.java`: row locking (Oracle XE & Azure SQL `UPDLOCK, ROWLOCK`), soft holds, transactional outbox, concurrency test harnesses, **Chaos Scenario 1** (DB degradation). | **Pillar 2 & 4** (Backend Logic & Chaos 1) |
| **Maye** | Lead Risk Analytics Engineer & Scrum Backlog Lead | `backend/risk-service`: Gate 0 + S2 sync scoring (p99 < 200ms SLA), NanoJev INT8 threat synthesis, prompt caching, JIRA backlog tracking, **Chaos Scenario 2** (Risk service kill). | **Pillar 1 & 4** (JIRA & Chaos 2) |
| **JM** | Lead Flutter Architect & Datadog Observability | `flutter_client`: cross-platform Web/Mobile parity, client circuit breaker, Datadog APM Agent integration, W3C trace waterfalls, E2E testing passes. | **Pillar 3 & 4** (UI & Observability) |
| **Wax** | Lead Core Banking Integration Engineer (Temenos T24) | `OfsMessageBuilder.java`, `TemenosLoopbackClient.java`: raw OFSCore serialization (`FUNDS.TRANSFER...`), local loopback simulation server. | **Pillar 2** (T24 Core Banking Hook) |
| **Mae** | Flutter Mobile Engineer & Agile Scrum Coordinator | `flutter_client`: native KeyStore/Keychain encryption (`flutter_secure_storage`), responsive forms, JIRA sprint burn-down, evaluation demo runbook. | **Pillar 1 & 3** (JIRA & Mobile Client) |
| **Angel** | Lead API Gateway, Auth & Identity Security Engineer | `gateway-service`: routes, Redis rate limiting (>10 rps), `account-service`: login, JWT access tokens, RTR token rotation, RFC-7807 error format, GitHub Actions CI/CD lead. | **Pillar 1 & 2** (API & Perimeter Auth) |
| **Mayor** | Cloud Infrastructure Security, AKS & Core Systems Co-Lead | `docker-compose.yml`: hardened bridge network, Azure SQL Ledger & PostgreSQL triggers, AKS deployment manifests and Helm charts, T24 co-owner, **Chaos Scenario 3** (Perimeter attack). | **Pillar 1 & 4** (DevSecOps & Chaos 3) |

---

## 6. Daily Implementation Schedule (Days 1 to 9)

```
Day 1: Domain Definition, API Contracts & JIRA Initialization
       - Map unified API endpoints in API_SPECIFICATION.md; initialize JIRA sprint cards across the 3 tracks.

Day 2: Multi-Tier Database Setup & Connection Pool Hardening
       - Initialize Oracle XE operational tables and PostgreSQL append-only audit triggers; configure HikariCP pool caps (30).

Day 3: Core Remittance Engine & Asynchronous Risk Analytics
       - Code the Spring Boot remittance service alongside the Python FastAPI risk scoring tool; wire non-blocking HTTP loop.

Day 4: Perimeter Security, Temenos T24 Hook & Rate Limiting
       - Configure JWT validation rules, Redis RTR token families, and serialize raw OFSCore strings to the loopback listener.

Day 5: Cloud DevSecOps Containerization & Network Hardening
       - Build multi-stage Dockerfiles; lock down docker-compose network bridge isolation; configure Datadog APM tracing.

Day 6: Flutter Multiplatform Assembly & Client-Side Resilience
       - Assemble unified Flutter screens (Web and Mobile); configure native hardware KeyStore/Keychain token storage; test circuit breaker.

Day 7: Chaos Engineering Protocols & Failure Injection Checkpoint
       - Execute end-to-end integration passes; run the 3 chaos failure injection scripts (DB choke, Risk kill, Perimeter attack).

Day 8: Final Presentation & Live Integrated Demonstration
       - Demonstrate live remittance routing: Flutter Client -> Gateway -> Risk Scoring -> T24 Simulation -> Oracle Commit -> Postgres Audit.

Day 9: Final Comprehensive Examination & Project Sign-Off
       - Technical grading defense, comprehensive knowledge examination, and official capstone evaluation sign-offs.
```

---

## 7. Developer Quick Start Guide

### Prerequisites
1. **Docker Desktop** (version 4.25+)
2. **Java 21 JDK** (configured in your `PATH`)
3. **Flutter SDK 3.x & Dart 3.x**
4. **Python 3.11+** (for local Risk Engine development)
5. **Maven** (bundled `.\mvnw.cmd` included in the repository)

### Launching the Platform via Docker Compose

```powershell
# 1. Package backend microservice artifacts
cd backend
.\mvnw.cmd clean package -DskipTests
cd ..

# 2. Build and launch all 14 containerized services
docker compose -f infrastructure/docker-compose.yml up -d --build
```

### Local Development Workflow (Running Services Locally)

If you prefer developing with live reload on host machines:

```powershell
# Step 1: Start backing infrastructure containers
docker compose -f infrastructure/docker-compose.yml up -d oracle-xe-master postgres-audit-vault redis-cache kafka-broker mailhog kafka-ui adminer dd-agent

# Step 2: Start microservices (in separate terminals)
# Terminal 1: API Gateway (:8080)
cd backend/gateway-service && ..\mvnw.cmd spring-boot:run

# Terminal 2: Account & Identity Service (:8081)
cd backend/account-service && ..\mvnw.cmd spring-boot:run

# Terminal 3: Orchestration & Ledger Engine (:8082)
cd backend/ledger-mutation-engine && ..\mvnw.cmd spring-boot:run

# Terminal 4: Notification Service (:8083)
cd backend/notification-service && ..\mvnw.cmd spring-boot:run

# Terminal 5: Python Risk Engine (:8084)
cd backend/risk-service && python -m app.server

# Step 3: Run Flutter Web Portal
cd flutter_client
flutter run -d chrome --web-port 3000
```

### Database Web Console (Adminer Credentials)

Adminer provides a browser-based SQL client to inspect and query both the Oracle XE operational database and the PostgreSQL audit vault.

* **Adminer Web URL:** `http://localhost:8088`

#### Oracle Database XE 21c (Master Operational Store)

When logging into Adminer, fill in the following fields:

| Field | Value | Notes |
| :--- | :--- | :--- |
| **System** | `Oracle (beta)` | Select from the system dropdown |
| **Server** | `oracle-xe-master/XEPDB1` | Uses container service name on `banking-net` |
| **Username** | `fse_user` | Application schema owner (or `SYSTEM` for DBA access) |
| **Password** | `fse_password` | For `fse_user` (or `Password123#` for `SYSTEM`) |
| **Database** | `XEPDB1` | Pluggable database name |

For external database tools (DBeaver, SQL Developer) connecting from the host machine:
* Host: `localhost`, Port: `1521`, Service Name: `XEPDB1`, User: `fse_user`, Password: `fse_password`

#### PostgreSQL 16 (Immutable Audit Vault)

When logging into Adminer, fill in the following fields:

| Field | Value | Notes |
| :--- | :--- | :--- |
| **System** | `PostgreSQL` | Select from the system dropdown |
| **Server** | `postgres-audit-vault` | Or `postgres-audit-vault:5432` on `banking-net` |
| **Username** | `audit_user` | Audit vault database user |
| **Password** | `audit_password` | Configured password |
| **Database** | `banking_audit` | Target audit database |

For external database tools (DBeaver, pgAdmin, psql) connecting from the host machine:
* Host: `localhost`, Port: `5433`, Database: `banking_audit`, User: `audit_user`, Password: `audit_password`

---

## 8. Repository Structure

```text
.
├── README.md                           # Master single source of truth & architectural decisions
├── API_SPECIFICATION.md                # REST API payloads, validation rules, and error codes
├── ERD.md                              # Entity-Relationship diagram and database data dictionary
├── JIRA_BACKLOG.md                     # Sprint user stories, story points, and EARS criteria
├── capstone2_architecture.html         # Interactive Archify diagram (Local Docker Mesh)
├── capstone2_azure_scaling.html        # Interactive Archify diagram (Azure Cloud Architecture)
├── docs/
│   ├── CAPSTONE2_SCOPE.md              # Formal scope boundaries, Redis namespaces & Azure decisions
│   ├── SPRINT_PLAN.md                  # Day-by-day 9-day implementation schedule & rubric points
│   ├── TEAM_RESPONSIBILITY_MATRIX.md   # Member ownership, pod breakdown, and 100-point rubric
│   └── TEMENOS_T24_INTEGRATION_GUIDE.md# OFSCore message format and loopback mock guide
├── infrastructure/
│   ├── docker-compose.yml              # Orchestration for all microservices, databases, and caches
│   ├── oracle/
│   │   └── init.sql                    # Oracle XE 21c DDL, outbox tables, and seed accounts
│   ├── postgres/
│   │   └── init.sql                    # PostgreSQL audit vault DDL and anti-tamper trigger
│   └── datadog/                        # Datadog Agent configuration (APM, OTLP traces, logs)
├── flutter_client/                     # Unified Flutter Web & Mobile Application
│   ├── lib/
│   │   ├── screens/                    # Dashboard, transfer flow, OTP verification modal
│   │   ├── services/                   # Dio HTTP client, circuit breaker interceptor
│   │   └── security/                   # Hardware KeyStore / Keychain storage abstraction
└── backend/
    ├── pom.xml                         # Aggregator POM (Spring Boot 3.3.5, Java 21)
    ├── common-contracts/               # Shared DTOs, enums, events, and exceptions
    ├── gateway-service/                # Spring Cloud Gateway, Redis rate limiter, JWT filter
    ├── account-service/                # KYC onboarding, JWT token issuance, RTR token rotation
    ├── ledger-mutation-engine/         # Balance mutation orchestrator, locks, T24 hook, outbox
    ├── notification-service/           # Kafka consumer, email receipts, 2FA OTP, spool buffer
    └── risk-service/                   # Decoupled S2 XGBoost and NanoJev second-look risk service
```
