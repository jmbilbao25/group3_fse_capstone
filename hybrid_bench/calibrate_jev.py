"""
Phase 4: NanoJev Zero-Shot Inference, Temperature Calibration, and Escalate-Only Tuning.
Implements:
  - Raw logits scoring on memo-present rows of T, V, C1, C2, C3, C4
  - Caching in hybrid_bench/cache/ keyed by SHA256(model_hash + ":" + prompt)
  - Temperature scaling calibration on validation set V only (NLL minimization)
  - Expected Calibration Error (ECE) computation before and after calibration
  - Reliability calibration plot saved to hybrid_bench/reports/calibration_curve.png
  - Tuning of the two escalate-only thresholds (theta_block, theta_2fa) on V
  - Standalone S5 metrics on memo-present rows
"""

import os
import sys
from typing import Dict, Any, List, Tuple, Optional

# Ensure project root in sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import json
import time
import yaml
import numpy as np
import pandas as pd
from scipy.optimize import minimize_scalar
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from sklearn.metrics import roc_auc_score, average_precision_score, f1_score, confusion_matrix
import joblib

from hybrid_bench.wrapper import NanoJevRawWrapper
from hybrid_bench.gate0 import Gate0Filter
from hybrid_bench.train_xgb import TabularFeaturePipeline
import __main__
__main__.TabularFeaturePipeline = TabularFeaturePipeline

def compute_ece(probs: np.ndarray, y_true_indices: np.ndarray, n_bins: int = 10) -> Tuple[float, List[Dict[str, float]]]:
    """
    Computes Expected Calibration Error (ECE) across multi-class predictions.
    """
    confidences = np.max(probs, axis=1)
    predictions = np.argmax(probs, axis=1)
    accuracies = (predictions == y_true_indices)

    bin_boundaries = np.linspace(0.0, 1.0, n_bins + 1)
    ece = 0.0
    bin_details = []

    for i in range(n_bins):
        bin_lower = bin_boundaries[i]
        bin_upper = bin_boundaries[i + 1]

        in_bin = (confidences > bin_lower) & (confidences <= bin_upper) if i > 0 else (confidences >= bin_lower) & (confidences <= bin_upper)
        prop_in_bin = np.mean(in_bin)

        if prop_in_bin > 0:
            accuracy_in_bin = float(np.mean(accuracies[in_bin]))
            avg_confidence_in_bin = float(np.mean(confidences[in_bin]))
            ece += np.abs(avg_confidence_in_bin - accuracy_in_bin) * prop_in_bin
            bin_details.append({
                "bin_lower": round(bin_lower, 2),
                "bin_upper": round(bin_upper, 2),
                "count": int(np.sum(in_bin)),
                "accuracy": round(accuracy_in_bin, 4),
                "confidence": round(avg_confidence_in_bin, 4)
            })

    return round(float(ece), 4), bin_details


def score_memo_present_rows(wrapper: NanoJevRawWrapper, df: pd.DataFrame, split_name: str) -> List[Dict[str, Any]]:
    """
    Runs zero-shot inference for all memo-present rows in a DataFrame.
    Uses SHA256 disk caching to ensure reproducibility and high speed.
    """
    memo_present_df = df[df["memo_present"]].copy()
    print(f"  Scoring Split '{split_name}': {len(memo_present_df):,} memo-present rows (out of {len(df):,} total)...")

    results = []
    t0 = time.perf_counter()
    cache_hits = 0

    for idx, row in memo_present_df.iterrows():
        spike = float(row.get("spike_ratio", 1.0))
        velocity = float(row.get("velocity_kmh", 0.0))
        vpn = bool(row.get("is_vpn", False))
        memo = str(row.get("memo", "")).strip()

        pred = wrapper.predict_raw_logits(
            spike_ratio=spike,
            velocity_kmh=velocity,
            is_vpn=vpn,
            memo=memo,
            use_cache=True
        )

        if pred.get("cached", False):
            cache_hits += 1

        results.append({
            "transaction_id": row["transaction_id"],
            "user_id": row["user_id"],
            "is_fraud": bool(row["is_fraud"]),
            "action_label": str(row["action_label"]),
            "spike_ratio": spike,
            "velocity_kmh": velocity,
            "memo": memo,
            "logits": pred["logits"],
            "raw_probs": pred["raw_probs"],
            "choice": pred["choice"],
            "latency_ms": pred["latency_ms"]
        })

    elapsed_s = time.perf_counter() - t0
    print(f"    Completed in {elapsed_s:.2f}s ({cache_hits}/{len(results)} cache hits, avg: {elapsed_s/max(len(results),1)*1000:.1f}ms/tx)")
    return results


