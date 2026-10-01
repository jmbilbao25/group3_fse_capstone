# Integrated Capstone: Team Responsibility Matrix & Work Breakdown

## 1. Engineering Pods & Team Structure

To ensure balanced workload distribution across the 7 team members and complete alignment with the Integrated Capstone 100-point evaluation matrix, the team is organized into **three specialized engineering pods**:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                     INTEGRATED CAPSTONE TEAM ORGANIZATION                       │
├──────────────────────────┬──────────────────────────┬───────────────────────────┤
│ Pod 1: Core Banking &    │ Pod 2: Perimeter, Cloud  │ Pod 3: Flutter UI &       │
│ Ledger Settlement        │ Security & Fraud Scoring │ Telemetry Observability   │
├──────────────────────────┼──────────────────────────┼───────────────────────────┤
│ • Zel (Tech Lead)        │ • Maye (Lead Risk Eng)   │ • JM (Lead Flutter & APM) │
│ • Wax (Core Eng Lead)    │ • Angel (Lead Security)  │ • Mae (Flutter & Agile)   │
│ • Mayor (Core & DevSec)  │ • Mayor (Co-Lead DevSec) │ • Maye (Co-Lead Agile)    │
└──────────────────────────┴──────────────────────────┴───────────────────────────┘
```

---

## 2. Detailed Member-by-Member Ownership Breakdown

### 1. Zel: Technical Lead, Core Mutation Engine & Ledger Testing
* **Primary Role:** Full-Stack Track Lead & Relational Consistency Owner
* **Core Responsibilities:**
  * Implements the core transaction flow in `ledger-mutation-engine` (`BalanceMutationService`).
  * Enforces deterministic lock ordering (locking lower account ID first) with `SELECT ... FOR UPDATE` in Oracle XE and `SELECT ... WITH (UPDLOCK, ROWLOCK)` in Azure SQL to prevent deadlocks and overdrafts.
  * Manages the soft hold placement and release flow for high-value transfers (> PHP 50,000.00).
  * Implements the transactional outbox pattern to relay events to Kafka / Azure Event Hubs without distributed locking overhead.
  * Owns the core backend unit test suite, concurrency multi-threading test harnesses, and Chaos Protocol 1 (database degradation recovery).
* **Specific Codebase Files:**
  * `backend/ledger-mutation-engine/src/main/java/com/bank/ledger/engine/service/BalanceMutationService.java`
  * `backend/ledger-mutation-engine/src/main/java/com/bank/ledger/engine/controller/BalanceMutationController.java`
  * `backend/ledger-mutation-engine/src/main/java/com/bank/ledger/engine/outbox/OutboxRelayScheduler.java`
  * `backend/ledger-mutation-engine/src/test/java/...` (Concurrency & lock unit tests)
* **Chaos Engineering & Demo Duty:** Leads the Database Degradation Recovery test (connection throttling and Resilience4j circuit breaker verification).

---

### 2. Maye: Lead Risk Analytics Engineer & Scrum Backlog Lead
* **Primary Role:** Fraud Risk Analytics Lead & Agile Backlog Coordinator
* **Core Responsibilities:**
  * Designs and builds the asynchronous Python Risk Engine (`backend/risk-engine`) using FastAPI and `asyncio`.
  * Implements transfer risk heuristics: velocity checks (frequency of transfers per minute), amount deviation from account history, and recipient risk flags.
  * Enforces the hard 0.85 threshold rule: returns structured evaluation payloads where scores > 0.85 mandate immediate transfer rejection.
  * Optimizes the non-blocking execution loop to guarantee response times strictly within the ≤ 200 ms SLA.
  * Co-owns JIRA sprint initialization, writing user stories with formal EARS criteria, story point estimation, and task burn-down tracking.
* **Specific Codebase Files:**
  * `backend/risk-engine/main.py` (FastAPI app and asyncio route handlers)
  * `backend/risk-engine/evaluator.py` (Risk heuristic algorithms and math)
  * `backend/risk-engine/Dockerfile` (Lightweight Python container build)
  * `JIRA_BACKLOG.md` (Sprint epics, cards, story point estimations)
* **Chaos Engineering & Demo Duty:** Leads the Risk Engine Interruption test (killing the container mid-sprint and proving the Spring backend catches connection loss within ≤ 200 ms).

---

### 3. JM: Lead Flutter Architect, Datadog Observability & E2E Testing
* **Primary Role:** Lead Flutter Architect & Observability Specialist
* **Core Responsibilities:**
  * Architects the unified **Flutter cross-platform client** for both Mobile (iOS/Android) and Web (Flutter Web on CanvasKit/Wasm :3000), guaranteeing 100% UI and functional parity.
  * Implements the client-side circuit breaker: catching gateway timeouts and displaying an active "Service Temporarily Unavailable" screen.
  * Integrates the Datadog APM Agent container and AKS DaemonSet (`:8126` APM and `:4318` OTLP), configuring W3C trace context header propagation (`traceparent`) across Flutter HTTP interceptors.
  * Builds custom Datadog dashboards displaying live request waterfalls, p50/p95/p99 latency histograms, and container logs.
  * Orchestrates end-to-end integration testing passes across the entire flow.
* **Specific Codebase Files:**
  * `flutter_client/lib/screens/...` (Unified dashboard, transfer form, OTP verification modal)
  * `flutter_client/lib/services/api_client.dart` (Dio/HTTP interceptor with circuit breaker)
  * `infrastructure/docker-compose.yml` (Datadog agent configuration and labels)
  * `infrastructure/datadog/...` (APM dashboard exports and trace configs)
* **Chaos Engineering & Demo Duty:** Operates the live Datadog monitoring screen during the final presentation, showing the visual request waterfall and latency changes during failure injection.

---

### 4. Wax: Lead Core Banking Integration Engineer (Temenos T24)
* **Primary Role:** Legacy Systems Specialist & Core Integration Lead
* **Core Responsibilities:**
  * Implements the Temenos T24 OFSCore serialization module in Java Spring Boot.
  * Formats approved transactions into authentic raw OFS message strings:  
    `FUNDS.TRANSFER,AUTH/I/PROCESS,//PH100223,TXN.REF=...,DEBIT.ACCT=...,CREDIT.ACCT=...`
  * Develops the local loopback simulation server (internal TCP socket or HTTP loopback listener) simulating the Temenos T24 mainframe.
  * Validates OFS syntax parsing, handles simulated bank branch codes (`//PH100223`), and returns authentic simulated core confirmations (`TXN-XXXX//1/SUCCESS`).
  * Documents the legacy core banking integration seam and data dictionary for evaluation defense.
