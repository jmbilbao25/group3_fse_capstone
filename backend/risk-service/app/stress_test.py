"""
Automated Stress Test Suite for NanoJev Risk Engine (Qwen2.5-0.5B).
Executes concurrent synthetic transactions across normal and fraud patterns,
measuring p50, p90, p95 latencies, throughput, and error rates.
"""

import time
import json
import random
import statistics
import concurrent.futures
from urllib import request

SCENARIOS = [
    {
        "name": "Routine Grocery Transfer (Primary Device Biometric)",
        "payload": {
            "account_id": "acc-2001-sav-001",
            "target_account_id": "acc-2002-chk-001",
            "user_id": "usr-1001-cst-001",
            "amount": 1250.00,
            "memo": "supermarket groceries",
            "latitude": 14.5547,
            "longitude": 121.0200,
            "is_primary_device": True
        }
    },
    {
        "name": "Remote-Access Tool Detected (AnyDesk Advisory Warning)",
        "payload": {
            "account_id": "acc-2001-sav-001",
            "target_account_id": "acc-9999-ext-888",
            "user_id": "usr-1001-cst-001",
            "amount": 8500.00,
            "memo": "tech support assistance refund",
            "latitude": 14.5547,
            "longitude": 121.0200,
            "is_primary_device": True,
            "device_context": {
                "device_model": "Xiaomi Redmi 9A",
                "active_accessibility_services": ["com.anydesk.anydeskandroid"],
                "media_projection": {"is_screen_sharing": True}
            }
        }
    },
    {
        "name": "Live Phone Call Coercion (Advisory Warning)",
        "payload": {
            "account_id": "acc-2001-sav-001",
            "target_account_id": "acc-5555-chk-002",
            "user_id": "usr-1001-cst-001",
            "amount": 12000.00,
            "memo": "urgent tax settlement fee",
            "latitude": 14.5547,
            "longitude": 121.0200,
            "is_primary_device": True,
            "device_context": {
                "telephony": {"call_state": "CALL_STATE_OFFHOOK", "call_duration_seconds": 340.0},
                "interaction": {"time_spent_on_form_seconds": 3.0}
            }
        }
    },
    {
        "name": "Secondary Device Transfer (Out-of-Band Push Notification)",
        "payload": {
            "account_id": "acc-2001-sav-001",
            "target_account_id": "acc-3001-sav-002",
            "user_id": "usr-1001-cst-001",
            "amount": 3200.00,
            "memo": "dinner bill split",
            "latitude": 14.5547,
            "longitude": 121.0200,
            "is_primary_device": False
        }
    },
    {
        "name": "Crypto Scam / Urgent Fee (Async Reviewer Queue)",
        "payload": {
            "account_id": "acc-2002-chk-001",
            "target_account_id": "acc-8888-cry-001",
            "user_id": "usr-1002-cst-002",
            "amount": 35000.00,
            "memo": "urgent crypto release fee guaranteed profit",
            "latitude": 14.6760,
            "longitude": 121.0437,
            "is_primary_device": True
        }
    },
    {
        "name": "Impossible Travel / Velocity Anomaly (Gate 0 Hard Block)",
        "payload": {
            "account_id": "acc-2003-sav-002",
            "target_account_id": "acc-7777-chk-001",
            "user_id": "usr-1003-cst-003",
            "amount": 15000.00,
            "memo": "overseas transfer",
            "latitude": 1.3521,
            "longitude": 103.8198,
            "is_primary_device": True
        }
    },
    {
        "name": "Critical Tampering / Emulator High Value (Gate 0 Hard Block)",
        "payload": {
            "account_id": "acc-2004-chk-002",
            "target_account_id": "acc-6666-chk-001",
            "user_id": "usr-1004-cst-004",
            "amount": 60000.00,
            "memo": "emulator drain",
            "latitude": 14.5869,
            "longitude": 121.0614,
            "emulator": True,
            "is_primary_device": False
        }
    }
]

