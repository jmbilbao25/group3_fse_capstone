# Retail Bank Transfer Risk Engine

This service is the fraud detection and risk screening engine for the retail bank transfer pipeline. It implements a decoupled architecture:
1. A synchronous evaluation path combining Gate 0 deterministic rules with an XGBoost tabular model (S2) returning in under 2 milliseconds.
2. An asynchronous background reviewer using a quantized language model (NanoJev, based on Qwen2.5-0.5B INT8 ONNX) that screens memo-present transfers for social engineering and scam patterns.

---

## 1. System Architecture

The service decouples immediate authorization latency from deeper semantic analysis of transfer memos.

```
Inbound Transfer Request
       │
       ▼
┌────────────────────────────────────────────────────────┐
│ Synchronous Path (SLA p99 < 200 ms, actual ~2 ms)     │
│                                                        │
│  1. Gate 0 Hard Rules (Impossible travel, tampering)   │
│     │                                                  │
│     ├── Tripped  ──> BLOCK or REQUIRE_2FA              │
│     │                                                  │
│     └── Passed                                         │
│           │                                            │
│           ▼                                            │
│  2. S2 Tabular XGBoost Inference (40+ features)        │
│     │                                                  │
│     ├── p >= 0.50 ──> BLOCK                            │
│     ├── p >= 0.40 ──> REQUIRE_2FA                      │
│     └── p <  0.40 ──> ALLOW                            │
└───────────────────────┬────────────────────────────────┘
                        │
                        ▼
           Return Synchronous Decision
       (ALLOW / REQUIRE_2FA / BLOCK to Caller)
                        │
      ┌─────────────────┴─────────────────┐
      │ Has memo AND decision != BLOCK    │
      ▼                                   ▼
 [ Enqueue Background Job ]         [ Finish Request ]
      │
      ▼
┌────────────────────────────────────────────────────────┐
│ Asynchronous Second-Look Reviewer (Worker Pool)        │
│                                                        │
│  - Bounded in-memory queue (capacity: 1,000)           │
│  - 2 background worker threads (8 ONNX intra-op)       │
│  - SHA-256 prompt cache (sub-millisecond retrieval)    │
│  - NanoJev INT8 ONNX classification                    │
│  - Escalate-only invariant: RiskTier(final) >= S2      │
│  - Settlement window evaluation (60 seconds default)   │
│                                                        │
│  If escalated within window:                           │
│    status -> HELD                                      │
│    generate analyst case card                          │
│    trigger background SAR if high risk                 │
│  If escalated after window:                            │
│    status remains SETTLED                              │
│    flagged as LATE_ESCALATION in analyst queue         │
└────────────────────────────────────────────────────────┘
```

### Core Invariants

1. Escalate-Only Invariant: The background reviewer may only escalate a decision, never downgrade it. The logic is enforced in `enforce_escalate_only()`:
   - S2 `ALLOW` can become `REQUIRE_2FA` or `BLOCK`.
   - S2 `REQUIRE_2FA` can become `BLOCK`, but never `ALLOW`.
   - S2 `BLOCK` is immutable.
   - Any transfer marked `HELD` cannot be released back to `SETTLED` by reviewer fallback logic.
2. Non-Blocking Failure Modes: If the background queue is full, the job is dropped to `UNREVIEWED` and a metric counter is incremented. If inference times out or errors, the transfer status remains untouched. The synchronous transfer path never blocks or fails due to reviewer load.
3. Untrusted Memo Handling: All memo strings are treated as untrusted user input. Text classifications use structured label logit evaluation rather than open-ended text generation, preventing prompt injection attacks from manipulating output actions.

---

## 2. Historical Tests and Architectural Decisions

During initial development, the team evaluated running the language model directly inside the synchronous request path. Benchmarking showed this created significant operational problems.

### Previous Tests and Benchmark Findings

1. Synchronous LLM Latency Collapse:
   Running NanoJev Qwen2.5-0.5B INT8 ONNX synchronously on CPU took between 250 ms and 900 ms per forward pass. Under a concurrent load of 25 transactions per second, synchronous p99 latency exceeded 1,200 ms, failing the 200 ms banking SLA.
