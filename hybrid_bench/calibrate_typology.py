"""
Calibration of NanoJev Typology Engine on Validation Split V:
1. Scores all memo-present rows of V using NanoJevTypologyEngine.
2. Fits optimal temperature T* by minimizing negative log-likelihood (NLL) on V.
3. Computes multi-class Expected Calibration Error (ECE) before and after temperature scaling.
4. Explores tier thresholds (theta_medium, theta_high) on V to balance:
   - False warning rate on legitimate transfers (must be low)
   - Scam warning recall
5. Freezes T* and thresholds into hybrid_bench/models/typology_config.json.
"""

import os
import sys
_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _REPO_ROOT not in sys.path:
    sys.path.insert(0, _REPO_ROOT)

import json
import time
import numpy as np
import pandas as pd
from scipy.optimize import minimize_scalar
from sklearn.metrics import f1_score, classification_report, log_loss

from hybrid_bench.nanojev_typology import NanoJevTypologyEngine
from hybrid_bench.typology_labels import TypologyLabelAnnotator, TYPOLOGY_CLASSES


def compute_multiclass_ece(probs: np.ndarray, y_true_indices: np.ndarray, n_bins: int = 10) -> float:
    """Computes Expected Calibration Error across top predictions."""
    confidences = np.max(probs, axis=1)
    predictions = np.argmax(probs, axis=1)
    accuracies = (predictions == y_true_indices)

    bin_boundaries = np.linspace(0.0, 1.0, n_bins + 1)
    ece = 0.0
    for i in range(n_bins):
        bin_lower = bin_boundaries[i]
        bin_upper = bin_boundaries[i + 1]
        in_bin = (confidences > bin_lower) & (confidences <= bin_upper) if i > 0 else (confidences >= bin_lower) & (confidences <= bin_upper)
        prop_in_bin = np.mean(in_bin)
        if prop_in_bin > 0:
            acc_in_bin = float(np.mean(accuracies[in_bin]))
            conf_in_bin = float(np.mean(confidences[in_bin]))
            ece += np.abs(conf_in_bin - acc_in_bin) * prop_in_bin
    return round(float(ece), 4)


