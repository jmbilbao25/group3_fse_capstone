"""
Phase 3: Gate 0 + XGBoost Training, TF-IDF Baseline, and Feature Ablations.
Implements:
  - S1: Tuned Rules Baseline (thresholds tuned on V)
  - S2: Gate 0 + XGBoost (Tabular + Device Context, no memo)
  - S3: Gate 0 + XGBoost + TF-IDF Memo Score (5-fold OOF on T)
  - Ablation A: XGBoost without device context features
  - Ablation B: XGBoost without purpose / payee features
  - SHAP tree explanation and feature importance extraction
  - Threshold tuning on V (tau_2fa, tau_block)
"""

import os
import sys
from typing import Tuple, List, Dict, Any, Optional

# Ensure project root is in sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import json
import time
import joblib
import yaml
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

import xgboost as xgb
from sklearn.model_selection import StratifiedKFold
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score, average_precision_score, f1_score, confusion_matrix
import shap

from hybrid_bench.gate0 import Gate0Filter

def get_feature_columns(df: pd.DataFrame) -> Tuple[List[str], List[str], List[str]]:
    """Separates numeric, boolean, and categorical feature columns."""
    exclude = {
        "transaction_id", "user_id", "split", "is_fraud", "action_label",
        "memo", "memo_present", "memo_signal", "typology_novel", "is_gate0_trivial",
        "gate0_action", "gate0_reason", "gate0_passed"
    }

    cols = [c for c in df.columns if c not in exclude]
    numeric_cols = []
    boolean_cols = []
    categorical_cols = []

    for c in cols:
        if df[c].dtype == bool or set(df[c].dropna().unique()).issubset({True, False, 0, 1}):
            boolean_cols.append(c)
        elif pd.api.types.is_numeric_dtype(df[c]):
            numeric_cols.append(c)
        else:
            categorical_cols.append(c)

    return numeric_cols, boolean_cols, categorical_cols

class TabularFeaturePipeline:
    """Preprocesses tabular data with consistent encoding between train and test."""

    def __init__(self, drop_device: bool = False, drop_purpose_payee: bool = False):
        self.drop_device = drop_device
        self.drop_purpose_payee = drop_purpose_payee
        self.cat_mappings: Dict[str, Dict[str, int]] = {}
        self.feature_names: List[str] = []

        self.device_features = {
            "device_id_new", "device_age_days", "accounts_per_device", "rooted",
            "hooking", "emulator", "debugger", "tampered", "unofficial_store",
            "dev_options", "mock_location", "accessibility_active", "screen_sharing",
            "attestation_verdict", "os_patch_age_days", "login_method",
            "seconds_since_login", "failed_logins_1h", "credential_change_hours_ago",
            "payee_pasted", "form_seconds", "gps_accuracy_m", "tz_mismatch",
            "ip_gps_mismatch", "is_vpn"
        }

        self.purpose_payee_features = {
            "transfer_purpose", "payee_type", "new_payee", "payee_age_days", "senders_to_payee_24h"
        }

    def fit_transform(self, df: pd.DataFrame) -> pd.DataFrame:
        data = df.copy()
        num_cols, bool_cols, cat_cols = get_feature_columns(data)

        # Apply ablations
        if self.drop_device:
            num_cols = [c for c in num_cols if c not in self.device_features]
            bool_cols = [c for c in bool_cols if c not in self.device_features]
            cat_cols = [c for c in cat_cols if c not in self.device_features]

        if self.drop_purpose_payee:
            num_cols = [c for c in num_cols if c not in self.purpose_payee_features]
            bool_cols = [c for c in bool_cols if c not in self.purpose_payee_features]
            cat_cols = [c for c in cat_cols if c not in self.purpose_payee_features]

        processed = pd.DataFrame(index=data.index)

        # Numeric: fill na with median
        for c in num_cols:
            med = data[c].median()
            processed[c] = data[c].fillna(med).astype(float)

        # Boolean: cast to int
        for c in bool_cols:
            processed[c] = data[c].astype(int)

        # Categorical: one-hot or frequency mapping
        for c in cat_cols:
            cats = sorted(data[c].astype(str).unique().tolist())
            self.cat_mappings[c] = {cat: idx for idx, cat in enumerate(cats)}
            processed[c] = data[c].astype(str).map(self.cat_mappings[c]).fillna(-1).astype(int)

        self.feature_names = processed.columns.tolist()
        return processed

    def transform(self, df: pd.DataFrame) -> pd.DataFrame:
        data = df.copy()
        processed = pd.DataFrame(index=data.index)

        for c in self.feature_names:
            if c in self.cat_mappings:
                processed[c] = data[c].astype(str).map(self.cat_mappings[c]).fillna(-1).astype(int)
            elif c in data.columns:
                if data[c].dtype == bool:
                    processed[c] = data[c].astype(int)
                else:
                    processed[c] = data[c].fillna(0.0).astype(float)
            else:
                processed[c] = 0.0

        return processed[self.feature_names]


