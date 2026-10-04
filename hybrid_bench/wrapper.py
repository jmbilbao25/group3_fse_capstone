"""
NanoJev Raw Logits Wrapper:
Provides zero-shot inference directly from Qwen2.5-0.5B ONNX
without applying telemetry heuristic priors or regex overrides.
Caches predictions by SHA256(model_hash + prompt).
"""

import os
import sys
import time
import hashlib
import json
import numpy as np
from typing import Dict, Any, Optional, Tuple

try:
    import onnxruntime as ort
    from tokenizers import Tokenizer
    ONNX_AVAILABLE = True
except ImportError:
    ONNX_AVAILABLE = False


class NanoJevRawWrapper:
    """
    Thin, clean wrapper around Qwen2.5-0.5B ONNX.
    Extracts raw pre-prior logits for ALLOW, REQUIRE_2FA, and BLOCK tokens.
    """

    def __init__(self, model_path: Optional[str] = None, tokenizer_path: Optional[str] = None, cache_dir: Optional[str] = None, intra_op_threads: int = 8):
        self.model_loaded = False
        self.session = None
        self.tokenizer = None
        self.static_pkv: Dict[str, np.ndarray] = {}
        self.tok_allow_ids = []
        self.tok_block_ids = []
        self.tok_req_ids = []
        self.model_hash = ""
        self.intra_op_threads = intra_op_threads

        # Default paths
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        default_model_dir = os.path.join(base_dir, "backend", "risk-service", "app", "models", "qwen")
        self.model_path = model_path or os.path.join(default_model_dir, "model_int8.onnx")
        self.tokenizer_path = tokenizer_path or os.path.join(default_model_dir, "tokenizer.json")
        self.cache_dir = cache_dir or os.path.join(os.path.dirname(os.path.abspath(__file__)), "cache")
        os.makedirs(self.cache_dir, exist_ok=True)

        # Temperature scaling calibration parameters (tuned on V)
        self.temperature: float = 1.0

        if ONNX_AVAILABLE and os.path.isfile(self.model_path) and os.path.isfile(self.tokenizer_path):
            self._load_model()

    def _load_model(self):
        try:
            # Model hash for cache validation (sample first 1MB for speed)
            h = hashlib.sha256()
            with open(self.model_path, "rb") as f:
                h.update(f.read(1024 * 1024))
            self.model_hash = h.hexdigest()[:16]

            self.tokenizer = Tokenizer.from_file(self.tokenizer_path)
            self.tok_allow_ids = [self.tokenizer.encode(" ALLOW").ids[0], self.tokenizer.encode("ALLOW").ids[0]]
            self.tok_block_ids = [self.tokenizer.encode(" BLOCK").ids[0], self.tokenizer.encode("BLOCK").ids[0]]
            self.tok_req_ids = [self.tokenizer.encode(" REQUIRE").ids[0], self.tokenizer.encode("REQUIRE").ids[0]]

            # Allocate static past_key_values (empty for single forward pass)
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

            # Pre-warm
            self._warmup()
        except Exception as e:
            print(f"[NanoJevRawWrapper] Load error: {e}", file=sys.stderr)
            self.model_loaded = False

    def _warmup(self):
        dummy_prompt = "<|im_start|>system\nYou are NanoJev.<|im_end|>\n<|im_start|>user\nWarmup\nVerdict:<|im_end|>\n<|im_start|>assistant\n"
        enc = self.tokenizer.encode(dummy_prompt)
        seq_len = len(enc.ids)
        inputs = dict(self.static_pkv)
        inputs['input_ids'] = np.array([enc.ids], dtype=np.int64)
        inputs['attention_mask'] = np.ones((1, seq_len), dtype=np.int64)
        inputs['position_ids'] = np.arange(seq_len, dtype=np.int64).reshape(1, seq_len)
        self.session.run(None, inputs)

    def build_prompt(self, spike_ratio: float, velocity_kmh: float, is_vpn: bool, memo: str) -> str:
        """Constructs prompt matching the production NanoJevEngine template."""
        return (
            f"<|im_start|>system\n"
            f"You are NanoJev banking risk model. Classify verdict: ALLOW, REQUIRE_2FA, or BLOCK.<|im_end|>\n"
            f"<|im_start|>user\n"
            f"Spike: {spike_ratio:.1f}x | Speed: {velocity_kmh:.1f}km/h | VPN: {is_vpn} | Memo: \"{memo}\"\n"
            f"Verdict:<|im_end|>\n"
            f"<|im_start|>assistant\n"
        )

    def predict_raw_logits(
        self,
        spike_ratio: float = 1.0,
        velocity_kmh: float = 0.0,
        is_vpn: bool = False,
        memo: str = "",
        use_cache: bool = True
    ) -> Dict[str, Any]:
        """
        Runs neural forward pass and extracts raw unadulterated logits.
        Returns:
            {
                "logits": {"ALLOW": float, "REQUIRE_2FA": float, "BLOCK": float},
                "raw_probs": {"ALLOW": float, "REQUIRE_2FA": float, "BLOCK": float},
                "calibrated_probs": {"ALLOW": float, "REQUIRE_2FA": float, "BLOCK": float},
                "choice": str ("ALLOW" | "REQUIRE_2FA" | "BLOCK"),
                "latency_ms": float,
                "cached": bool
            }
        """
        prompt = self.build_prompt(spike_ratio, velocity_kmh, is_vpn, memo)
        prompt_hash = hashlib.sha256((self.model_hash + ":" + prompt).encode("utf-8")).hexdigest()
        cache_file = os.path.join(self.cache_dir, f"{prompt_hash}.json")

        if use_cache and os.path.isfile(cache_file):
            try:
                with open(cache_file, "r", encoding="utf-8") as f:
                    cached_data = json.load(f)
                cached_data["cached"] = True
                # Re-apply current temperature to cached logits
                logits = cached_data["logits"]
                calibrated = self._softmax_temperature(logits, self.temperature)
                cached_data["calibrated_probs"] = calibrated
                return cached_data
            except Exception:
                pass

        if not self.model_loaded:
            raise RuntimeError("NanoJevRawWrapper model is not loaded.")

        t0 = time.perf_counter()
        enc = self.tokenizer.encode(prompt)
        seq_len = len(enc.ids)

        inputs = dict(self.static_pkv)
        inputs['input_ids'] = np.array([enc.ids], dtype=np.int64)
        inputs['attention_mask'] = np.ones((1, seq_len), dtype=np.int64)
        inputs['position_ids'] = np.arange(seq_len, dtype=np.int64).reshape(1, seq_len)

        outputs = self.session.run(None, inputs)
        logits_tensor = outputs[0][0, -1, :]
        latency_ms = (time.perf_counter() - t0) * 1000.0

        allow_logit = float(max(logits_tensor[self.tok_allow_ids[0]], logits_tensor[self.tok_allow_ids[1]]))
        block_logit = float(max(logits_tensor[self.tok_block_ids[0]], logits_tensor[self.tok_block_ids[1]]))
        req_logit = float(max(logits_tensor[self.tok_req_ids[0]], logits_tensor[self.tok_req_ids[1]]))

        raw_logits = {
            "ALLOW": round(allow_logit, 4),
            "REQUIRE_2FA": round(req_logit, 4),
            "BLOCK": round(block_logit, 4)
        }

        raw_probs = self._softmax_temperature(raw_logits, 1.0)
        calibrated_probs = self._softmax_temperature(raw_logits, self.temperature)

        # Zero-shot choice (argmax on raw logits)
        choice = max(raw_logits.items(), key=lambda kv: kv[1])[0]

        result = {
            "logits": raw_logits,
            "raw_probs": raw_probs,
            "calibrated_probs": calibrated_probs,
            "choice": choice,
            "latency_ms": round(latency_ms, 2),
            "cached": False
        }

        if use_cache:
            try:
                with open(cache_file, "w", encoding="utf-8") as f:
                    json.dump(result, f)
            except Exception:
                pass

        return result

    @staticmethod
    def _softmax_temperature(logits: Dict[str, float], temp: float = 1.0) -> Dict[str, float]:
        temp = max(temp, 0.01)
        keys = ["ALLOW", "REQUIRE_2FA", "BLOCK"]
        vals = np.array([logits[k] / temp for k in keys], dtype=np.float64)
        exp_vals = np.exp(vals - np.max(vals))
        probs = exp_vals / np.sum(exp_vals)
        return {k: round(float(p), 4) for k, p in zip(keys, probs)}
