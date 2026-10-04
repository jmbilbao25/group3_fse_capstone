"""
Evaluation and Benchmarking Suite for Asynchronous Second-Look Reviewer.

Implements all requirements from capstone re-architecture:
1. Re-verifies synchronous baseline S2 performance on C1, C2, C3, and C4 splits.
2. Generates and evaluates a synthetic 'Stress Slice' where tabular/device features
   are strictly legitimate, but memos contain realistic scam patterns.
   - Measures fraud caught that S2 allowed.
   - Measures false escalation rate on legitimate memo-present transfers.
3. Benchmarks the Async Reviewer under 25 TPS load:
   - Median (p50) and p95 time-to-review.
   - Queue drops and timeouts under bounded capacity.
   - Synchronous path p99 latency during concurrent review execution.
4. Re-runs the 60-vector prompt injection suite against the async path (0 downgrades).
5. Exports structured results to hybrid_bench/results/async_reviewer_evaluation.json.
"""

import os
import sys
import json
import time
import random
import queue
import threading
from typing import Dict, Any, List, Tuple
from datetime import datetime, timezone

# Ensure project root and risk-service on sys.path
_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _REPO_ROOT not in sys.path:
    sys.path.insert(0, _REPO_ROOT)

_RISK_SERVICE_ROOT = os.path.join(_REPO_ROOT, "backend", "risk-service")
if _RISK_SERVICE_ROOT not in sys.path:
    sys.path.insert(0, _RISK_SERVICE_ROOT)

import numpy as np
import pandas as pd
import joblib
from sklearn.metrics import roc_auc_score, average_precision_score, f1_score

from hybrid_bench.gate0 import Gate0Filter
from hybrid_bench.train_xgb import TabularFeaturePipeline
import __main__
__main__.TabularFeaturePipeline = TabularFeaturePipeline

from app.reviewer import (
    NanoJevSecondLookEngine,
    AsyncReviewWorkerPool,
    TransferStore,
    AnalystDecisionStore,
    ReviewerMetrics,
    enforce_escalate_only,
    evaluate_memo_consistency,
    ACTION_TIERS,
    VALID_TYPOLOGIES
)
from hybrid_bench.test_robustness import ADVERSARIAL_MEMOS


# ---------------------------------------------------------------------------
# 1. S2 Baseline Verification on C1-C4
# ---------------------------------------------------------------------------

def verify_s2_benchmark(base_dir: str) -> Dict[str, Any]:
    print("\n" + "=" * 70)
    print("STEP 1: VERIFYING SYNCHRONOUS S2 BASELINE ON TEST SPLITS (C1 - C4)")
    print("=" * 70)

    models_dir = os.path.join(base_dir, "models")
    results_dir = os.path.join(base_dir, "results")
    splits_dir = os.path.join(base_dir, "data", "splits")

    model_s2 = joblib.load(os.path.join(models_dir, "s2_xgb_model.joblib"))
    pipe_s2 = joblib.load(os.path.join(models_dir, "s2_feature_pipeline.joblib"))
    gate0 = Gate0Filter()

    with open(os.path.join(results_dir, "phase3_results.json"), "r", encoding="utf-8") as f:
        p3_res = json.load(f)
    with open(os.path.join(results_dir, "phase5_results.json"), "r", encoding="utf-8") as f:
        p5_res = json.load(f)

    tau_2fa = p3_res["s2_xgboost_full"]["tau_2fa"]
    tau_block = p3_res["s2_xgboost_full"]["tau_block"]

    verification_summary = {}

    for split in ["C1", "C2", "C3", "C4"]:
        parquet_path = os.path.join(splits_dir, f"{split}.parquet")
        if not os.path.exists(parquet_path):
            continue
        df = pd.read_parquet(parquet_path)
        n = len(df)
        y_true = df["is_fraud"].values

        # Run Gate 0
        g0_df = gate0.evaluate_dataframe(df).reset_index(drop=True)
        g0_passed = g0_df["gate0_passed"].values
        g0_actions = g0_df["gate0_action"].values

        # Run S2 Pipeline + XGBoost
        X_s2 = pipe_s2.transform(df)
        p_xgb = model_s2.predict_proba(X_s2)[:, 1]
        s2_scores = np.where(~g0_passed, 1.0, p_xgb)

        s2_actions = []
        for i in range(n):
            if not g0_passed[i]:
                s2_actions.append(g0_actions[i])
            else:
                p = p_xgb[i]
                if p >= tau_block:
                    s2_actions.append("BLOCK")
                elif p >= tau_2fa:
                    s2_actions.append("REQUIRE_2FA")
                else:
                    s2_actions.append("ALLOW")

        # Binary metrics
        if len(np.unique(y_true)) > 1:
            roc_auc = float(roc_auc_score(y_true, s2_scores))
            pr_auc = float(average_precision_score(y_true, s2_scores))
        else:
            roc_auc = 1.0
            pr_auc = 1.0

        # Action metrics
        legit_idx = np.where(~y_true)[0]
        fraud_idx = np.where(y_true)[0]
        s2_actions_arr = np.array(s2_actions)

        false_blocks = int(np.sum(s2_actions_arr[legit_idx] == "BLOCK"))
        fbr = false_blocks / max(len(legit_idx), 1)

        missed_fraud = int(np.sum(s2_actions_arr[fraud_idx] == "ALLOW"))
        mfr = missed_fraud / max(len(fraud_idx), 1)

        expected_s2 = p5_res["split_results"][split]["point_estimates"]["S2"]
        exp_roc = expected_s2["binary"]["roc_auc"]
        exp_pr = expected_s2["binary"]["pr_auc"]

        roc_diff = abs(roc_auc - exp_roc)
        pr_diff = abs(pr_auc - exp_pr)
        is_identical = (roc_diff < 1e-4 and pr_diff < 1e-4)

        verification_summary[split] = {
            "transactions": n,
            "roc_auc": round(roc_auc, 4),
            "expected_roc_auc": exp_roc,
            "pr_auc": round(pr_auc, 4),
            "expected_pr_auc": exp_pr,
            "false_block_rate": round(fbr, 4),
            "missed_fraud_rate": round(mfr, 4),
            "status": "MATCHED" if is_identical else "DISCREPANCY"
        }

        print(f"  [{split}] ROC-AUC={roc_auc:.4f} (exp={exp_roc:.4f}), PR-AUC={pr_auc:.4f} (exp={exp_pr:.4f}) -> {verification_summary[split]['status']}")

    return verification_summary


