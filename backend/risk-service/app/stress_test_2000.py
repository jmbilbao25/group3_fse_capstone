"""
2,000 Transaction High-Throughput Stress Test Suite for Cascading Two-Gate Risk Engine.
Simulates a real-world banking traffic distribution across 2,000 transactions:
- 85% (1,700 tx): Routine everyday payments (groceries, lunch, rent, utility bills)
- 5%  (100 tx): Blatant impossible travel velocity fraud
- 10% (200 tx): Ambiguous edge cases, scam memos, amount spikes, and VPN discrepancies

Measures:
- Total execution time and overall Throughput (TPS)
- Gate 0 (Fast-Path) vs Gate 1 (Neural Qwen) resolution distribution
- Latency percentiles (min, avg, p50, p90, p95, p99, max) for Gate 0 vs Gate 1
- Decision breakdown (ALLOW, REQUIRE_2FA, BLOCK)
- Error rate (HTTP 200 vs exceptions)
"""

import time
import json
import random
import statistics
import concurrent.futures
from urllib import request
from typing import Dict, List, Any

# Customer profiles
CUSTOMERS = [
    {"user_id": "usr-1001-cst-001", "account_id": "acc-2001-sav-001", "home_lat": 14.5547, "home_lon": 121.0200, "avg": 2500.0},
    {"user_id": "usr-1002-cst-002", "account_id": "acc-2002-chk-001", "home_lat": 14.6760, "home_lon": 121.0437, "avg": 4000.0},
    {"user_id": "usr-1003-cst-003", "account_id": "acc-2003-sav-002", "home_lat": 10.3157, "home_lon": 123.8854, "avg": 15000.0},
    {"user_id": "usr-1004-cst-004", "account_id": "acc-2004-chk-002", "home_lat": 14.5869, "home_lon": 121.0614, "avg": 2000.0},
]

ROUTINE_MEMOS = [
    "supermarket groceries", "lunch with colleagues", "monthly rent payment",
    "meralco electric bill", "maynilad water payment", "pharmacy vitamins",
    "coffee and pastry", "allowance transfer", "grab car ride payment",
    "dinner delivery", "school supplies", "pet food purchase"
]

SCAM_MEMOS = [
    "urgent processing fee to release cryptocurrency trading profit",
    "deposit advance fee to claim grand prize promo winning",
    "locked capital deposit for guaranteed 40% monthly return",
    "urgent unlock fee for frozen international wallet account",
    "urgent customs clearance fee for parcel package release",
    "temporary holding transfer for mule redirection"
]

FOREIGN_CITIES = [
    {"name": "Singapore", "lat": 1.3521, "lon": 103.8198},
    {"name": "Tokyo", "lat": 35.6762, "lon": 139.6503},
    {"name": "Frankfurt", "lat": 50.1109, "lon": 8.6821},
    {"name": "Sydney", "lat": -33.8688, "lon": 151.2093}
]

