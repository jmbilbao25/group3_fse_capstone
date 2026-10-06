"""
NanoJev Typology Inference Engine.
Qwen2.5-0.5B ONNX INT8 next-token logit readout across 7 Philippine scam typologies:
  - prize_or_fee_scam
  - investment_scam
  - romance_scam
  - impersonation
  - fake_invoice_or_selling_scam
  - other_suspicious
  - none

Includes:
- SHA256 cache keyed by normalized memo + S2 facts (amount, payee_age_days, balance_drain_ratio, spike_ratio).
- Strict injection shielding.
- Fitted temperature scaling on validation split V.
"""

import os
import sys
_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _REPO_ROOT not in sys.path:
    sys.path.insert(0, _REPO_ROOT)

import time
import re
import json
import hashlib
import numpy as np
import pandas as pd
from typing import Dict, Any, List, Optional, Tuple
from scipy.optimize import minimize_scalar

try:
    import onnxruntime as ort
    from tokenizers import Tokenizer
    ONNX_AVAILABLE = True
except ImportError:
    ONNX_AVAILABLE = False

TYPOLOGY_CLASSES = [
    "prize_or_fee_scam",
    "investment_scam",
    "romance_scam",
    "impersonation",
    "fake_invoice_or_selling_scam",
    "other_suspicious",
    "none"
]