* **Specific Codebase Files:**
  * `backend/ledger-mutation-engine/src/main/java/com/bank/ledger/engine/t24/OfsMessageBuilder.java`
  * `backend/ledger-mutation-engine/src/main/java/com/bank/ledger/engine/t24/TemenosLoopbackClient.java`
  * `backend/ledger-mutation-engine/src/main/java/com/bank/ledger/engine/t24/mock/T24LoopbackServer.java`
  * `docs/TEMENOS_T24_INTEGRATION_GUIDE.md`
* **Chaos Engineering & Demo Duty:** Proves the OFSCore transmission loop during the live demo and explains core banking mainframe integration to the evaluation board.

---

### 5. Mae: Flutter Mobile Assembly & Agile Scrum Coordinator
* **Primary Role:** Flutter Mobile Engineer & Sprint Coordinator
* **Core Responsibilities:**
  * Implements the native mobile device integration in Flutter: hardware-backed credential protection via `flutter_secure_storage` (iOS Keychain & Android KeyStore).
  * Builds the responsive Flutter widgets ensuring identical look, feel, and typography between mobile touch screens and web browser layouts.
  * Coordinates with JM on client-side retry rules and the fail-fast circuit breaker behavior.
  * Co-owns JIRA task administration with Maye, keeping sub-tasks across Cloud DevSecOps, Mobile, and Full-Stack tracks up to date.
  * Prepares evaluation slide decks, presentation runbooks, and submission deliverables.
* **Specific Codebase Files:**
  * `flutter_client/lib/security/secure_storage.dart` (KeyStore / Keychain abstraction)
  * `flutter_client/lib/widgets/...` (Reusable financial form components)
  * `flutter_client/lib/services/circuit_breaker.dart` (Client-side fail-fast logic)
  * `JIRA_BACKLOG.md` and Capstone Presentation artifacts
* **Chaos Engineering & Demo Duty:** Drives the live Flutter app during the final demo, demonstrating the user journey from login to OTP entry and showing the "Service Temporarily Unavailable" screen when the gateway is disrupted.

---

