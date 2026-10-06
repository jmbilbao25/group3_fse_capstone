import os
import sys
import numpy as np
import pandas as pd
import onnxruntime as ort
from tokenizers import Tokenizer
from sklearn.metrics import classification_report, f1_score

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

cand_tokens = {
    'prize_or_fee_scam': tok.encode(" prize").ids[0],
    'investment_scam': tok.encode(" investment").ids[0],
    'romance_scam': tok.encode(" romance").ids[0],
    'impersonation': tok.encode(" impersonation").ids[0],
    'fake_invoice_or_selling_scam': tok.encode(" invoice").ids[0],
    'other_suspicious': tok.encode(" suspicious").ids[0],
    'none': tok.encode(" none").ids[0]
}

# Few-shot prompt template
few_shot_prefix = (
    "<|im_start|>system\n"
    "You are NanoJev scam typology classifier for Philippine retail bank transfers. Classify the memo into exactly one label:\n"
    "- prize_or_fee_scam (fake prize, claiming fee, task bonus)\n"
    "- investment_scam (crypto profit, forex, guaranteed return)\n"
    "- romance_scam (online lover, emergency ticket, dating)\n"
    "- impersonation (bank official, arrest warrant, police, unfreeze fee)\n"
    "- fake_invoice_or_selling_scam (online seller, delivery fee, order)\n"
    "- other_suspicious (money mule, illegal gambling)\n"
    "- none (routine groceries, bills, rent, allowance, generic transfer)\n"
    "<|im_end|>\n"
    "<|im_start|>user\nMemo: \"SM supermarket weekly grocery\"\nTypology:<|im_end|>\n<|im_start|>assistant\n none<|im_end|>\n"
    "<|im_start|>user\nMemo: \"Urgent processing fee to release crypto profit\"\nTypology:<|im_end|>\n<|im_start|>assistant\n investment_scam<|im_end|>\n"
    "<|im_start|>user\nMemo: \"Raffle winning claiming deposit\"\nTypology:<|im_end|>\n<|im_start|>assistant\n prize_or_fee_scam<|im_end|>\n"
    "<|im_start|>user\nMemo: \"PNP arrest warrant fine settlement fee\"\nTypology:<|im_end|>\n<|im_start|>assistant\n impersonation<|im_end|>\n"
)

preds = []
for _, row in v_memos.iterrows():
    memo = str(row['memo']).strip()
    prompt = few_shot_prefix + f"<|im_start|>user\nMemo: \"{memo}\"\nTypology:<|im_end|>\n<|im_start|>assistant\n"
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

v_memos['pred_few_shot'] = preds
macro_f1 = f1_score(v_memos['gt_typology'], v_memos['pred_few_shot'], average='macro')
print(f"Few-Shot Macro-F1 on V: {macro_f1:.4f}")
print(classification_report(v_memos['gt_typology'], v_memos['pred_few_shot'], zero_division=0))