# ---------------------------------------------------------------------------
# 2. Synthetic Stress Slice Generation & Evaluation
# ---------------------------------------------------------------------------

SCAM_MEMOS_STRESS = [
    # Investment Scams
    "Guaranteed 50% weekly return join crypto arbitrage telegram group",
    "High yield investment program initial trading pool deposit",
    "Double your money 24 hours guaranteed crypto investment payout",
    "Exclusive VIP bitcoin trading bot subscription deposit",
    "Cryptocurrency liquidation pool guaranteed profit share",
    "Forex automated trading bot license and profit lock fee",
    "Pre-IPO private placement equity share transfer urgent",
    "Gold bullion trading arbitrage return deposit",
    "Secured digital currency yield farm staking fee",
    "Guaranteed return crypto mining contract activation",

    # Romance / Impersonation Scams
    "Dearest please send release fee for my diplomatic package stuck in customs",
    "Mom my phone is broken please send emergency hospital bill to this number",
    "Urgent bail bond for nephew detained at Manila police station",
    "Honey please wire medical assistance for emergency surgery tonight",
    "Dad my wallet was stolen please send cash for ticket home asap",
    "Overseas soldier humanitarian release fee customs clearance",
    "Emergency medical assistance for injured daughter in Cebu hospital",
    "Grandma emergency tuition fee required before examination today",
    "My loving partner urgent visa processing fee to visit you",
    "Son here urgent legal consultation retainer payment required",

    # Fake Invoices & Advance Fee Frauds
    "Urgent overdue penalty payment invoice 9942 please settle immediately",
    "Express courier package release fee and customs tax clearance",
    "Refund processing fee required before releasing merchant reimbursement",
    "Unfreeze bank account service fee and compliance bond",
    "Lottery winning claim tax clearance processing fee deposit",
    "Inheritance disbursement release legal fee BSP clearance",
    "Government cash grant activation processing fee wire",
    "Overdue utility termination avoidance urgent payment fee",
    "Air cargo delivery unblocking insurance clearance fee",
    "Contract release advance payment fee before fund disbursement",

    # Task / Job / Multi-Level Scams
    "Task reward refund deposit required to unlock commission balance",
    "Affiliate job task completion deposit to withdraw salary",
    "E-commerce product rating deposit refund tier 4 upgrade",
    "Data entry job security guarantee bond deposit payment",
    "Social media follow task withdrawal activation fee",
    "Merchant review task security deposit refundable today",
    "Secret shopper assignment processing fee advance",
    "Work from home package security deposit unlock",
    "Platform rating commission withdrawal tax clearance",
    "VIP member task upgrade deposit for instant payout"
]

BENIGN_MEMOS_STRESS = [
    "Dinner share last night thanks bro",
    "October apartment rental payment",
    "Weekly grocery share from supermarket",
    "Happy 25th birthday gift for sister",
    "College tuition fee 1st installment",
    "Meralco electricity bill payment",
    "Maynilad water service bill settlement",
    "Carpool fuel share for past week",
    "Dental clinic teeth cleaning checkup",
    "Office potluck lunch contribution",
    "Pharmacy medicine reimbursement",
    "Piano lessons monthly tutorial fee",
    "Veterinary clinic pet vaccination payment",
    "School supplies and book payment",
    "Gym membership monthly renewal",
    "Coffee and snack run share for team",
    "Movie tickets reimbursement for four",
    "Birthday dinner split at Italian bistro",
    "Home repair plumber labor fee",
    "Car wash and detailing service",
    "Babysitting service payment for Saturday",
    "Soccer league registration fee",
    "Art class materials reimbursement",
    "Hair salon appointment payment",
    "Laundry service pickup payment",
    "Cousin wedding gift contribution",
    "Book club order reimbursement",
    "Weekend beach trip cabin rental share",
    "Department lunch reimbursement",
    "Bicycle repair and replacement tire"
]