def run_phase4():
    print("=" * 70)
    print("PHASE 4: NANOJEV CALIBRATION & ESCALATE-ONLY TUNING")
    print("=" * 70)

    base_dir = os.path.dirname(os.path.abspath(__file__))
    splits_dir = os.path.join(base_dir, "data", "splits")
    reports_dir = os.path.join(base_dir, "reports")
    results_dir = os.path.join(base_dir, "results")
    cache_dir = os.path.join(base_dir, "cache")
    models_dir = os.path.join(base_dir, "models")
    os.makedirs(reports_dir, exist_ok=True)
    os.makedirs(results_dir, exist_ok=True)
    os.makedirs(cache_dir, exist_ok=True)

    # 1. Initialize NanoJev Wrapper
    print("\n[1/5] Initializing NanoJev Zero-Shot Wrapper...")
    wrapper = NanoJevRawWrapper(cache_dir=cache_dir)
    if not wrapper.model_loaded:
        print("ERROR: NanoJev ONNX model failed to load. Halting Phase 4.", file=sys.stderr)
        sys.exit(1)
    print("  NanoJev ONNX model and tokenizer loaded successfully.")

    # 2. Score memo-present rows on Validation Set V only (Rule 4: touch test sets once in Phase 5)
    print("\n[2/5] Scoring memo-present rows on Validation Set V only...", flush=True)
    splits_data = {}
    scored_results = {}
    for s_name in ["V"]:
        path = os.path.join(splits_dir, f"{s_name}.parquet")
        if os.path.isfile(path):
            df = pd.read_parquet(path)
            splits_data[s_name] = df
            scored_results[s_name] = score_memo_present_rows(wrapper, df, s_name)

    # 3. Temperature Scaling Calibration on Validation Set V only
    print("\n[3/5] Calibrating Temperature on Validation Set V only...")
    v_scores = scored_results["V"]
    v_logits = np.array([[r["logits"]["ALLOW"], r["logits"]["REQUIRE_2FA"], r["logits"]["BLOCK"]] for r in v_scores])

    # True class index mapping: 0=ALLOW, 1=REQUIRE_2FA, 2=BLOCK
    # Legitimate -> ALLOW (0); Fraud -> REQUIRE_2FA (1) or BLOCK (2) based on action_label
    class_map = {"ALLOW": 0, "REQUIRE_2FA": 1, "BLOCK": 2}
    v_true_labels = np.array([class_map[r["action_label"]] for r in v_scores])

    # NLL function to minimize
    def nll_loss(t: float) -> float:
        scaled = v_logits / max(t, 0.01)
        exp_scaled = np.exp(scaled - np.max(scaled, axis=1, keepdims=True))
        probs = exp_scaled / np.sum(exp_scaled, axis=1, keepdims=True)
        # Cross entropy loss
        correct_probs = probs[np.arange(len(v_true_labels)), v_true_labels]
        return -float(np.mean(np.log(np.maximum(correct_probs, 1e-12))))

    # Optimize temperature
    res = minimize_scalar(nll_loss, bounds=(0.2, 5.0), method="bounded")
    optimal_temp = round(float(res.x), 3)

    # Compute uncalibrated vs calibrated probabilities on V
    v_uncal_probs = np.exp(v_logits - np.max(v_logits, axis=1, keepdims=True))
    v_uncal_probs = v_uncal_probs / np.sum(v_uncal_probs, axis=1, keepdims=True)

    v_cal_logits = v_logits / optimal_temp
    v_cal_probs = np.exp(v_cal_logits - np.max(v_cal_logits, axis=1, keepdims=True))
    v_cal_probs = v_cal_probs / np.sum(v_cal_probs, axis=1, keepdims=True)

    ece_before, details_before = compute_ece(v_uncal_probs, v_true_labels)
    ece_after, details_after = compute_ece(v_cal_probs, v_true_labels)

    print(f"  Uncalibrated ECE on V: {ece_before:.4f}")
    print(f"  Optimal Temperature T on V: {optimal_temp:.3f}")
    print(f"  Calibrated ECE on V: {ece_after:.4f} (Reduction: -{(ece_before - ece_after):.4f})")

    # Set wrapper calibrated temperature
    wrapper.temperature = optimal_temp

    # Generate Reliability Plot
    fig, axes = plt.subplots(1, 2, figsize=(12, 5))
    # Uncalibrated
    conf_before = [d["confidence"] for d in details_before]
    acc_before = [d["accuracy"] for d in details_before]
    axes[0].plot([0, 1], [0, 1], "k--", label="Perfect Calibration")
    axes[0].plot(conf_before, acc_before, "o-", color="crimson", label=f"Uncalibrated (ECE = {ece_before:.3f})")
    axes[0].set_title("Reliability Diagram: Uncalibrated NanoJev (T=1.0)")
    axes[0].set_xlabel("Mean Predicted Confidence")
    axes[0].set_ylabel("Empirical Accuracy")
    axes[0].set_xlim([0, 1])
    axes[0].set_ylim([0, 1])
    axes[0].grid(True, alpha=0.3)
    axes[0].legend()

    # Calibrated
    conf_after = [d["confidence"] for d in details_after]
    acc_after = [d["accuracy"] for d in details_after]
    axes[1].plot([0, 1], [0, 1], "k--", label="Perfect Calibration")
    axes[1].plot(conf_after, acc_after, "s-", color="forestgreen", label=f"Calibrated (T = {optimal_temp:.2f}, ECE = {ece_after:.3f})")
    axes[1].set_title(f"Reliability Diagram: Calibrated NanoJev (T={optimal_temp:.2f})")
    axes[1].set_xlabel("Mean Predicted Confidence")
    axes[1].set_ylabel("Empirical Accuracy")
    axes[1].set_xlim([0, 1])
    axes[1].set_ylim([0, 1])
    axes[1].grid(True, alpha=0.3)
    axes[1].legend()

    plt.tight_layout()
    rel_plot_path = os.path.join(reports_dir, "calibration_curve.png")
    plt.savefig(rel_plot_path, dpi=200)
    plt.close()
    print(f"  Saved Reliability Diagram: {rel_plot_path}")

    # 4. Tune Escalate-Only Thresholds (theta_block, theta_2fa) on V only
    print("\n[4/5] Tuning Escalate-Only Combining Rule on Validation Set V only...")
    # Load S2 XGBoost model and pipeline
    model_s2 = joblib.load(os.path.join(models_dir, "s2_xgb_model.joblib"))
    pipe_full = joblib.load(os.path.join(models_dir, "s2_feature_pipeline.joblib"))

    # Load Phase 3 results for S2 thresholds
    phase3_path = os.path.join(results_dir, "phase3_results.json")
    with open(phase3_path, "r", encoding="utf-8") as f:
        p3_res = json.load(f)
    tau_2fa = p3_res["s2_xgboost_full"]["tau_2fa"]
    tau_block = p3_res["s2_xgboost_full"]["tau_block"]

    # Evaluate S2 initial actions on all V
    val_df = splits_data["V"]
    g0 = Gate0Filter()
    val_g0_df = g0.evaluate_dataframe(val_df)
    X_val_s2 = pipe_full.transform(val_g0_df)
    xgb_probs_v = model_s2.predict_proba(X_val_s2)[:, 1]

    initial_actions_v = []
    for idx, r in val_g0_df.iterrows():
        if not r["gate0_passed"]:
            initial_actions_v.append(r["gate0_action"])
        else:
            p = xgb_probs_v[idx]
            if p >= tau_block:
                initial_actions_v.append("BLOCK")
            elif p >= tau_2fa:
                initial_actions_v.append("REQUIRE_2FA")
            else:
                initial_actions_v.append("ALLOW")

    # Map scored memo results for V
    v_memo_lookup = {r["transaction_id"]: r for r in v_scores}

    def compute_op_cost(actions: List[str]) -> float:
        cost = 0.0
        for i, r in val_df.reset_index(drop=True).iterrows():
            is_fraud = bool(r["is_fraud"])
            act = actions[i]
            amt = float(r["amount_php"])
            if is_fraud:
                if act == "ALLOW":
                    cost += amt
                elif act == "REQUIRE_2FA":
                    cost += 0.15 * amt + 25.0
                elif act == "BLOCK":
                    cost += 0.0
            else:
                if act == "BLOCK":
                    cost += 1000.0
                elif act == "REQUIRE_2FA":
                    cost += 25.0
        return cost

    best_score = -1e9
    best_theta_block = 0.50
    best_theta_2fa = 0.35
    best_metrics = {}

    y_val_bool = val_df["is_fraud"].values
    y_val_actions = val_df["action_label"].values

    # Grid search theta_block and theta_2fa on V
    for th_blk in np.linspace(0.20, 0.70, 11):
        for th_2fa in np.linspace(0.15, 0.60, 10):
            final_actions = []
            for idx, r in val_df.reset_index(drop=True).iterrows():
                tx_id = r["transaction_id"]
                a0 = initial_actions_v[idx]

                if not r["memo_present"] or tx_id not in v_memo_lookup:
                    final_actions.append(a0)
                else:
                    # Apply calibrated probabilities
                    memo_res = v_memo_lookup[tx_id]
                    z = np.array([memo_res["logits"]["ALLOW"], memo_res["logits"]["REQUIRE_2FA"], memo_res["logits"]["BLOCK"]]) / optimal_temp
                    exp_z = np.exp(z - np.max(z))
                    probs_c = exp_z / np.sum(exp_z)
                    p_allow_c, p_req_c, p_blk_c = probs_c[0], probs_c[1], probs_c[2]

                    # Escalate-only combining rule
                    if p_blk_c >= th_blk:
                        if a0 == "REQUIRE_2FA":
                            a_star = "BLOCK"
                        elif a0 == "ALLOW":
                            a_star = "REQUIRE_2FA"
                        else:
                            a_star = "BLOCK"
                    elif (p_req_c + p_blk_c) >= th_2fa and a0 == "ALLOW":
                        a_star = "REQUIRE_2FA"
                    else:
                        a_star = a0

                    final_actions.append(a_star)

            # Measure performance on V
            final_actions_arr = np.array(final_actions)
            correct = np.where(y_val_bool, np.isin(final_actions_arr, ["BLOCK", "REQUIRE_2FA"]), final_actions_arr == "ALLOW")
            acc = float(np.mean(correct))
            macro_f1 = float(f1_score(y_val_actions, final_actions_arr, average="macro", labels=["ALLOW", "REQUIRE_2FA", "BLOCK"], zero_division=0))
            cost = compute_op_cost(final_actions)

            # Objective: maximize composite validation utility (balanced macro F1 & accuracy)
            score = macro_f1 + 0.5 * acc
            if score > best_score:
                best_score = score
                best_theta_block = round(float(th_blk), 3)
                best_theta_2fa = round(float(th_2fa), 3)
                best_metrics = {
                    "accuracy": round(acc, 4),
                    "macro_f1": round(macro_f1, 4),
                    "op_cost_php": round(cost, 2)
                }

    print(f"  Tuned Escalate-Only Thresholds on V:")
    print(f"    theta_block = {best_theta_block:.3f} | theta_2fa = {best_theta_2fa:.3f}")
    print(f"    Validation Metrics: Acc={best_metrics['accuracy']*100:.2f}%, Macro-F1={best_metrics['macro_f1']:.4f}, Cost=PHP {best_metrics['op_cost_php']:,.2f}")

    # 5. Standalone S5 (NanoJev) Metrics on Memo-Present Rows of V
    print("\n[5/5] Recording Standalone S5 Metrics on Memo-Present Rows of V...")
    v_memo_fraud = np.array([r["is_fraud"] for r in v_scores])
    v_memo_risk_probs = v_cal_probs[:, 1] + v_cal_probs[:, 2] # P(REQUIRE_2FA) + P(BLOCK)
    v_s5_roc = roc_auc_score(v_memo_fraud, v_memo_risk_probs) if len(np.unique(v_memo_fraud)) > 1 else 1.0
    v_s5_pr = average_precision_score(v_memo_fraud, v_memo_risk_probs) if len(np.unique(v_memo_fraud)) > 1 else 1.0
    v_s5_choices = np.array([r["choice"] for r in v_scores])
    v_s5_correct = np.where(v_memo_fraud, np.isin(v_s5_choices, ["BLOCK", "REQUIRE_2FA"]), v_s5_choices == "ALLOW")
    v_s5_acc = float(np.mean(v_s5_correct))

    print(f"  S5 Standalone (Memo-Present V): ROC-AUC = {v_s5_roc:.4f} | PR-AUC = {v_s5_pr:.4f} | Accuracy = {v_s5_acc*100:.2f}%")

    # 6. Save Phase 4 Results
    phase4_results = {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "memo_present_counts": {s: len(scored_results[s]) for s in scored_results},
        "temperature_calibration": {
            "optimal_temperature": optimal_temp,
            "ece_uncalibrated": ece_before,
            "ece_calibrated": ece_after,
            "ece_reduction": round(float(ece_before - ece_after), 4),
            "reliability_diagram": rel_plot_path
        },
        "escalate_only_tuning": {
            "theta_block": best_theta_block,
            "theta_2fa": best_theta_2fa,
            "val_accuracy": best_metrics["accuracy"],
            "val_macro_f1": best_metrics["macro_f1"],
            "val_cost_php": best_metrics["op_cost_php"]
        },
        "s5_standalone_v": {
            "roc_auc": round(float(v_s5_roc), 4),
            "pr_auc": round(float(v_s5_pr), 4),
            "accuracy": round(v_s5_acc, 4)
        }
    }

    results_file = os.path.join(results_dir, "phase4_results.json")
    with open(results_file, "w", encoding="utf-8") as f:
        json.dump(phase4_results, f, indent=2)
    print(f"\nSaved Phase 4 results to: {results_file}")

    # Update LOG.md
    log_file = os.path.join(base_dir, "LOG.md")
    log_entry = f"""
## Phase 4: NanoJev Zero-Shot Calibration & Escalate-Only Tuning
- **Timestamp**: {phase4_results['timestamp']}
- **Zero-Shot Scoring**: Scored all memo-present rows ({len(v_scores)} on V).
- **Temperature Scaling on V**:
  - Uncalibrated ECE: {ece_before:.4f}
  - Optimal Temperature T: {optimal_temp:.3f}
  - Calibrated ECE: {ece_after:.4f} (-{(ece_before - ece_after):.4f})
  - Reliability Diagram: saved to `hybrid_bench/reports/calibration_curve.png`.
- **Escalate-Only Threshold Tuning on V**:
  - theta_block: {best_theta_block:.3f}
  - theta_2fa: {best_theta_2fa:.3f}
  - Fusion Accuracy on V: {best_metrics['accuracy']*100:.2f}%
  - Fusion Macro-F1 on V: {best_metrics['macro_f1']:.4f}
- **S5 Standalone (Memo-Present V)**: ROC-AUC = {v_s5_roc:.4f}, PR-AUC = {v_s5_pr:.4f}, Accuracy = {v_s5_acc*100:.2f}%.
"""
    with open(log_file, "a", encoding="utf-8") as f:
        f.write(log_entry.strip() + "\n\n")
    print(f"Updated: {log_file}")
    return phase4_results

if __name__ == "__main__":
    run_phase4()
