# Benchmark Preregistration Document

This document records the preregistered evaluation plan, system specifications, decision boundaries, hypotheses, metrics, and statistical protocols for benchmarking the hybrid risk scoring pipeline:
**Gate 0 Hard Rules -> XGBoost (Always) -> NanoJev (Zero-shot, Memo-Present Only, Escalate-Only)**.

---

## 1. Evaluated Systems

The benchmark compares five distinct risk evaluation architectures evaluated across identical data splits:

- **S1: Tuned Rules Baseline**
  Deterministic rule set with multi-factor thresholds (amount spike, velocity, distance, device flags, keyword regex) tuned strictly on validation set $V$.
- **S2: Gate 0 + XGBoost (No Memo)**
  Gate 0 hard rules followed by an XGBoost model trained on all tabular, temporal, behavioural, and device context features. Completely ignores memo text and memo presence.
- **S3: Gate 0 + XGBoost + TF-IDF Baseline**
  Gate 0 hard rules followed by an XGBoost model enriched with an out-of-fold (OOF 5-fold on $T$) logistic regression score derived from word/char n-gram TF-IDF representations of the transfer memo.
- **S4: Gate 0 + XGBoost + NanoJev Escalate-Only (Headline System)**
  Gate 0 hard rules followed by XGBoost for initial action scoring. If a memo is present, Qwen2.5-0.5B ONNX executes zero-shot classification to produce calibrated probabilities. An escalate-only rule may elevate the risk action by at most one tier, but can never downgrade it.
- **S5: NanoJev Standalone (Reference Only)**
  Zero-shot Qwen2.5-0.5B ONNX evaluated on memo-present transactions using prompt-based classification, serving as an isolated reference point.

---

## 2. Decision Logic and the Escalate-Only Combining Rule

### 2.1 Gate 0 Hard Rules (Immediate Deterministic Triage)
Gate 0 evaluates unambiguous physical and device integrity constraints before any model execution:
1. `velocity_kmh > 1000.0` -> `BLOCK` (Reason: `IMPOSSIBLE_TRAVEL_VELOCITY`)
2. `(emulator OR hooking) AND amount_php >= HIGH_VALUE_THRESHOLD` -> `BLOCK` (Reason: `CRITICAL_DEVICE_TAMPERING_HIGH_VALUE`)
3. `rooted AND device_id_new AND amount_php >= MED_VALUE_THRESHOLD` -> `REQUIRE_2FA` (Reason: `ROOTED_NEW_DEVICE_ELEVATED_AMOUNT`)
4. `attestation_verdict == 'FAILED' AND amount_php >= MED_VALUE_THRESHOLD` -> `REQUIRE_2FA` (Reason: `FAILED_DEVICE_ATTESTATION`)
5. `mock_location AND distance_from_home_km > 150.0` -> `REQUIRE_2FA` (Reason: `MOCK_LOCATION_SPOOFING`)

If any Gate 0 rule triggers, its action is final and terminal. Downstream models are bypassed.

### 2.2 XGBoost Initial Action ($a_0$)
For transactions passing Gate 0, XGBoost outputs a continuous fraud score $\hat{y} \in [0, 1]$.
Two thresholds $(\tau_{\text{2fa}}, \tau_{\text{block}})$ tuned on validation set $V$ define initial action $a_0$:
- If $\hat{y} \ge \tau_{\text{block}}$: $a_0 = \text{BLOCK}$
- Else if $\hat{y} \ge \tau_{\text{2fa}}$: $a_0 = \text{REQUIRE\_2FA}$
- Else: $a_0 = \text{ALLOW}$

### 2.3 Escalate-Only Fusion Rule
If `memo_present == False`, final action $a^* = a_0$.
If `memo_present == True`:
NanoJev produces temperature-calibrated probabilities:
$$P(\text{ALLOW}), \quad P(\text{REQUIRE\_2FA}), \quad P(\text{BLOCK})$$
Using at most two thresholds $(\theta_{\text{block}}, \theta_{\text{2fa}})$ tuned on validation set $V$:
- **Escalation to BLOCK**:
  If $P(\text{BLOCK}) \ge \theta_{\text{block}}$:
  - If $a_0 == \text{REQUIRE\_2FA}$: $a^* = \text{BLOCK}$ (raised one level)
  - If $a_0 == \text{ALLOW}$: $a^* = \text{REQUIRE\_2FA}$ (raised at most one level to avoid single-stage over-escalation)
- **Escalation to 2FA**:
  Else if $P(\text{REQUIRE\_2FA}) + P(\text{BLOCK}) \ge \theta_{\text{2fa}}$:
  - If $a_0 == \text{ALLOW}$: $a^* = \text{REQUIRE\_2FA}$ (raised one level)
  - If $a_0 \in \{\text{REQUIRE\_2FA}, \text{BLOCK}\}$: $a^* = a_0$ (unchanged)