class TFIDFMemeoBaseline:
    """Out-of-fold TF-IDF + Logistic Regression model on transfer memos."""

    def __init__(self):
        self.vectorizer = TfidfVectorizer(ngram_range=(1, 2), min_df=2, max_features=500, lowercase=True)
        self.clf = LogisticRegression(C=1.0, max_iter=500, class_weight="balanced")

    def fit_oof_train(self, train_df: pd.DataFrame) -> np.ndarray:
        """5-fold stratified out-of-fold scoring on training split T."""
        memos = train_df["memo"].fillna("").astype(str).values
        y = train_df["is_fraud"].values
        oof_preds = np.zeros(len(train_df), dtype=float)

        skf = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
        for train_idx, val_idx in skf.split(memos, y):
            fold_vec = TfidfVectorizer(ngram_range=(1, 2), min_df=2, max_features=500, lowercase=True)
            X_tr = fold_vec.fit_transform(memos[train_idx])
            X_va = fold_vec.transform(memos[val_idx])

            fold_clf = LogisticRegression(C=1.0, max_iter=500, class_weight="balanced")
            fold_clf.fit(X_tr, y[train_idx])
            oof_preds[val_idx] = fold_clf.predict_proba(X_va)[:, 1]

        # Fit full on all T
        X_full = self.vectorizer.fit_transform(memos)
        self.clf.fit(X_full, y)
        return oof_preds

    def predict_proba(self, df: pd.DataFrame) -> np.ndarray:
        memos = df["memo"].fillna("").astype(str).values
        X = self.vectorizer.transform(memos)
        return self.clf.predict_proba(X)[:, 1]


def build_tuned_rules_model(train_df: pd.DataFrame, val_df: pd.DataFrame) -> Dict[str, Any]:
    """
    S1: Tuned Rules Baseline.
    Heuristic rule scoring function tuned on validation set V.
    """
    def score_rules(df: pd.DataFrame, w_spike: float, w_drain: float, w_dev: float, w_vpn: float) -> np.ndarray:
        score = np.zeros(len(df), dtype=float)
        score += (df["spike_ratio"] >= 3.0) * w_spike
        score += (df["balance_drain_ratio"] >= 0.70) * w_drain
        score += (df["rooted"] | df["hooking"] | df["emulator"]) * w_dev
        score += (df["is_vpn"]) * w_vpn
        score += (df["velocity_kmh"] > 150.0) * 20.0
        score += (df["new_payee"] & (df["senders_to_payee_24h"] >= 4)) * 15.0
        return score

    best_f1 = -1.0
    best_params = {}

    # Grid search on V
    y_val = val_df["is_fraud"].values
    for w_spike in [15.0, 25.0]:
        for w_drain in [10.0, 20.0]:
            for w_dev in [20.0, 35.0]:
                for w_vpn in [10.0, 20.0]:
                    scores = score_rules(val_df, w_spike, w_drain, w_dev, w_vpn)
                    for thresh in np.linspace(20.0, 60.0, 9):
                        preds = scores >= thresh
                        f1 = f1_score(y_val, preds, zero_division=0)
                        if f1 > best_f1:
                            best_f1 = f1
                            best_params = {
                                "w_spike": w_spike,
                                "w_drain": w_drain,
                                "w_dev": w_dev,
                                "w_vpn": w_vpn,
                                "thresh": thresh,
                                "val_f1": round(f1, 4)
                            }

    return best_params


def train_xgboost(
    X_train: pd.DataFrame,
    y_train: np.ndarray,
    X_val: pd.DataFrame,
    y_val: np.ndarray,
    monotone_constraints: Optional[Dict[str, int]] = None
) -> xgb.XGBClassifier:
    mono = {}
    if monotone_constraints:
        for f, direction in monotone_constraints.items():
            if f in X_train.columns:
                mono[f] = direction

    model = xgb.XGBClassifier(
        n_estimators=300,
        learning_rate=0.08,
        max_depth=4,
        subsample=0.85,
        colsample_bytree=0.85,
        monotone_constraints=mono if mono else None,
        random_state=42,
        eval_metric="logloss",
        early_stopping_rounds=25,
        tree_method="hist",
        n_jobs=-1
    )

    model.fit(
        X_train, y_train,
        eval_set=[(X_val, y_val)],
        verbose=False
    )
    return model


