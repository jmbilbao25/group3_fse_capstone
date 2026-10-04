"""
FastAPI Microservice: Decoupled Transfer Risk Engine.
Synchronous Path: Gate 0 + XGBoost (S2) Only (< 2 ms on CPU).
Asynchronous Path: NanoJev (Qwen2.5-0.5B INT8 ONNX) Second-Look Reviewer.
"""

import os
import sys
import time
import uuid
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import pandas as pd
import joblib

# Ensure repo root and app package are importable
_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
if _REPO_ROOT not in sys.path:
    sys.path.insert(0, _REPO_ROOT)

from app.models import (
    RiskAnalysisRequest,
    RiskAnalysisResponse,
    RiskMetrics,
    AnalystDecisionRequest,
    ReviewerMetricsResponse
)
from app.seed_data import get_customer_profile
from app.geo_math import analyze_location_signals
from app.reviewer import (
    NanoJevSecondLookEngine,
    TransferStore,
    AnalystDecisionStore,
    ReviewerMetrics,
    AsyncReviewWorkerPool
)

from hybrid_bench.gate0 import Gate0Filter
from hybrid_bench.train_xgb import TabularFeaturePipeline
import __main__
__main__.TabularFeaturePipeline = TabularFeaturePipeline

app = FastAPI(
    title="Retail Banking Transfer Risk Engine",
    version="2.0.0",
    description="Synchronous Gate 0 + XGBoost (S2) Risk Engine with Async NanoJev Second-Look Reviewer."
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration
SETTLEMENT_WINDOW_SECONDS = float(os.environ.get("SETTLEMENT_WINDOW_SECONDS", 60.0))
REVIEW_QUEUE_MAXSIZE = int(os.environ.get("REVIEW_QUEUE_MAXSIZE", 1000))
REVIEW_WORKER_THREADS = int(os.environ.get("REVIEW_WORKER_THREADS", 2))
ONNX_INTRA_OP_THREADS = int(os.environ.get("ONNX_INTRA_OP_THREADS", 8))
TAU_2FA = float(os.environ.get("TAU_2FA", 0.40))
TAU_BLOCK = float(os.environ.get("TAU_BLOCK", 0.50))

# 1. Initialize Gate 0 and S2 XGBoost Models
models_dir = os.path.join(_REPO_ROOT, "hybrid_bench", "models")
model_s2_path = os.path.join(models_dir, "s2_xgb_model.joblib")
pipe_s2_path = os.path.join(models_dir, "s2_feature_pipeline.joblib")

gate0 = Gate0Filter()
s2_model = joblib.load(model_s2_path) if os.path.isfile(model_s2_path) else None
s2_pipeline = joblib.load(pipe_s2_path) if os.path.isfile(pipe_s2_path) else None

# 2. Initialize Async Second-Look Reviewer components
transfer_store = TransferStore(settlement_window_seconds=SETTLEMENT_WINDOW_SECONDS)
analyst_store = AnalystDecisionStore()
reviewer_metrics = ReviewerMetrics()

nanojev_engine = NanoJevSecondLookEngine(
    intra_op_threads=ONNX_INTRA_OP_THREADS,
    temperature=5.0,
    theta_block=0.40,
    theta_2fa=0.60
)

worker_pool = AsyncReviewWorkerPool(
    engine=nanojev_engine,
    transfer_store=transfer_store,
    analyst_store=analyst_store,
    metrics=reviewer_metrics,
    explainer_model=s2_model,
    feature_pipeline=s2_pipeline,
    max_queue_size=REVIEW_QUEUE_MAXSIZE,
    num_workers=REVIEW_WORKER_THREADS,
    job_timeout_seconds=1.5
)


@app.on_event("shutdown")
def shutdown_event():
    worker_pool.shutdown()


@app.get("/health")
def health_check():
    return {
        "status": "UP",
        "service": "risk-service",
        "architecture": "Decoupled Sync S2 + Async NanoJev Reviewer",
        "version": "2.0.0",
        "sync_engine": "Gate 0 + XGBoost (S2)",
        "async_reviewer": {
            "model": "Qwen2.5-0.5B INT8 ONNX",
            "model_loaded": nanojev_engine.model_loaded,
            "intra_op_threads": nanojev_engine.intra_op_threads,
            "settlement_window_seconds": SETTLEMENT_WINDOW_SECONDS
        }
    }


@app.get("/api/v1/risk/customers/{identifier}")
def get_customer(identifier: str):
    profile = get_customer_profile(identifier)
    return profile


@app.post("/api/v1/risk/analyze", response_model=RiskAnalysisResponse)
@app.post("/api/v1/risk/transfer", response_model=RiskAnalysisResponse)
def analyze_transfer_risk(req: RiskAnalysisRequest):
    """
    Synchronous Path: Gate 0 + XGBoost (S2) Only.
    Returns S2 decision in < 2 ms.
    If memo is present and decision is not BLOCK, enqueues async review job
    and sets status to PENDING_SETTLEMENT for the simulated window (default 60s).
    """
    start_time = time.perf_counter()
    tx_id = req.transaction_id or f"TX-RISK-{uuid.uuid4().hex[:8].upper()}"

    # 1. Customer baseline
    lookup_key = req.account_id or req.user_id or ""
    customer = get_customer_profile(lookup_key)
    home_coords = customer.get("home_coordinates", {"latitude": 14.5995, "longitude": 120.9842})
    last_tx = customer.get("last_transaction")
    avg_amount = float(customer.get("average_transfer_amount", 2000.0))

    # 2. Location coordinates
    current_lat = req.latitude if req.latitude is not None else home_coords["latitude"]
    current_lon = req.longitude if req.longitude is not None else home_coords["longitude"]
    prev_lat = last_tx["coordinates"]["latitude"] if last_tx else None
    prev_lon = last_tx["coordinates"]["longitude"] if last_tx else None
    prev_time_iso = last_tx["timestamp"] if last_tx else None

    # 3. Deterministic Geo & Velocity Math
    geo_signals = analyze_location_signals(
        current_lat=current_lat,
        current_lon=current_lon,
        home_lat=home_coords["latitude"],
        home_lon=home_coords["longitude"],
        prev_lat=prev_lat,
        prev_lon=prev_lon,
        prev_timestamp_iso=prev_time_iso,
        ip_lat=req.ip_latitude,
        ip_lon=req.ip_longitude,
    )

    amount = float(req.amount)
    memo = req.memo or ""
    spike_ratio = round(amount / avg_amount, 2) if avg_amount > 0 else 1.0
    est_balance = float(customer.get("balance", amount * 3.0))
    balance_drain = round(min(1.0, amount / est_balance), 2) if est_balance > 0 else 0.50

    # Construct comprehensive tabular telemetry row for S2 model & async reviewer
    tabular_row = {
        "amount_php": amount,
        "user_avg_amount_php": avg_amount,
        "spike_ratio": spike_ratio,
        "balance_drain_ratio": balance_drain,
        "cum_outflow_1h": amount,
        "cum_outflow_24h": amount,
        "payees_24h": 1,
        "payee_age_days": req.payee_age_days,
        "senders_to_payee_24h": 1,
        "hour": datetime.now(timezone.utc).hour,
        "dow": datetime.now(timezone.utc).weekday(),
        "usual_hour_gap": 2.0,
        "dormant_days": 0.0,
        "device_age_days": 180.0,
        "accounts_per_device": 1,
        "os_patch_age_days": 30.0,
        "seconds_since_login": 120.0,
        "failed_logins_1h": 0,
        "credential_change_hours_ago": 720.0,
        "form_seconds": 15.0,
        "gps_accuracy_m": 10.0,
        "distance_from_home_km": geo_signals["distance_from_home_km"],
        "distance_from_prev_km": geo_signals["distance_from_last_km"],
        "elapsed_minutes": geo_signals["elapsed_minutes"],
        "velocity_kmh": geo_signals["velocity_kmh"],
        "new_payee": req.new_payee,
        "device_id_new": False,
        "rooted": req.rooted,
        "hooking": req.hooking,
        "emulator": req.emulator,
        "debugger": False,
        "tampered": req.tampered,
        "unofficial_store": False,
        "dev_options": False,
        "mock_location": req.mock_location or geo_signals["is_impossible_travel"],
        "accessibility_active": False,
        "screen_sharing": False,
        "payee_pasted": False,
        "tz_mismatch": False,
        "ip_gps_mismatch": geo_signals["ip_discrepancy_km"] > 500.0,
        "is_vpn": req.is_vpn or geo_signals["is_vpn_detected"],
        "transfer_purpose": "Funds Transfer",
        "payee_type": "third_party_individual",
        "channel": "mobile_banking",
        "attestation_verdict": req.attestation_verdict,
        "login_method": "biometrics"
    }

    # 4. Gate 0 Deterministic Hard Rules
    gate0_row = {
        "velocity_kmh": geo_signals["velocity_kmh"],
        "amount_php": amount,
        "rooted": req.rooted,
        "hooking": req.hooking,
        "emulator": req.emulator,
        "tampered": req.tampered,
        "device_id_new": req.new_payee,
        "attestation_verdict": req.attestation_verdict,
        "mock_location": req.mock_location or geo_signals["is_impossible_travel"],
        "distance_from_home_km": geo_signals["distance_from_home_km"]
    }

    g0_action, g0_reason = gate0.evaluate_row(gate0_row, trigger_async_sar=True)

    if g0_action is not None:
        # Gate 0 hard rule tripped!
        decision = g0_action
        primary_flag = g0_reason
        fraud_score = 100 if decision == "BLOCK" else 75
        is_anomaly = True
        anomaly_prob = 1.0 if decision == "BLOCK" else 0.75
        all_flags = [g0_reason]
        status = "BLOCKED" if decision == "BLOCK" else "REQUIRE_2FA"
        review_enqueued = False
    else:
        # Gate 0 Passed -> XGBoost (S2) Tabular Inference
        if s2_model is not None and s2_pipeline is not None:
            df_row = pd.DataFrame([tabular_row])
            X_trans = s2_pipeline.transform(df_row)
            p_xgb = float(s2_model.predict_proba(X_trans)[0, 1])
        else:
            p_xgb = 0.05

        fraud_score = int(round(p_xgb * 100))
        anomaly_prob = round(p_xgb, 4)
        is_anomaly = p_xgb >= TAU_2FA

        if p_xgb >= TAU_BLOCK:
            decision = "BLOCK"
            primary_flag = "HIGH_TABULAR_RISK_SCORE"
            all_flags = ["HIGH_XGBOOST_RISK"]
            status = "BLOCKED"
            review_enqueued = False
        elif p_xgb >= TAU_2FA:
            decision = "REQUIRE_2FA"
            primary_flag = "ELEVATED_TABULAR_RISK"
            all_flags = ["MODERATE_XGBOOST_RISK"]
            status = "REQUIRE_2FA"
            review_enqueued = False
        else:
            decision = "ALLOW"
            primary_flag = "NORMAL_TRANSACTION"
            all_flags = ["ROUTINE_TRANSACTION"]
            status = "PENDING_SETTLEMENT" if (memo and memo.strip()) else "SETTLED"
            review_enqueued = False

    # 5. Post-Decision Enqueueing for Memo-Present Transfers
    has_memo = bool(memo and memo.strip())
    if has_memo and decision != "BLOCK":
        # Persist transfer record in TransferStore
        transfer_store.save_transfer(
            transaction_id=tx_id,
            user_id=customer.get("user_id", req.user_id or "USR-UNKNOWN"),
            account_id=req.account_id,
            target_account_id=req.target_account_id,
            amount=amount,
            memo=memo,
            s2_action=decision,
            s2_score=fraud_score,
            tabular_features=tabular_row
        )

        # Enqueue second-look review job
        review_enqueued = worker_pool.enqueue_review(
            transaction_id=tx_id,
            s2_action=decision,
            s2_score=fraud_score,
            memo=memo,
            amount=amount,
            tabular_data=tabular_row
        )

    elapsed_ms = (time.perf_counter() - start_time) * 1000.0

    return RiskAnalysisResponse(
        transaction_id=tx_id,
        decision=decision,
        fraud_score=fraud_score,
        is_anomaly=is_anomaly,
        anomaly_probability=anomaly_prob,
        primary_flag=primary_flag,
        all_flags=all_flags,
        metrics=RiskMetrics(
            distance_from_home_km=geo_signals["distance_from_home_km"],
            distance_from_last_km=geo_signals["distance_from_last_km"],
            elapsed_minutes=geo_signals["elapsed_minutes"],
            velocity_kmh=geo_signals["velocity_kmh"],
            is_impossible_travel=geo_signals["is_impossible_travel"],
            is_high_speed_transit=geo_signals["is_high_speed_transit"],
            ip_discrepancy_km=geo_signals["ip_discrepancy_km"],
            is_vpn_detected=geo_signals["is_vpn_detected"],
            spike_ratio=spike_ratio
        ),
        customer_summary={
            "user_id": customer.get("user_id"),
            "full_name": customer.get("full_name"),
            "average_transfer": avg_amount,
            "home_location": home_coords.get("label", "Unknown")
        },
        evaluation_time_ms=round(elapsed_ms, 2),
        status=status,
        review_enqueued=review_enqueued,
        settlement_window_seconds=SETTLEMENT_WINDOW_SECONDS
    )


@app.get("/api/v1/risk/metrics", response_model=ReviewerMetricsResponse)
def get_metrics():
    """Returns async reviewer queue depth, drop counts, timeouts, and review latencies."""
    return reviewer_metrics.get_summary()


@app.get("/api/v1/risk/transfers/{tx_id}")
def get_transfer_status(tx_id: str):
    """Queries current state of a transfer, including settlement status and review results."""
    rec = transfer_store.get_transfer(tx_id)
    if not rec:
        raise HTTPException(status_code=404, detail=f"Transfer {tx_id} not found")
    return rec


@app.get("/api/v1/analyst/cases")
def list_analyst_cases():
    """Returns all escalated case cards pending compliance / fraud review."""
    return transfer_store.get_analyst_cases()


@app.post("/api/v1/analyst/decision")
def record_analyst_decision(req: AnalystDecisionRequest):
    """Stores analyst verdict (CONFIRM_FRAUD or DISMISS) into append-only JSONL storage."""
    result = analyst_store.record_decision(
        case_id=req.case_id,
        transaction_id=req.transaction_id,
        decision=req.decision,
        analyst_id=req.analyst_id or "ANALYST_01",
        notes=req.notes or ""
    )
    return {"status": "SUCCESS", "entry": result}


@app.post("/api/v1/risk/simulate/{scenario_name}")
def simulate_scenario(scenario_name: str):
    scenarios = {
        "normal": RiskAnalysisRequest(
            user_id="USR-1001",
            account_id="ACC-100001",
            target_account_id="ACC-100002",
            amount=1500.00,
            memo="lunch payment",
            latitude=14.5547,
            longitude=121.0200
        ),
        "impossible_travel": RiskAnalysisRequest(
            user_id="USR-1003",
            account_id="ACC-100003",
            target_account_id="ACC-100004",
            amount=15000.00,
            memo="business transfer",
            latitude=1.3521,
            longitude=103.8198
        ),
        "scam_memo": RiskAnalysisRequest(
            user_id="USR-1002",
            account_id="ACC-100002",
            target_account_id="ACC-100005",
            amount=38000.00,
            memo="urgent crypto release fee for investment profit",
            latitude=14.6760,
            longitude=121.0437
        ),
        "vpn_mismatch": RiskAnalysisRequest(
            user_id="USR-1004",
            account_id="ACC-100004",
            target_account_id="ACC-100001",
            amount=8500.00,
            memo="services rendered",
            latitude=14.5869,
            longitude=121.0614,
            ip_latitude=52.3676,
            ip_longitude=4.9041
        )
    }

    if scenario_name not in scenarios:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown scenario '{scenario_name}'. Valid options: {list(scenarios.keys())}"
        )

    return analyze_transfer_risk(scenarios[scenario_name])
