"""
Main Orchestration Script for hybrid_bench:
Executes the full benchmark pipeline end-to-end:
  - Phase 0: Reconnaissance (environment & engine inspection)
  - Phase 2: Data Generation (disjoint user splits T, V, C1, C2, C3, C4)
  - Phase 3: Gate 0 + XGBoost Training, TF-IDF baseline, and feature ablations
  - Phase 4: NanoJev Zero-Shot Calibration and Escalate-Only Threshold Tuning
  - Phase 5: Multi-System Evaluation, Cluster Bootstrapping, and Hypotheses
  - Phase 6: Latency and Throughput Benchmarking
  - Phase 7: Adversarial Robustness and Metamorphic Testing
  - Phase 8: Comprehensive Markdown Report Generation (REPORT.md)

Usage:
    py -m hybrid_bench.run_all --profile quick
    py -m hybrid_bench.run_all --profile full
    py -m hybrid_bench.run_all --phase 8
"""

import sys
import argparse
import time

from hybrid_bench.recon import run_recon
from hybrid_bench.data.generate import generate_splits
from hybrid_bench.train_xgb import run_phase3
from hybrid_bench.calibrate_jev import run_phase4
from hybrid_bench.evaluate import run_phase5
from hybrid_bench.benchmark_latency import run_phase6
from hybrid_bench.test_robustness import run_phase7
from hybrid_bench.reports.generate_report import generate_report

def main():
    parser = argparse.ArgumentParser(description="Run hybrid risk engine benchmark pipeline.")
    parser.add_argument("--profile", choices=["quick", "full"], default="quick", help="Execution profile (quick or full)")
    parser.add_argument("--phase", type=str, default="all", help="Specific phase to run (0, 2, 3, 4, 5, 6, 7, 8, or all)")
    args = parser.parse_args()

    start_time = time.time()
    print("=" * 75)
    print(f"HYBRID RISK ENGINE BENCHMARK ORCHESTRATOR [profile='{args.profile}', phase='{args.phase}']")
    print("=" * 75)

    if args.phase in ["all", "0"]:
        print("\n>>> [1/8] Executing Phase 0: Reconnaissance...")
        run_recon()

    if args.phase in ["all", "2"]:
        print(f"\n>>> [2/8] Executing Phase 2: Data Generation (profile={args.profile})...")
        generate_splits(profile=args.profile)

    if args.phase in ["all", "3"]:
        print("\n>>> [3/8] Executing Phase 3: XGBoost Training & Feature Ablations...")
        run_phase3()

    if args.phase in ["all", "4"]:
        print("\n>>> [4/8] Executing Phase 4: NanoJev Zero-Shot Calibration & Tuning...")
        run_phase4()

    if args.phase in ["all", "5"]:
        boot_reps = 100 if args.profile == "quick" else 1000
        print(f"\n>>> [5/8] Executing Phase 5: Multi-System Evaluation ({boot_reps} bootstrap resamples)...")
        run_phase5(bootstrap_reps=boot_reps)

    if args.phase in ["all", "6"]:
        print("\n>>> [6/8] Executing Phase 6: Latency & Throughput Benchmarking...")
        run_phase6()

    if args.phase in ["all", "7"]:
        print("\n>>> [7/8] Executing Phase 7: Adversarial Robustness & Prompt Injection...")
        run_phase7()

    if args.phase in ["all", "8"]:
        print("\n>>> [8/8] Executing Phase 8: Programmatic Report Compilation...")
        report_path = generate_report()
        print(f"Markdown report compiled successfully at: {report_path}")
        from hybrid_bench.reports.generate_excel_report import build_excel_report
        excel_path = build_excel_report()
        print(f"Excel report compiled successfully at: {excel_path}")

    elapsed = time.time() - start_time
    print("\n" + "=" * 75)
    print(f"BENCHMARK PIPELINE COMPLETED IN {elapsed:.2f} SECONDS")
    print("=" * 75)

if __name__ == "__main__":
    main()