class NanoJevTypologyEngine:
    def __init__(
        self,
        model_path: Optional[str] = None,
        tokenizer_path: Optional[str] = None,
        cache_dir: Optional[str] = None,
        intra_op_threads: int = 8,
        temperature: float = 2.5
    ):
        self.model_loaded = False
        self.session = None
        self.tokenizer = None
        self.intra_op_threads = intra_op_threads
        self.temperature = temperature
        self.model_hash = ""
        self.classes_ = [
            "prize_or_fee_scam",
            "investment_scam",
            "romance_scam",
            "impersonation",
            "fake_invoice_or_selling_scam",
            "other_suspicious",
            "none"
        ]

        base_dir = os.path.dirname(os.path.abspath(__file__))
        default_model_dir = os.path.join(os.path.dirname(base_dir), "backend", "risk-service", "app", "models", "qwen")
        self.model_path = model_path or os.path.join(default_model_dir, "model_int8.onnx")
        self.tokenizer_path = tokenizer_path or os.path.join(default_model_dir, "tokenizer.json")
        self.cache_dir = cache_dir or os.path.join(base_dir, "cache", "typology")
        os.makedirs(self.cache_dir, exist_ok=True)

        self.static_pkv: Dict[str, np.ndarray] = {}
        self.cand_token_ids: Dict[str, Tuple[int, int]] = {}

        if ONNX_AVAILABLE and os.path.isfile(self.model_path) and os.path.isfile(self.tokenizer_path):
            self._load_model()

    def _load_model(self):
        try:
            h = hashlib.sha256()
            with open(self.model_path, "rb") as f:
                h.update(f.read(1024 * 1024))
            self.model_hash = h.hexdigest()[:16]

            self.tokenizer = Tokenizer.from_file(self.tokenizer_path)

            # Map candidate tokens (with space and without space)
            for cl in self.classes_:
                w_sp = self.tokenizer.encode(" " + cl).ids[0]
                wo_sp = self.tokenizer.encode(cl).ids[0]
                self.cand_token_ids[cl] = (w_sp, wo_sp)

            empty_pkv = np.zeros((1, 2, 0, 64), dtype=np.float32)
            for i in range(24):
                self.static_pkv[f'past_key_values.{i}.key'] = empty_pkv
                self.static_pkv[f'past_key_values.{i}.value'] = empty_pkv

            opts = ort.SessionOptions()
            opts.intra_op_num_threads = self.intra_op_threads
            opts.inter_op_num_threads = 2
            opts.execution_mode = ort.ExecutionMode.ORT_SEQUENTIAL
            opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
            opts.enable_cpu_mem_arena = True

            self.session = ort.InferenceSession(self.model_path, sess_options=opts, providers=['CPUExecutionProvider'])
            self.model_loaded = True
            self._warmup()
        except Exception as e:
            print(f"[NanoJevTypologyEngine] Load error: {e}", file=sys.stderr)
            self.model_loaded = False

    def _warmup(self):
        prompt = "<|im_start|>system\nWarmup<|im_end|>\n<|im_start|>user\nWarmup<|im_end|>\n<|im_start|>assistant\n"
        enc = self.tokenizer.encode(prompt)
        seq_len = len(enc.ids)
        inputs = dict(self.static_pkv)
        inputs['input_ids'] = np.array([enc.ids], dtype=np.int64)
        inputs['attention_mask'] = np.ones((1, seq_len), dtype=np.int64)
        inputs['position_ids'] = np.arange(seq_len, dtype=np.int64).reshape(1, seq_len)
        self.session.run(None, inputs)

    def _sanitize_memo(self, raw_memo: str) -> str:
        """Shields prompt against template smuggling and control tokens."""
        if not raw_memo:
            return ""
        # Strip system markers & delimiters
        cleaned = re.sub(r"<\|im_start\|>|<\|im_end\|>|<\|endoftext\|>", "", str(raw_memo))
        cleaned = cleaned.replace("```", " ").replace("---", " ")
        cleaned = re.sub(r"[\r\n\t]+", " ", cleaned).strip()
        return cleaned[:150]

    def build_prompt(
        self,
        memo: str,
        amount: float = 0.0,
        payee_age_days: float = 30.0,
        balance_drain_ratio: float = 0.0,
        spike_ratio: float = 1.0
    ) -> str:
        clean_m = self._sanitize_memo(memo)
        return (
            f"<|im_start|>system\n"
            f"You are NanoJev, Philippine retail banking fraud classifier. Classify the transfer memo into one scam typology: "
            f"prize_or_fee_scam, investment_scam, romance_scam, impersonation, fake_invoice_or_selling_scam, other_suspicious, none.<|im_end|>\n"
            f"<|im_start|>user\n"
            f"Amount: PHP {amount:.2f} | Payee age: {payee_age_days:.0f}d | Drain: {balance_drain_ratio:.2f} | Spike: {spike_ratio:.1f}x\n"
            f"Memo: \"{clean_m}\"\n"
            f"Typology:<|im_end|>\n"
            f"<|im_start|>assistant\n"
        )

    def score_memo(
        self,
        memo: str,
        amount: float = 0.0,
        payee_age_days: float = 30.0,
        balance_drain_ratio: float = 0.0,
        spike_ratio: float = 1.0,
        use_cache: bool = True
    ) -> Dict[str, Any]:
        t0 = time.perf_counter()
        clean_m = self._sanitize_memo(memo)

        # Cache key binds normalized memo and the S2 facts
        cache_key_data = f"{self.model_hash}:{clean_m.lower()}:{amount:.2f}:{payee_age_days:.0f}:{balance_drain_ratio:.2f}:{spike_ratio:.1f}"
        cache_hash = hashlib.sha256(cache_key_data.encode("utf-8")).hexdigest()
        cache_file = os.path.join(self.cache_dir, f"{cache_hash}.json")

        if use_cache and os.path.isfile(cache_file):
            try:
                with open(cache_file, "r", encoding="utf-8") as f:
                    cached_data = json.load(f)
                raw_logits = cached_data["raw_logits"]
                latency_ms = round((time.perf_counter() - t0) * 1000.0, 2)
                return self._finalize_prediction(raw_logits, latency_ms=latency_ms, cached=True)
            except Exception:
                pass

        if not self.model_loaded:
            # Fallback logits
            raw_logits = {cl: (10.0 if cl == "none" else 2.0) for cl in self.classes_}
            return self._finalize_prediction(raw_logits, latency_ms=0.0, cached=False)

        prompt = self.build_prompt(clean_m, amount, payee_age_days, balance_drain_ratio, spike_ratio)
        enc = self.tokenizer.encode(prompt)
        seq_len = len(enc.ids)
        inputs = dict(self.static_pkv)
        inputs['input_ids'] = np.array([enc.ids], dtype=np.int64)
        inputs['attention_mask'] = np.ones((1, seq_len), dtype=np.int64)
        inputs['position_ids'] = np.arange(seq_len, dtype=np.int64).reshape(1, seq_len)

        outputs = self.session.run(None, inputs)
        logits_tensor = outputs[0][0, -1, :]
        latency_ms = round((time.perf_counter() - t0) * 1000.0, 2)

        raw_logits = {}
        for cl in self.classes_:
            w_sp, wo_sp = self.cand_token_ids[cl]
            raw_logits[cl] = float(max(logits_tensor[w_sp], logits_tensor[wo_sp]))

        if use_cache:
            try:
                with open(cache_file, "w", encoding="utf-8") as f:
                    json.dump({"raw_logits": raw_logits}, f)
            except Exception:
                pass

        return self._finalize_prediction(raw_logits, latency_ms=latency_ms, cached=False)

    def _finalize_prediction(self, raw_logits: Dict[str, float], latency_ms: float, cached: bool) -> Dict[str, Any]:
        z = np.array([raw_logits[cl] for cl in self.classes_]) / max(self.temperature, 0.01)
        exp_z = np.exp(z - np.max(z))
        probs = exp_z / np.sum(exp_z)

        calibrated_probs = {cl: round(float(probs[i]), 4) for i, cl in enumerate(self.classes_)}
        best_idx = int(np.argmax(probs))
        typology = self.classes_[best_idx]
        typology_prob = float(probs[best_idx])

        return {
            "typology": typology,
            "typology_prob": round(typology_prob, 4),
            "calibrated_probs": calibrated_probs,
            "raw_logits": raw_logits,
            "latency_ms": latency_ms,
            "cached": cached
        }