def send_transaction(req_idx: int, target_url: str = "http://127.0.0.1:8084/api/v1/risk/analyze"):
    scenario = random.choice(SCENARIOS)
    payload = dict(scenario["payload"])
    payload["transaction_id"] = f"TX-STRESS-{req_idx:04d}"
    payload["amount"] = round(payload["amount"] + random.uniform(-10.0, 10.0), 2)
    
    data = json.dumps(payload).encode("utf-8")
    req = request.Request(target_url, data=data, headers={"Content-Type": "application/json"}, method="POST")
    
    t0 = time.perf_counter()
    try:
        with request.urlopen(req, timeout=10.0) as resp:
            elapsed_ms = (time.perf_counter() - t0) * 1000.0
            body = json.loads(resp.read().decode("utf-8"))
            return {
                "idx": req_idx,
                "scenario": scenario["name"],
                "status_code": resp.status,
                "elapsed_ms": elapsed_ms,
                "decision": body.get("decision"),
                "auth_method": body.get("auth_method"),
                "advisory_tier": body.get("advisory_tier"),
                "fraud_score": body.get("fraud_score"),
                "neural_latency_ms": body.get("neural_metadata", {}).get("neural_latency_ms", 0.0),
                "error": None
            }
    except Exception as e:
        elapsed_ms = (time.perf_counter() - t0) * 1000.0
        return {
            "idx": req_idx,
            "scenario": scenario["name"],
            "status_code": 500,
            "elapsed_ms": elapsed_ms,
            "decision": None,
            "auth_method": None,
            "advisory_tier": None,
            "fraud_score": None,
            "neural_latency_ms": 0.0,
            "error": str(e)
        }

def run_stress_test(total_requests: int = 100, concurrency: int = 5):
    print("=" * 70)
    print(f"Risk Engine Live Run: {total_requests} transactions at concurrency={concurrency}")
    print("=" * 70)
    
    t_start = time.perf_counter()
    results = []
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [executor.submit(send_transaction, i) for i in range(1, total_requests + 1)]
        for f in concurrent.futures.as_completed(futures):
            results.append(f.result())
    
    total_duration_s = time.perf_counter() - t_start
    
    latencies = [r["elapsed_ms"] for r in results]
    neural_latencies = [r["neural_latency_ms"] for r in results if r["neural_latency_ms"] > 0]
    errors = [r for r in results if r["error"] is not None or r["status_code"] != 200]
    
    latencies.sort()
    neural_latencies.sort()
    
    p50 = latencies[int(len(latencies) * 0.50)]
    p90 = latencies[int(len(latencies) * 0.90)]
    p95 = latencies[int(len(latencies) * 0.95)]
    
    decisions = {}
    auth_methods = {}
    advisories = {}
    for r in results:
        d = r.get("decision", "ERROR")
        decisions[d] = decisions.get(d, 0) + 1
        
        am = r.get("auth_method", "UNKNOWN")
        auth_methods[am] = auth_methods.get(am, 0) + 1
        
        adv = r.get("advisory_tier", "NONE")
        if adv != "NONE":
            advisories[adv] = advisories.get(adv, 0) + 1
    
    print("\nExecution Summary:")
    print(f"- Total Requests:      {total_requests}")
    print(f"- Concurrency:         {concurrency}")
    print(f"- Total Wall Time:     {total_duration_s:.2f}s")
    print(f"- Throughput:          {total_requests / total_duration_s:.2f} req/sec")
    print(f"- Success Rate:        {((total_requests - len(errors)) / total_requests) * 100:.1f}% ({len(errors)} errors)")
    
    print("\nEnd-to-End Latency:")
    print(f"- Min:                 {min(latencies):.1f}ms")
    print(f"- Average:             {statistics.mean(latencies):.1f}ms")
    print(f"- Median (p50):        {p50:.1f}ms")
    print(f"- 90th percentile:     {p90:.1f}ms")
    print(f"- 95th percentile:     {p95:.1f}ms")
    print(f"- Max:                 {max(latencies):.1f}ms")
    
    print("\nDecision Distribution:")
    for dec, count in sorted(decisions.items()):
        print(f"- {dec}: {count} ({count/total_requests*100:.1f}%)")
        
    print("\nAuthorization Method Distribution (Zero SMS OTP):")
    for am, count in sorted(auth_methods.items()):
        print(f"- {am}: {count} ({count/total_requests*100:.1f}%)")
        
    if advisories:
        print("\nAdvisory Warnings Triggered:")
        for adv, count in sorted(advisories.items()):
            print(f"- {adv}: {count} ({count/total_requests*100:.1f}%)")
    print("=" * 70)

if __name__ == "__main__":
    import sys
    reqs = int(sys.argv[1]) if len(sys.argv) > 1 else 100
    conc = int(sys.argv[2]) if len(sys.argv) > 2 else 5
    run_stress_test(reqs, conc)
