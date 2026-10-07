# Hybrid Risk Engine Benchmark Suite

Empirical evaluation harness, dataset generators, and statistical benchmarking suite for the two-stage retail bank transfer risk engine.

## 1. Overview and purpose

`hybrid_bench` contains the benchmarking pipelines, synthetic transaction datasets, latency profiling tools, and compliance reporting scripts used to evaluate the retail transfer risk engine.

It measures:
1. **Stage A tabular inference:** Gate 0 deterministic rules and XGBoost classification accuracy, precision, recall, and sub-30 ms latency distributions.
2. **Stage B threat synthesis:** Comparison between the legacy autoregressive engine (NanoJev) and the non-autoregressive encoder engine (Laya), measuring latency, memory utilization, throughput, and safety invariant adherence.
3. **AMLC compliance generation:** Automatic drafting of Suspicious Transaction Reports (STR/SAR) under Anti-Money Laundering Council guidelines.

## 2. Directory structure

```
hybrid_bench/
├── data/                      # Transaction datasets, typologies, and label mappings
├── results/                   # Raw evaluation metrics, calibration curves, sample sets
│   ├── two_stage_evaluation.json
│   ├── phase3_results.json ... phase7_results.json
│   └── samples_*.csv
├── reports/                   # Publication-ready reports and SAR compliance drafts
│   ├── laya_benchmark_results.json     # Laya vs NanoJev empirical benchmark data
│   ├── Risk_Engine_Benchmark_Report.xlsx
│   ├── Two_Stage_Risk_Engine_Paper_Benchmark.xlsx
│   └── sar_drafts/                     # Generated AMLC SAR draft files
├── benchmark_latency.py       # P50, P90, P99 latency measurement harness
├── evaluate.py                # Full classification evaluation pipeline
├── run_all.py                 # Master execution script for entire benchmark suite
└── test_robustness.py         # Adversarial robustness and invariant tests
```

## 3. Key findings and benchmark summary

From `hybrid_bench/reports/laya_benchmark_results.json`:

* **Inference latency:**
  * NanoJev (Qwen2.5-0.5B ONNX): P50 = 480.00 ms, P99 = 535.12 ms
  * Laya (ModernBERT / mmBERT): P50 = 0.02 ms, P99 = 0.10 ms
  * Speedup: **5,352x faster** at P99
* **Throughput:** Scaled from ~2 requests/second under NanoJev to over 10,000 requests/second under Laya on commodity hardware.
* **Synchronous memo analysis:** Laya scores Philippine scam vernacular, task scams, and emergency impersonation in real time (< 0.1 ms), allowing synchronous memo evaluation before transaction authorization.
* **Safety invariant:** 100% pass rate on the Escalate-Only invariant across all evaluated transaction samples.

## 4. Running the benchmarks

Activate the Python virtual environment:

```powershell
.\.venv\Scripts\Activate.ps1
```

Run latency profiling:
```bash
python hybrid_bench/benchmark_latency.py
```

Run full evaluation suite:
```bash
python hybrid_bench/run_all.py
```

Run robustness and invariant verification tests:
```bash
pytest hybrid_bench/test_robustness.py -v
```

Generate paper benchmark Excel workbook:
```bash
python hybrid_bench/reports/generate_paper_benchmark_excel.py
```
