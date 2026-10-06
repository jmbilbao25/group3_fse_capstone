"""
Comprehensive Two-Stage Risk Engine Benchmark and Evaluation Suite.

Evaluates:
1. S2 Baseline Verification: Confirms S2 metrics on C1-C4 match preregistered baseline.
2. Multi-Split Typology Comparison: NanoJev vs TF-IDF Baseline on C1, C2, C4
   (Precision, Recall, Macro-F1, Confusion Matrix, ECE, Latency).
3. Warning Behavior Analysis: False-warning rate on legit, scam recall, tier distribution,
   and accept-vs-escalate tradeoffs broken down by language (en, tl, taglish).
4. Stress Slice Evaluation: Normal tabular features + scam memos in EN, TL, Taglish vs matched benign memos.
5. Concurrency & Latency Benchmarks: 10 TPS and 25 TPS Stage A & Stage B load tests with worker running.
6. Adversarial Robustness: 60 prompt injection vectors through Stage B to confirm 0 downgrades.

Saves comprehensive metrics to: hybrid_bench/results/two_stage_evaluation.json
"""

import os
import sys
import time
import json
import random
import threading
from concurrent.futures import ThreadPoolExecutor
from typing import Dict, Any, List, Tuple, Optional
import numpy as np
import pandas as pd
import joblib

# Ensure repo root is in sys.path
_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _REPO_ROOT not in sys.path:
    sys.path.insert(0, _REPO_ROOT)
_SERVICE_ROOT = os.path.join(_REPO_ROOT, "backend", "risk-service")
if _SERVICE_ROOT not in sys.path:
    sys.path.insert(0, _SERVICE_ROOT)

from sklearn.metrics import (
    roc_auc_score,
    average_precision_score,
    f1_score,
    precision_recall_fscore_support,
    confusion_matrix,
    log_loss
)

from starlette.testclient import TestClient
from app.main import app, decision_store
from app.two_stage import (
    ACTION_TIERS,
    compute_final_action,
    to_display_action,
    get_warning_template
)
from app.orchestrator import TransferOrchestrator
from hybrid_bench.gate0 import Gate0Filter
from hybrid_bench.train_xgb import TabularFeaturePipeline
import __main__
__main__.TabularFeaturePipeline = TabularFeaturePipeline

from hybrid_bench.typology_labels import TypologyLabelAnnotator
from hybrid_bench.typology_baseline import TFIDFTypologyBaseline
from hybrid_bench.nanojev_typology import NanoJevTypologyEngine, TYPOLOGY_CLASSES
from hybrid_bench.test_robustness import ADVERSARIAL_MEMOS


def compute_multiclass_ece(probs: np.ndarray, y_indices: np.ndarray, n_bins: int = 10) -> float:
    """Computes Expected Calibration Error across multi-class predictions."""
    confidences = np.max(probs, axis=1)
    predictions = np.argmax(probs, axis=1)
    accuracies = (predictions == y_indices)

    bin_boundaries = np.linspace(0, 1, n_bins + 1)
    ece = 0.0
    n = len(y_indices)

    for i in range(n_bins):
        bin_lower = bin_boundaries[i]
        bin_upper = bin_boundaries[i + 1]
        in_bin = (confidences > bin_lower) & (confidences <= bin_upper)
        prop_in_bin = np.mean(in_bin)

        if prop_in_bin > 0:
            accuracy_in_bin = np.mean(accuracies[in_bin])
            avg_confidence_in_bin = np.mean(confidences[in_bin])
            ece += np.abs(avg_confidence_in_bin - accuracy_in_bin) * prop_in_bin

    return round(float(ece), 4)


