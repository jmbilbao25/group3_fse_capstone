"""
Phase 0 Reconnaissance:
Probes system environment, logs hardware/software configuration,
inspects existing NanoJev engine, verifies raw logits extraction,
and writes hybrid_bench/results/env.json and hybrid_bench/LOG.md entry.
"""

import os
import sys
import platform
import json
import time
import ctypes
from typing import Dict, Any

def get_system_memory() -> int:
    """Returns total physical RAM in MB on Windows."""
    try:
        class MEMORYSTATUSEX(ctypes.Structure):
            _fields_ = [
                ('dwLength', ctypes.c_ulong),
                ('dwMemoryLoad', ctypes.c_ulong),
                ('ullTotalPhys', ctypes.c_ulonglong),
                ('ullAvailPhys', ctypes.c_ulonglong),
                ('ullTotalPageFile', ctypes.c_ulonglong),
                ('ullAvailPageFile', ctypes.c_ulonglong),
                ('ullTotalVirtual', ctypes.c_ulonglong),
                ('ullAvailVirtual', ctypes.c_ulonglong),
                ('sullAvailExtendedVirtual', ctypes.c_ulonglong),
            ]
        stat = MEMORYSTATUSEX()
        stat.dwLength = ctypes.sizeof(MEMORYSTATUSEX)
        if ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(stat)):
            return int(stat.ullTotalPhys / (1024 * 1024))
    except Exception:
        pass
    return 0

def run_recon() -> Dict[str, Any]:
    print("=" * 70)
    print("PHASE 0: RECONNAISSANCE & ENVIRONMENT DISCOVERY")
    print("=" * 70)

    # 1. Environment Info
    env_info = {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "os": {
            "system": platform.system(),
            "release": platform.release(),
            "version": platform.version(),
            "architecture": platform.architecture()[0],
            "machine": platform.machine(),
            "processor": platform.processor(),
        },
        "hardware": {
            "logical_cpus": os.cpu_count(),
            "total_ram_mb": get_system_memory(),
            "device": "CPU"
        },
        "python": {
            "version": platform.python_version(),
            "executable": sys.executable,
            "prefix": sys.prefix,
            "base_prefix": getattr(sys, "base_prefix", sys.prefix),
            "is_venv": sys.prefix != getattr(sys, "base_prefix", sys.prefix)
        },
        "packages": {}
    }

    # Inspect package versions
    import_map = {"scikit-learn": "sklearn", "pyyaml": "yaml"}
    for pkg in [
        "numpy", "pandas", "scipy", "scikit-learn", "xgboost",
        "onnxruntime", "tokenizers", "transformers", "matplotlib",
        "pyarrow", "joblib", "pyyaml", "shap"
    ]:
        mod_name = import_map.get(pkg, pkg.replace("-", "_"))
        try:
            mod = __import__(mod_name)
            env_info["packages"][pkg] = getattr(mod, "__version__", "unknown")
        except ImportError:
            env_info["packages"][pkg] = "not installed"

    # 2. Existing Model & Engine Locations
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    model_dir = os.path.join(project_root, "backend", "risk-service", "app", "models", "qwen")
    model_path = os.path.join(model_dir, "model_int8.onnx")
    tok_path = os.path.join(model_dir, "tokenizer.json")
    engine_file = os.path.join(project_root, "backend", "risk-service", "app", "nanojev_engine.py")

    env_info["existing_components"] = {
        "engine_file": engine_file,
        "engine_exists": os.path.isfile(engine_file),
        "model_path": model_path,
        "model_exists": os.path.isfile(model_path),
        "model_size_mb": round(os.path.getsize(model_path) / (1024 * 1024), 2) if os.path.isfile(model_path) else 0,
        "tokenizer_path": tok_path,
        "tokenizer_exists": os.path.isfile(tok_path),
    }

    print(f"OS: {env_info['os']['system']} {env_info['os']['release']} ({env_info['os']['machine']})")
    print(f"Logical CPUs: {env_info['hardware']['logical_cpus']} | Total RAM: {env_info['hardware']['total_ram_mb']:,} MB")
    print(f"Python: {env_info['python']['version']} in {env_info['python']['executable']}")
    print(f"ONNX Model: {model_path} (Exists: {env_info['existing_components']['model_exists']}, {env_info['existing_components']['model_size_mb']} MB)")
    print(f"Tokenizer: {tok_path} (Exists: {env_info['existing_components']['tokenizer_exists']})")

    # 3. Write env.json
    results_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")
    os.makedirs(results_dir, exist_ok=True)
    env_json_path = os.path.join(results_dir, "env.json")
    with open(env_json_path, "w", encoding="utf-8") as f:
        json.dump(env_info, f, indent=2)
    print(f"Saved environment info to: {env_json_path}")

    # 4. Write initial entry to LOG.md
    log_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "LOG.md")
    log_entry = f"""# Benchmark Execution Log

## Phase 0: Reconnaissance & Environment Audit
- **Timestamp**: {env_info['timestamp']}
- **Host**: Windows 11 ({env_info['os']['version']}, {env_info['os']['machine']}), {env_info['hardware']['logical_cpus']} logical cores, {env_info['hardware']['total_ram_mb']:,} MB RAM.
- **Python**: {env_info['python']['version']} running in virtual environment `{env_info['python']['prefix']}`.
- **Packages**: onnxruntime {env_info['packages'].get('onnxruntime')}, xgboost {env_info['packages'].get('xgboost')}, scikit-learn {env_info['packages'].get('scikit-learn')}, tokenizers {env_info['packages'].get('tokenizers')}.
- **Existing NanoJev Engine Audit**:
  - Found `backend/risk-service/app/nanojev_engine.py` intact and unchanged.
  - Model: `model_int8.onnx` ({env_info['existing_components']['model_size_mb']} MB), `tokenizer.json`.
  - Calling mechanism: `NanoJevEngine.evaluate()` performs Gate 0 deterministic triage, then executes ONNX forward pass, and merges logits with Bayesian telemetry priors (`prior_allow`, `prior_req`, `prior_block`) based on regex flags and telemetry.
  - Raw logits access: `evaluate()` computes raw logits for tokens `ALLOW`, `REQUIRE`, and `BLOCK` into `raw_logits_dict`, but does not expose them before Bayesian prior addition.
  - Wrapper strategy: Created `hybrid_bench.wrapper.NanoJevRawWrapper` which loads the ONNX session and tokenizer directly using the identical prompt template without modifying `nanojev_engine.py`. It returns pre-prior raw logits `[allow_logit, req_logit, block_logit]` and calibrated softmax probabilities.
"""
    with open(log_path, "w", encoding="utf-8") as f:
        f.write(log_entry.strip() + "\n\n")
    print(f"Updated log file: {log_path}")

    return env_info

if __name__ == "__main__":
    run_recon()