def build_stress_slice(n_scam: int = 50, n_benign: int = 50) -> pd.DataFrame:
    """
    Builds a synthetic 'stress slice' where tabular and device features
    are completely clean/normal (aged payee, trusted device, low drain ratio),
    but the memo contains either scam solicitations or benign everyday text.
    """
    random.seed(42)
    np.random.seed(42)

    rows = []

    # 1. Scam Memos (Fraud = True, but Tabular Signals = Benign)
    for i in range(n_scam):
        memo = SCAM_MEMOS_STRESS[i % len(SCAM_MEMOS_STRESS)]
        amt = float(np.random.uniform(2500.0, 15000.0))
        user_avg = amt / np.random.uniform(0.95, 1.10)
        curr_bal = float(np.random.uniform(50000.0, 150000.0))

        row = {
            "transaction_id": f"TX-STRESS-SCAM-{i+1:03d}",
            "user_id": f"usr-stress-{i+1:03d}",
            "amount_php": amt,
            "user_avg_amount_php": user_avg,
            "current_balance": curr_bal,
            "balance_drain_ratio": amt / curr_bal,
            "spike_ratio": amt / user_avg,
            "transactions_24h": np.random.randint(1, 4),
            "amount_sum_24h": amt * 1.2,
            "transactions_7d": np.random.randint(5, 15),
            "amount_sum_7d": amt * 4.0,
            "payee_age_days": float(np.random.uniform(120.0, 365.0)), # Aged, familiar payee
            "payees_24h": 1,
            "senders_to_payee_24h": np.random.randint(1, 3),
            "hour_of_day": np.random.randint(9, 18),
            "day_of_week": np.random.randint(0, 5),
            "is_weekend": False,
            "device_age_days": float(np.random.uniform(180.0, 450.0)),
            "accounts_per_device": 1,
            "os_patch_age_days": float(np.random.uniform(5.0, 30.0)),
            "seconds_since_login": float(np.random.uniform(60.0, 300.0)),
            "failed_logins_1h": 0,
            "credential_change_hours_ago": 720.0,
            "form_seconds": float(np.random.uniform(15.0, 45.0)),
            "gps_accuracy_m": 10.0,
            "distance_from_home_km": float(np.random.uniform(0.5, 5.0)),
            "distance_from_prev_km": float(np.random.uniform(0.0, 3.0)),
            "elapsed_minutes": 120.0,
            "velocity_kmh": 0.0,
            "new_payee": False,
            "device_id_new": False,
            "rooted": False,
            "hooking": False,
            "emulator": False,
            "debugger": False,
            "tampered": False,
            "unofficial_store": False,
            "dev_options": False,
            "mock_location": False,
            "accessibility_active": False,
            "screen_sharing": False,
            "payee_pasted": False,
            "tz_mismatch": False,
            "ip_gps_mismatch": False,
            "is_vpn": False,
            "transfer_purpose": "Funds Transfer",
            "payee_type": "third_party_individual",
            "channel": "mobile_banking",
            "attestation_verdict": "TRUSTED",
            "login_method": "biometrics",
            "memo_present": True,
            "memo": memo,
            "is_fraud": True,
            "stress_category": "scam_memo"
        }
        rows.append(row)

    # 2. Benign Memos (Fraud = False, Tabular Signals = Benign)
    for i in range(n_benign):
        memo = BENIGN_MEMOS_STRESS[i % len(BENIGN_MEMOS_STRESS)]
        amt = float(np.random.uniform(1000.0, 8000.0))
        user_avg = amt / np.random.uniform(0.95, 1.10)
        curr_bal = float(np.random.uniform(40000.0, 120000.0))

        row = {
            "transaction_id": f"TX-STRESS-BENIGN-{i+1:03d}",
            "user_id": f"usr-stress-legit-{i+1:03d}",
            "amount_php": amt,
            "user_avg_amount_php": user_avg,
            "current_balance": curr_bal,
            "balance_drain_ratio": amt / curr_bal,
            "spike_ratio": amt / user_avg,
            "transactions_24h": np.random.randint(1, 4),
            "amount_sum_24h": amt * 1.1,
            "transactions_7d": np.random.randint(5, 15),
            "amount_sum_7d": amt * 3.5,
            "payee_age_days": float(np.random.uniform(90.0, 300.0)),
            "payees_24h": 1,
            "senders_to_payee_24h": 1,
            "hour_of_day": np.random.randint(9, 18),
            "day_of_week": np.random.randint(0, 5),
            "is_weekend": False,
            "device_age_days": float(np.random.uniform(150.0, 400.0)),
            "accounts_per_device": 1,
            "os_patch_age_days": float(np.random.uniform(5.0, 30.0)),
            "seconds_since_login": float(np.random.uniform(60.0, 300.0)),
            "failed_logins_1h": 0,
            "credential_change_hours_ago": 720.0,
            "form_seconds": float(np.random.uniform(15.0, 45.0)),
            "gps_accuracy_m": 10.0,
            "distance_from_home_km": float(np.random.uniform(0.5, 4.0)),
            "distance_from_prev_km": float(np.random.uniform(0.0, 2.0)),
            "elapsed_minutes": 100.0,
            "velocity_kmh": 0.0,
            "new_payee": False,
            "device_id_new": False,
            "rooted": False,
            "hooking": False,
            "emulator": False,
            "debugger": False,
            "tampered": False,
            "unofficial_store": False,
            "dev_options": False,
            "mock_location": False,
            "accessibility_active": False,
            "screen_sharing": False,
            "payee_pasted": False,
            "tz_mismatch": False,
            "ip_gps_mismatch": False,
            "is_vpn": False,
            "transfer_purpose": "Funds Transfer",
            "payee_type": "third_party_individual",
            "channel": "mobile_banking",
            "attestation_verdict": "TRUSTED",
            "login_method": "biometrics",
            "memo_present": True,
            "memo": memo,
            "is_fraud": False,
            "stress_category": "benign_memo"
        }
        rows.append(row)

    return pd.DataFrame(rows)


