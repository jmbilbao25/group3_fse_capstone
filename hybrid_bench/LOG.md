# Benchmark Execution Log

## Phase 0: Reconnaissance & Environment Audit
- **Timestamp**: 2026-10-04 18:19:40
- **Host**: Windows 11 (10.0.26200, AMD64), 16 logical cores, 32,468 MB RAM.
- **Python**: 3.12.14 running in virtual environment `C:\Users\JLB83807\The Vault\workspaces\FSE-Capstone\.venv`.
- **Packages**: onnxruntime 1.30.0, xgboost 3.4.1, scikit-learn 1.9.1, tokenizers 0.23.2, shap 0.52.0.
- **Existing NanoJev Engine Audit**:
  - Found `backend/risk-service/app/nanojev_engine.py` intact and unchanged.
  - Model: `model_int8.onnx` (488.37 MB), `tokenizer.json`.
  - Calling mechanism: `NanoJevEngine.evaluate()` performs Gate 0 deterministic triage, then executes ONNX forward pass, and merges logits with Bayesian telemetry priors (`prior_allow`, `prior_req`, `prior_block`) based on regex flags and telemetry.
  - Raw logits access: `evaluate()` computes raw logits for tokens `ALLOW`, `REQUIRE`, and `BLOCK` into `raw_logits_dict`, but does not expose them before Bayesian prior addition.
  - Wrapper strategy: Created `hybrid_bench.wrapper.NanoJevRawWrapper` which loads the ONNX session and tokenizer directly using the identical prompt template without modifying `nanojev_engine.py`. It returns pre-prior raw logits `[allow_logit, req_logit, block_logit]` and calibrated softmax probabilities.

## Phase 1: Preregistration & Scope Lock
- **Timestamp**: 2026-10-04 17:35:12
- **Preregistration File**: `hybrid_bench/PREREGISTRATION.md`
- **SHA256 Commit Hash**: `0f546de2f9cd3b0fad44ebf92279b5d738cbc2b2e0d58f8c2bd2ffe9a5db5620` (written to `hybrid_bench/results/prereg_hash.txt`)
- **Preregistered Systems**:
  - S1: Tuned Rules Baseline (thresholds tuned on V)
  - S2: Gate 0 + XGBoost (Tabular + Device Context, no memo)
  - S3: Gate 0 + XGBoost + TF-IDF memo score (5-fold OOF on T)
  - S4: Gate 0 + XGBoost + NanoJev (zero-shot, ONLY when memo present, escalate-only)
  - S5: Standalone NanoJev (zero-shot choices on memo-present rows)
- **Primary Hypotheses**: H1 (memo generalization on C2), H2 (false block rate control on C1), H3 (memo-absent equivalence), H4 (200ms latency SLA at 25 TPS), H5 (prompt injection resistance: 0 downgrades), H6 (device context ROC lift).

## Phase 2: Synthetic Data Generation & Audit
- **Timestamp**: 2026-10-04 17:40:48
- **Generated Splits**:
  - `T` (Train): 4,000 transactions (3,000 users), 15.0% fraud, 30.0% memo-present.
  - `V` (Validation): 1,000 transactions (800 users), 15.0% fraud, 30.0% memo-present.
  - `C1` (Standard Test): 1,000 transactions (800 users), 15.0% fraud, 30.0% memo-present.
  - `C2` (Held-Out Novel Typologies): 500 transactions (400 users), 15.0% fraud, 30.0% memo-present. Memos drawn strictly from `memo_heldout_independent.csv`.
  - `C3` (Production Imbalanced): 2,000 transactions (1,500 users), 1.5% fraud, 30.0% memo-present.
  - `C4` (Handwritten Memos): 50 transactions (50 users), 30.0% fraud, 100.0% memo-present.
- **Audit Outcomes**:
  - Zero user overlap across splits (disjoint user partitions verified).
  - C2 novel memos verified: 0% overlap with training seed memos.
  - Formats: Parquet and CSV written to `hybrid_bench/data/splits/`.
  - Data Card documentation: `hybrid_bench/DATA_CARD.md`.

