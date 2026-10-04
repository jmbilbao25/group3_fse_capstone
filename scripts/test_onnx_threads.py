import time
import os
import onnxruntime as ort
from tokenizers import Tokenizer
import numpy as np

model_path = 'backend/risk-service/app/models/qwen/model_int8.onnx'
tok_path = 'backend/risk-service/app/models/qwen/tokenizer.json'
tok = Tokenizer.from_file(tok_path)
prompt = "<|im_start|>system\nYou are NanoJev banking risk model.<|im_end|>\n<|im_start|>user\nSpike: 1.5x | Speed: 12.0km/h | VPN: False | Memo: \"urgent processing fee\"<|im_end|>\n<|im_start|>assistant\n"
enc = tok.encode(prompt)
seq_len = len(enc.ids)

empty_pkv = np.zeros((1, 2, 0, 64), dtype=np.float32)
inputs = {}
for i in range(24):
    inputs[f'past_key_values.{i}.key'] = empty_pkv
    inputs[f'past_key_values.{i}.value'] = empty_pkv
inputs['input_ids'] = np.array([enc.ids], dtype=np.int64)
inputs['attention_mask'] = np.ones((1, seq_len), dtype=np.int64)
inputs['position_ids'] = np.arange(seq_len, dtype=np.int64).reshape(1, seq_len)

print(f"Testing ONNX thread performance on {os.cpu_count()} logical cores...")
for threads in [2, 4, 8, 12, 16]:
    opts = ort.SessionOptions()
    opts.intra_op_num_threads = threads
    opts.inter_op_num_threads = 2
    opts.execution_mode = ort.ExecutionMode.ORT_SEQUENTIAL
    opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
    opts.enable_cpu_mem_arena = True
    sess = ort.InferenceSession(model_path, sess_options=opts, providers=['CPUExecutionProvider'])
    sess.run(None, inputs) # warmup
    t0 = time.perf_counter()
    for _ in range(5):
        sess.run(None, inputs)
    lat = (time.perf_counter() - t0) / 5.0 * 1000.0
    print(f"Threads={threads}: {lat:.1f}ms")