2. False Escalation on Conversational Memos:
   Zero-shot language models evaluated with temperature scaling exhibit probability entropy on casual, benign transfer notes (such as "dinner split", "lunch with team", or informal Taglish phrases). Using the language model as a synchronous gate caused excessive friction on legitimate account holders.
3. S2 Tabular Strengths:
   The XGBoost tabular model (S2) evaluates 40+ numerical, categorical, and behavioral features in 1.2 to 2.0 ms. Across benchmark splits, S2 delivered consistent discrimination:
   - Split C1 (Standard Test, 300 txns): ROC-AUC 0.9997, PR-AUC 0.9986.
   - Split C2 (Novel Memos, 300 txns): ROC-AUC 0.9995, PR-AUC 0.9974.
   - Split C3 (Production Imbalanced, 1,000 txns): ROC-AUC 0.9990, PR-AUC 0.8487.
   - Split C4 (Handwritten Memos, 100 txns): ROC-AUC 1.0000, PR-AUC 1.0000.
4. S2 Tabular Blind Spot (Synthetic Stress Slice):
   While S2 performed well on tabular data, it was blind to authorized push payment (APP) fraud. When a victim is manipulated by a scammer, they send money from their usual device, at their usual location, with normal velocity. In a stress test of 50 scam transactions paired with normal behavioral features, S2 allowed 100% of the scams (0/50 caught).
5. Decoupled Reviewer Results:
   Offloading NanoJev to an asynchronous worker resolved both problems:
   - Synchronous p99 latency dropped to 83.11 ms under 25 TPS on CPU (comfortably under the 200 ms SLA).
   - The asynchronous reviewer caught 42 out of 50 scam transactions (84.0%) that S2 missed.
   - A 60-vector prompt injection suite across 600 trials showed 0 downgrades.

### Architectural Decisions

| Decision | Choice | Rationale |
| :--- | :--- | :--- |
| Synchronous Engine | Gate 0 + XGBoost (S2) | Sub-2 ms execution, deterministic hard rules, high precision on device/velocity data. |
| Reviewer Engine | Qwen2.5-0.5B INT8 ONNX | Runs locally on CPU without GPU hardware or external API egress costs. |
| Concurrency Model | Decoupled Background Worker Pool | Prevents neural inference latency from stalling the customer-facing payment rail. |
| ONNX Intra-Op Threads | 8 Threads | Benchmarking showed 8 threads gave the lowest latency on multi-core host CPUs. |
| Prompt Caching | SHA-256 Prompt Cache | Caches logit outputs for recurring memo phrases, reducing lookup time to < 1 ms. |
| Invariant Policy | Escalate-Only | Mathematically guarantees the reviewer cannot weaken an S2 decision or bypass security blocks. |
| Settlement Window | 60-Second Simulated Window | Matches ACH and batched clearing windows, allowing time to hold funds before disbursement. |

---

## 3. Orchestrator Service Contract

This section defines the API contract between the Java Orchestration Engine (`ledger-mutation-engine`) and the Risk Engine (`risk-service`).

### Endpoint

```http
POST /api/v1/risk/analyze
Content-Type: application/json
```

*(Note: `/api/v1/risk/transfer` is available as a backward-compatible alias.)*

### Request Schema

```json
{
  "transaction_id": "TX-20261004-9842",
  "user_id": "USR-1001",
  "account_id": "ACC-100001",
  "target_account_id": "ACC-200002",
  "amount": 15000.00,
  "currency": "PHP",
  "memo": "Payment for services rendered",

  "latitude": 14.5995,
  "longitude": 120.9842,
  "ip_address": "120.28.0.1",
  "ip_latitude": 14.6000,
  "ip_longitude": 120.9800,

  "rooted": false,
  "hooking": false,
  "emulator": false,
  "tampered": false,
  "attestation_verdict": "PASS",
  "mock_location": false,
  "is_vpn": false,

  "payee_age_days": 180.0,
  "new_payee": false
}
```

### Request Fields Specification