### 6. Angel: Lead API Gateway, Auth & Identity Security Engineer, CI/CD Lead
* **Primary Role:** Cloud DevSecOps Perimeter Lead & Auth/Identity Architect
* **Core Responsibilities:**
  * Configures the Spring Cloud Gateway (`gateway-service` on port 8080) as the reverse proxy for all inbound traffic.
  * Manages the Account & Authentication Service (`account-service` on port 8081): user registration, login, and signed HMAC-SHA256 JWT access token issuance (15-min TTL).
  * Implements Refresh Token Rotation (`TokenRotationService`) with automatic replay breach detection and token family purging in Redis.
  * Implements the Redis-backed token-bucket filter (`replenishRate: 10`, `burstCapacity: 20`): dropping requests exceeding 10 req/sec with HTTP 429 Too Many Requests.
  * Establishes the automated **GitHub Actions CI/CD pipeline** (`.github/workflows/ci-cd.yml`): automated unit tests, Flake8 linting, Trivy vulnerability scanning, building multi-arch OCI images, and publishing to Azure Container Registry (ACR).
  * Standardizes all error payloads to RFC-7807 Problem Details across all microservices.
  * Maintains and publishes `API_SPECIFICATION.md` and the Postman collection.
* **Specific Codebase Files:**
  * `backend/account-service/src/main/java/com/fse/banking/account/controller/AuthController.java` (Login, Register, Refresh, Logout)
  * `backend/account-service/src/main/java/com/fse/banking/account/security/JwtProvider.java` (JWT token generation & parsing)
  * `backend/account-service/src/main/java/com/fse/banking/account/service/TokenRotationService.java` (RTR & breach containment)
  * `.github/workflows/ci-cd.yml` (GitHub Actions CI/CD automated pipeline)
  * `backend/gateway-service/src/main/resources/application.yml` (Route definitions & rate limits)
  * `API_SPECIFICATION.md` and `postman_collection.json`
* **Chaos Engineering & Demo Duty:** Demonstrates edge rate limiting and JWT validation by firing high-concurrency requests (>10 rps) and proving the gateway returns HTTP 429 while backend microservices remain unburdened.

---

### 7. Mayor: Cloud Infrastructure Security, AKS & Core Systems Co-Lead
* **Primary Role:** Cloud DevSecOps Security Lead & T24 Core Co-Owner
* **Core Responsibilities:**
  * Hardens the Docker Compose environment (`infrastructure/docker-compose.yml`), stripping host port exposures from internal microservices (ports 8081, 8082, 8083, 8084) so only Gateway port 8080 is reachable from the host.
  * Authors the **Azure Kubernetes Service (AKS)** deployment manifests and Helm charts (`infrastructure/k8s/...`) for zero-downtime rolling deployments, network policies, and Horizontal Pod Autoscalers.
  * Implements database compliance security: PostgreSQL triggers (`trg_no_update_delete`) for local dev, and **Azure SQL Ledger append-only table configuration** (`LEDGER = ON (APPEND_ONLY = ON)`) for cloud production.
  * Collaborates with Wax on the Temenos T24 OFSCore loopback socket implementation, error handling, and socket reconnection logic.
  * Builds and executes the automated penetration testing script for Chaos Protocol 3 (Perimeter Rejection Check).
* **Specific Codebase Files:**
  * `infrastructure/docker-compose.yml` (Hardened bridge network & isolated port bindings)
  * `infrastructure/k8s/...` (AKS Deployment, Service, HPA, and Ingress manifests)
  * `infrastructure/postgres/init.sql` & Azure SQL Ledger DDL scripts
  * `backend/ledger-mutation-engine/src/main/java/com/bank/ledger/engine/t24/...`
  * `scripts/chaos/chaos-perimeter-rejection.sh` (or `.ps1`)
* **Chaos Engineering & Demo Duty:** Executes the Perimeter Rejection Check live, proving that automated script attacks targeting internal container ports are completely blocked by network isolation and Kubernetes network policies.

---

## 3. Evaluation Pillar Responsibility Matrix (100-Point Model)