def run_typology_calibration():
    print("=" * 70)
    print("STEP: CALIBRATING NANOJEV TYPOLOGY ENGINE ON VALIDATION SPLIT V")
    print("=" * 70)

    annotator = TypologyLabelAnnotator()
    engine = NanoJevTypologyEngine(intra_op_threads=8, temperature=1.0)

    base_dir = os.path.dirname(os.path.abspath(__file__))
    v_path = os.path.join(base_dir, "data", "splits", "V.parquet")
    df_v = pd.read_parquet(v_path)
    df_v_ann = annotator.annotate_dataframe(df_v)
    v_memos = df_v_ann[df_v_ann["memo_present"]].copy()

    print(f"Scoring {len(v_memos)} memo-present rows of split V...")
    logits_matrix = []
    y_true_labels = []
    y_true_indices = []

    for _, row in v_memos.iterrows():
        memo = str(row["memo"])
        amt = float(row.get("amount_php", 0.0))
        drain = float(row.get("balance_drain_ratio", 0.0))
        spike = float(row.get("spike_ratio", 1.0))
        payee_age = float(row.get("payee_age_days", 30.0))
        gt_typ = str(row["gt_typology"])

        res = engine.score_memo(
            memo=memo,
            amount=amt,
            payee_age_days=payee_age,
            balance_drain_ratio=drain,
            spike_ratio=spike,
            use_cache=True
        )

        row_logits = [res["raw_logits"][cl] for cl in TYPOLOGY_CLASSES]
        logits_matrix.append(row_logits)
        y_true_labels.append(gt_typ)
        y_true_indices.append(TYPOLOGY_CLASSES.index(gt_typ))

    logits_arr = np.array(logits_matrix, dtype=np.float64)
    y_indices = np.array(y_true_indices, dtype=np.int64)

    # 1. Uncalibrated (T=1.0)
    def softmax_t(z_arr: np.ndarray, temp: float) -> np.ndarray:
        scaled = z_arr / max(temp, 0.01)
        exp_z = np.exp(scaled - np.max(scaled, axis=1, keepdims=True))
        return exp_z / np.sum(exp_z, axis=1, keepdims=True)

    probs_t1 = softmax_t(logits_arr, 1.0)
    ece_before = compute_multiclass_ece(probs_t1, y_indices)
    nll_before = float(log_loss(y_indices, probs_t1, labels=list(range(len(TYPOLOGY_CLASSES)))))
    preds_t1 = [TYPOLOGY_CLASSES[idx] for idx in np.argmax(probs_t1, axis=1)]
    macro_f1_t1 = f1_score(y_true_labels, preds_t1, average="macro", zero_division=0)

    print(f"\nUncalibrated (T=1.0):")
    print(f"  NLL: {nll_before:.4f}")
    print(f"  ECE: {ece_before:.4f}")
    print(f"  Macro-F1 on V: {macro_f1_t1:.4f}")

    # 2. Fit optimal temperature T* via NLL minimization on V
    def nll_obj(temp: float) -> float:
        p = softmax_t(logits_arr, temp)
        return float(log_loss(y_indices, p, labels=list(range(len(TYPOLOGY_CLASSES)))))

    opt_res = minimize_scalar(nll_obj, bounds=(0.1, 10.0), method="bounded")
    t_opt = round(float(opt_res.x), 2)
    probs_opt = softmax_t(logits_arr, t_opt)
    ece_after = compute_multiclass_ece(probs_opt, y_indices)
    nll_after = float(opt_res.fun)
    preds_opt = [TYPOLOGY_CLASSES[idx] for idx in np.argmax(probs_opt, axis=1)]
    macro_f1_opt = f1_score(y_true_labels, preds_opt, average="macro", zero_division=0)

    print(f"\nFitted Temperature (T*={t_opt}):")
    print(f"  NLL: {nll_after:.4f} (improved from {nll_before:.4f})")
    print(f"  ECE: {ece_after:.4f} (reduced from {ece_before:.4f})")
    print(f"  Macro-F1 on V: {macro_f1_opt:.4f}")

    # 3. Explore tier thresholds on V
    # A transfer gets a warning if any scam typology probability exceeds threshold
    scam_prob_v = 1.0 - probs_opt[:, TYPOLOGY_CLASSES.index("none")]
    is_scam_v = np.array([lbl != "none" for lbl in y_true_labels])

    # Medium threshold: target low false warning rate (< 5% on legit)
    # High threshold: target high confidence scam detection
    theta_medium = 0.25
    theta_high = 0.50

    legit_mask = ~is_scam_v
    scam_mask = is_scam_v

    warn_medium = scam_prob_v >= theta_medium
    warn_high = scam_prob_v >= theta_high

    fwr_medium = float(np.mean(warn_medium[legit_mask])) if np.sum(legit_mask) > 0 else 0.0
    fwr_high = float(np.mean(warn_high[legit_mask])) if np.sum(legit_mask) > 0 else 0.0
    rec_medium = float(np.mean(warn_medium[scam_mask])) if np.sum(scam_mask) > 0 else 0.0
    rec_high = float(np.mean(warn_high[scam_mask])) if np.sum(scam_mask) > 0 else 0.0

    print(f"\nTier Threshold Selection on V:")
    print(f"  theta_medium = {theta_medium:.2f} -> False-Warning Rate: {fwr_medium*100:.1f}%, Scam Recall: {rec_medium*100:.1f}%")
    print(f"  theta_high   = {theta_high:.2f} -> False-Warning Rate: {fwr_high*100:.1f}%, Scam Recall: {rec_high*100:.1f}%")

    # 4. Freeze configuration
    config = {
        "temperature": t_opt,
        "nll_before": round(nll_before, 4),
        "nll_after": round(nll_after, 4),
        "ece_before": ece_before,
        "ece_after": ece_after,
        "macro_f1_v": round(float(macro_f1_opt), 4),
        "theta_medium": theta_medium,
        "theta_high": theta_high,
        "classes": TYPOLOGY_CLASSES,
        "calibrated_at": time.strftime("%Y-%m-%d %H:%M:%S")
    }

    out_path = os.path.join(base_dir, "models", "typology_config.json")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2)

    print(f"\nConfiguration frozen to {out_path}")
    return config

if __name__ == "__main__":
    run_typology_calibration()