def tune_action_thresholds(y_val: np.ndarray, y_probs: np.ndarray) -> Tuple[float, float, float]:
    """
    Grid searches tau_2fa and tau_block on validation set V
    to maximize 3-action macro-F1.
    """
    best_macro_f1 = -1.0
    best_t2fa = 0.25
    best_tblock = 0.65

    # Target actions: Fraud -> BLOCK (if prob high) or REQUIRE_2FA; Legit -> ALLOW
    y_true_actions = np.where(y_val, "BLOCK", "ALLOW")

    for t_2fa in np.linspace(0.10, 0.45, 15):
        for t_blk in np.linspace(0.50, 0.85, 15):
            if t_2fa >= t_blk:
                continue
            pred_actions = np.where(y_probs >= t_blk, "BLOCK", np.where(y_probs >= t_2fa, "REQUIRE_2FA", "ALLOW"))
            # 3-action mapping: treat both BLOCK and REQUIRE_2FA as valid fraud interventions
            correct = np.where(y_val, np.isin(pred_actions, ["BLOCK", "REQUIRE_2FA"]), pred_actions == "ALLOW")
            f1 = float(np.mean(correct))
            if f1 > best_macro_f1:
                best_macro_f1 = f1
                best_t2fa = round(t_2fa, 3)
                best_tblock = round(t_blk, 3)

    return best_t2fa, best_tblock, round(best_macro_f1, 4)