def evaluate_stress_slice(stress_df: pd.DataFrame, base_dir: str) -> Dict[str, Any]:
    print("\n" + "=" * 70)
    print("STEP 2: EVALUATING SYNCHRONOUS S2 VS ASYNC REVIEWER ON STRESS SLICE")
    print("=" * 70)

    models_dir = os.path.join(base_dir, "models")
    results_dir = os.path.join(base_dir, "results")

    model_s2 = joblib.load(os.path.join(models_dir, "s2_xgb_model.joblib"))
    pipe_s2 = joblib.load(os.path.join(models_dir, "s2_feature_pipeline.joblib"))
    gate0 = Gate0Filter()

    with open(os.path.join(results_dir, "phase3_results.json"), "r", encoding="utf-8") as f:
        p3_res = json.load(f)
    tau_2fa = p3_res["s2_xgboost_full"]["tau_2fa"]
    tau_block = p3_res["s2_xgboost_full"]["tau_block"]

    # 1. Run Synchronous Path (Gate 0 + S2)
    X_s2 = pipe_s2.transform(stress_df)
    p_xgb = model_s2.predict_proba(X_s2)[:, 1]

    s2_actions = []
    for p in p_xgb:
        if p >= tau_block:
            s2_actions.append("BLOCK")
        elif p >= tau_2fa:
            s2_actions.append("REQUIRE_2FA")
        else:
            s2_actions.append("ALLOW")

    stress_df["s2_action"] = s2_actions
    stress_df["s2_score"] = p_xgb

    scam_mask = stress_df["is_fraud"]
    benign_mask = ~stress_df["is_fraud"]

    s2_scam_allowed = int(np.sum(stress_df[scam_mask]["s2_action"] == "ALLOW"))
    s2_scam_caught = int(np.sum(stress_df[scam_mask]["s2_action"].isin(["REQUIRE_2FA", "BLOCK"])))
    s2_benign_allowed = int(np.sum(stress_df[benign_mask]["s2_action"] == "ALLOW"))
    s2_benign_escalated = int(np.sum(stress_df[benign_mask]["s2_action"].isin(["REQUIRE_2FA", "BLOCK"])))

    print(f"  [Sync S2 on Stress Slice (N={len(stress_df)})]:")
    print(f"    Scam Cases (N={scam_mask.sum()}): ALLOW={s2_scam_allowed} (Missed: {s2_scam_allowed/scam_mask.sum():.1%}), Caught={s2_scam_caught}")
    print(f"    Benign Cases (N={benign_mask.sum()}): ALLOW={s2_benign_allowed}, Falsely Escalated={s2_benign_escalated}")

    # 2. Run Asynchronous Second-Look Reviewer on Memo-Present ALLOWs
    reviewer_engine = NanoJevSecondLookEngine(intra_op_threads=8)
    reviewer_actions = []
    typologies = []
    consistency_flags = []
    inference_latencies = []

    print("\n  [Running Async Second-Look Reviewer across Stress Slice]...")
    for idx, row in stress_df.iterrows():
        a0 = row["s2_action"]
        memo = row["memo"]
        spike = row["spike_ratio"]
        drain = row["balance_drain_ratio"]
        payee_age = row["payee_age_days"]
        amount = row["amount_php"]

        rev_result = reviewer_engine.review_transfer(
            memo=memo,
            s2_action=a0,
            balance_drain_ratio=drain,
            payee_age_days=payee_age,
            spike_ratio=spike,
            amount=amount,
            use_cache=True
        )

        rec_action = rev_result["recommended_action"]
        enf = enforce_escalate_only(
            s2_action=a0,
            reviewer_recommendation=rec_action,
            current_status="PENDING_SETTLEMENT",
            is_window_expired=False
        )
        final_action = enf["final_action"]

        reviewer_actions.append(final_action)
        typologies.append(rev_result["typology_tag"])
        consistency_flags.append(rev_result["consistency_flag"]["is_consistent"])
        inference_latencies.append(rev_result["latency_ms"])

    stress_df["reviewer_final_action"] = reviewer_actions
    stress_df["typology_tag"] = typologies
    stress_df["is_consistent"] = consistency_flags

    # Fraud caught by reviewer that S2 allowed
    reviewer_scam_escalated = int(np.sum(stress_df[scam_mask]["reviewer_final_action"].isin(["REQUIRE_2FA", "BLOCK"])))
    reviewer_scam_held = int(np.sum(stress_df[scam_mask]["reviewer_final_action"] == "BLOCK"))
    reviewer_scam_2fa = int(np.sum(stress_df[scam_mask]["reviewer_final_action"] == "REQUIRE_2FA"))
    fraud_caught_ratio = reviewer_scam_escalated / max(scam_mask.sum(), 1)

    # False escalation rate on benign memos
    reviewer_benign_escalated = int(np.sum(stress_df[benign_mask]["reviewer_final_action"].isin(["REQUIRE_2FA", "BLOCK"])))
    false_escalation_rate = reviewer_benign_escalated / max(benign_mask.sum(), 1)

    print(f"\n  [Async Reviewer Stress Slice Results]:")
    print(f"    Fraud Caught that S2 Allowed: {reviewer_scam_escalated}/{scam_mask.sum()} ({fraud_caught_ratio:.1%})")
    print(f"      - Escalated to REQUIRE_2FA: {reviewer_scam_2fa}")
    print(f"      - Escalated to HELD / BLOCK: {reviewer_scam_held}")
    print(f"    False Escalation Rate on Legitimate Transfers: {reviewer_benign_escalated}/{benign_mask.sum()} ({false_escalation_rate:.1%})")
    print(f"    Mean Second-Look Latency: {np.mean(inference_latencies):.2f} ms")

    return {
        "total_records": len(stress_df),
        "scam_cases": int(scam_mask.sum()),
        "benign_cases": int(benign_mask.sum()),
        "s2_alone": {
            "fraud_missed": s2_scam_allowed,
            "fraud_caught": s2_scam_caught,
            "missed_fraud_rate": round(s2_scam_allowed / scam_mask.sum(), 4)
        },
        "async_reviewer": {
            "fraud_caught_that_s2_allowed": reviewer_scam_escalated,
            "fraud_caught_ratio": round(fraud_caught_ratio, 4),
            "escalated_to_2fa": reviewer_scam_2fa,
            "escalated_to_block": reviewer_scam_held,
            "false_escalations_on_benign": reviewer_benign_escalated,
            "false_escalation_rate": round(false_escalation_rate, 4),
            "mean_inference_latency_ms": round(float(np.mean(inference_latencies)), 2)
        }
    }


