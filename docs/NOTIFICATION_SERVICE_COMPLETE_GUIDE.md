# Core Retail Banking: Notification & Alert Microservice (`:8083`)
### Comprehensive Architecture, Compliance Matrix & Demonstration Playbook

---

## 1. What is the Notification Service?

The **Notification & Alert Service** (`notification-service` running on port `:8083`) is a dedicated, event-driven Spring Boot microservice in our Core Retail Ledger architecture.

### Primary Purpose:
Whenever financial transactions or balance adjustments take place in the bank, this service handles:
1. **Customer Communications:** Automatically generating and dispatching rich HTML digital receipts for completed transfers.
2. **Regulatory Compliance (BSP MORB & AMLA):** Automatically enforcing the **Maker-Checker principle** and alerting authorized bank officers (Branch Operations Officers and Branch Heads) when transactions exceed regulatory thresholds.
3. **Audit Trail Logging:** Persisting a permanent record of all alerts and receipts into the Oracle Database `NOTIFICATIONS` table.

### Key Architectural Characteristics:
* **Asynchronous & Non-Blocking:** Consumes transaction events via Apache Kafka without slowing down the Core Mutation Engine.
* **Idempotent (Anti-Spam):** Uses Redis distributed caching to eliminate duplicate emails caused by network retries or Kafka rebalances.
* **Resilient (Circuit Buffering):** Features an in-memory retry spool that buffers messages during downstream SMTP outages so no receipts are lost.
* **12-Factor App Design:** Operates with MailHog during local development/testing and transitions to enterprise cloud mail providers (AWS SES, SendGrid) in production via environment variables without changing any code.

---

## 2. Technical Stack & Port Mappings

| Component | Technology | Port | Role in Architecture |
| :--- | :--- | :--- | :--- |
| **Microservice** | Spring Boot 3.3.x, OpenJDK 21 LTS | `8083` | Event consumption, receipt generation, REST simulation endpoints |
| **Message Broker** | Apache Kafka | `9092` | Subscribes to topic `banking.transfers.events` (Consumer Group: `notification-workers`) |
| **Deduplication Cache** | Redis 7 Alpine | `6379` | Key `notif:seen:<transfer_id>` (TTL: 1 hour) for idempotency |
| **Template Engine** | Thymeleaf 3 | Internal | Renders branded, responsive HTML email templates |
| **Audit Master Database** | Oracle XE 21c Master | `1521` | Persists alerts to the `NOTIFICATIONS` table |
| **Testing Mail Sandbox** | MailHog (SMTP & Web UI) | `1025` (SMTP)<br>`8025` (Web) | Catches outgoing emails locally with an instant web browser inbox |
| **Real-time Push** | WebSockets (STOMP) & SSE | Internal / `8083` | Broadcasts live alerts to `/topic/teller-alerts` and browser toasts |

---

## 3. How It Works (Event-Driven Data Flow)

```
┌─────────────────────────────────┐
│     Ledger Mutation Engine      │ (Executes Balance Debit/Credit on Oracle XE)
└────────────────┬────────────────┘
                 │ 1. Emits TransactionNotificationEvent
                 ▼
┌─────────────────────────────────┐
│       Apache Kafka Broker       │ (Topic: banking.transfers.events)
└────────────────┬────────────────┘
                 │ 2. Consumed by 4 concurrent worker threads
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│               Notification Service (Port :8083)                 │
│                                                                 │
│  [ Step A: Idempotency Check ] ──► Redis (notif:seen:<id>)      │
│  [ Step B: Regulatory Tiering ]──► Evaluates BSP & AMLA Rules   │
│  [ Step C: Receipt Formatting ]──► Masks Account & SHA-256 Hash │
│  [ Step D: Template Engine ]   ──► Thymeleaf HTML Compilation   │
│  [ Step E: SMTP Dispatch ]     ──► JavaMailSender               │
│  [ Step F: Audit Persistence ] ──► Oracle NOTIFICATIONS Table   │
└────────────────┬────────────────────────────────┬───────────────┘
                 │                                │
     (Customer Receipt / Alerts)         (Real-time Teller Push)
                 │                                │
                 ▼                                ▼
┌─────────────────────────────────┐    ┌──────────────────────────┐
│      MailHog Web Inbox          │    │   STOMP WebSocket / SSE  │
│   (http://localhost:8025)       │    │  (/topic/teller-alerts)  │
└─────────────────────────────────┘    └──────────────────────────┘
```