- **Default**:
  $a^* = a_0$.

**Core Invariant**: For all transactions $i$, $\text{RiskTier}(a^*) \ge \text{RiskTier}(a_0)$ where $\text{RiskTier}(\text{ALLOW}) = 0 < \text{RiskTier}(\text{REQUIRE\_2FA}) = 1 < \text{RiskTier}(\text{BLOCK}) = 2$.
NanoJev can never downgrade an action. Prompt injections cannot lower fraud risk.

---

## 3. Preregistered Hypotheses

- **H1 (Memo Generalization)**: On memo-present rows of held-out set $C_2$ (novel scam typologies and unseen phrasing), S4 achieves higher PR-AUC or higher recall at 1.0% FPR than S2 (tabular only) and S3 (TF-IDF baseline).
- **H2 (False Block Control)**: S4 does not increase the false-block rate on legitimate transactions by more than 0.50 percentage points compared to S2 on standard test set $C_1$.
- **H3 (Memo-Absent Equivalence)**: On memo-absent rows, the predictions of S4 and S2 are identical by construction ($S_4 \equiv S_2$).
- **H4 (Latency and Throughput SLA)**: In CPU single-request execution with 10 worker threads, p99 end-to-end latency remains within 200 ms under an open-loop arrival rate of 25 TPS, with a 150 ms timeout fallback protecting tail latency.
- **H5 (Prompt Injection Resistance)**: Over at least 50 adversarial prompt injection memos injected into fraud records, zero transactions result in a downgraded action.
- **H6 (Device Feature Contribution)**: An ablation study demonstrates that incorporating device context features yields a statistically significant increase in XGBoost ROC-AUC over an identical model trained without device features.

---

## 4. Evaluation Metrics and Cost Matrix

### 4.1 Binary Detection Metrics (Fraud vs Legitimate)
- Precision-Recall AUC (PR-AUC)
- ROC-AUC
- Recall at fixed 1.0% False Positive Rate (FPR)
- Recall at fixed 0.1% FPR (evaluated on $C_3$)
- Precision at 90.0% Recall
- Total Alerts generated per 1,000 transactions

### 4.2 Three-Action Metrics and Operational Cost Matrix
- Macro-averaged F1 score across ALLOW, REQUIRE_2FA, BLOCK
- Complete 3x3 Confusion Matrix
- False Block Rate on legitimate users: $\frac{N(\text{Legit } \to \text{ BLOCK})}{N(\text{Legit})}$
- Missed Fraud Rate: $\frac{N(\text{Fraud } \to \text{ ALLOW})}{N(\text{Fraud})}$
- **Expected Cost per 1,000 Transactions**:
  $$\text{Cost} = \sum_{i} \text{Cost}(y_i, a_i^*)$$
  Based on explicitly labeled banking operational assumptions in `config.yaml`:
  - Missed Fraud ($y=\text{Fraud}, a^*=\text{ALLOW}$): Cost equals transaction amount in PHP.
  - False Block ($y=\text{Legit}, a^*=\text{BLOCK}$): Fixed friction and support cost of PHP 1,000.
  - Step-up Authentication ($y=\text{Legit}, a^*=\text{REQUIRE\_2FA}$): SMS OTP and friction cost of PHP 25.
  - Mitigated Fraud ($y=\text{Fraud}, a^*=\text{REQUIRE\_2FA}$): 2FA halts fraud with probability 0.85; remaining 0.15 incurs full fraud loss plus PHP 25.
  - Correct Block ($y=\text{Fraud}, a^*=\text{BLOCK}$): Zero fraud loss, PHP 0 operational penalty.
  - Correct Allow ($y=\text{Legit}, a^*=\text{ALLOW}$): PHP 0.

---

## 5. Statistical Protocols

1. **Bootstrap Confidence Intervals**: 95% empirical bootstrap confidence intervals computed using 1,000 cluster resamples grouped by `user_id` to preserve intra-user correlation.
2. **Paired Difference Tests**: Bootstrap distribution of differences $(S_4 - S_2)$ and $(S_4 - S_3)$ evaluated for statistical significance ($\alpha = 0.05$).
3. **Multi-Seed Stability**: Data generation and XGBoost training executed across 3 independent random seeds (`42`, `101`, `2024`) reporting mean and standard deviation.
4. **Fairness Controls**: Identical splits across all systems; identical hyperparameter search budget (30 trials of random search with early stopping on $V$); all thresholds selected strictly on $V$ before evaluating test sets $C_1, C_2, C_3$.
