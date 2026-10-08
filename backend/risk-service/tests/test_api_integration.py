"""
Integration tests for FastAPI Risk Service with Synchronous S2 + Asynchronous NanoJev Reviewer.
"""

import os
import sys
import time
import pytest
from starlette.testclient import TestClient

# Ensure backend/risk-service is on sys.path
_SERVICE_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _SERVICE_ROOT not in sys.path:
    sys.path.insert(0, _SERVICE_ROOT)

from app.main import app, transfer_store, reviewer_metrics


@pytest.fixture(scope="module")
def client():
    with TestClient(app) as c:
        c.get("/health")
        c.post("/api/v1/risk/analyze", json={
            "transaction_id": "TX-WARMUP-INIT",
            "account_id": "acc-2001-sav-001",
            "target_account_id": "acc-2002-chk-001",
            "amount": 100.0,
            "memo": "warmup memo"
        })
        yield c


def test_health_check(client):
    res = client.get("/health")
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "UP"
    assert "S2" in data["sync_engine"]


def test_sync_path_fast_allow_without_memo(client):
    """Sync path returns in < 50ms without waiting for reviewer when no memo is present."""
    payload = {
        "transaction_id": "TX-TEST-NOMEMO-01",
        "user_id": "USR-1001",
        "account_id": "acc-2001-sav-001",
        "target_account_id": "acc-2002-chk-001",
        "amount": 500.0,
        "memo": "",
        "latitude": 14.5995,
        "longitude": 120.9842
    }
    t0 = time.perf_counter()
    res = client.post("/api/v1/risk/analyze", json=payload)
    elapsed_ms = (time.perf_counter() - t0) * 1000.0

    assert res.status_code == 200
    data = res.json()
    assert data["decision"] == "ALLOW"
    assert data["status"] == "SETTLED"
    assert data["review_enqueued"] is False
    assert data["evaluation_time_ms"] < 200.0  # Engine execution under 200ms
    assert elapsed_ms < 500.0  # HTTP loopback latency bound


def test_sync_gate0_impossible_travel_block(client):
    """Impossible travel trips Gate 0 and blocks immediately."""
    payload = {
        "transaction_id": "TX-TEST-IMPOSSIBLE-01",
        "user_id": "USR-1003",
        "account_id": "acc-2003-sav-002",
        "target_account_id": "acc-2001-sav-001",
        "amount": 15000.0,
        "memo": "business transfer",
        # Singapore GPS coordinates
        "latitude": 1.3521,
        "longitude": 103.8198
    }
    res = client.post("/api/v1/risk/analyze", json=payload)
    assert res.status_code == 200
    data = res.json()
    assert data["decision"] == "BLOCK"
    assert data["primary_flag"] == "IMPOSSIBLE_TRAVEL_VELOCITY"
    assert data["status"] == "BLOCKED"
    assert data["review_enqueued"] is False


def test_async_second_look_escalation_flow(client):
    """
    1. Transfer with normal numbers but scam memo:
       - Sync path returns ALLOW immediately (p99 < 100ms) with status PENDING_SETTLEMENT.
       - Asynchronous second-look reviewer runs in background.
       - NanoJev detects scam pattern and escalates within the window:
         PENDING_SETTLEMENT -> HELD.
       - Analyst Case Card is generated and visible.
       - Analyst records decision.
    """
    tx_id = f"TX-TEST-SCAM-{int(time.time()*1000)}"
    payload = {
        "transaction_id": tx_id,
        "user_id": "USR-1002",
        "account_id": "acc-2002-chk-001",
        "target_account_id": "acc-2005-sav-001",
        "amount": 1200.0,
        "memo": "guaranteed return 50% profit weekly send crypto now",
        "latitude": 14.5995,
        "longitude": 120.9842
    }

    t0 = time.perf_counter()
    res = client.post("/api/v1/risk/analyze", json=payload)
    sync_dur_ms = (time.perf_counter() - t0) * 1000.0

    assert res.status_code == 200
    data = res.json()
    # Initial S2 decision is ALLOW
    assert data["decision"] == "ALLOW"
    assert data["status"] == "PENDING_SETTLEMENT"
    assert data["review_enqueued"] is True
    assert data["evaluation_time_ms"] < 200.0
    assert sync_dur_ms < 500.0

    # Poll status until reviewed (up to 2.5s for neural forward pass)
    transfer_data = None
    for _ in range(25):
        time.sleep(0.1)
        status_res = client.get(f"/api/v1/risk/transfers/{tx_id}")
        if status_res.status_code == 200:
            transfer_data = status_res.json()
            if transfer_data.get("review_status") == "REVIEWED":
                break

    assert transfer_data is not None
    assert transfer_data["review_status"] == "REVIEWED"
    # Escalate-only invariant changed PENDING_SETTLEMENT -> HELD
    assert transfer_data["status"] == "HELD"
    assert transfer_data["review_result"]["escalated"] is True
    assert transfer_data["review_result"]["typology_tag"] == "investment_scam"

    # Verify Analyst Case Card was queued
    cases_res = client.get("/api/v1/analyst/cases")
    assert cases_res.status_code == 200
    cases = cases_res.json()
    matching_cases = [c for c in cases if c["transaction_id"] == tx_id]
    assert len(matching_cases) >= 1
    card = matching_cases[0]
    assert card["s2_initial_action"] == "ALLOW"
    assert card["final_action"] in ["REQUIRE_2FA", "BLOCK"]
    assert card["scam_typology"] == "investment_scam"
    assert len(card["top_3_shap_features"]) == 3

    # Submit Analyst Decision
    dec_payload = {
        "case_id": card["case_id"],
        "transaction_id": tx_id,
        "decision": "CONFIRM_FRAUD",
        "analyst_id": "TEST_ANALYST",
        "notes": "Verified investment ponzi fraud memo"
    }
    dec_res = client.post("/api/v1/analyst/decision", json=dec_payload)
    assert dec_res.status_code == 200
    assert dec_res.json()["status"] == "SUCCESS"


def test_metrics_endpoint(client):
    res = client.get("/api/v1/risk/metrics")
    assert res.status_code == 200
    metrics = res.json()
    assert "queue_depth" in metrics
    assert "drops" in metrics
    assert "timeouts" in metrics
    assert "reviews_completed" in metrics
    assert metrics["reviews_completed"] >= 1
