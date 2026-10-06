import os
import sys
import numpy as np
import pandas as pd
import onnxruntime as ort
from tokenizers import Tokenizer
from sklearn.metrics import classification_report, f1_score, confusion_matrix

model_path = 'backend/risk-service/app/models/qwen/model_int8.onnx'
tok_path = 'backend/risk-service/app/models/qwen/tokenizer.json'
tok = Tokenizer.from_file(tok_path)

opts = ort.SessionOptions()
opts.intra_op_num_threads = 8
opts.inter_op_num_threads = 2
sess = ort.InferenceSession(model_path, sess_options=opts, providers=['CPUExecutionProvider'])

empty_pkv = np.zeros((1, 2, 0, 64), dtype=np.float32)
static_pkv = {f'past_key_values.{i}.key': empty_pkv for i in range(24)}
static_pkv.update({f'past_key_values.{i}.value': empty_pkv for i in range(24)})

df_v = pd.read_parquet('hybrid_bench/data/splits/V.parquet')
v_memos = df_v[df_v['memo_present']].copy()

# Ground truth mapping for the 55 memos in V
def assign_gt_typology(memo: str, signal: str) -> str:
    m = memo.lower()
    if signal in ('legit', 'neutral'):
        return 'none'
    if 'lucky draw' in m or 'commission guarantee' in m or 'app testin' in m:
        return 'prize_or_fee_scam'
    if 'crypto' in m or 'liquidity' in m or 'foreign exchange' in m:
        return 'investment_scam'
    if 'bdo account' in m or 'reactivation' in m:
        return 'impersonation'
    return 'other_suspicious'

v_memos['gt_typology'] = [assign_gt_typology(r['memo'], r['memo_signal']) for _, r in v_memos.iterrows()]
print("Ground truth distribution on V:")
print(v_memos['gt_typology'].value_counts())

candidate_labels = [
    'prize_or_fee_scam',
    'investment_scam',
    'romance_scam',
    'impersonation',
    'fake_invoice_or_selling_scam',
    'other_suspicious',
    'none'
]

# We will test token selection strategies:
# Strategy 1: First word of label with space: " prize", " investment", " romance", " impersonation", " invoice", " suspicious", " none"
cand_tokens = {
    'prize_or_fee_scam': tok.encode(" prize").ids[0],
    'investment_scam': tok.encode(" investment").ids[0],
    'romance_scam': tok.encode(" romance").ids[0],
    'impersonation': tok.encode(" impersonation").ids[0],
    'fake_invoice_or_selling_scam': tok.encode(" invoice").ids[0],
    'other_suspicious': tok.encode(" suspicious").ids[0],
    'none': tok.encode(" none").ids[0]
}

preds = []
logits_list = []

for _, row in v_memos.iterrows():
    memo = str(row['memo']).strip()
    amount = float(row['amount_php'])
    spike = float(row.get('spike_ratio', 1.0))
    drain = float(row.get('balance_drain_ratio', 0.0))
    payee_age = float(row.get('payee_age_days', 30.0))
    
    prompt = (
        f"<|im_start|>system\n"
        f"You are NanoJev scam typology classifier. Given a Philippine bank transfer, classify the memo into exactly one typology label: "
        f"prize, investment, romance, impersonation, invoice, suspicious, none.<|im_end|>\n"
        f"<|im_start|>user\n"
        f"Amount: PHP {amount:.2f} | Drain: {drain:.2f} | Spike: {spike:.1f}x | Payee age: {payee_age:.0f} days | Memo: \"{memo}\"\n"
        f"Typology:<|im_end|>\n"
        f"<|im_start|>assistant\n"
    )
    enc = tok.encode(prompt)
    seq_len = len(enc.ids)
    inputs = dict(static_pkv)
    inputs['input_ids'] = np.array([enc.ids], dtype=np.int64)
    inputs['attention_mask'] = np.ones((1, seq_len), dtype=np.int64)
    inputs['position_ids'] = np.arange(seq_len, dtype=np.int64).reshape(1, seq_len)
    outputs = sess.run(None, inputs)
    logits = outputs[0][0, -1, :]
    
    scores = {cl: float(logits[tid]) for cl, tid in cand_tokens.items()}
    pred = max(scores, key=scores.get)
    preds.append(pred)
    logits_list.append([scores[cl] for cl in candidate_labels])

v_memos['pred_typology'] = preds
macro_f1 = f1_score(v_memos['gt_typology'], v_memos['pred_typology'], average='macro')
print(f"\nZero-Shot Macro-F1 on V: {macro_f1:.4f}")
print("\nClassification Report:")
print(classification_report(v_memos['gt_typology'], v_memos['pred_typology'], labels=candidate_labels, zero_division=0))