| Field Name | Type | Required | Default | Description |
| :--- | :--- | :---: | :--- | :--- |
| `transaction_id` | String | Yes | Auto-generated UUID | Unique transaction reference string. |
| `user_id` | String | Yes | N/A | Initiating customer identifier (e.g. `USR-1001`). |
| `account_id` | String | Yes | N/A | Source account number (e.g. `ACC-100001`). |
| `target_account_id` | String | Yes | N/A | Destination account number. |
| `amount` | Float | Yes | N/A | Transfer amount in PHP (must be greater than 0). |
| `currency` | String | No | `"PHP"` | Currency ISO code. |
| `memo` | String | No | `""` | User-entered transfer memo or description. |
| `latitude` | Float | Optional | Customer Home Lat | GPS latitude from client device. |
| `longitude` | Float | Optional | Customer Home Lon | GPS longitude from client device. |
| `ip_address` | String | Optional | `null` | Client connection IP address. |
| `ip_latitude` | Float | Optional | `null` | IP-based resolved latitude (used to detect proxy discrepancy). |
| `ip_longitude` | Float | Optional | `null` | IP-based resolved longitude. |
| `rooted` | Boolean | Optional | `false` | Hardware integrity flag: device is rooted or jailbroken. |
| `hooking` | Boolean | Optional | `false` | Frida, Xposed, or substrate hook detected on device. |
| `emulator` | Boolean | Optional | `false` | Client is running inside an Android/iOS emulator. |
| `tampered` | Boolean | Optional | `false` | APK signature mismatch or binary repackaging detected. |
| `attestation_verdict` | String | Optional | `"PASS"` | Play Integrity / App Attest verdict (`"PASS"`, `"FAIL"`, `"UNTRUSTED"`). |
| `mock_location` | Boolean | Optional | `false` | Mock location provider enabled in developer settings. |
| `is_vpn` | Boolean | Optional | `false` | Connection originated from known VPN or datacenter IP. |
| `payee_age_days` | Float | Optional | `90.0` | Age of relationship with beneficiary in days. |
| `new_payee` | Boolean | Optional | `false` | True if this is the first transfer to this recipient. |

### Response Schema

```json
{
  "transaction_id": "TX-20261004-9842",
  "decision": "ALLOW",
  "status": "PENDING_SETTLEMENT",
  "fraud_score": 12,
  "is_anomaly": false,
  "anomaly_probability": 0.1245,
  "primary_flag": "NONE",
  "all_flags": [],
  "metrics": {
    "distance_from_home_km": 2.41,
    "velocity_kmh": 15.2,
    "is_impossible_travel": false,
    "is_vpn_detected": false,
    "spike_ratio": 1.15
  },
  "customer_summary": {
    "user_id": "USR-1001",
    "full_name": "Juan Dela Cruz",
    "average_transfer": 2000.0,
    "home_location": "Manila, Philippines"
  },
  "evaluation_time_ms": 1.84,
  "review_enqueued": true,
  "settlement_window_seconds": 60.0
}
```

### Response Fields Specification

| Field Name | Type | Allowed Values | Semantics for Orchestrator |
| :--- | :--- | :--- | :--- |
| `transaction_id` | String | Matches request | Correlation identifier. |
| `decision` | String | `ALLOW`, `REQUIRE_2FA`, `BLOCK` | Synchronous risk decision. |
| `status` | String | `SETTLED`, `PENDING_SETTLEMENT`, `REQUIRE_2FA`, `BLOCKED`, `HELD` | Lifecycle status of the transfer. |
| `fraud_score` | Integer | `0` to `100` | Calibrated fraud probability scaled to 100. |
| `is_anomaly` | Boolean | `true`, `false` | True if risk score exceeds the 2FA threshold (score >= 40). |
| `primary_flag` | String | String code | Reason code (`IMPOSSIBLE_TRAVEL_VELOCITY`, `CRITICAL_DEVICE_TAMPERING`, `NONE`, etc.). |
| `review_enqueued` | Boolean | `true`, `false` | True if a background second-look review job was submitted. |
| `settlement_window_seconds` | Float | Numeric seconds (e.g. `60.0`) | Holding duration during which the reviewer can hold funds. |
| `evaluation_time_ms` | Float | Milliseconds | Server-side execution latency. |

### Orchestrator Implementation Rules

1. Decision Routing:
   - `BLOCK`: The orchestrator aborts the transaction immediately, rolls back the database operation, and returns a security rejection error to the caller.
   - `REQUIRE_2FA`: The orchestrator reserves funds under a soft hold (`hold_amount`), generates a 6-digit OTP, saves it in Redis with a 5-minute TTL, and dispatches a notification.
   - `ALLOW`: If `status` is `SETTLED` (no memo present), funds commit immediately. If `status` is `PENDING_SETTLEMENT` (memo present), funds are authorized with a 60-second clearing window.
