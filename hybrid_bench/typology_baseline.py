"""
TF-IDF Baseline for Scam Typology Classification.
Implements TF-IDF (word (1, 2) + char (3, 5) n-grams) + Logistic Regression.
Trained on memo-present rows of split T with ground truth typology labels.
Used to compare against NanoJev on Macro-F1, ECE, and false-warning rates.
"""

import os
import sys
_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _REPO_ROOT not in sys.path:
    sys.path.insert(0, _REPO_ROOT)

import joblib
import numpy as np
import pandas as pd
from typing import Dict, Any, Tuple, List, Optional
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.pipeline import FeatureUnion
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import classification_report, f1_score

from hybrid_bench.typology_labels import TypologyLabelAnnotator

TYPOLOGY_CLASSES = [
    "prize_or_fee_scam",
    "investment_scam",
    "romance_scam",
    "impersonation",
    "fake_invoice_or_selling_scam",
    "other_suspicious",
    "none"
]

class TFIDFTypologyBaseline:
    def __init__(self, model_save_path: Optional[str] = None):
        self.model_save_path = model_save_path
        self.vectorizer = FeatureUnion([
            ("word", TfidfVectorizer(ngram_range=(1, 2), min_df=1, sublinear_tf=True, token_pattern=r"(?u)\b\w+\b")),
            ("char", TfidfVectorizer(ngram_range=(3, 5), analyzer="char_wb", min_df=1, sublinear_tf=True))
        ])
        # LogisticRegression with balanced class weighting and l2 penalty
        self.clf = LogisticRegression(
            C=1.0,
            max_iter=1000,
            class_weight="balanced",
            random_state=42
        )
        self.classes_ = TYPOLOGY_CLASSES
        self.is_fitted = False

    def fit(self, train_memos: List[str], train_labels: List[str]):
        """Fits the TF-IDF feature union and logistic regression model."""
        clean_memos = [str(m or "").strip().lower() for m in train_memos]
        X = self.vectorizer.fit_transform(clean_memos)
        
        # Ensure all TYPOLOGY_CLASSES are recognized
        self.clf.fit(X, train_labels)
        self.is_fitted = True
        
        if self.model_save_path:
            os.makedirs(os.path.dirname(self.model_save_path), exist_ok=True)
            joblib.dump({"vectorizer": self.vectorizer, "clf": self.clf}, self.model_save_path)

    def predict_proba(self, memos: List[str]) -> np.ndarray:
        """Returns probability distribution across TYPOLOGY_CLASSES."""
        clean_memos = [str(m or "").strip().lower() for m in memos]
        X = self.vectorizer.transform(clean_memos)
        probs = self.clf.predict_proba(X)
        
        # Align column order with TYPOLOGY_CLASSES
        clf_classes = list(self.clf.classes_)
        aligned = np.zeros((len(memos), len(TYPOLOGY_CLASSES)), dtype=np.float32)
        for i, target_cls in enumerate(TYPOLOGY_CLASSES):
            if target_cls in clf_classes:
                idx = clf_classes.index(target_cls)
                aligned[:, i] = probs[:, idx]
            else:
                aligned[:, i] = 0.0
                
        # Re-normalize rows
        row_sums = aligned.sum(axis=1, keepdims=True)
        row_sums[row_sums == 0] = 1.0
        aligned = aligned / row_sums
        return aligned

    def predict(self, memos: List[str]) -> List[str]:
        probs = self.predict_proba(memos)
        pred_indices = np.argmax(probs, axis=1)
        return [TYPOLOGY_CLASSES[idx] for idx in pred_indices]

    @classmethod
    def load(cls, model_path: str) -> "TFIDFTypologyBaseline":
        data = joblib.load(model_path)
        inst = cls(model_save_path=model_path)
        inst.vectorizer = data["vectorizer"]
        inst.clf = data["clf"]
        inst.is_fitted = True
        return inst


def train_and_evaluate_tfidf():
    annotator = TypologyLabelAnnotator()
    base_dir = os.path.dirname(os.path.abspath(__file__))
    splits_dir = os.path.join(base_dir, "data", "splits")
    
    # 1. Load and annotate training split T
    df_t = pd.read_parquet(os.path.join(splits_dir, "T.parquet"))
    df_t_ann = annotator.annotate_dataframe(df_t)
    df_t_memo = df_t_ann[df_t_ann["memo_present"]].copy()
    
    # In addition to T, enrich training with seed pools so all 7 typologies have support
    train_seeds = annotator.train_seeds
    extra_memos = []
    extra_labels = []
    for _, r in train_seeds.iterrows():
        raw = str(r["memo"])
        sig = str(r["signal"]).lower()
        st = str(r.get("subtype", "generic")).lower()
        from hybrid_bench.typology_labels import SUBTYPE_TO_TYPOLOGY
        typ = SUBTYPE_TO_TYPOLOGY.get(st, "other_suspicious") if sig == "scam" else "none"
        extra_memos.append(raw)
        extra_labels.append(typ)
        
    all_train_memos = list(df_t_memo["memo"].values) + extra_memos
    all_train_labels = list(df_t_memo["gt_typology"].values) + extra_labels
    
    model_path = os.path.join(base_dir, "models", "tfidf_typology_model.joblib")
    baseline = TFIDFTypologyBaseline(model_save_path=model_path)
    baseline.fit(all_train_memos, all_train_labels)
    print("TF-IDF Typology Baseline trained successfully.")
    
    # 2. Evaluate on V, C1, C2, C4
    for split_name in ["V", "C1", "C2", "C4"]:
        df_split = pd.read_parquet(os.path.join(splits_dir, f"{split_name}.parquet"))
        df_ann = annotator.annotate_dataframe(df_split)
        memo_rows = df_ann[df_ann["memo_present"]].copy()
        
        preds = baseline.predict(list(memo_rows["memo"].values))
        macro_f1 = f1_score(memo_rows["gt_typology"], preds, average="macro")
        acc = float(np.mean(memo_rows["gt_typology"].values == np.array(preds)))
        print(f"\n--- Split {split_name} (N={len(memo_rows)}) ---")
        print(f"Accuracy: {acc:.4f}, Macro-F1: {macro_f1:.4f}")
        print(classification_report(memo_rows["gt_typology"], preds, labels=TYPOLOGY_CLASSES, zero_division=0))

if __name__ == "__main__":
    train_and_evaluate_tfidf()
