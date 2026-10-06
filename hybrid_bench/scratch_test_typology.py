import onnxruntime as ort
from tokenizers import Tokenizer
import numpy as np

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

test_memos = [
    ('Claim fee for PCSO grand lotto winner promo', 'prize_or_fee_scam'),
    ('Deposit advance fee to claim grand prize promo winning', 'prize_or_fee_scam'),
    ('Urgent processing fee to release cryptocurrency trading profit', 'investment_scam'),
    ('Locked capital deposit for guaranteed 40% monthly return', 'investment_scam'),
    ('VIP dating romance partner emergency luggage release transit fee', 'romance_scam'),
    ('BDO account reactivation fee to release locked incoming remittance', 'impersonation'),
    ('Government e-Gov portal penalty compromise fee to lift arrest warrant', 'impersonation'),
    ('TikTok live selling unboxing gift refund release insurance', 'fake_invoice_or_selling_scam'),
    ('Paki cash out agad at ipadala ang 80 percent via Palawan Express', 'other_suspicious'),
    ('SM Supermarket grocery haul', 'none'),
    ('Meralco bill for October 2026', 'none')
]

token_map = {
    'prize_or_fee_scam': tok.encode(" prize").ids[0],
    'investment_scam': tok.encode(" investment").ids[0],
    'romance_scam': tok.encode(" romance").ids[0],
    'impersonation': tok.encode(" impersonation").ids[0],
    'fake_invoice_or_selling_scam': tok.encode(" invoice").ids[0],
    'other_suspicious': tok.encode(" suspicious").ids[0],
    'none': tok.encode(" none").ids[0]
}

print("Tokens used:", token_map)

for memo, expected in test_memos:
    prompt = (
        f"<|im_start|>system\n"
        f"You are NanoJev scam typology classifier. Given a Philippine bank transfer, classify the memo into exactly one typology label:\n"
        f"prize, investment, romance, impersonation, invoice, suspicious, or none.<|im_end|>\n"
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
    
    scores = {typ: float(logits[tid]) for typ, tid in token_map.items()}
    pred = max(scores, key=scores.get)
    print(f"Memo: {memo[:40]:<40} Expected: {expected:<28} Predicted: {pred:<28} Match: {pred == expected}")