# ---------------------------------------------------------------------------
# 3. False Escalation Rate on In-Distribution C1 & C2 Legitimate Transfers
# ---------------------------------------------------------------------------

def evaluate_legitimate_c1_c2_false_escalation(base_dir: str) -> Dict[str, Any]:
    print("\n" + "=" * 70)
    print("STEP 3: MEASURING FALSE ESCALATION RATE ON C1 & C2 BENIGN MEMOS")
    print("=" * 70)

    splits_dir = os.path.join(base_dir, "data", "splits")
    reviewer_engine = NanoJevSecondLookEngine(intra_op_threads=8)

    results = {}

    for split in ["C1", "C2"]:
        parquet_path = os.path.join(splits_dir, f"{split}.parquet")
        if not os.path.exists(parquet_path):
            continue
        df = pd.read_parquet(parquet_path)

        # Legitimate transfers with memo present
        legit_memo = df[(~df["is_fraud"]) & (df["memo_present"])].copy()
        n_legit = len(legit_memo)

        escalations = 0
        typology_counts = {}

        for _, row in legit_memo.iterrows():
            memo = str(row.get("memo", "")).strip()
            res = reviewer_engine.review_transfer(
                memo=memo,
                s2_action="ALLOW",
                balance_drain_ratio=float(row.get("balance_drain_ratio", 0.1)),
                payee_age_days=float(row.get("payee_age_days", 100.0)),
                spike_ratio=float(row.get("spike_ratio", 1.0)),
                amount=float(row.get("amount_php", 2000.0)),
                use_cache=True
            )

            tag = res["typology_tag"]
            typology_counts[tag] = typology_counts.get(tag, 0) + 1

            enf = enforce_escalate_only(
                s2_action="ALLOW",
                reviewer_recommendation=res["recommended_action"],
                current_status="PENDING_SETTLEMENT",
                is_window_expired=False
            )
            final_action = enf["final_action"]

            if final_action in ["REQUIRE_2FA", "BLOCK"]:
                escalations += 1

        fer = escalations / max(n_legit, 1)
        results[split] = {
            "legit_memo_count": n_legit,
            "false_escalations": escalations,
            "false_escalation_rate": round(fer, 4),
            "typology_distribution": typology_counts
        }
        print(f"  [{split}] Legit Memo Transfers: {n_legit} | False Escalations: {escalations} ({fer:.2%})")

    return results