def run_phase3():
    print("=" * 70)
    print("PHASE 3: GATE 0 + XGBOOST TRAINING & FEATURE ABLATIONS")
    print("=" * 70)

    base_dir = os.path.dirname(os.path.abspath(__file__))
    splits_dir = os.path.join(base_dir, "data", "splits")
    models_dir = os.path.join(base_dir, "models")
    reports_dir = os.path.join(base_dir, "reports")
    results_dir = os.path.join(base_dir, "results")
    os.makedirs(models_dir, exist_ok=True)
    os.makedirs(reports_dir, exist_ok=True)
    os.makedirs(results_dir, exist_ok=True)

    # 1. Load splits
    print("[1/6] Loading splits T (train) and V (validation)...")
    train_df = pd.read_parquet(os.path.join(splits_dir, "T.parquet"))
    val_df = pd.read_parquet(os.path.join(splits_dir, "V.parquet"))
    print(f"  T: {len(train_df):,} rows (fraud: {train_df['is_fraud'].sum():,})")
    print(f"  V: {len(val_df):,} rows (fraud: {val_df['is_fraud'].sum():,})")

    # 2. Gate 0 Triage Audit
    print("\n[2/6] Auditing Gate 0 Hard Rules...")
    g0 = Gate0Filter()
    train_g0_audit = g0.audit_split(train_df, "T")
    val_g0_audit = g0.audit_split(val_df, "V")
    print(f"  Gate 0 fired on T: {train_g0_audit['gate0_fired_count']}/{len(train_df)} ({train_g0_audit['gate0_fired_pct']}%) | Prec: {train_g0_audit['overall_precision']*100:.1f}%")
    print(f"  Gate 0 fired on V: {val_g0_audit['gate0_fired_count']}/{len(val_df)} ({val_g0_audit['gate0_fired_pct']}%) | Prec: {val_g0_audit['overall_precision']*100:.1f}%")

    # Filter out Gate 0 fired rows for XGBoost training
    train_xgb_df = g0.evaluate_dataframe(train_df)
    train_xgb_pass = train_xgb_df[train_xgb_df["gate0_passed"]]
    val_xgb_df = g0.evaluate_dataframe(val_df)
    val_xgb_pass = val_xgb_df[val_xgb_df["gate0_passed"]]

    # 3. Fit S1 (Tuned Rules Baseline)
    print("\n[3/6] Tuning S1 (Rules-Only Baseline) on V...")
    s1_params = build_tuned_rules_model(train_df, val_df)
    print(f"  S1 optimal parameters on V: {s1_params}")

    # 4. Feature Pipelines & S2 (Gate 0 + XGBoost Full)
    print("\n[4/6] Training S2 (Gate 0 + XGBoost Full with Device Context)...")
    pipe_full = TabularFeaturePipeline(drop_device=False, drop_purpose_payee=False)
    X_train_s2 = pipe_full.fit_transform(train_xgb_pass)
    y_train = train_xgb_pass["is_fraud"].values
    X_val_s2 = pipe_full.transform(val_xgb_pass)
    y_val = val_xgb_pass["is_fraud"].values

    monotone_constraints = {
        "spike_ratio": 1,
        "balance_drain_ratio": 1,
        "cum_outflow_1h": 1,
        "cum_outflow_24h": 1,
        "payees_24h": 1,
        "failed_logins_1h": 1
    }

    model_s2 = train_xgboost(X_train_s2, y_train, X_val_s2, y_val, monotone_constraints)
    val_probs_s2 = model_s2.predict_proba(X_val_s2)[:, 1]
    s2_roc = roc_auc_score(y_val, val_probs_s2)
    s2_pr = average_precision_score(y_val, val_probs_s2)
    tau_2fa, tau_block, macro_f1_v = tune_action_thresholds(y_val, val_probs_s2)

    print(f"  S2 on V: ROC-AUC = {s2_roc:.4f} | PR-AUC = {s2_pr:.4f}")
    print(f"  S2 V-tuned Thresholds: tau_2fa = {tau_2fa:.3f} | tau_block = {tau_block:.3f} (Val Score: {macro_f1_v:.4f})")

    # Save S2
    joblib.dump(model_s2, os.path.join(models_dir, "s2_xgb_model.joblib"))
    joblib.dump(pipe_full, os.path.join(models_dir, "s2_feature_pipeline.joblib"))

    # 5. S3: TF-IDF Memo Baseline
    print("\n[5/6] Training S3 (XGBoost + OOF TF-IDF Memo Score)...")
    tfidf_baseline = TFIDFMemeoBaseline()
    oof_memo_train = tfidf_baseline.fit_oof_train(train_xgb_pass)
    oof_memo_val = tfidf_baseline.predict_proba(val_xgb_pass)

    X_train_s3 = X_train_s2.copy()
    X_train_s3["tfidf_memo_score"] = oof_memo_train
    X_val_s3 = X_val_s2.copy()
    X_val_s3["tfidf_memo_score"] = oof_memo_val

    model_s3 = train_xgboost(X_train_s3, y_train, X_val_s3, y_val)
    val_probs_s3 = model_s3.predict_proba(X_val_s3)[:, 1]
    s3_roc = roc_auc_score(y_val, val_probs_s3)
    s3_pr = average_precision_score(y_val, val_probs_s3)
    print(f"  S3 on V: ROC-AUC = {s3_roc:.4f} | PR-AUC = {s3_pr:.4f}")

    joblib.dump(model_s3, os.path.join(models_dir, "s3_xgb_model.joblib"))
    joblib.dump(tfidf_baseline, os.path.join(models_dir, "s3_tfidf_baseline.joblib"))

    # 6. Ablation Studies
    print("\n[6/6] Executing Feature Ablation Studies...")
    # Ablation A: Without Device Features
    pipe_no_device = TabularFeaturePipeline(drop_device=True, drop_purpose_payee=False)
    X_train_nodev = pipe_no_device.fit_transform(train_xgb_pass)
    X_val_nodev = pipe_no_device.transform(val_xgb_pass)
    model_nodev = train_xgboost(X_train_nodev, y_train, X_val_nodev, y_val)
    val_probs_nodev = model_nodev.predict_proba(X_val_nodev)[:, 1]
    nodev_roc = roc_auc_score(y_val, val_probs_nodev)
    nodev_pr = average_precision_score(y_val, val_probs_nodev)
    device_lift_roc = s2_roc - nodev_roc
    print(f"  Ablation A (No Device): ROC-AUC = {nodev_roc:.4f} | Device Lift: +{device_lift_roc:.4f} ROC-AUC")

    # Ablation B: Without Purpose/Payee Features
    pipe_no_payee = TabularFeaturePipeline(drop_device=False, drop_purpose_payee=True)
    X_train_nopayee = pipe_no_payee.fit_transform(train_xgb_pass)
    X_val_nopayee = pipe_no_payee.transform(val_xgb_pass)
    model_nopayee = train_xgboost(X_train_nopayee, y_train, X_val_nopayee, y_val)
    val_probs_nopayee = model_nopayee.predict_proba(X_val_nopayee)[:, 1]
    nopayee_roc = roc_auc_score(y_val, val_probs_nopayee)
    nopayee_pr = average_precision_score(y_val, val_probs_nopayee)
    payee_lift_roc = s2_roc - nopayee_roc
    print(f"  Ablation B (No Payee/Purpose): ROC-AUC = {nopayee_roc:.4f} | Payee Lift: +{payee_lift_roc:.4f} ROC-AUC")

    # 7. SHAP Analysis
    print("\nExtracting Tree SHAP Explanations...")
    explainer = shap.TreeExplainer(model_s2)
    shap_values = explainer(X_val_s2)

    # Top-10 features by mean absolute SHAP value
    mean_abs_shap = np.mean(np.abs(shap_values.values), axis=0)
    top_indices = np.argsort(mean_abs_shap)[::-1][:10]
    top_10_features = []
    for idx in top_indices:
        feat_name = X_val_s2.columns[idx]
        val_mean = float(mean_abs_shap[idx])
        top_10_features.append({"feature": feat_name, "mean_abs_shap": round(val_mean, 4)})

    print("  Top-10 Features by SHAP Importance:")
    for rank, f_info in enumerate(top_10_features, 1):
        print(f"    {rank}. {f_info['feature']:<28} (SHAP: {f_info['mean_abs_shap']:.4f})")

    # Save SHAP Summary Plot
    plt.figure(figsize=(10, 6))
    shap.summary_plot(shap_values.values, X_val_s2, plot_type="dot", max_display=10, show=False)
    plt.title("XGBoost SHAP Feature Importance (Validation Set V)")
    plt.tight_layout()
    shap_plot_path = os.path.join(reports_dir, "shap_importance.png")
    plt.savefig(shap_plot_path, dpi=200)
    plt.close()
    print(f"  Saved SHAP plot: {shap_plot_path}")

    # 8. Record Results
    phase3_results = {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "gate0_audit": {
            "T": train_g0_audit,
            "V": val_g0_audit
        },
        "s1_tuned_rules": s1_params,
        "s2_xgboost_full": {
            "val_roc_auc": round(float(s2_roc), 4),
            "val_pr_auc": round(float(s2_pr), 4),
            "tau_2fa": tau_2fa,
            "tau_block": tau_block,
            "val_3action_score": macro_f1_v
        },
        "s3_xgboost_tfidf": {
            "val_roc_auc": round(float(s3_roc), 4),
            "val_pr_auc": round(float(s3_pr), 4)
        },
        "ablations": {
            "no_device_features": {
                "val_roc_auc": round(float(nodev_roc), 4),
                "val_pr_auc": round(float(nodev_pr), 4),
                "roc_lift": round(float(device_lift_roc), 4)
            },
            "no_purpose_payee_features": {
                "val_roc_auc": round(float(nopayee_roc), 4),
                "val_pr_auc": round(float(nopayee_pr), 4),
                "roc_lift": round(float(payee_lift_roc), 4)
            }
        },
        "top_10_features_shap": top_10_features
    }

    results_file = os.path.join(results_dir, "phase3_results.json")
    with open(results_file, "w", encoding="utf-8") as f:
        json.dump(phase3_results, f, indent=2)
    print(f"\nSaved Phase 3 results to: {results_file}")

    # Update LOG.md
    log_file = os.path.join(base_dir, "LOG.md")
    log_entry = f"""
## Phase 3: Gate 0 + XGBoost Training & Feature Ablations
- **Timestamp**: {phase3_results['timestamp']}
- **Gate 0 Execution**:
  - Filtered {train_g0_audit['gate0_fired_count']}/{len(train_df)} rows on T ({train_g0_audit['gate0_fired_pct']}%, precision: {train_g0_audit['overall_precision']*100:.1f}%)
  - Filtered {val_g0_audit['gate0_fired_count']}/{len(val_df)} rows on V ({val_g0_audit['gate0_fired_pct']}%, precision: {val_g0_audit['overall_precision']*100:.1f}%)
- **S1 (Tuned Rules Baseline)**: Tuned on V with optimal parameters {s1_params}.
- **S2 (XGBoost Tabular + Device Context)**:
  - Val ROC-AUC: {s2_roc:.4f} | Val PR-AUC: {s2_pr:.4f}
  - Tuned Thresholds: tau_2fa = {tau_2fa:.3f}, tau_block = {tau_block:.3f}
- **S3 (XGBoost + OOF TF-IDF Memo Baseline)**:
  - Val ROC-AUC: {s3_roc:.4f} | Val PR-AUC: {s3_pr:.4f}
- **Ablation Studies**:
  - Without Device Features: ROC-AUC = {nodev_roc:.4f} (Device Lift: +{device_lift_roc:.4f} ROC-AUC)
  - Without Payee/Purpose: ROC-AUC = {nopayee_roc:.4f} (Payee Lift: +{payee_lift_roc:.4f} ROC-AUC)
- **SHAP Analysis**: Generated beeswarm summary plot at `hybrid_bench/reports/shap_importance.png`.
"""
    with open(log_file, "a", encoding="utf-8") as f:
        f.write(log_entry.strip() + "\n\n")
    print(f"Updated: {log_file}")

    return phase3_results

if __name__ == "__main__":
    run_phase3()