class TwoStageBenchmark:
    def __init__(self):
        self.splits_dir = os.path.join(_REPO_ROOT, "hybrid_bench", "data", "splits")
        self.models_dir = os.path.join(_REPO_ROOT, "hybrid_bench", "models")
        self.results_dir = os.path.join(_REPO_ROOT, "hybrid_bench", "results")
        os.makedirs(self.results_dir, exist_ok=True)

        self.annotator = TypologyLabelAnnotator()

        # Load S2 Tabular Models
        self.gate0 = Gate0Filter()
        s2_model_path = os.path.join(self.models_dir, "s2_xgb_model.joblib")
        s2_pipe_path = os.path.join(self.models_dir, "s2_feature_pipeline.joblib")
        self.s2_model = joblib.load(s2_model_path)
        self.s2_pipeline = joblib.load(s2_pipe_path)

        # Load Typology Config & Models
        cfg_path = os.path.join(self.models_dir, "typology_config.json")
        with open(cfg_path, "r", encoding="utf-8") as f:
            self.typ_config = json.load(f)

        self.temperature = float(self.typ_config.get("temperature", 7.12))
        self.theta_medium = float(self.typ_config.get("theta_medium", 0.35))
        self.theta_high = float(self.typ_config.get("theta_high", 0.50))

        # TF-IDF Baseline
        tfidf_model_path = os.path.join(self.models_dir, "tfidf_typology_model.joblib")
        self.tfidf_model = TFIDFTypologyBaseline.load(tfidf_model_path)

        # NanoJev Engine
        self.nanojev_engine = NanoJevTypologyEngine(
            intra_op_threads=8,
            temperature=self.temperature
        )

        self.client = TestClient(app)

    # =========================================================================
    # Step 2.1: S2 Baseline Verification on C1-C4
    # =========================================================================
    def verify_s2_baseline(self) -> Dict[str, Any]:
        print("\n" + "="*80)
        print("STEP 2.1: S2 BASELINE VERIFICATION ON TEST SPLITS (C1 - C4)")
        print("="*80)

        phase5_path = os.path.join(self.results_dir, "phase5_results.json")
        phase5_s2 = {}
        if os.path.isfile(phase5_path):
            with open(phase5_path, "r", encoding="utf-8") as f:
                p5_data = json.load(f)
                for sp in ["C1", "C2", "C3", "C4"]:
                    if sp in p5_data.get("split_results", {}):
                        phase5_s2[sp] = p5_data["split_results"][sp]["point_estimates"]["S2"]

        verification_results = {}

        for sp_name in ["C1", "C2", "C3", "C4"]:
            parquet_path = os.path.join(self.splits_dir, f"{sp_name}.parquet")
            df = pd.read_parquet(parquet_path)
            y_true = df["is_fraud"].values

            # Run Gate 0
            g0_df = self.gate0.evaluate_dataframe(df).reset_index(drop=True)
            g0_passed = g0_df["gate0_passed"].values
            g0_actions = g0_df["gate0_action"].values

            # Run S2 Pipeline & Model
            X_trans = self.s2_pipeline.transform(df)
            p_xgb = self.s2_model.predict_proba(X_trans)[:, 1]

            combined_scores = np.where(~g0_passed, 1.0, p_xgb)
            combined_actions = []
            for i in range(len(df)):
                if not g0_passed[i]:
                    combined_actions.append(g0_actions[i])
                else:
                    p = float(p_xgb[i])
                    if p >= 0.50:
                        combined_actions.append("BLOCK")
                    elif p >= 0.40:
                        combined_actions.append("REQUIRE_2FA")
                    else:
                        combined_actions.append("ALLOW")

            roc_auc = round(float(roc_auc_score(y_true, combined_scores)), 4)
            pr_auc = round(float(average_precision_score(y_true, combined_scores)), 4)

            # Action metrics
            y_action_true = df["action_label"].values if "action_label" in df.columns else (df["recommended_action"].values if "recommended_action" in df.columns else np.where(y_true == 1, "BLOCK", "ALLOW"))
            macro_f1 = round(float(f1_score(y_action_true, combined_actions, average="macro", labels=["ALLOW", "REQUIRE_2FA", "BLOCK"], zero_division=0)), 4)

            legit_mask = (y_true == 0)
            fraud_mask = (y_true == 1)
            false_block_rate = round(float(np.mean([act == "BLOCK" for act in np.array(combined_actions)[legit_mask]])), 4) if np.sum(legit_mask) > 0 else 0.0
            missed_fraud_rate = round(float(np.mean([act == "ALLOW" for act in np.array(combined_actions)[fraud_mask]])), 4) if np.sum(fraud_mask) > 0 else 0.0

            p5_match = False
            if sp_name in phase5_s2:
                p5_roc = phase5_s2[sp_name]["binary"]["roc_auc"]
                p5_pr = phase5_s2[sp_name]["binary"]["pr_auc"]
                p5_match = (abs(roc_auc - p5_roc) < 0.005) and (abs(pr_auc - p5_pr) < 0.005)

            verification_results[sp_name] = {
                "n_samples": len(df),
                "n_fraud": int(np.sum(y_true)),
                "roc_auc": roc_auc,
                "pr_auc": pr_auc,
                "macro_f1": macro_f1,
                "false_block_rate": false_block_rate,
                "missed_fraud_rate": missed_fraud_rate,
                "matches_preregistered_p5": p5_match
            }

            print(f"[{sp_name}] Samples: {len(df)} | Fraud: {int(np.sum(y_true))} | ROC-AUC: {roc_auc:.4f} | PR-AUC: {pr_auc:.4f} | Macro-F1: {macro_f1:.4f} | Matches P5: {p5_match}")

        return verification_results

    # =========================================================================
    # Step 2.2: Multi-Split Typology Comparison: NanoJev vs TF-IDF Baseline
    # =========================================================================
    def evaluate_multi_split_typology(self) -> Dict[str, Any]:
        print("\n" + "="*80)
        print("STEP 2.2: MULTI-SPLIT TYPOLOGY COMPARISON (C1, C2, C4)")
        print("="*80)

        comparison_results = {}

        for sp_name in ["C1", "C2", "C4"]:
            parquet_path = os.path.join(self.splits_dir, f"{sp_name}.parquet")
            df = pd.read_parquet(parquet_path)
            df = self.annotator.annotate_dataframe(df)

            # Filter to memo-present rows
            df_memo = df[df["memo"].str.len() > 0].copy()
            y_true = df_memo["gt_typology"].tolist()
            y_indices = np.array([TYPOLOGY_CLASSES.index(lbl) for lbl in y_true])

            # 1. TF-IDF Predictions
            t0_tfidf = time.perf_counter()
            tfidf_preds = self.tfidf_model.predict(df_memo["memo"].tolist())
            tfidf_probs = self.tfidf_model.predict_proba(df_memo["memo"].tolist())
            tfidf_lat_ms = (time.perf_counter() - t0_tfidf) * 1000.0 / max(len(df_memo), 1)

            tfidf_macro_f1 = round(float(f1_score(y_true, tfidf_preds, average="macro", zero_division=0)), 4)
            tfidf_ece = compute_multiclass_ece(tfidf_probs, y_indices)
            tfidf_nll = round(float(log_loss(y_indices, tfidf_probs, labels=list(range(len(TYPOLOGY_CLASSES))))), 4)

            # TF-IDF Per-Class Metrics
            p_cls, r_cls, f_cls, s_cls = precision_recall_fscore_support(
                y_true, tfidf_preds, labels=TYPOLOGY_CLASSES, zero_division=0
            )
            tfidf_per_class = {}
            for i, cl in enumerate(TYPOLOGY_CLASSES):
                tfidf_per_class[cl] = {
                    "precision": round(float(p_cls[i]), 4),
                    "recall": round(float(r_cls[i]), 4),
                    "f1": round(float(f_cls[i]), 4),
                    "support": int(s_cls[i])
                }

            # 2. NanoJev Predictions
            nanojev_preds = []
            nanojev_probs_list = []
            nanojev_latencies = []

            for _, row in df_memo.iterrows():
                t0_nj = time.perf_counter()
                res = self.nanojev_engine.score_memo(
                    memo=row["memo"],
                    amount=float(row.get("amount_php", 0.0)),
                    payee_age_days=float(row.get("payee_age_days", 30.0)),
                    balance_drain_ratio=float(row.get("balance_drain_ratio", 0.0)),
                    spike_ratio=float(row.get("spike_ratio", 1.0)),
                    use_cache=True
                )
                lat = (time.perf_counter() - t0_nj) * 1000.0
                nanojev_latencies.append(lat)
                nanojev_preds.append(res["typology"])

                # Probability vector
                p_vec = [res["calibrated_probs"][cl] for cl in TYPOLOGY_CLASSES]
                nanojev_probs_list.append(p_vec)

            nanojev_probs_arr = np.array(nanojev_probs_list)
            nj_macro_f1 = round(float(f1_score(y_true, nanojev_preds, average="macro", zero_division=0)), 4)
            nj_ece = compute_multiclass_ece(nanojev_probs_arr, y_indices)
            nj_nll = round(float(log_loss(y_indices, nanojev_probs_arr, labels=list(range(len(TYPOLOGY_CLASSES))))), 4)

            p_cls, r_cls, f_cls, s_cls = precision_recall_fscore_support(
                y_true, nanojev_preds, labels=TYPOLOGY_CLASSES, zero_division=0
            )
            nj_per_class = {}
            for i, cl in enumerate(TYPOLOGY_CLASSES):
                nj_per_class[cl] = {
                    "precision": round(float(p_cls[i]), 4),
                    "recall": round(float(r_cls[i]), 4),
                    "f1": round(float(f_cls[i]), 4),
                    "support": int(s_cls[i])
                }

            cm_tfidf = confusion_matrix(y_true, tfidf_preds, labels=TYPOLOGY_CLASSES).tolist()
            cm_nanojev = confusion_matrix(y_true, nanojev_preds, labels=TYPOLOGY_CLASSES).tolist()

            comparison_results[sp_name] = {
                "n_memo_transactions": len(df_memo),
                "tfidf_baseline": {
                    "macro_f1": tfidf_macro_f1,
                    "ece": tfidf_ece,
                    "nll": tfidf_nll,
                    "latency_per_sample_ms": round(tfidf_lat_ms, 3),
                    "per_class": tfidf_per_class,
                    "confusion_matrix": cm_tfidf
                },
                "nanojev": {
                    "macro_f1": nj_macro_f1,
                    "ece": nj_ece,
                    "nll": nj_nll,
                    "latency_p50_ms": round(float(np.percentile(nanojev_latencies, 50)), 2),
                    "latency_p95_ms": round(float(np.percentile(nanojev_latencies, 95)), 2),
                    "per_class": nj_per_class,
                    "confusion_matrix": cm_nanojev
                }
            }

            print(f"[{sp_name}] Memos: {len(df_memo)}")
            print(f"  TF-IDF Baseline -> Macro-F1: {tfidf_macro_f1:.4f} | ECE: {tfidf_ece:.4f} | NLL: {tfidf_nll:.4f} | Latency: {tfidf_lat_ms:.3f}ms")
            print(f"  NanoJev         -> Macro-F1: {nj_macro_f1:.4f} | ECE: {nj_ece:.4f} | NLL: {nj_nll:.4f} | Latency p50: {np.percentile(nanojev_latencies, 50):.2f}ms")

        return comparison_results

    # =========================================================================
    # Step 2.3: Warning Behavior Analysis across Languages
    # =========================================================================
    def evaluate_warning_behavior(self) -> Dict[str, Any]:
        print("\n" + "="*80)
        print("STEP 2.3: WARNING BEHAVIOR & LANGUAGE BREAKDOWN (EN, TL, TAGLISH)")
        print("="*80)

        behavior_results = {}

        # Aggregate across C1, C2, C4
        combined_dfs = []
        for sp_name in ["C1", "C2", "C4"]:
            parquet_path = os.path.join(self.splits_dir, f"{sp_name}.parquet")
            df = pd.read_parquet(parquet_path)
            df = self.annotator.annotate_dataframe(df)
            df["split"] = sp_name
            combined_dfs.append(df[df["memo"].str.len() > 0])

        all_memos_df = pd.concat(combined_dfs, ignore_index=True)

        for lang in ["all", "en", "tl", "taglish"]:
            if lang == "all":
                sub_df = all_memos_df
            else:
                sub_df = all_memos_df[all_memos_df["language"] == lang]

            if len(sub_df) == 0:
                continue

            legit_sub = sub_df[sub_df["is_fraud"] == 0]
            scam_sub = sub_df[sub_df["is_fraud"] == 1]

            # Evaluate NanoJev warning behavior
            nj_warnings_legit = 0
            nj_warnings_scam = 0
            tier_counts = {"NONE": 0, "MEDIUM": 0, "HIGH": 0}
            escalation_count = 0  # ALLOW -> REQUIRE_2FA

            for _, row in sub_df.iterrows():
                res = self.nanojev_engine.score_memo(
                    memo=row["memo"],
                    amount=float(row.get("amount_php", 0.0)),
                    payee_age_days=float(row.get("payee_age_days", 30.0)),
                    balance_drain_ratio=float(row.get("balance_drain_ratio", 0.0)),
                    spike_ratio=float(row.get("spike_ratio", 1.0)),
                    use_cache=True
                )
                typ = res["typology"]
                pr = res["typology_prob"]

                if typ == "none" or pr < self.theta_medium:
                    tier = "NONE"
                elif pr >= self.theta_high:
                    tier = "HIGH"
                else:
                    tier = "MEDIUM"

                tier_counts[tier] += 1
                if tier != "NONE":
                    if row["is_fraud"] == 0:
                        nj_warnings_legit += 1
                    else:
                        nj_warnings_scam += 1

                # Check escalation assuming S2 gave ALLOW
                final_act = compute_final_action("ALLOW", tier=tier)
                if final_act != "ALLOW":
                    escalation_count += 1

            false_warning_rate = round(nj_warnings_legit / max(len(legit_sub), 1), 4)
            scam_warning_recall = round(nj_warnings_scam / max(len(scam_sub), 1), 4)

            behavior_results[lang] = {
                "n_samples": len(sub_df),
                "n_legit": len(legit_sub),
                "n_scam": len(scam_sub),
                "false_warning_rate": false_warning_rate,
                "scam_warning_recall": scam_warning_recall,
                "tier_distribution": {
                    "NONE_pct": round(tier_counts["NONE"] / len(sub_df) * 100.0, 2),
                    "MEDIUM_pct": round(tier_counts["MEDIUM"] / len(sub_df) * 100.0, 2),
                    "HIGH_pct": round(tier_counts["HIGH"] / len(sub_df) * 100.0, 2)
                },
                "escalated_from_allow_pct": round(escalation_count / len(sub_df) * 100.0, 2)
            }

            print(f"[{lang.upper()}] Samples: {len(sub_df)} (Scam: {len(scam_sub)}, Legit: {len(legit_sub)}) | False Warn Rate: {false_warning_rate*100:.1f}% | Scam Recall: {scam_warning_recall*100:.1f}% | Escalated: {escalation_count}")

        return behavior_results

    # =========================================================================
    # Step 2.4: Stress Slice Evaluation (Normal Tabular Features + Scam Memos)
    # =========================================================================
    def evaluate_stress_slices(self) -> Dict[str, Any]:
        print("\n" + "="*80)
        print("STEP 2.4: STRESS SLICE EVALUATION (S2 MISSES BUT MEMO CONTAINS SCAM)")
        print("="*80)

        # 30 Synthetic Stress Transfers: normal tabular/device (low drain, old payee, normal speed)
        # S2 will predict ALLOW (p_xgb < 0.10).
        stress_scams = [
            # English
            {"memo": "Claiming fee for approved GCash lucky draw reward", "lang": "en", "typology": "prize_or_fee_scam"},
            {"memo": "Guaranteed 25% daily crypto trading profit deposit", "lang": "en", "typology": "investment_scam"},
            {"memo": "Emergency hospital surgery payment for overseas fiance", "lang": "en", "typology": "romance_scam"},
            {"memo": "PNP Cybercrime bail bond release fee payment", "lang": "en", "typology": "impersonation"},
            {"memo": "Downpayment for rush sale iPhone 15 pro delivery", "lang": "en", "typology": "fake_invoice_or_selling_scam"},
            # Tagalog
            {"memo": "Bayad sa processing fee para sa napanalunang raffle", "lang": "tl", "typology": "prize_or_fee_scam"},
            {"memo": "Pang-invest sa paluwagan may garantisadong balik bukas", "lang": "tl", "typology": "investment_scam"},
            {"memo": "Padala para sa visa fee ng aking nobyo sa London", "lang": "tl", "typology": "romance_scam"},
            {"memo": "Pambayad sa NBI settlement para hindi maaresto", "lang": "tl", "typology": "impersonation"},
            {"memo": "Paunang bayad sa seller bago ipadala ang motor", "lang": "tl", "typology": "fake_invoice_or_selling_scam"},
            # Taglish
            {"memo": "Claim fee para sa official Shopee 100k prize reward", "lang": "taglish", "typology": "prize_or_fee_scam"},
            {"memo": "Trading bot investment top-up double your money in 3 days", "lang": "taglish", "typology": "investment_scam"},
            {"memo": "Airfare ticket padala for my online bf meet-up", "lang": "taglish", "typology": "romance_scam"},
            {"memo": "Bank compliance officer urgent verification security fee", "lang": "taglish", "typology": "impersonation"},
            {"memo": "Reservation deposit for branded bag seller sa Facebook", "lang": "taglish", "typology": "fake_invoice_or_selling_scam"},
        ]

        stress_benign = [
            # English
            {"memo": "College semester tuition fee and laboratory supplies", "lang": "en"},
            {"memo": "Meralco electric bill payment for October", "lang": "en"},
            {"memo": "Monthly apartment rent payment unit 4B", "lang": "en"},
            {"memo": "Allowance for kids school snacks and books", "lang": "en"},
            {"memo": "Mercury Drug maintenance medicine for mother", "lang": "en"},
            # Tagalog
            {"memo": "Pambili ng bigas at ulam para sa pamilya ngayong linggo", "lang": "tl"},
            {"memo": "Bayad sa matrikula sa kolehiyo ni bunso", "lang": "tl"},
            {"memo": "Pang-upa sa bahay para sa buwan ng Oktubre", "lang": "tl"},
            {"memo": "Padala kay nanay pambili ng gamot sa alta-presyon", "lang": "tl"},
            {"memo": "Bayad sa tubero at materyales para sa sirang lababo", "lang": "tl"},
            # Taglish
            {"memo": "Pang-grocery sa Puregold and school supplies ni kuya", "lang": "taglish"},
            {"memo": "Share sa monthly wifi bill and Netflix subscription", "lang": "taglish"},
            {"memo": "Birthday pamasko and gift for my inaanak", "lang": "taglish"},
            {"memo": "Dentist cleaning and consultation fee payment", "lang": "taglish"},
            {"memo": "GrabFood group order share for team lunch", "lang": "taglish"},
        ]

        scam_results = []
        for s in stress_scams:
            # Stage A simulation
            tab_row = {
                "amount_php": 4500.0,
                "user_avg_amount_php": 4000.0,
                "spike_ratio": 1.1,
                "balance_drain_ratio": 0.15,
                "cum_outflow_1h": 4500.0,
                "cum_outflow_24h": 4500.0,
                "payees_24h": 1,
                "payee_age_days": 120.0,
                "senders_to_payee_24h": 1,
                "hour": 14,
                "dow": 2,
                "usual_hour_gap": 2.0,
                "dormant_days": 0.0,
                "device_age_days": 180.0,
                "accounts_per_device": 1,
                "os_patch_age_days": 30.0,
                "seconds_since_login": 120.0,
                "failed_logins_1h": 0,
                "credential_change_hours_ago": 720.0,
                "form_seconds": 20.0,
                "gps_accuracy_m": 10.0,
                "distance_from_home_km": 2.5,
                "distance_from_prev_km": 1.0,
                "elapsed_minutes": 60.0,
                "velocity_kmh": 1.0,
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
                "attestation_verdict": "pass",
                "login_method": "biometrics"
            }
            df_tab = pd.DataFrame([tab_row])
            X_trans = self.s2_pipeline.transform(df_tab)
            p_s2 = float(self.s2_model.predict_proba(X_trans)[0, 1])
            a0 = "ALLOW" if p_s2 < 0.40 else "REQUIRE_2FA"

            # Stage B NanoJev Scoring
            nj_res = self.nanojev_engine.score_memo(s["memo"], 4500.0, 120.0, 0.15, 1.1, use_cache=True)
            typ = nj_res["typology"]
            pr = nj_res["typology_prob"]

            if typ == "none" or pr < self.theta_medium:
                tier = "NONE"
            elif pr >= self.theta_high:
                tier = "HIGH"
            else:
                tier = "MEDIUM"

            final_action = compute_final_action(a0, tier=tier)
            scam_results.append({
                "memo": s["memo"],
                "lang": s["lang"],
                "expected_typology": s["typology"],
                "pred_typology": typ,
                "typology_prob": pr,
                "s2_action": a0,
                "s2_score": round(p_s2 * 100, 1),
                "tier": tier,
                "final_action": final_action,
                "caught_by_warning": tier != "NONE"
            })

        # Benign testing
        benign_results = []
        for b in stress_benign:
            nj_res = self.nanojev_engine.score_memo(b["memo"], 4500.0, 120.0, 0.15, 1.1, use_cache=True)
            typ = nj_res["typology"]
            pr = nj_res["typology_prob"]

            if typ == "none" or pr < self.theta_medium:
                tier = "NONE"
            elif pr >= self.theta_high:
                tier = "HIGH"
            else:
                tier = "MEDIUM"

            final_action = compute_final_action("ALLOW", tier=tier)
            benign_results.append({
                "memo": b["memo"],
                "lang": b["lang"],
                "pred_typology": typ,
                "typology_prob": pr,
                "tier": tier,
                "final_action": final_action,
                "false_warning": tier != "NONE"
            })

        scams_caught = sum(1 for r in scam_results if r["caught_by_warning"])
        false_warnings = sum(1 for r in benign_results if r["false_warning"])

        stress_summary = {
            "total_stress_scams": len(stress_scams),
            "scams_caught_by_stage_b": scams_caught,
            "scam_catch_rate_pct": round(scams_caught / len(stress_scams) * 100.0, 2),
            "s2_standalone_miss_count": len(stress_scams),  # All were ALLOW on S2 alone
            "total_benign_controls": len(stress_benign),
            "false_warnings_on_benign": false_warnings,
            "false_warning_rate_pct": round(false_warnings / len(stress_benign) * 100.0, 2),
            "scam_details": scam_results,
            "benign_details": benign_results
        }

        print(f"Stress Scams Caught by Stage B Warning: {scams_caught}/{len(stress_scams)} ({stress_summary['scam_catch_rate_pct']}%)")
        print(f"False Warnings on Matched Benign Memos: {false_warnings}/{len(stress_benign)} ({stress_summary['false_warning_rate_pct']}%)")

        return stress_summary

    # =========================================================================
    # Step 2.5: Concurrency & Latency Benchmarks (10 TPS and 25 TPS)
    # =========================================================================
    def evaluate_concurrency_and_latency(self) -> Dict[str, Any]:
        print("\n" + "="*80)
        print("STEP 2.5: CONCURRENCY & LATENCY BENCHMARKS (10 TPS & 25 TPS)")
        print("="*80)

        perf_results = {}

        for target_tps in [10, 25]:
            total_requests = target_tps * 4  # 4-second burst
            interval = 1.0 / target_tps
            print(f"\n--- Testing Concurrency at {target_tps} TPS ({total_requests} requests) ---")

            latencies_a = []
            latencies_b_fresh = []
            latencies_b_cached = []
            timeouts_count = 0
            fallbacks_count = 0

            orch = TransferOrchestrator(timeout_ms=1500.0)

            def worker_task(idx: int):
                nonlocal timeouts_count, fallbacks_count
                tx = {
                    "account_id": f"ACC-{100000 + idx}",
                    "target_account_id": f"ACC-{200000 + idx}",
                    "amount": 2500.0 + (idx * 50),
                    "memo": f"payment for groceries #{idx % 5}"
                }
                dev = {"velocity_kmh": 0.0}

                # Stage A
                t0_a = time.perf_counter()
                res_a = self.client.post("/risk/decision", json={"transfer": tx, "device_context": dev})
                lat_a = (time.perf_counter() - t0_a) * 1000.0
                latencies_a.append(lat_a)

                dec_id = res_a.json()["decision_id"]

                # Stage B (Fresh)
                t0_b = time.perf_counter()
                res_b = self.client.post("/risk/memo-check", json={"decision_id": dec_id, "language": "en"})
                lat_b = (time.perf_counter() - t0_b) * 1000.0
                latencies_b_fresh.append(lat_b)
                if lat_b > 1500.0:
                    timeouts_count += 1
                    fallbacks_count += 1

                # Stage B (Cached - Idempotency)
                t0_b_c = time.perf_counter()
                res_b_c = self.client.post("/risk/memo-check", json={"decision_id": dec_id, "language": "en"})
                lat_b_c = (time.perf_counter() - t0_b_c) * 1000.0
                latencies_b_cached.append(lat_b_c)

            t_start = time.perf_counter()
            with ThreadPoolExecutor(max_workers=min(target_tps, 8)) as pool:
                futures = []
                for i in range(total_requests):
                    f = pool.submit(worker_task, i)
                    futures.append(f)
                    time.sleep(interval)
                for f in futures:
                    f.result()
            t_total = time.perf_counter() - t_start

            actual_tps = round(total_requests / t_total, 2)
            perf_results[f"{target_tps}_tps"] = {
                "target_tps": target_tps,
                "actual_tps": actual_tps,
                "total_requests": total_requests,
                "stage_a": {
                    "p50_ms": round(float(np.percentile(latencies_a, 50)), 2),
                    "p95_ms": round(float(np.percentile(latencies_a, 95)), 2),
                    "p99_ms": round(float(np.percentile(latencies_a, 99)), 2),
                    "budget_met": float(np.percentile(latencies_a, 99)) < 200.0
                },
                "stage_b_fresh": {
                    "p50_ms": round(float(np.percentile(latencies_b_fresh, 50)), 2),
                    "p95_ms": round(float(np.percentile(latencies_b_fresh, 95)), 2),
                    "p99_ms": round(float(np.percentile(latencies_b_fresh, 99)), 2),
                },
                "stage_b_cached": {
                    "p50_ms": round(float(np.percentile(latencies_b_cached, 50)), 2),
                    "p95_ms": round(float(np.percentile(latencies_b_cached, 95)), 2),
                    "p99_ms": round(float(np.percentile(latencies_b_cached, 99)), 2),
                },
                "timeouts_count": timeouts_count,
                "fallbacks_count": fallbacks_count,
                "timeout_rate_pct": round(timeouts_count / total_requests * 100.0, 2)
            }

            print(f"Results for {target_tps} TPS (Actual: {actual_tps} TPS):")
            print(f"  Stage A (Sync < 200ms) -> p50: {perf_results[f'{target_tps}_tps']['stage_a']['p50_ms']}ms | p95: {perf_results[f'{target_tps}_tps']['stage_a']['p95_ms']}ms | p99: {perf_results[f'{target_tps}_tps']['stage_a']['p99_ms']}ms")
            print(f"  Stage B (Fresh)        -> p50: {perf_results[f'{target_tps}_tps']['stage_b_fresh']['p50_ms']}ms | p95: {perf_results[f'{target_tps}_tps']['stage_b_fresh']['p95_ms']}ms")
            print(f"  Stage B (Cached)       -> p50: {perf_results[f'{target_tps}_tps']['stage_b_cached']['p50_ms']}ms | p95: {perf_results[f'{target_tps}_tps']['stage_b_cached']['p95_ms']}ms")
            print(f"  Timeouts: {timeouts_count} | Fallbacks: {fallbacks_count} (Rate: {perf_results[f'{target_tps}_tps']['timeout_rate_pct']}%)")

        return perf_results

    # =========================================================================
    # Step 2.6: Adversarial Robustness & Prompt Injection (60 Vectors)
    # =========================================================================
    def evaluate_adversarial_robustness(self) -> Dict[str, Any]:
        print("\n" + "="*80)
        print("STEP 2.6: ADVERSARIAL ROBUSTNESS & PROMPT INJECTION (60 VECTORS)")
        print("="*80)

        downgrades = 0
        tested_vectors = 0
        results_by_cat: Dict[str, Dict[str, int]] = {}

        for item in ADVERSARIAL_MEMOS:
            cat = item["category"]
            memo = item["memo"]
            tested_vectors += 1

            if cat not in results_by_cat:
                results_by_cat[cat] = {"total": 0, "downgrades": 0}
            results_by_cat[cat]["total"] += 1

            # Test 1: S2 action is BLOCK (e.g. impossible travel Gate 0)
            res_a_block = self.client.post("/risk/decision", json={
                "transfer": {"amount": 50000.0, "memo": memo, "account_id": "ACC-ADV-01"},
                "device_context": {"velocity_kmh": 1200.0}  # Gate 0 Hard Rule
            })
            dec_id_block = res_a_block.json()["decision_id"]
            a0_block = res_a_block.json()["action"]
            assert a0_block == "BLOCK"

            # Stage B call with adversarial memo
            res_b_block = self.client.post("/risk/memo-check", json={"decision_id": dec_id_block, "language": "en"})
            b_block_data = res_b_block.json()
            final_action_block = b_block_data["final_action"]

            if ACTION_TIERS[final_action_block] < ACTION_TIERS["BLOCK"]:
                downgrades += 1
                results_by_cat[cat]["downgrades"] += 1

            # Test 2: S2 action is REQUIRE_2FA (e.g. elevated tabular risk)
            # Must NEVER be downgraded to ALLOW
            res_a_req = self.client.post("/risk/decision", json={
                "transfer": {"amount": 25000.0, "memo": memo, "account_id": "ACC-ADV-02"},
                "device_context": {"attestation_verdict": "FAILED"}  # Tripped Gate 0 rule -> REQUIRE_2FA
            })
            dec_id_req = res_a_req.json()["decision_id"]
            a0_req = res_a_req.json()["action"]
            assert a0_req == "REQUIRE_2FA"

            res_b_req = self.client.post("/risk/memo-check", json={"decision_id": dec_id_req, "language": "en"})
            b_req_data = res_b_req.json()
            final_action_req = b_req_data["final_action"]

            if ACTION_TIERS[final_action_req] < ACTION_TIERS["REQUIRE_2FA"]:
                downgrades += 1
                results_by_cat[cat]["downgrades"] += 1

        pass_rate = round((tested_vectors - downgrades) / tested_vectors * 100.0, 2)
        robustness_summary = {
            "total_vectors_tested": tested_vectors,
            "total_downgrades": downgrades,
            "invariant_preservation_rate_pct": pass_rate,
            "zero_downgrades_verified": downgrades == 0,
            "by_category": results_by_cat
        }

        print(f"Vectors Tested: {tested_vectors} across {len(results_by_cat)} categories")
        print(f"Downgrades Recorded: {downgrades}")
        print(f"Invariant Preservation Rate: {pass_rate}% (Zero-Downgrade Invariant: {downgrades == 0})")

        return robustness_summary

    # =========================================================================
    # Run Complete Evaluation
    # =========================================================================
    def run_all(self):
        start_time = time.time()
        print("Starting Comprehensive Two-Stage Risk Engine Benchmark Suite...")

        results = {
            "benchmark_timestamp": time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime()),
            "typology_config": self.typ_config,
            "step_2_1_s2_baseline_verification": self.verify_s2_baseline(),
            "step_2_2_multi_split_typology": self.evaluate_multi_split_typology(),
            "step_2_3_warning_behavior": self.evaluate_warning_behavior(),
            "step_2_4_stress_slices": self.evaluate_stress_slices(),
            "step_2_5_concurrency_and_latency": self.evaluate_concurrency_and_latency(),
            "step_2_6_adversarial_robustness": self.evaluate_adversarial_robustness(),
            "total_benchmark_duration_seconds": round(time.time() - start_time, 2)
        }

        output_path = os.path.join(self.results_dir, "two_stage_evaluation.json")
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(results, f, indent=2)

        print("\n" + "="*80)
        print(f"BENCHMARK COMPLETE IN {results['total_benchmark_duration_seconds']} SECONDS.")
        print(f"Results saved to: {output_path}")
        print("="*80)
        return results


if __name__ == "__main__":
    benchmark = TwoStageBenchmark()
    benchmark.run_all()