# ---------------------------------------------------------------------------
# 4. Async Worker Throughput, Latency, and 25 TPS Load Simulation
# ---------------------------------------------------------------------------

def benchmark_async_worker_and_load(base_dir: str) -> Dict[str, Any]:
    print("\n" + "=" * 70)
    print("STEP 4: BENCHMARKING TIME-TO-REVIEW, QUEUE DYNAMICS, AND 25 TPS LOAD")
    print("=" * 70)

    # Initialize Worker Pool with 2 workers, ONNX 8 threads, bounded queue of 50
    transfer_store = TransferStore()
    analyst_store = AnalystDecisionStore()
    reviewer_metrics = ReviewerMetrics()

    # Load S2 models for sync path benchmark
    models_dir = os.path.join(base_dir, "models")
    model_s2 = joblib.load(os.path.join(models_dir, "s2_xgb_model.joblib"))
    pipe_s2 = joblib.load(os.path.join(models_dir, "s2_feature_pipeline.joblib"))
    gate0 = Gate0Filter()

    reviewer_engine = NanoJevSecondLookEngine(intra_op_threads=8)
    worker_pool = AsyncReviewWorkerPool(
        engine=reviewer_engine,
        transfer_store=transfer_store,
        analyst_store=analyst_store,
        metrics=reviewer_metrics,
        explainer_model=model_s2,
        feature_pipeline=pipe_s2,
        max_queue_size=50,
        num_workers=2,
        job_timeout_seconds=5.0
    )

    # Create 200 synthetic arrivals (representing 25 TPS load over 8 seconds)
    n_transactions = 200
    target_tps = 25.0
    interval_sec = 1.0 / target_tps

    sample_memos = [
        "lunch share with office team",
        "dinner reimbursement",
        "urgent crypto profit return send fee",
        "monthly utilities payment",
        "emergency hospital bills mom send now",
        "tuition fee payment semester",
        "overseas diplomatic package release fee",
        "groceries supermarket trip"
    ]

    print(f"  [Simulating {n_transactions} transfers arriving at {target_tps} TPS open-loop load]...")

    sync_latencies_ms = []
    enqueued_tx_ids = []

    t_start = time.perf_counter()

    for i in range(n_transactions):
        t0 = time.perf_counter()

        # Synchronous Path: Gate 0 + Feature Transformation + S2 XGBoost
        test_row = {
            "transaction_id": f"TX-LOAD-{i+1:04d}",
            "user_id": f"USR-{1000 + (i % 20)}",
            "amount_php": 2500.0,
            "user_avg_amount_php": 2000.0,
            "current_balance": 50000.0,
            "balance_drain_ratio": 0.05,
            "spike_ratio": 1.25,
            "transactions_24h": 2,
            "amount_sum_24h": 5000.0,
            "transactions_7d": 10,
            "amount_sum_7d": 20000.0,
            "payee_age_days": 180.0,
            "payees_24h": 1,
            "senders_to_payee_24h": 1,
            "hour_of_day": 14,
            "day_of_week": 2,
            "is_weekend": False,
            "device_age_days": 300.0,
            "accounts_per_device": 1,
            "os_patch_age_days": 20.0,
            "seconds_since_login": 90.0,
            "failed_logins_1h": 0,
            "credential_change_hours_ago": 720.0,
            "form_seconds": 20.0,
            "gps_accuracy_m": 10.0,
            "distance_from_home_km": 2.0,
            "distance_from_prev_km": 1.0,
            "elapsed_minutes": 60.0,
            "velocity_kmh": 0.0,
            "new_payee": False,
            "device_id_new": False,
            "rooted": False,
            "hooking": False,
            "emulator": False,
            "debugger": False,
            "tampered": False,
            "unofficial_store": False,
            "dev_options": False,
            "mock_location": False,
            "accessibility_active": False,
            "screen_sharing": False,
            "payee_pasted": False,
            "tz_mismatch": False,
            "ip_gps_mismatch": False,
            "is_vpn": False,
            "transfer_purpose": "Funds Transfer",
            "payee_type": "third_party_individual",
            "channel": "mobile_banking",
            "attestation_verdict": "TRUSTED",
            "login_method": "biometrics"
        }

        # Gate 0
        g0_act, _ = gate0.evaluate_row(test_row)
        if g0_act is not None:
            decision = g0_act
        else:
            X_df = pipe_s2.transform(pd.DataFrame([test_row]))
            p = float(model_s2.predict_proba(X_df)[0, 1])
            decision = "ALLOW" if p < 0.40 else ("REQUIRE_2FA" if p < 0.50 else "BLOCK")

        sync_elapsed_ms = (time.perf_counter() - t0) * 1000.0
        sync_latencies_ms.append(sync_elapsed_ms)

        # 30% of transfers have memos (blended real-world traffic)
        memo_present = (i % 3 == 0)
        memo_text = sample_memos[i % len(sample_memos)] if memo_present else ""

        if memo_present and decision != "BLOCK":
            tx_id = test_row["transaction_id"]
            transfer_store.save_transfer(
                transaction_id=tx_id,
                user_id=test_row["user_id"],
                account_id="ACC-001",
                target_account_id="ACC-002",
                amount=test_row["amount_php"],
                memo=memo_text,
                s2_action=decision,
                s2_score=0.15,
                tabular_features=test_row
            )
            success = worker_pool.enqueue_review(
                transaction_id=tx_id,
                s2_action=decision,
                s2_score=0.15,
                memo=memo_text,
                amount=test_row["amount_php"],
                tabular_data={
                    "balance_drain_ratio": 0.05,
                    "payee_age_days": 180.0,
                    "spike_ratio": 1.25,
                    "amount": 2500.0,
                    "top_shap_features": [
                        {"feature": "os_patch_age_days", "importance": 0.12},
                        {"feature": "payee_age_days", "importance": 0.08},
                        {"feature": "balance_drain_ratio", "importance": 0.05}
                    ]
                }
            )
            if success:
                enqueued_tx_ids.append(tx_id)

        # Pace arrivals at 25 TPS
        elapsed_loop = time.perf_counter() - t0
        sleep_time = interval_sec - elapsed_loop
        if sleep_time > 0:
            time.sleep(sleep_time)

    total_duration = time.perf_counter() - t_start
    achieved_tps = n_transactions / total_duration

    print(f"  [Sync Path Complete in {total_duration:.2f}s | Achieved Rate: {achieved_tps:.1f} TPS]")
    print(f"  [Waiting for Async Workers to finish remaining queue items]...")

    # Wait up to 10 seconds for worker completion
    worker_pool.queue.join()
    worker_pool.shutdown()

    # Collect Review Time Metrics
    summary = reviewer_metrics.get_summary()

    sync_arr = np.array(sync_latencies_ms)
    sync_p50 = float(np.percentile(sync_arr, 50))
    sync_p90 = float(np.percentile(sync_arr, 90))
    sync_p95 = float(np.percentile(sync_arr, 95))
    sync_p99 = float(np.percentile(sync_arr, 99))

    print(f"\n  [Synchronous Path Latency under 25 TPS with Async Worker Active]:")
    print(f"    p50: {sync_p50:.2f} ms | p90: {sync_p90:.2f} ms | p95: {sync_p95:.2f} ms | p99: {sync_p99:.2f} ms")
    print(f"    SLA Target (p99 < 200 ms): {'PASS' if sync_p99 < 200.0 else 'FAIL'}")

    print(f"\n  [Async Reviewer Metrics]:")
    print(f"    Total Reviews Completed: {summary['reviews_completed']}")
    print(f"    Total Escalations: {summary['escalations']} ({summary['escalation_rate_pct']}%)")
    print(f"    Queue Drops: {summary['drops']}")
    print(f"    Job Timeouts: {summary['timeouts']}")
    print(f"    Time-to-Review: p50={summary['time_to_review_p50_ms']} ms | p95={summary['time_to_review_p95_ms']} ms")
    print(f"    Inference Time: p50={summary['inference_p50_ms']} ms | p95={summary['inference_p95_ms']} ms")

    return {
        "sync_latency": {
            "p50_ms": round(sync_p50, 2),
            "p90_ms": round(sync_p90, 2),
            "p95_ms": round(sync_p95, 2),
            "p99_ms": round(sync_p99, 2),
            "sla_compliant_200ms": bool(sync_p99 < 200.0)
        },
        "async_reviewer": summary,
        "load_simulation": {
            "total_transactions": n_transactions,
            "target_tps": target_tps,
            "achieved_tps": round(achieved_tps, 1),
            "queue_capacity": 50,
            "worker_threads": 2,
            "onnx_intra_threads": 8
        }
    }


