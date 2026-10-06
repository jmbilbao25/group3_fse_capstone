# Retail bank transfer risk engine

This service provides real-time fraud risk screening and targeted scam friction for retail bank transfers. It implements a two-stage evaluation pipeline:
1. Stage A (synchronous, latency budget under 200 ms): Gate 0 deterministic rules and an XGBoost tabular model (S2) evaluating transaction velocity, account age, balance drain, and device integrity.
2. Stage B (synchronous-bounded, default timeout 1500 ms): NanoJev language model engine (Qwen2.5-0.5B INT8 ONNX) that synthesizes unstructured device telemetry (remote-access apps like AnyDesk, active voice calls, payee mismatches) and scam typologies into calibrated advisory warnings.

---

## 1. System architecture

The engine balances sub-200 ms payment settlement latency with targeted friction against Authorized Push Payment (APP) scams and remote-access hijacking.

```
Inbound Transfer Request
       │
       ▼
┌────────────────────────────────────────────────────────┐
│ Stage A: Synchronous Tabular Risk (< 200 ms budget)    │
│                                                        │
│  1. Gate 0 Hard Rules (Impossible travel, tampering)   │
│     │                                                  │
│     ├── Tripped  ──> BLOCK (Zero SMS OTP bypass)       │
│     │                                                  │
│     └── Passed                                         │
│           │                                            │
│           ▼                                            │
│  2. S2 Tabular XGBoost Inference (40+ features)        │
│     │                                                  │
│     ├── p >= 0.50 ──> BLOCK                            │
│     ├── p >= 0.40 ──> REQUIRE_2FA (Step-up auth)       │
│     └── p <  0.40 ──> ALLOW                            │
└───────────────────────┬────────────────────────────────┘
                        │
                        ▼
      Action a0 Evaluated (ALLOW | ADVISORY | BLOCK)
                        │
       ┌────────────────┴────────────────┐
       │ Threat telemetry or memo?       │
       ▼                                 ▼
   [ YES ]                            [ NO ]
       │                                 │
       ▼                                 ▼
┌──────────────────────────────┐   Standard Settle (ALLOW)
│ Stage B: Threat Synthesis    │   Bound Hardware Biometrics
│ (Bounded: 1500 ms timeout)   │   or Push to Primary Device
│                              │
│  - Synthesizes device context│
│    (AnyDesk, TeamViewer,     │
│    active call, mismatches)  │
│  - Classifies scam typologies│
│  - Applies temperature       │
│    scaling (T* = 7.12)       │
│  - Invariant rule:           │
│    a1 = max(a0, a_nj)        │
└──────────────┬───────────────┘
               │
               ▼
   Friction Action Selected
       ├── ALLOW: Bound biometrics and immediate ledger settle
       ├── ADVISORY_WARNING: In-app warning modal (Cancel | 10-Min Hold | Proceed)
       ├── REQUIRE_2FA: Step-up authentication (Biometric + MPIN)
       └── BLOCK: Outright rejection (Critical anomaly)
               │
               ▼ (Fire-and-forget)
┌────────────────────────────────────────────────────────┐
│ Async Event Dispatch (POST /risk/events)               │
│                                                        │
│  - JSONL append-only audit trail                       │
│  - Automatic AMLC SAR draft filings for high-risk cases│
│  - Analyst triage queue for compliance review          │
└────────────────────────────────────────────────────────┘
```

---

## 2. Decision actions and friction tiers

The engine enforces four distinct action tiers:

| Tier | Code Name | Display Action | Trigger Criteria | Customer Experience |
| :---: | :--- | :--- | :--- | :--- |
| **0** | `ALLOW` | Clean Settlement | Low tabular risk, clean telemetry, no scam indicators | Routine payment. Requires local bound biometric verification (or push notification). |
| **1** | `ADVISORY_WARNING` | Contextual Advisory | Remote-access app detected, active call coercion, or moderate scam typology (prob >= 0.35) | Non-blocking warning modal with explanation in customer language: Cancel, 10-minute hold, or Proceed. |
| **2** | `REQUIRE_2FA` | Step-Up Authentication | High tabular velocity, spike ratio, or repeated anomalies | Step-up verification: local biometric confirmation plus transaction MPIN. Zero SMS OTP allowed. |
| **3** | `BLOCK` | Transfer Rejection | Gate 0 rule trip (speed > 1000 km/h, rooted device) or extreme risk (prob >= 0.50) | Payment aborted immediately. Funds preserved in sender account. |

### Escalate-only safety invariant

To prevent malicious prompts or model variance from weakening security, Stage B enforces an architectural invariant:

$$\text{RiskTier}(a_1) \ge \text{RiskTier}(a_0)$$

Where action ranks are: `ALLOW` (0) < `ADVISORY_WARNING` (1) < `REQUIRE_2FA` (2) < `BLOCK` (3).

NanoJev can escalate a transfer (for example from `ALLOW` to `ADVISORY_WARNING` or `REQUIRE_2FA`), but it can never downgrade a transfer. A Stage A `BLOCK` verdict remains immutable regardless of memo text.

