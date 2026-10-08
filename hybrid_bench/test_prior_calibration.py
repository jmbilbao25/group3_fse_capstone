import numpy as np
import pandas as pd
from sklearn.metrics import classification_report, f1_score

# In evaluate_typology_v.py we recorded logits
# Let's see what happens if we subtract the mean logit across V or compute prior offsets
# Let's inspect the logits across V
import onnxruntime as ort
from tokenizers import Tokenizer

model_path = 'backend/risk-service/app/models/qwen/model_int8.onnx'
tok_path = 'backend/risk-service/app/models/qwen/tokenizer.json'
tok = Tokenizer.from_file(tok_path)

opts = ort.SessionOptions()
opts.intra_op_num_threads = 8
sess = ort.InferenceSession(model_path, sess_options=opts, providers=['CPUExecutionProvider'])

empty_pkv = np.zeros((1, 2, 0, 64), dtype=np.float32)
static_pkv = {f'past_key_values.{i}.key': empty_pkv for i in range(24)}
static_pkv.update({f'past_key_values.{i}.value': empty_pkv for i in range(24)})

df_v = pd.read_parquet('hybrid_bench/data/splits/V.parquet')
v_memos = df_v[df_v['memo_present']].copy()

def assign_gt(m, sig):
    ml = m.lower()
    if sig in ('legit', 'neutral'):
        return 'none'
    if 'lucky draw' in ml or 'commission guarantee' in ml or 'app testin' in ml:
        return 'prize_or_fee_scam'
    if 'crypto' in ml or 'liquidity' in ml or 'foreign exchange' in ml:
        return 'investment_scam'
    if 'bdo account' in ml or 'reactivation' in ml:
        return 'impersonation'
    return 'other_suspicious'

v_memos['gt'] = [assign_gt(r['memo'], r['memo_signal']) for _, r in v_memos.iterrows()]

candidate_labels = [
    'prize_or_fee_scam',
    'investment_scam',
    'romance_scam',
    'impersonation',
    'fake_invoice_or_selling_scam',
    'other_suspicious',
    'none'
]

cand_tokens = {
    'prize_or_fee_scam': tok.encode(" prize").ids[0],
    'investment_scam': tok.encode(" investment").ids[0],
    'romance_scam': tok.encode(" romance").ids[0],
    'impersonation': tok.encode(" impersonation").ids[0],
    'fake_invoice_or_selling_scam': tok.encode(" invoice").ids[0],
    'other_suspicious': tok.encode(" suspicious").ids[0],
    'none': tok.encode(" none").ids[0]
}

# Unconditional prompt (empty memo) to get baseline prior logits
empty_prompt = (
    "<|im_start|>system\n"
    "You are NanoJev scam typology classifier. Given a Philippine bank transfer, classify the memo into exactly one typology label: "
    "prize, investment, romance, impersonation, invoice, suspicious, none.<|im_end|>\n"
    "<|im_start|>user\n"
    "Memo: \"\"\n"
    "Typology:<|im_end|>\n"
    "<|im_start|>assistant\n"
)
enc = tok.encode(empty_prompt)
seq_len = len(enc.ids)
inputs = dict(static_pkv)
inputs['input_ids'] = np.array([enc.ids], dtype=np.int64)
inputs['attention_mask'] = np.ones((1, seq_len), dtype=np.int64)
inputs['position_ids'] = np.arange(seq_len, dtype=np.int64).reshape(1, seq_len)
outputs = sess.run(None, inputs)
uncond_logits = outputs[0][0, -1, :]
uncond_priors = {cl: float(uncond_logits[tid]) for cl, tid in cand_tokens.items()}
print("Unconditional prior logits:", uncond_priors)

# Now test pointwise mutual information (PMI): logit - uncond_prior
preds_pmi = []
for _, row in v_memos.iterrows():
    memo = str(row['memo']).strip()
    prompt = (
        f"<|im_start|>system\n"
        f"You are NanoJev scam typology classifier. Given a Philippine bank transfer, classify the memo into exactly one typology label: "
        f"prize, investment, romance, impersonation, invoice, suspicious, none.<|im_end|>\n"
        f"<|im_start|>user\n"
        f"Memo: \"{memo}\"\n"
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
    
    # Subtract unconditional prior (Context-Free PMI / calibration)
    pmi_scores = {cl: float(logits[tid]) - uncond_priors[cl] for cl, tid in cand_tokens.items()}
    pred = max(pmi_scores, key=pmi_scores.get)
    preds_pmi.append(pred)

v_memos['pred_pmi'] = preds_pmi
pmi_macro_f1 = f1_score(v_memos['gt'], v_memos['pred_pmi'], average='macro')
print(f"PMI-Calibrated Macro-F1 on V: {pmi_macro_f1:.4f}")
print(classification_report(v_memos['gt'], v_memos['pred_pmi'], zero_division=0))