2. Holding and Escalation Handling:
   - If the background reviewer escalates a pending transfer to `HELD`, the transfer status is updated in the database.
   - The orchestrator can check transfer status by calling `GET /api/v1/risk/transfers/{transaction_id}`.
   - If the 60-second window elapses without an escalation, the transfer transitions to fully settled status.
3. Timeout and Fallback:
   - Recommended orchestrator HTTP timeout: 500 ms to 1,500 ms.
   - If the risk engine is offline or times out, the orchestrator should fall back to static rule thresholds (`ALLOW` with secondary balance limits) rather than failing the customer transfer.

---

## 4. Secondary Endpoints & Analyst Workflow

### Service Health
```http
GET /health
```
Returns service operational state, active worker thread counts, model loading status, and Datadog APM configuration.

### Operational Metrics
```http
GET /api/v1/risk/metrics
```
Returns real-time background reviewer statistics:
```json
{
  "queue_depth": 0,
  "drops": 0,
  "timeouts": 0,
  "reviews_completed": 142,
  "escalations": 18,
  "escalation_rate_pct": 12.68,
  "time_to_review_p50_ms": 48.59,
  "time_to_review_p95_ms": 65.00,
  "inference_p50_ms": 32.10,
  "inference_p95_ms": 44.80
}
```

### Analyst Case Queue
```http
GET /api/v1/analyst/cases
```
Returns all cases escalated by the background reviewer, complete with:
- Synchronous S2 score.
- Top 3 SHAP feature attributions.
- NanoJev scam typology tag (`investment_scam`, `romance_scam`, `impersonation`, `fake_invoice`, `other`, `none`).
- Consistency flag between declared memo and behavioral facts.
- Recommended analyst action.

### Record Analyst Decision
```http
POST /api/v1/analyst/decision
Content-Type: application/json

{
  "case_id": "CASE-TX-20261004-9842",
  "transaction_id": "TX-20261004-9842",
  "decision": "CONFIRM_FRAUD",
  "analyst_id": "ANALYST_02",
  "notes": "Verified fraudulent crypto solicitation"
}
```
Records the analyst resolution directly into `data/analyst_decisions.jsonl`. This audit log provides clean, ground-truth label data for future model retraining passes.

---

## 5. Configuration & Environment Variables

| Variable Name | Default Value | Description |
| :--- | :--- | :--- |
| `SETTLEMENT_WINDOW_SECONDS` | `60.0` | Holding window duration for memo-present transfers. |
| `REVIEW_QUEUE_MAXSIZE` | `1000` | Maximum capacity of the in-memory background review queue. |
| `REVIEW_WORKER_THREADS` | `2` | Number of background worker threads for NanoJev reviews. |
| `ONNX_INTRA_OP_THREADS` | `8` | Intra-op parallel threads for the ONNX Runtime session. |
| `TAU_2FA` | `0.40` | S2 probability threshold to trigger 2FA verification. |
| `TAU_BLOCK` | `0.50` | S2 probability threshold to trigger a hard block. |
| `DD_AGENT_HOST` | `dd-agent` | Hostname of the Datadog Agent container. |
| `DD_TRACE_AGENT_PORT` | `8126` | Port for Datadog APM trace collection. |
| `DD_SERVICE` | `risk-service` | Service name registered in Datadog APM. |

---

## 6. How to Run

### Option 1: Via Docker Compose (Recommended for Teammates)

When you pull the repository, the service is pre-configured to build and start automatically alongside the orchestrator:

```powershell
# From the repository root
docker compose -f infrastructure/docker-compose.yml up -d --build risk-service ledger-mutation-engine
```

Check health:
```powershell
curl http://localhost:8084/health
```

### Option 2: Running Locally on Host

1. Install Python dependencies:
```powershell
cd backend/risk-service
python -m pip install -r requirements.txt
```

2. Start the service:
```powershell
python -m app.server
```
The server will start on port 8084.

3. Run automated tests:
```powershell
pytest tests/
```

To run all backend microservices together locally, execute:
```powershell
cd backend
.\start-all-services.ps1
```
This script launches all 5 backend microservices (including `risk-service` on port 8084) with Datadog tracing enabled.