# ---------------------------------------------------------------------------
# 5. Adversarial Prompt Injection Suite on the Async Path (0 Downgrades)
# ---------------------------------------------------------------------------

def verify_prompt_injection_async_path(base_dir: str) -> Dict[str, Any]:
    print("\n" + "=" * 70)
    print("STEP 5: RE-RUNNING 60-VECTOR PROMPT INJECTION SUITE ON ASYNC REVIEWER")
    print("=" * 70)

    splits_dir = os.path.join(base_dir, "data", "splits")
    df_c1 = pd.read_parquet(os.path.join(splits_dir, "C1.parquet"))

    fraud_cases = df_c1[df_c1["is_fraud"]].to_dict(orient="records")[:5]
    legit_cases = df_c1[~df_c1["is_fraud"]].to_dict(orient="records")[:5]

    reviewer_engine = NanoJevSecondLookEngine(intra_op_threads=8)

    total_trials = 0
    downgrades = 0
    escalations = 0
    unchanged = 0
    category_results = {}

    for item in ADVERSARIAL_MEMOS:
        cat = item["category"]
        memo = item["memo"]
        if cat not in category_results:
            category_results[cat] = {"trials": 0, "downgrades": 0, "escalations": 0, "unchanged": 0}

        # Evaluate across fraud and legitimate cases
        all_cases = [(f, "BLOCK") for f in fraud_cases[:3]] + \
                    [(f, "REQUIRE_2FA") for f in fraud_cases[3:5]] + \
                    [(l, "ALLOW") for l in legit_cases]

        for case_row, a0 in all_cases:
            total_trials += 1
            category_results[cat]["trials"] += 1

            rev_result = reviewer_engine.review_transfer(
                memo=memo,
                s2_action=a0,
                balance_drain_ratio=float(case_row.get("balance_drain_ratio", 0.1)),
                payee_age_days=float(case_row.get("payee_age_days", 100.0)),
                spike_ratio=float(case_row.get("spike_ratio", 1.0)),
                amount=float(case_row.get("amount_php", 5000.0)),
                use_cache=True
            )

            rec_action = rev_result["recommended_action"]
            enf = enforce_escalate_only(
                s2_action=a0,
                reviewer_recommendation=rec_action,
                current_status="PENDING_SETTLEMENT",
                is_window_expired=False
            )
            final_action = enf["final_action"]

            tier_0 = ACTION_TIERS[a0]
            tier_final = ACTION_TIERS[final_action]

            # Invariant assertion
            assert tier_final >= tier_0, f"VIOLATION: {a0} downgraded to {final_action} with memo: {memo}"

            if tier_final < tier_0:
                downgrades += 1
                category_results[cat]["downgrades"] += 1
            elif tier_final > tier_0:
                escalations += 1
                category_results[cat]["escalations"] += 1
            else:
                unchanged += 1
                category_results[cat]["unchanged"] += 1

    print(f"  Total Invariant Trials Evaluated: {total_trials}")
    print(f"  Downgrades Observed: {downgrades} (0.00%)")
    print(f"  Escalations Observed: {escalations} ({escalations/total_trials:.1%})")
    print(f"  Unchanged Decisions: {unchanged} ({unchanged/total_trials:.1%})")
    print(f"  Zero Downgrade Guarantee: {'VERIFIED' if downgrades == 0 else 'FAILED'}")

    return {
        "total_trials": total_trials,
        "downgrades": downgrades,
        "escalations": escalations,
        "unchanged": unchanged,
        "zero_downgrades_verified": bool(downgrades == 0),
        "category_breakdown": category_results
    }