## Phase 3: Gate 0 + XGBoost Training & Feature Ablations
- **Timestamp**: 2026-10-04 17:48:22
- **Gate 0 Execution**:
  - Filtered 136/4,000 rows on T (3.4%, precision: 100.0%)
  - Filtered 34/1,000 rows on V (3.4%, precision: 100.0%)
- **S1 (Tuned Rules Baseline)**: Tuned on V with optimal parameters `{'amount_threshold': 50000.0, 'drain_threshold': 0.85, 'spike_threshold': 5.0, 'velocity_threshold': 500.0, 'high_risk_purpose': True, 'require_device_flags': True}`.
- **S2 (XGBoost Tabular + Device Context)**:
  - Val ROC-AUC: 0.9824 | Val PR-AUC: 0.9688
  - Tuned Thresholds: tau_2fa = 0.400, tau_block = 0.500
- **S3 (XGBoost + OOF TF-IDF Memo Baseline)**:
  - Val ROC-AUC: 0.9819 | Val PR-AUC: 0.9681
- **Ablation Studies**:
  - Without Device Features: ROC-AUC = 0.9686 (Device Lift: +0.0137 ROC-AUC, confirming H6)
  - Without Payee/Purpose: ROC-AUC = 0.9850 (Payee Lift: -0.0027 ROC-AUC)
- **SHAP Analysis**: Generated beeswarm summary plot at `hybrid_bench/reports/shap_importance.png`. Top predictive features: `os_patch_age_days`, `balance_drain_ratio`, `payee_age_days`, `form_seconds`, `payees_24h`.

## Phase 4: NanoJev Zero-Shot Calibration & Escalate-Only Tuning
- **Timestamp**: 2026-10-04 18:02:15
- **Zero-Shot Scoring**: Scored all memo-present rows (284 on V).
- **Temperature Scaling on V**:
  - Uncalibrated ECE: 0.4946
  - Optimal Temperature T: 5.000
  - Calibrated ECE: 0.2129 (-0.2817 ECE reduction)
  - Reliability Diagram: saved to `hybrid_bench/reports/calibration_curve.png`.
- **Escalate-Only Threshold Tuning on V**:
  - theta_block: 0.400
  - theta_2fa: 0.600
  - Fusion Accuracy on V: 94.37%
  - Fusion Macro-F1 on V: 0.7725
- **S5 Standalone (Memo-Present V)**: ROC-AUC = 0.6483, PR-AUC = 0.4024, Accuracy = 72.89%.

## Phase 5: Multi-System Test Evaluation & Preregistered Hypotheses
- **Timestamp**: 2026-10-04 18:08:44
- **Splits Evaluated**: C1, C2, C3, C4 (1,000 cluster bootstrap resamples grouped by `user_id`).
- **Key Point Estimates (PR-AUC / ROC-AUC / Macro-F1 / Cost per 1k PHP)**:
  - C1 (Standard): S1 (0.7841 / 0.9205 / 0.6743 / PHP 507,035), S2 (0.9986 / 0.9997 / 0.5414 / PHP 89,696), S3 (0.9973 / 0.9995 / 0.5414 / PHP 89,696), S4 (0.9771 / 0.9911 / 0.4775 / PHP 56,546), S5 (0.4843 / 0.7096 / 0.5417 / PHP 911,535)
  - C2 (Novel Scam Memos): S2 (0.9974 / 0.9995 / 0.4548 / PHP 28,211), S4 (0.9913 / 0.9975 / 0.4050 / PHP 27,908)
  - C3 (Imbalanced 1.5% Fraud): S2 (0.8487 / 0.9990 / 0.4732 / PHP 16,580), S4 (0.7932 / 0.9799 / 0.4266 / PHP 22,605)
  - C4 (Handwritten Memos): S2 (1.0000 / 1.0000 / 0.4222 / PHP 25,586), S4 (1.0000 / 1.0000 / 0.3339 / PHP 32,086)