| Evaluation Pillar | Points | Core Deliverables | Primary Owners |
| :--- | :---: | :--- | :--- |
| **Pillar 1: Domain Definition, JIRA & Multi-Tier Database / Ledger** | **25 Pts** | • Unified API contracts & endpoints in `API_SPECIFICATION.md`<br>• JIRA tracking board setup split across 3 roles<br>• Oracle XE schema, Azure SQL Ledger & PostgreSQL triggers<br>• Connection pooling parameters (HikariCP capped at 30) | **Angel** (API)<br>**Maye & Mae** (JIRA)<br>**Zel & Mayor** (Databases & Ledger) |
| **Pillar 2: Backend Business Logic & Perimeter Security** | **25 Pts** | • Spring Boot remittance service with pessimistic row locks<br>• Python asyncio Risk Engine (0.00-1.00 score, ≤200ms SLA)<br>• Temenos T24 OFSCore serialization and loopback hook<br>• JWT validation & RFC-7807 global error coordinator | **Zel** (Remittance Core)<br>**Maye** (Risk Engine)<br>**Wax & Mayor** (T24)<br>**Angel** (Perimeter & Auth) |
| **Pillar 3: Cloud DevSecOps Infrastructure, AKS, CI/CD & Flutter Assembly** | **25 Pts** | • Multi-stage Dockerfiles & AKS manifests/Helm charts<br>• GitHub Actions automated CI/CD pipeline to ACR and AKS<br>• Unified Flutter client (Mobile KeyStore + Web Parity)<br>• Client-side fail-fast circuit breaker ("Service Unavailable")<br>• Datadog APM Agent request tracing & waterfall dashboards | **Mayor & Angel** (AKS & CI/CD DevSecOps)<br>**Mae & JM** (Flutter Clients)<br>**JM** (Datadog Observability) |
| **Pillar 4: Chaos Engineering Protocols & Live Demo Defense** | **25 Pts** | • Scenario 1: Database degradation recovery test<br>• Scenario 2: Risk engine container interruption (≤200ms SLA)<br>• Scenario 3: Perimeter direct port rejection check<br>• Live end-to-end integrated demo from mobile to core ledger | **Zel & JM** (Chaos 1)<br>**Maye & Zel** (Chaos 2)<br>**Mayor & Angel** (Chaos 3)<br>**Full Team** (Live Demo) |

---

## 4. Day-by-Day Sprint Plan & Implementation Schedule (Days 1 to 9)