---

## 3. Cryptographic device binding and zero SMS OTP

In compliance with Philippine regulatory standards under BSP Circular 1213:

1. **Zero SMS OTP for transactions**: SMS OTP is strictly restricted to initial customer onboarding and new device registration. No transaction authorization or risk bypass may occur through SMS OTP due to SIM-swapping vulnerabilities.
2. **Primary Device authentication**: Transfers initiated from the customer's registered Primary Device require local hardware biometrics (Face ID or Fingerprint via native KeyStore / Keychain).
3. **Secondary Device authentication**: Transfers initiated from an unbound Secondary Device (Web Banking or Tablet) dispatch an Out-of-Band (OOB) Push Notification to the registered Primary Device for biometric confirmation.
4. **Routine transfer authorization**: Even clean, low-risk transfers (`ALLOW`) require local hardware biometric confirmation before ledger mutation.

---

## 4. Unstructured device threat synthesis

Rather than inspecting memos alone, Stage B analyzes device telemetry strings that cannot be represented in standard tabular feature trees:

- **Remote-access package names**: Presence of tools like `com.anydesk.anydeskandroid`, `com.teamviewer.host.market`, or `com.rustdesk.rustdesk`.
- **Accessibility service monitors**: Background accessibility services observing screen contents.
- **Active call state**: Telephony manager reporting `CALL_STATE_OFFHOOK` during transaction entry (indicates live social engineering coercion).
- **Purpose and payee mismatches**: Declared transfer purpose (such as "house rental" or "family support") directed to known commercial merchant accounts or unrelated entities.

When any threat context is detected, `threat_builder.py` constructs a normalized threat narrative:

```text
DEVICE_THREAT: AnyDesk remote control package active.
CALL_STATE: Voice call off-hook during transfer entry.
PURPOSE_MISMATCH: Declared purpose 'tax refund' transferred to individual retail payee.
```

NanoJev evaluates this threat narrative alongside transaction parameters to assign the appropriate advisory warning dialog template from `warning_catalog.py`.

---

## 5. API endpoints specification

### Stage A: Synchronous tabular decision
```http
POST /risk/stage-a
Content-Type: application/json
```
Evaluates Gate 0 rules and XGBoost tabular models. Returns within 30 ms.

```json
{
  "transaction_id": "TX-1001",
  "user_id": "USR-1001",
  "account_id": "ACC-100001",
  "target_account_id": "ACC-200002",
  "amount": 15000.00,
  "currency": "PHP",
  "memo": "Processing investment deposit",
  "device_id": "DEV-IPHONE-01",
  "is_primary_device": true,
  "latitude": 14.5995,
  "longitude": 120.9842,
  "remote_app_active": true,
  "active_call": true
}
```

Response:
```json
{
  "decision_id": "DEC-9842",
  "a0": "ADVISORY_WARNING",
  "s2_score": 0.28,
  "threat_context_present": true,
  "memo_check_required": true,
  "auth_method": "BIOMETRIC_PRIMARY"
}
```

### Stage B: Threat synthesis and advisory selection
```http
POST /risk/stage-b
Content-Type: application/json

{
  "decision_id": "DEC-9842",
  "language": "en"
}
```

Response:
```json
{
  "decision_id": "DEC-9842",
  "final_action": "ADVISORY_WARNING",
  "tier": "MEDIUM",
  "typology": "remote_access_malware",
  "typology_prob": 0.485,
  "warning_dialog": {
    "dialog_id": "WARN_REMOTE_ACCESS_01",
    "title": "Remote Screen Sharing Detected",
    "body": "AnyDesk is currently active on your phone. Scammers use remote tools to take over your banking session. Never proceed if someone instructed you to install this app.",
    "bullet_points": [
      "Hang up any incoming call claiming to be bank security",
      "Uninstall remote access applications before continuing",
      "Bank staff will never ask you to install screen sharing tools"
    ],
    "cancel_button_label": "Cancel Transfer",
    "pause_button_label": "Pause for 10 Minutes",
    "continue_button_label": "I Understand, Proceed"
  },
  "auth_method": "BIOMETRIC_PRIMARY"
}
```

### Asynchronous event logging and AMLC reporting
```http
POST /risk/events
Content-Type: application/json

{
  "transaction_id": "TX-1001",
  "decision_id": "DEC-9842",
  "user_action": "proceed",
  "final_action": "ADVISORY_WARNING",
  "sar_drafted": false
}
```

When a transfer is blocked or meets high-risk criteria, the service automatically drafts a formatted forensic Markdown report in `hybrid_bench/reports/sar_drafts/` for AMLC compliance review.

---

## 6. Local development and testing

### Environment setup
```powershell
cd backend/risk-service
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### Start the risk engine server
```powershell
python -m app.server
```
The FastAPI application listens on port 8084.

### Run automated tests
```powershell
pytest tests/ -v
```
All 36 unit, integration, and security invariant tests run locally without requiring external network dependencies.