### The Step-by-Step Flow:
1. **Transaction Event Published:** When a funds transfer is processed, an event is placed on Kafka topic `banking.transfers.events`.
2. **Kafka Ingestion:** The `TransactionEventConsumer` picks up the message using the consumer group `notification-workers`.
3. **Idempotency Filter:** The service queries Redis (`SET notif:seen:<id> 1 NX EX 3600`). If the event was already processed, it is immediately dropped to prevent duplicate customer emails.
4. **BSP & AMLA Policy Evaluation:** The service checks the transfer amount against regulatory thresholds.
5. **Dispatch & Persistence:**
   * If **Committed (Tier 1)**: Renders `transaction-receipt.html` and sends the receipt to the customer's email.
   * If **Held (Tier 2 or Tier 3)**: Renders `maker-checker-alert.html`, sends an urgent alert to compliance officers, and broadcasts WebSocket alerts to branch teller terminals.
   * The notification record is saved to the Oracle `NOTIFICATIONS` table for compliance auditability.

---

## 4. BSP MORB & AMLA Regulatory Compliance Matrix

Our implementation strictly enforces the **Manual of Regulations for Banks (MORB)** and the **Anti-Money Laundering Act (AMLA)**:

| Transaction Tier | Amount (PHP) | Required Roles | Workflow & Regulatory Rules | System Output |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 1: Normal Transaction** | **`₱0.01 – ₱50,000.00`** | **1 Person** (Teller only) | Handled directly by branch teller without supervisor intervention. Standard execution. | • Customer **HTML Receipt** emailed<br>• Real-time SSE browser toast pushed<br>• Masked accounts (`ACC-****-471`) & SHA-256 hash |
| **Tier 2: Dual Control (Maker-Checker)** | **`₱50,000.01 – ₱499,999.99`** | **Maker:** Teller / Clerk<br>**Checker:** Branch Operations Officer (**BOO**) or Branch Cashier | Teller encodes the transfer; transaction is held in `PENDING_APPROVAL`. The BOO logs in on their terminal to review customer ID, signature card, and authorizes. | • `ALERT_BROADCAST` to `/topic/teller-alerts`<br>• Email to BOO / Compliance Officer<br>• Workflow note: Verify ID & Signature Card |
| **Tier 3: High-Value / AMLA Covered** | **`₱500,000.00 and above`** | **Maker:** Teller<br>**Checker 1:** BOO<br>**Approver 2:** Branch Head / Operations Manager | Mandatory **Covered Transaction Report (CTR)** filing under AMLA. Requires dual manager approval before balance mutation. | • `ALERT_BROADCAST` with AMLA CTR flag<br>• Urgent email to BOO & Branch Head<br>• Workflow note: CTR filing mandatory under AMLA |

---

## 4.1 Database Seed Users & Role Architecture (BSP & T24 Segregation of Duties)

To satisfy **Temenos T24** core banking security standards and **BSP Circular 808 (IT Risk Management & Segregation of Duties)**, financial permissions are strictly segregated:

| User ID | Full Name | Email | System Role | Business Function | Permissions & Dual Control Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`U1001`** | **Juan Dela Cruz** | `juan.dc@email.com` | `CUSTOMER` | Primary Retail Customer | **Maker:** Initiates digital transfers. Account holder receiving digital HTML receipts. |
| **`U1002`** | **Maria Santos** | `maria.s@email.com` | `CUSTOMER` | Retail Customer / Beneficiary | **Beneficiary:** Account holder receiving inbound funds and credit confirmations. |
| **`U3001`** | **Alex Mercer** | `alex.teller@bank.com` | `TELLER` | Front-Line Branch Teller | **Maker:** Encodes over-the-counter transactions. Authority limit capped at ₱50,000.00. |
| **`U3002`** | **Beatriz Ocampo** | `beatriz.manager@bank.com` | `TELLER` | Branch Operations Officer (BOO) / Senior Checker | **Checker:** Authorizes Tier 2 Dual Control holds (₱50k–₱500k). Acts as **Checker 1** for Tier 3 AMLA reviews. |
| **`U0001`** | **Diana Vance** | `diana.admin@bank.com` | `ADMIN` | IT Super User / System Administrator | **Infrastructure Only:** Manages IT configs, server nodes, user provisioning, and audit trails. **STRICTLY FORBIDDEN** from initiating or approving financial transactions. |

### Why Must ₱500,000+ Require Dual Authorization (2 Approvers)?
1. **AMLA Law Compliance:** Republic Act No. 9160 (Anti-Money Laundering Act) defines transactions $\ge$ ₱500,000.00 as **Covered Transactions (CTRs)**. Due to money laundering and terrorism financing risks, no single officer can approve the release of funds.
2. **Dual-Eyes Principle in Core Banking (T24):** 
   - **Checker 1 (BOO):** Validates transactional completeness, checks customer signature card/KYC ID, and verifies encoding accuracy.
   - **Approver 2 (Branch Head / Operations Manager):** Performs high-level risk assessment, confirms source of wealth/funds, and signs off on the mandatory Covered Transaction Report to the AMLC before the Core Ledger commits the debit/credit mutation.