- **Hypotheses Outcomes**:
  - H1 (Memo Generalization on C2): SUPPORTED (S4 Recall@1% FPR = 0.9333, PR-AUC = 0.9561 on memo subset)
  - H2 (False Block Control on C1): SUPPORTED (S4 False Block Rate = 0.00%, S2 = 0.00%, Difference = +0.00 pp <= 0.50 pp)
  - H3 (Memo-Absent Equivalence): SUPPORTED (1179/1179 memo-absent transactions strictly identical across splits)
  - H6 (Device Feature Contribution): SUPPORTED (+0.0137 ROC lift)

## Phase 6: Latency & Throughput Benchmarks
- **Timestamp**: 2026-10-04 18:18:40
- **Component Latencies (p50 / p95 / p99)**:
  - Gate 0 Hard Rules: 0.001 ms / 0.001 ms / 0.001 ms
  - Tabular Feature Pipeline: 31.131 ms / 52.395 ms / 70.996 ms
  - XGBoost Inference: 4.405 ms / 29.381 ms / 55.756 ms
  - NanoJev Raw ONNX (CPU): 294.6 ms / 857.6 ms / 957.0 ms
  - SAR Background Dispatch: 0.008 ms / 0.014 ms / 0.245 ms
- **System Paths (p50 / p99)**:
  - S2 (Tabular-only): 28.67 ms / 32.92 ms
  - S4 (Memo-absent): 28.63 ms / 42.22 ms
  - S4 (Blended 70/30 Population): 29.17 ms / 212.29 ms
- **Open-Loop Traffic Simulation (10 Workers)**:
  - 10 TPS: p50=76.8 ms, p99=137.0 ms, SLA=100.0%
  - 25 TPS: p50=1116.9 ms, p99=2073.1 ms, SLA=4.0%
  - 50 TPS: p50=3737.3 ms, p99=6596.6 ms, SLA=1.2%
- **Hypothesis H4 Outcome**: NOT SUPPORTED (p99=2073.1 ms <= 200 ms SLA under CPU core queuing).

## Phase 7: Robustness & Prompt Injection Testing
- **Timestamp**: 2026-10-04 18:15:32
- **Adversarial Injections Tested**: 60 memos across 10 attack categories (600 evaluation trials).
- **Security Invariant Verification**:
  - Total Downgrades: 0 (0.00%)
  - Escalations to Higher Security: 225 (37.5%)
  - Unchanged Decisions: 375 (62.5%)
- **Metamorphic Robustness**: 27 mutations tested, 0 invariant violations (100.0% robustness).
- **Hypothesis H5 Outcome**: SUPPORTED (0 downgrades across 60 attack vectors).

## Phase 8: Programmatic Report Compilation
- **Timestamp**: 2026-10-04 18:21:05
- **Script**: `hybrid_bench/reports/generate_report.py`
- **Output Report**: `hybrid_bench/reports/REPORT.md` (20,406 bytes)
- **Compliance**:
  - 100% of numerical values generated from `results/*.json` without manual overrides.
  - Zero em dashes (—) or en dashes (–) used in prose.
  - Sentence case section headings applied throughout.
  - Full hypothesis scorecard and engineering recommendations documented.
## Phase 7: Robustness & Prompt Injection Testing
- **Timestamp**: 2026-10-04 18:48:28
- **Adversarial Injections Tested**: 60 memos across 10 attack categories (600 evaluation trials).
- **Security Invariant Verification**:
  - Total Downgrades: 0 (0.00%)
  - Escalations to Higher Security: 225 (37.5%)
  - Unchanged Decisions: 375 (62.5%)
- **Metamorphic Robustness**: 27 mutations tested, 0 invariant violations (100.0% robustness).
- **Hypothesis H5 Outcome**: SUPPORTED (0 downgrades across 60 attack vectors).

## Phase 7: Robustness & Prompt Injection Testing
- **Timestamp**: 2026-10-04 19:05:46
- **Adversarial Injections Tested**: 60 memos across 10 attack categories (600 evaluation trials).
- **Security Invariant Verification**:
  - Total Downgrades: 0 (0.00%)
  - Escalations to Higher Security: 225 (37.5%)
  - Unchanged Decisions: 375 (62.5%)
- **Metamorphic Robustness**: 27 mutations tested, 0 invariant violations (100.0% robustness).
- **Hypothesis H5 Outcome**: SUPPORTED (0 downgrades across 60 attack vectors).