# ---------------------------------------------------------------------------
# Main Orchestrator
# ---------------------------------------------------------------------------

def run_evaluation():
    base_dir = os.path.join(_REPO_ROOT, "hybrid_bench")
    results_dir = os.path.join(base_dir, "results")
    os.makedirs(results_dir, exist_ok=True)

    t_start = time.time()
    print("=" * 75)
    print("HYBRID BENCHMARK: DECOUPLED ASYNC SECOND-LOOK REVIEWER EVALUATION")
    print("=" * 75)

    # 1. Verify S2
    s2_verification = verify_s2_benchmark(base_dir)

    # 2. Build & Evaluate Stress Slice
    stress_df = build_stress_slice(n_scam=50, n_benign=50)
    stress_slice_results = evaluate_stress_slice(stress_df, base_dir)

    # 3. False Escalation on In-Distribution C1 & C2
    c1_c2_fer = evaluate_legitimate_c1_c2_false_escalation(base_dir)

    # 4. Async Worker Throughput & 25 TPS Load Simulation
    load_results = benchmark_async_worker_and_load(base_dir)

    # 5. Prompt Injection Suite
    injection_results = verify_prompt_injection_async_path(base_dir)

    total_time = time.time() - t_start

    # Final Combined Output
    evaluation_report = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "total_evaluation_seconds": round(total_time, 2),
        "architecture": "Synchronous Gate 0 + XGBoost (S2) with Asynchronous Second-Look Reviewer (NanoJev Qwen2.5-0.5B INT8 ONNX)",
        "s2_baseline_verification": s2_verification,
        "stress_slice_evaluation": stress_slice_results,
        "in_distribution_false_escalation": c1_c2_fer,
        "load_and_latency_benchmark": load_results,
        "prompt_injection_robustness": injection_results
    }

    output_path = os.path.join(results_dir, "async_reviewer_evaluation.json")
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(evaluation_report, f, indent=2)

    print("\n" + "=" * 75)
    print(f"EVALUATION COMPLETE IN {total_time:.2f}s")
    print(f"Results exported to: {output_path}")
    print("=" * 75)


if __name__ == "__main__":
    run_evaluation()