### Why IT Admin Diana Vance Can NOT Be a Financial Approver:
* Under **BSP IT Risk Guidelines & COBIT**, allowing an IT Super User (`ADMIN`) to approve banking transactions creates an existential fraud loophole.
* Because an IT Admin has access to server infrastructure, database administration, and logs, combining financial authorization rights with IT admin privileges violates the **Four-Eyes Principle** and enables undetected rogue balance manipulation.
* Therefore, IT Super Users are strictly restricted to non-financial system management.

---

## 5. Live Showcase & Demonstration Playbook

Follow these exact steps during your project defense or team presentation.

> **Pre-requisite:** Open the MailHog Web Inbox in your browser:  
> 👉 **[http://localhost:8025](http://localhost:8025)**

---

### Scenario 1: Tier 1 Normal Transfer (Happy Path Customer Receipt)
* **Context:** A customer sends ₱25,000.00 (within the ₱50k single-teller limit).
* **PowerShell Command:**
  ```powershell
  Invoke-RestMethod -Uri "http://localhost:8083/api/v1/notifications/simulate-transfer" -Method Post -ContentType "application/json" -Body "{}"
  ```
* **What to Show on Screen:**
  1. Open [http://localhost:8025](http://localhost:8025).
  2. Open the email sent to `customer@corebank.ph` with subject `Transaction Receipt: ₱25,000.00 [...]`.
  3. **Point out key compliance features on the receipt:**
     * **Emerald `COMMITTED` status badge.**
     * **Masked Accounts:** Shows `ACC--****-471` (protects customer privacy under the Data Privacy Act).
     * **Pre/Post Balance breakdown:** Balance Before vs Balance After.
     * **Cryptographic SHA-256 Audit Hash:** Proves the receipt was not tampered with.

---

### Scenario 2: Tier 2 Dual Control Hold (₱150,000.00 Maker-Checker)
* **Context:** A teller encodes a ₱150,000.00 transfer (between ₱50k and ₱500k). Under BSP MORB, it cannot execute automatically and requires BOO approval.
* **PowerShell Command:**
  ```powershell
  Invoke-RestMethod -Uri "http://localhost:8083/api/v1/notifications/simulate-tier2-maker-checker" -Method Post
  ```
* **What to Show on Screen:**
  1. Terminal response outputs: `status: ALERT_BROADCAST`, `tier: TIER_2_DUAL_CONTROL`.
  2. In MailHog, click the new email sent to `compliance-officer@corebank.ph`:
     * Subject: `DUAL CONTROL REVIEW: Transfer ₱150,000.00 Requires BOO Approval [...]`
     * Header Badge: `TIER 2: DUAL CONTROL REQUIRED`
     * Required Roles: `Maker: Teller / Clerk | Checker: Branch Operations Officer (BOO) or Branch Cashier`
     * Workflow Instruction: `Teller encoded transfer; BOO must review customer ID and signature card before authorization.`

---

### Scenario 3: Tier 3 AMLA Covered Hold (₱750,000.00 High-Value CTR)
* **Context:** A customer deposits/transfers ₱750,000.00 (meets/exceeds ₱500,000.00 AMLA threshold). Requires Covered Transaction Report (CTR) filing and dual manager sign-off.
* **PowerShell Command:**
  ```powershell
  Invoke-RestMethod -Uri "http://localhost:8083/api/v1/notifications/simulate-tier3-amla" -Method Post
  ```
* **What to Show on Screen:**
  1. Terminal response outputs: `status: ALERT_BROADCAST`, `tier: TIER_3_AMLA_COVERED`.
  2. Notice the warning: `MANDATORY: Covered Transaction Report (CTR) filing required under AMLA before balance mutation.`
  3. In MailHog, open the email:
     * Subject: `URGENT AMLA HOLD: Transfer ₱750,000.00 Requires CTR Filing & Dual Manager Approval [...]`
     * Crimson Security Header: `URGENT AMLA HOLD`
     * AMLA Status: `COVERED TRANSACTION REPORT (CTR) FILING MANDATORY`
     * Required Roles: `Maker: Teller | Checker 1: BOO | Approver 2: Branch Head / Operations Manager`

---

### Scenario 4: Anti-Spam / Idempotency Duplicate Suppression
* **Context:** A customer double-clicks the transfer button or Kafka redelivers an event due to a temporary network lag. Customers must never receive duplicate emails for the same transaction.
* **PowerShell Command:**
  ```powershell
  $dup = @{
      transfer_id = "TRX-DEMO-DEDUP-99"
      source_account = "ACC-1002938471"
      destination_account = "ACC-2009847192"
      recipient_email = "maria.santos@corebank.ph"
      amount = 5000.00
      status = "COMMITTED"
      event_type = "TRANSFER_EXECUTED"
  } | ConvertTo-Json

  # 1st Send
  Write-Host "Attempt 1: Dispatching transfer..." -ForegroundColor Cyan
  Invoke-RestMethod -Uri "http://localhost:8083/api/v1/notifications/simulate-transfer" -Method Post -ContentType "application/json" -Body $dup

  # 2nd Send (Exact Duplicate)
  Write-Host "Attempt 2: Simulating network duplicate..." -ForegroundColor Yellow
  Invoke-RestMethod -Uri "http://localhost:8083/api/v1/notifications/simulate-transfer" -Method Post -ContentType "application/json" -Body $dup
  ```
* **What to Show on Screen:**
  1. Check MailHog: Search for `TRX-DEMO-DEDUP-99`.
  2. **Verify that exactly ONE email exists in MailHog**, not two!
  3. Show the Docker container logs:
     ```powershell
     docker logs --tail 5 notification-service
     ```
     *Output confirms:* `Duplicate notification suppressed for transfer: TRX-DEMO-DEDUP-99`

---

### Scenario 5: Oracle Database Audit Log Verification
* **Context:** Bank compliance auditors require permanent database proof of all sent notifications.
* **PowerShell Command:**
  ```powershell
  Invoke-RestMethod -Uri "http://localhost:8083/api/v1/notifications/history" | Select-Object -First 5 | Format-Table notificationId, type, message -AutoSize
  ```
* **What to Show on Screen:**
  * Displays the `NOTIFICATIONS` table records in Oracle XE, proving that every `TRANSACTION_ALERT`, `MAKER_CHECKER_ALERT`, and `AMLA_CTR_ALERT` is permanently recorded with timestamps.

---

### Scenario 6: Outage Resilience & In-Memory Spool Status
* **Context:** Shows how the service behaves if downstream email services experience downtime.
* **PowerShell Command:**
  ```powershell
  Invoke-RestMethod -Uri "http://localhost:8083/api/v1/notifications/spool-status"
  ```
* **What to Show on Screen:**
  * Demonstrates `spool_size: 0` and `circuit_open: False` when healthy.
  * Explains that if SMTP fails, emails enter the in-memory spool rather than failing the core banking transaction, and can be flushed via `POST /api/v1/notifications/flush-spool` when the connection recovers.

---

## 6. Everything You Need to Know (Defense Cheat Sheet)

### Q1: Why do we use MailHog instead of real email?
> **Answer:** *"MailHog is an enterprise-grade mock SMTP sandbox. In banking systems, developers never send live emails during development or automated tests to avoid exposing personal passwords in Git and to prevent accidentally spamming real people. MailHog runs locally in Docker, requires zero passwords, works offline, and lets us visually verify our HTML receipts. In production, we switch to an enterprise relay like AWS SES or SendGrid via environment variables with zero code changes."*

### Q2: Why is the Notification Service asynchronous?
> **Answer:** *"Sending an email across the internet can take 1 to 3 seconds. The Core Retail Ledger must process balance mutations in under 50 milliseconds. By decoupling notifications through Kafka, the ledger updates the balance instantly, drops an event into Kafka, and the Notification Service handles the receipt in the background without ever slowing down the banking core."*

### Q3: How do we prevent duplicate emails if a user double-clicks?
> **Answer:** *"We implement distributed idempotency using Redis. When a transaction event arrives, the service executes `SET notif:seen:<transfer_id> 1 NX EX 3600`. The first attempt acquires the key and sends the email. If a duplicate event arrives within an hour, Redis flags it as already seen, and the service suppresses the duplicate immediately."*

### Q4: How does our service satisfy BSP and AMLA regulations?
> **Answer:** *"Under the BSP Manual of Regulations for Banks (MORB) and AMLA, we enforce a 3-tier threshold: transactions up to ₱50k are handled directly by tellers; transactions from ₱50k to ₱500k enter Dual Control requiring Branch Operations Officer (BOO) review; and transactions ₱500k and above are flagged as AMLA Covered, requiring Covered Transaction Report (CTR) filing and dual manager approval (BOO + Branch Head) before balance mutation."*