def generate_payload(idx: int) -> Dict[str, Any]:
    cust = random.choice(CUSTOMERS)
    rand_val = random.random()

    # 85% Routine Legitimate
    if rand_val < 0.85:
        # Small distance from home (0 to 2 km)
        lat_offset = random.uniform(-0.015, 0.015)
        lon_offset = random.uniform(-0.015, 0.015)
        amount = round(random.uniform(100.0, cust["avg"] * 0.95), 2)
        memo = random.choice(ROUTINE_MEMOS)
        return {
            "transaction_id": f"TX-2K-{idx:05d}",
            "user_id": cust["user_id"],
            "account_id": cust["account_id"],
            "amount": amount,
            "memo": memo,
            "latitude": cust["home_lat"] + lat_offset,
            "longitude": cust["home_lon"] + lon_offset,
            "category": "ROUTINE"
        }

    # 5% Blatant Impossible Travel Velocity
    elif rand_val < 0.90:
        city = random.choice(FOREIGN_CITIES)
        amount = round(random.uniform(5000.0, 30000.0), 2)
        return {
            "transaction_id": f"TX-2K-{idx:05d}",
            "user_id": cust["user_id"],
            "account_id": cust["account_id"],
            "amount": amount,
            "memo": "funds transfer",
            "latitude": city["lat"],
            "longitude": city["lon"],
            "category": "IMPOSSIBLE_TRAVEL"
        }

    # 10% Ambiguous Edge Cases (Scams, amount spikes, VPN)
    else:
        is_scam_memo = random.random() < 0.60
        memo = random.choice(SCAM_MEMOS) if is_scam_memo else "consulting invoice payment"
        amount = round(cust["avg"] * random.uniform(3.5, 9.0), 2)
        is_vpn = random.random() < 0.40
        payload = {
            "transaction_id": f"TX-2K-{idx:05d}",
            "user_id": cust["user_id"],
            "account_id": cust["account_id"],
            "amount": amount,
            "memo": memo,
            "latitude": cust["home_lat"] + random.uniform(-0.05, 0.05),
            "longitude": cust["home_lon"] + random.uniform(-0.05, 0.05),
            "category": "AMBIGUOUS_OR_SCAM"
        }
        if is_vpn:
            payload["ip_latitude"] = 52.3676
            payload["ip_longitude"] = 4.9041
        return payload


def send_single_transaction(payload: Dict[str, Any], url: str = "http://127.0.0.1:8084/api/v1/risk/analyze") -> Dict[str, Any]:
    tx_cat = payload.pop("category")
    data = json.dumps(payload).encode("utf-8")
    req = request.Request(url, data=data, headers={"Content-Type": "application/json"}, method="POST")

    t0 = time.perf_counter()
    try:
        with request.urlopen(req, timeout=15.0) as resp:
            elapsed_ms = (time.perf_counter() - t0) * 1000.0
            body = json.loads(resp.read().decode("utf-8"))
            return {
                "id": payload["transaction_id"],
                "category": tx_cat,
                "status_code": resp.status,
                "elapsed_ms": elapsed_ms,
                "decision": body.get("decision"),
                "gate_used": body.get("gate_used", "UNKNOWN"),
                "fraud_score": body.get("fraud_score"),
                "neural_latency_ms": body.get("neural_metadata", {}).get("neural_latency_ms", 0.0),
                "error": None
            }
    except Exception as e:
        elapsed_ms = (time.perf_counter() - t0) * 1000.0
        return {
            "id": payload["transaction_id"],
            "category": tx_cat,
            "status_code": 500,
            "elapsed_ms": elapsed_ms,
            "decision": None,
            "gate_used": "ERROR",
            "fraud_score": None,
            "neural_latency_ms": 0.0,
            "error": str(e)
        }


