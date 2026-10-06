import os
import sys
_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _REPO_ROOT not in sys.path:
    sys.path.insert(0, _REPO_ROOT)

import json
import numpy as np
import pandas as pd
from sklearn.metrics import classification_report, f1_score

from hybrid_bench.nanojev_typology import NanoJevTypologyEngine
from hybrid_bench.typology_labels import TypologyLabelAnnotator, TYPOLOGY_CLASSES

annotator = TypologyLabelAnnotator()
engine = NanoJevTypologyEngine(intra_op_threads=8, temperature=2.5)

base_dir = os.path.dirname(os.path.abspath(__file__))
v_path = os.path.join(base_dir, "data", "splits", "V.parquet")
df_v = pd.read_parquet(v_path)
df_v_ann = annotator.annotate_dataframe(df_v)
v_memos = df_v_ann[df_v_ann["memo_present"]].copy()

# Empty prompt to compute unconditional prior
empty_prompt_res = engine.score_memo(memo="", use_cache=False)
uncond = empty_prompt_res["raw_logits"]
print("Unconditional priors:", uncond)

# Evaluate on V with prior subtraction
y_true = []
preds_raw = []
preds_pmi = []

for _, r in v_memos.iterrows():
    res = engine.score_memo(
        memo=r["memo"],
        amount=r.get("amount_php", 0.0),
        payee_age_days=r.get("payee_age_days", 30.0),
        balance_drain_ratio=r.get("balance_drain_ratio", 0.0),
        spike_ratio=r.get("spike_ratio", 1.0)
    )
    raw_l = res["raw_logits"]
    pmi_l = {cl: raw_l[cl] - uncond[cl] for cl in TYPOLOGY_CLASSES}
    
    pred_raw = max(raw_l, key=raw_l.get)
    pred_pmi = max(pmi_l, key=pmi_l.get)
    
    y_true.append(r["gt_typology"])
    preds_raw.append(pred_raw)
    preds_pmi.append(pred_pmi)

print("\n--- Split V Raw Zero-Shot ---")
print("Macro-F1:", f1_score(y_true, preds_raw, average="macro", zero_division=0))
print(classification_report(y_true, preds_raw, labels=TYPOLOGY_CLASSES, zero_division=0))

print("\n--- Split V Context-Free Prior Calibrated (PMI) ---")
print("Macro-F1:", f1_score(y_true, preds_pmi, average="macro", zero_division=0))
print(classification_report(y_true, preds_pmi, labels=TYPOLOGY_CLASSES, zero_division=0))