| Day | Sprint | Rubric Task | Deliverable (from capstone doc) | Core & T24 Engine (Zel, Wax, Mayor) | Web & Mobile Redesign (JM, Mae) | API & Risk Engine (Angel, Maye) | DevOps, Datadog & Jira (JM, Maye, Mae) | Testing & Security (Zel, Mayor, Angel) | Pts Due |
| :-: | :-: | :-: | :--- | :--- | :--- | :--- | :--- | :--- | :-: |
| **1** | Sprint 1 | T1 | **Domain definition & Jira initialization** | **Zel**: Review contract; draft DB balance entities.<br>**Wax & Mayor**: T24 entity model & ISO-8583 mapping. | **JM**: Mock UI server from OpenAPI; layout skeleton.<br>**Mae**: Wireframe user flows & brand guidelines. | **Angel**: Author and freeze OpenAPI 3.0 contract.<br>**Maye**: Draft risk threshold matrix & rules. | **Maye & Mae**: Jira project, Scrum board, DoD, workflows.<br>**JM**: Datadog APM org setup & repo structure. | **Zel**: Test plan & solvency acceptance criteria.<br>**Mayor & Angel**: Threat model & security gates. | **11** |
| **2** | Sprint 1 | T1 | **Multi-tier database & environment setup** | **Zel**: Oracle XE & Postgres DDL; `SELECT ... FOR UPDATE` prototype; Hikari pools.<br>**Wax**: T24 simulator schema. | **JM & Mae**: Responsive navigation, theme system, & dashboard components on mock. | **Angel**: Auth service skeleton & JWT filters.<br>**Maye**: Asyncio risk engine project skeleton. | **JM**: Docker Compose for DBs, Redis, Kafka; image check.<br>**Maye**: Jira Sprint 1 burn-down. | **Zel**: Postman collection for balance mutations.<br>**Mayor & Angel**: JMeter concurrency skeleton & DB checks. | **24** |
| **3** | Sprint 2 | T2 | **Backend business logic** | **Zel**: Balance mutation orchestrator + idempotency (`X-Idempotency-Key`).<br>**Wax & Mayor**: T24 ISO-8583 settlement adapter. | **JM**: Customer & Teller portal screens against mock.<br>**Mae**: Transfer & history UI components. | **Maye**: Python risk engine (asyncio) velocity checks.<br>**Angel**: Gateway Correlation-ID & route filters. | **JM**: Datadog APM Java tracer & container agent.<br>**Mae**: Jira issue tracking & blockers. | **Zel**: Concurrency test suite (pessimistic lock race).<br>**Mayor**: Security validation & input sanitization tests. | **19** |
| **4** | Sprint 2 | T2 | **Perimeter security integration** | **Zel**: Risk client + breaker, transactional outbox.<br>**Wax & Mayor**: T24 error handling & fallback adapter. | **JM**: Token storage design; Axios auth interceptors.<br>**Mae**: 2FA OTP modal screen & responsive forms. | **Angel**: JWT login, refresh token rotation (RTR) & breach detection.<br>**Maye**: Risk score evaluation topic. | **JM**: Account service circuit breaker & Redis cache.<br>**Maye & Mae**: Update DoD & acceptance criteria in Jira. | **Zel**: Contract and end-to-end integration tests.<br>**Angel & Mayor**: Replay breach tests & auth penetration audit. | **32** |
| **5** | Sprint 3 | T3 | **Cloud DevSecOps & containerization** | **Zel & Wax**: Multi-stage Dockerfiles for Core Engine & T24.<br>**Mayor**: Container security hardening & non-root user. | **JM**: Nginx container for web/mobile; secure session.<br>**Mae**: Customer portal transfer form & quick presets. | **Angel**: Gateway rate limiting (429 Redis bucket).<br>**Maye**: Containerize Python risk engine service. | **JM**: Multi-stage Compose on `banking-net` bridge; Datadog log scraper.<br>**Mae**: Sprint 3 tasks in Jira. | **Zel**: Compose smoke tests & container health checks.<br>**Mayor & Angel**: Container vulnerability scans & secrets audit. | **23** |
| **6** | Sprint 3 | T3 | **Mobile client assembly & consumption (feature freeze)** | **Zel & Wax**: Wire Core Engine to Kafka broker; bug fixes.<br>**Mayor**: OTel/Datadog tracing in core engine. | **JM**: Retry/breaker screens; wire client to live gateway.<br>**Mae**: Feature freeze visual audit & edge styling. | **Angel**: Fix contract mismatches & CORS boundaries.<br>**Maye**: Finalize risk scoring webhooks & event payload. | **JM**: Datadog APM dashboards (TPS, latency, errors); feature freeze.<br>**Maye & Mae**: Jira DoD audit. | **Zel**: Complete regression suite execution.<br>**Mayor & Angel**: API authorization & role privilege checks. | **26** |
| **7** | Sprint 4 | T4 | **Chaos engineering & system hardening** | **Zel**: Double-spend regression under 200+ concurrent threads.<br>**Wax & Mayor**: T24 timeout & network drop handling. | **JM**: UI timeout fallback, error toasts & offline alerts.<br>**Mae**: Chaos state UI testing & Jira bug logs. | **Maye**: Support risk-down chaos; auto-hold fallback.<br>**Angel**: Gateway load saturation handling & 429s. | **JM**: Chaos 1 (Kill DB / Redis); fix exposed ports; Datadog live alerts.<br>**Maye**: Log incident triage in Jira. | **Zel**: Chaos 2 & 3; aggressive JMeter breaking-point load.<br>**Mayor & Angel**: Penetration testing & port isolation. | **21** |
| **8** | Sprint 4 | T4 | **Final presentation & integrated demo** | **Zel, Wax & Mayor**: Bug-fix buffer, core architecture slides & runbooks. | **JM & Mae**: Demo-ready production build; presentation flow & backup capture. | **Angel & Maye**: README documentation, API catalog, & evidence pack. | **JM**: Datadog live presentation display & rehearsals.<br>**Maye & Mae**: Sprint burndown & Jira metrics. | **Zel**: Final regression verification; demo checklist.<br>**Mayor & Angel**: Security & compliance evidence. | **17** |
| **9** | Sprint 4 | T4 | **Program completion & final examination** | Exam and sign-off | Exam and sign-off | Exam and sign-off | Exam and sign-off | Exam and sign-off | **2** |
| | | | | | | | | **Total Points Due** | **175** |

### Sprint Goals

* **Sprint 1 (Days 1-2)**: Contract frozen, Jira live, both databases and pooling working, locking approach proven.
* **Sprint 2 (Days 3-4)**: Transfer flows end to end: orchestrator, risk engine, T24 simulator, JWT and error handling.
* **Sprint 3 (Days 5-6)**: Everything runs in Compose on an isolated network; web/mobile app talks to the real gateway. Feature freeze.
* **Sprint 4 (Days 7-9)**: All three chaos tests pass, demo rehearsed twice, final exam and sign-off.