def run_2000_benchmark(total_tx: int = 2000, concurrency: int = 12):
    print("=" * 80)
    print(f"HIGH-VOLUME BENCHMARK: Executing {total_tx:,} Transactions at Concurrency={concurrency}")
    print("Evaluating Cascading Two-Gate (Gate 0 Fast Path + Gate 1 Neural Qwen)")
    print("=" * 80)

    print("\n[1/3] Generating 2,000 realistic banking transactions...")
    payloads = [generate_payload(i) for i in range(1, total_tx + 1)]
    
    # Pre-warm connection
    warm_res = send_single_transaction(dict(payloads[0]))
    print(f"Warmup ping: {warm_res['elapsed_ms']:.1f}ms (Gate: {warm_res['gate_used']})")

    print(f"\n[2/3] Dispatching {total_tx:,} transactions through ThreadPoolExecutor...")
    t_start = time.perf_counter()
    results = []

    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [executor.submit(send_single_transaction, p) for p in payloads]
        for idx, f in enumerate(concurrent.futures.as_completed(futures), 1):
            results.append(f.result())
            if idx % 500 == 0 or idx == total_tx:
                curr_elapsed = time.perf_counter() - t_start
                curr_tps = idx / curr_elapsed
                print(f"  -> Processed {idx:,} / {total_tx:,} transactions ({idx/total_tx*100:.0f}%) | Elapsed: {curr_elapsed:.2f}s | Current: {curr_tps:.1f} TPS")

    total_wall_s = time.perf_counter() - t_start
    overall_tps = total_tx / total_wall_s

    # Metrics calculation
    errors = [r for r in results if r["error"] is not None]
    gate0_txs = [r for r in results if r["gate_used"] == "GATE_0_FAST_PATH"]
    gate1_txs = [r for r in results if r["gate_used"] == "GATE_1_NEURAL_QWEN"]

    all_latencies = sorted([r["elapsed_ms"] for r in results])
    g0_latencies = sorted([r["elapsed_ms"] for r in gate0_txs]) if gate0_txs else [0]
    g1_latencies = sorted([r["elapsed_ms"] for r in gate1_txs]) if gate1_txs else [0]
    neural_times = sorted([r["neural_latency_ms"] for r in gate1_txs if r["neural_latency_ms"] > 0])

    decisions = {}
    for r in results:
        d = r.get("decision", "ERROR")
        decisions[d] = decisions.get(d, 0) + 1

    print("\n" + "=" * 80)
    print("FINAL 2,000 TRANSACTION BENCHMARK REPORT")
    print("=" * 80)
    print(f"Total Transactions:        {total_tx:,}")
    print(f"Concurrent Workers:        {concurrency}")
    print(f"Total Execution Time:      {total_wall_s:.2f} seconds")
    print(f"Effective Throughput:      {overall_tps:.1f} TRANSACTIONS / SECOND")
    print(f"Success Rate:              {((total_tx - len(errors)) / total_tx) * 100:.2f}% ({len(errors)} errors)")

    print(f"\nTwo-Gate Triage Distribution:")
    print(f"  - Gate 0 (Fast Path, < 1ms):   {len(gate0_txs):,} ({len(gate0_txs)/total_tx*100:.1f}%)")
    print(f"  - Gate 1 (Neural Qwen, ~120ms): {len(gate1_txs):,} ({len(gate1_txs)/total_tx*100:.1f}%)")

    print(f"\nLatency Breakdown (End-to-End HTTP):")
    print(f"  - Fleet Average:           {statistics.mean(all_latencies):.2f}ms")
    print(f"  - Fleet Median (p50):      {all_latencies[int(len(all_latencies) * 0.50)]:.2f}ms")
    print(f"  - Fleet 90th percentile:   {all_latencies[int(len(all_latencies) * 0.90)]:.2f}ms")
    print(f"  - Fleet 95th percentile:   {all_latencies[int(len(all_latencies) * 0.95)]:.2f}ms")
    print(f"  - Fleet 99th percentile:   {all_latencies[int(len(all_latencies) * 0.99)]:.2f}ms")

    print(f"\nGate 0 vs Gate 1 Latency Contrast:")
    print(f"  - Gate 0 Average Latency:  {statistics.mean(g0_latencies):.2f}ms (Min: {min(g0_latencies):.2f}ms, p95: {g0_latencies[int(len(g0_latencies)*0.95)]:.2f}ms)")
    if gate1_txs:
        print(f"  - Gate 1 Average Latency:  {statistics.mean(g1_latencies):.2f}ms (Min: {min(g1_latencies):.2f}ms, p95: {g1_latencies[int(len(g1_latencies)*0.95)]:.2f}ms)")
        if neural_times:
            print(f"  - Gate 1 Pure Neural Time: {statistics.mean(neural_times):.2f}ms average")

    print(f"\nRisk Verdict Breakdown:")
    for dec, count in sorted(decisions.items()):
        print(f"  - {dec:<12}: {count:,} ({count/total_tx*100:.1f}%)")


if __name__ == "__main__":
    import sys
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 2000
    conc = int(sys.argv[2]) if len(sys.argv) > 2 else 12
    run_2000_benchmark(count, conc)
