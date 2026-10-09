"""
Production HTTP Server for Local Retail Bank Risk Engine with Datadog APM Tracing & Structured Logging.
Supports decoupled architecture:
  - Synchronous Path: Gate 0 + XGBoost (S2) (< 2 ms)
  - Asynchronous Second-Look Reviewer: NanoJev (Qwen2.5-0.5B INT8 ONNX)
Provides high-concurrency threaded HTTP serving for /health, /api/v1/risk/transfer,
/api/v1/risk/analyze, /api/v1/risk/metrics, /api/v1/risk/transfers/{id},
/api/v1/analyst/cases, and /api/v1/analyst/decision.
"""

import os
import sys
import json
import time
import uuid
import logging
from datetime import datetime, timezone
from http.server import HTTPServer, ThreadingHTTPServer, BaseHTTPRequestHandler
from typing import Dict, Any, Optional

# Add project root and service root to sys.path
_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
if _REPO_ROOT not in sys.path:
    sys.path.insert(0, _REPO_ROOT)

_SERVICE_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _SERVICE_ROOT not in sys.path:
    sys.path.insert(0, _SERVICE_ROOT)

from app.seed_data import get_customer_profile
from app.geo_math import analyze_location_signals
from app.models import RiskAnalysisRequest
from app.threat_builder import has_threat_context, build_threat_narrative, detect_threat_category
from app.warning_catalog import get_warning_dialog
from hybrid_bench.sar_generator import trigger_sar_async
from app.reviewer import (
    NanoJevSecondLookEngine,
    AsyncReviewWorkerPool,
    TransferStore,
    AnalystDecisionStore,
    ReviewerMetrics
)
from app.kyc import KycEvaluator, KycEvaluationRequest

kyc_evaluator = KycEvaluator()

# Datadog APM Tracing initialization
DD_AGENT_HOST = os.environ.get("DD_AGENT_HOST", "dd-agent")
DD_TRACE_AGENT_PORT = int(os.environ.get("DD_TRACE_AGENT_PORT", 8126))
DD_SERVICE = os.environ.get("DD_SERVICE", "risk-service")
DD_ENV = os.environ.get("DD_ENV", "local")
DD_VERSION = os.environ.get("DD_VERSION", "2.0.0")

try:
    from ddtrace import tracer
    TRACING_AVAILABLE = tracer.enabled
    print(f"[DATADOG APM] Native ddtrace enabled -> {tracer.agent_trace_url} (service={DD_SERVICE})", flush=True)
except Exception as e:
    TRACING_AVAILABLE = False
    print(f"[DATADOG APM] ddtrace not available: {e}", flush=True)

# Configuration
SETTLEMENT_WINDOW_SECONDS = float(os.environ.get("SETTLEMENT_WINDOW_SECONDS", 60.0))
REVIEW_QUEUE_MAXSIZE = int(os.environ.get("REVIEW_QUEUE_MAXSIZE", 1000))
REVIEW_WORKER_THREADS = int(os.environ.get("REVIEW_WORKER_THREADS", 2))
ONNX_INTRA_OP_THREADS = int(os.environ.get("ONNX_INTRA_OP_THREADS", 8))
TAU_2FA = float(os.environ.get("TAU_2FA", 0.40))
TAU_BLOCK = float(os.environ.get("TAU_BLOCK", 0.50))

# Initialize S2 Models & Gate 0
gate0 = None
s2_model = None
s2_pipeline = None

try:
    import joblib
    import pandas as pd
    from hybrid_bench.gate0 import Gate0Filter
    from hybrid_bench.train_xgb import TabularFeaturePipeline
    import __main__
    __main__.TabularFeaturePipeline = TabularFeaturePipeline

    gate0 = Gate0Filter()
    candidate_dirs = [
        os.environ.get("MODELS_DIR", ""),
        os.path.join(_SERVICE_ROOT, "app", "models"),
        os.path.join(_SERVICE_ROOT, "models"),
        os.path.join(_REPO_ROOT, "hybrid_bench", "models")
    ]
    for c_dir in candidate_dirs:
        if not c_dir or not os.path.isdir(c_dir):
            continue
        c_m = os.path.join(c_dir, "s2_xgb_model.joblib")
        c_p = os.path.join(c_dir, "s2_feature_pipeline.joblib")
        if os.path.isfile(c_m) and s2_model is None:
            s2_model = joblib.load(c_m)
        if os.path.isfile(c_p) and s2_pipeline is None:
            s2_pipeline = joblib.load(c_p)
    if s2_model is not None and s2_pipeline is not None:
        print("[INIT] S2 XGBoost Model and Tabular Feature Pipeline loaded successfully.", flush=True)
except Exception as e:
    print(f"[INIT] S2 / Gate0 optional components not loaded: {e}", flush=True)

# Initialize Stores and Reviewer Pool
transfer_store = TransferStore(settlement_window_seconds=SETTLEMENT_WINDOW_SECONDS)
analyst_store = AnalystDecisionStore()
reviewer_metrics = ReviewerMetrics()

# Laya non-autoregressive decision engine & Typology scoring
RISK_ENGINE_BACKEND = os.environ.get("RISK_ENGINE_BACKEND", "laya").lower()
typology_temp = float(os.environ.get("TYPOLOGY_TEMP", 7.12))
THETA_MEDIUM = float(os.environ.get("THETA_MEDIUM", 0.25))
THETA_HIGH = float(os.environ.get("THETA_HIGH", 0.50))

laya_engine_instance = None
typology_engine = None

if RISK_ENGINE_BACKEND == "laya":
    try:
        from app.reviewer import LayaSecondLookEngine
        from app.laya_engine import LayaEngine
        laya_engine_instance = LayaEngine(model_name="laya-multilingual")
        nanojev_engine = LayaSecondLookEngine(
            model_name="laya-multilingual",
            intra_op_threads=4,
            temperature=typology_temp,
            theta_block=THETA_HIGH,
            theta_2fa=THETA_MEDIUM
        )
        typology_engine = laya_engine_instance
        print("[INIT] Laya non-autoregressive System 1 engine initialized as primary backend.", flush=True)
    except Exception as e:
        print(f"[INIT] Laya initialization fallback to NanoJev: {e}", flush=True)
        nanojev_engine = NanoJevSecondLookEngine(
            intra_op_threads=ONNX_INTRA_OP_THREADS,
            temperature=5.0,
            theta_block=0.40,
            theta_2fa=0.60
        )
else:
    nanojev_engine = NanoJevSecondLookEngine(
        intra_op_threads=ONNX_INTRA_OP_THREADS,
        temperature=5.0,
        theta_block=0.40,
        theta_2fa=0.60
    )
    try:
        from hybrid_bench.nanojev_typology import NanoJevTypologyEngine
        typology_engine = NanoJevTypologyEngine(temp=typology_temp)
    except Exception:
        typology_engine = None

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


class RiskRequestHandler(BaseHTTPRequestHandler):
    server_version = "DecoupledRiskEngine/2.0"

    def log_message(self, format: str, *args: Any):
        """Override to prevent logging to stderr and suppress routine health check polling."""
        msg = format % args
        if "/health" in msg:
            return
        sys.stdout.write(f"{self.address_string()} - - [{self.log_date_time_string()}] {msg}\n")
        sys.stdout.flush()

    def _send_json(self, status_code: int, data: Dict[str, Any]):
        response_bytes = json.dumps(data, indent=2).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(response_bytes)))
        # Only attach CORS headers if direct client access (not proxied through an API Gateway with CORS)
        if not self.headers.get("X-Forwarded-For") and not self.headers.get("X-Forwarded-Host"):
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.end_headers()
        self.wfile.write(response_bytes)

    def do_OPTIONS(self):
        self.send_response(204)
        if not self.headers.get("X-Forwarded-For") and not self.headers.get("X-Forwarded-Host"):
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.end_headers()

    def do_GET(self):
        path = self.path.split("?")[0].rstrip("/")

        if path in ("/health", ""):
            engine_name = "Laya (ModernBERT / mmBERT)" if RISK_ENGINE_BACKEND == "laya" else "Qwen2.5-0.5B INT8 ONNX"
            self._send_json(200, {
                "status": "UP",
                "service": DD_SERVICE,
                "architecture": f"Decoupled Sync S2 + Synchronous {'Laya' if RISK_ENGINE_BACKEND == 'laya' else 'NanoJev'} Threat & Memo Engine",
                "version": DD_VERSION,
                "sync_engine": "Gate 0 + XGBoost (S2)",
                "threat_engine": engine_name,
                "async_reviewer": {
                    "model": engine_name,
                    "model_loaded": nanojev_engine.model_loaded,
                    "intra_op_threads": nanojev_engine.intra_op_threads,
                    "settlement_window_seconds": SETTLEMENT_WINDOW_SECONDS
                },
                "datadog_apm": TRACING_AVAILABLE
            })
            return

        if path == "/api/v1/risk/metrics":
            self._send_json(200, reviewer_metrics.get_summary())
            return

        if path == "/api/v1/analyst/cases":
            self._send_json(200, transfer_store.get_analyst_cases())
            return

        if path.startswith("/api/v1/risk/transfers/"):
            tx_id = path.replace("/api/v1/risk/transfers/", "").strip()
            rec = transfer_store.get_transfer(tx_id)
            if rec:
                self._send_json(200, rec)
            else:
                self._send_json(404, {"error": f"Transfer {tx_id} not found"})
            return

        if path.startswith("/api/v1/risk/customers/"):
            identifier = path.replace("/api/v1/risk/customers/", "").strip()
            profile = get_customer_profile(identifier)
            self._send_json(200, profile)
            return

        self._send_json(404, {"error": "Not Found", "path": self.path})

    def do_POST(self):
        path = self.path.split("?")[0].rstrip("/")
        content_length_hdr = self.headers.get("Content-Length")
        transfer_encoding = self.headers.get("Transfer-Encoding", "")

        if content_length_hdr is not None:
            content_length = int(content_length_hdr)
            body = self.rfile.read(content_length) if content_length > 0 else b"{}"
        elif "chunked" in transfer_encoding.lower():
            chunks = []
            while True:
                line = self.rfile.readline().strip()
                if not line:
                    break
                try:
                    chunk_len = int(line, 16)
                except ValueError:
                    break
                if chunk_len == 0:
                    self.rfile.readline()
                    break
                chunks.append(self.rfile.read(chunk_len))
                self.rfile.readline()
            body = b"".join(chunks)
        else:
            body = b"{}"

        try:
            payload = json.loads(body.decode("utf-8-sig")) if body else {}
        except Exception as e:
            self._send_json(400, {"error": "Invalid JSON payload", "detail": str(e)})
            return

        if path in ("/api/v1/risk/analyze", "/api/v1/risk/transfer", "/api/v1/risk/evaluate"):
            result = self._handle_analyze(payload)
            self._send_json(200, result)
            return

        if path == "/api/v1/analyst/decision":
            res = analyst_store.record_decision(
                case_id=payload.get("case_id", ""),
                transaction_id=payload.get("transaction_id", ""),
                decision=payload.get("decision", "CONFIRM_FRAUD"),
                analyst_id=payload.get("analyst_id", "ANALYST_01"),
                notes=payload.get("notes", "")
            )
            self._send_json(200, {"status": "SUCCESS", "entry": res})
            return

        if path.startswith("/api/v1/risk/simulate/"):
            scenario_name = path.replace("/api/v1/risk/simulate/", "").strip()
            result = self._handle_simulate(scenario_name)
            if "error" in result:
                self._send_json(400, result)
            else:
                self._send_json(200, result)
            return

        if path == "/api/v1/kyc/evaluate":
            try:
                req_obj = KycEvaluationRequest(**payload)
                eval_res = kyc_evaluator.evaluate(req_obj)
                res_dict = eval_res.model_dump() if hasattr(eval_res, "model_dump") else eval_res.dict()
                self._send_json(200, res_dict)
            except Exception as e:
                logging.error(f"[KYC EVALUATION ERROR] {e}", exc_info=True)
                self._send_json(500, {"error": "KYC Evaluation Failed", "detail": str(e)})
            return

        self._send_json(404, {"error": "Endpoint Not Found", "path": self.path})

    def _handle_analyze(self, req: Dict[str, Any]) -> Dict[str, Any]:
        start_time = time.perf_counter()
        tx_id = req.get("transaction_id") or f"TX-RISK-{uuid.uuid4().hex[:8].upper()}"

        account_id = req.get("account_id") or req.get("accountId") or "1000-2000-3001"
        user_id = req.get("user_id") or req.get("userId") or "usr-1001-cst-001"
        target_account_id = req.get("target_account_id") or req.get("targetAccountId") or "1000-2000-3002"
        customer = get_customer_profile(account_id) if account_id else get_customer_profile(user_id)

        home_coords = customer.get("home_coordinates", {"latitude": 14.5995, "longitude": 120.9842})
        last_tx = customer.get("last_transaction")
        avg_amount = float(customer.get("average_transfer_amount", 2000.0))
        current_balance = float(customer.get("current_balance", 50000.0))

        current_lat = float(req["latitude"]) if req.get("latitude") is not None else home_coords["latitude"]
        current_lon = float(req["longitude"]) if req.get("longitude") is not None else home_coords["longitude"]

        prev_lat = last_tx["coordinates"]["latitude"] if last_tx else None
        prev_lon = last_tx["coordinates"]["longitude"] if last_tx else None
        prev_time_iso = last_tx["timestamp"] if last_tx else None

        ip_lat = float(req["ip_latitude"]) if req.get("ip_latitude") is not None else None
        ip_lon = float(req["ip_longitude"]) if req.get("ip_longitude") is not None else None

        geo_signals = analyze_location_signals(
            current_lat=current_lat,
            current_lon=current_lon,
            home_lat=home_coords["latitude"],
            home_lon=home_coords["longitude"],
            prev_lat=prev_lat,
            prev_lon=prev_lon,
            prev_timestamp_iso=prev_time_iso,
            ip_lat=ip_lat,
            ip_lon=ip_lon,
        )

        amount = float(req.get("amount", 0.0))
        memo = str(req.get("memo", "")).strip()

        # Open Datadog APM trace span
        span = None
        trace_id = ""
        span_id = ""
        if TRACING_AVAILABLE:
            try:
                from ddtrace.propagation.http import HTTPPropagator
                parent_context = HTTPPropagator.extract(dict(self.headers))
                tracer.context_provider.activate(parent_context)
            except Exception:
                pass
            span = tracer.trace("risk.analyze", service=DD_SERVICE, resource="POST /api/v1/risk/analyze", span_type="web")
            trace_id = str(span.trace_id)
            span_id = str(span.span_id)

        try:
            # 1. Gate 0 Hard Rules Check
            gate0_action = None
            gate0_reason = None
            if geo_signals["is_impossible_travel"] or geo_signals["velocity_kmh"] > 1000.0:
                gate0_action = "BLOCK"
                gate0_reason = "IMPOSSIBLE_TRAVEL_VELOCITY"
            elif req.get("emulator", False) and amount >= 50000.0:
                gate0_action = "BLOCK"
                gate0_reason = "CRITICAL_DEVICE_TAMPERING_HIGH_VALUE"
            elif req.get("rooted", False) and req.get("new_payee", False) and amount >= 10000.0:
                gate0_action = "REQUIRE_2FA"
                gate0_reason = "ROOTED_NEW_DEVICE_ELEVATED_AMOUNT"

            if gate0_action:
                decision = gate0_action
                fraud_score = 100 if decision == "BLOCK" else 75
                is_anomaly = True
                anomaly_prob = 1.0 if decision == "BLOCK" else 0.75
                primary_flag = gate0_reason
                all_flags = [gate0_reason]
                status = "BLOCKED" if decision == "BLOCK" else "REQUIRE_2FA"
                review_enqueued = False
            else:
                # 2. S2 Tabular XGBoost Inference
                spike_ratio = round(amount / avg_amount, 2) if avg_amount > 0 else 1.0
                drain_ratio = round(amount / current_balance, 4) if current_balance > 0 else 0.0

                if s2_model is not None and s2_pipeline is not None:
                    row_dict = {
                        "amount_php": amount,
                        "user_avg_amount_php": avg_amount,
                        "current_balance": current_balance,
                        "balance_drain_ratio": drain_ratio,
                        "spike_ratio": spike_ratio,
                        "transactions_24h": 1,
                        "amount_sum_24h": amount,
                        "transactions_7d": 5,
                        "amount_sum_7d": amount * 2.0,
                        "payee_age_days": 180.0,
                        "payees_24h": 1,
                        "senders_to_payee_24h": 1,
                        "hour_of_day": 14,
                        "day_of_week": 2,
                        "is_weekend": False,
                        "device_age_days": 300.0,
                        "accounts_per_device": 1,
                        "os_patch_age_days": 20.0,
                        "seconds_since_login": 90.0,
                        "failed_logins_1h": 0,
                        "credential_change_hours_ago": 720.0,
                        "form_seconds": 20.0,
                        "gps_accuracy_m": 10.0,
                        "distance_from_home_km": geo_signals["distance_from_home_km"],
                        "distance_from_prev_km": geo_signals["distance_from_last_km"],
                        "elapsed_minutes": geo_signals["elapsed_minutes"],
                        "velocity_kmh": geo_signals["velocity_kmh"],
                        "new_payee": req.get("new_payee", False),
                        "device_id_new": False,
                        "rooted": req.get("rooted", False),
                        "hooking": req.get("hooking", False),
                        "emulator": req.get("emulator", False),
                        "debugger": False,
                        "tampered": req.get("tampered", False),
                        "unofficial_store": False,
                        "dev_options": False,
                        "mock_location": geo_signals["is_impossible_travel"],
                        "accessibility_active": False,
                        "screen_sharing": False,
                        "payee_pasted": False,
                        "tz_mismatch": False,
                        "ip_gps_mismatch": geo_signals["ip_discrepancy_km"] > 500.0,
                        "is_vpn": geo_signals["is_vpn_detected"],
                        "transfer_purpose": "Funds Transfer",
                        "payee_type": "third_party_individual",
                        "channel": "mobile_banking",
                        "attestation_verdict": req.get("attestation_verdict", "TRUSTED"),
                        "login_method": "biometrics"
                    }
                    import pandas as pd
                    X_df = s2_pipeline.transform(pd.DataFrame([row_dict]))
                    p_fraud = float(s2_model.predict_proba(X_df)[0, 1])
                else:
                    p_fraud = 0.05 if spike_ratio < 2.0 else 0.45

                if p_fraud >= TAU_BLOCK:
                    decision = "BLOCK"
                    status = "BLOCKED"
                elif p_fraud >= TAU_2FA:
                    decision = "REQUIRE_2FA"
                    status = "REQUIRE_2FA"
                else:
                    decision = "ALLOW"
                    status = "SETTLED"

                fraud_score = int(p_fraud * 100)
                is_anomaly = p_fraud >= TAU_2FA
                anomaly_prob = round(p_fraud, 4)
                primary_flag = "NONE" if decision == "ALLOW" else ("ELEVATED_S2_SCORE" if decision == "REQUIRE_2FA" else "CRITICAL_FRAUD_RISK")
                all_flags = [primary_flag] if primary_flag != "NONE" else []

            # 3. Synchronous Memo & Typology Analysis (powered by Laya < 0.2ms)
            memo_analysis = None
            clean_memo = memo.strip()
            if clean_memo and typology_engine is not None and getattr(typology_engine, "model_loaded", False):
                try:
                    memo_analysis = typology_engine.score_memo(
                        memo=clean_memo,
                        amount=amount,
                        payee_age_days=float(req.get("payee_age_days", 180.0)),
                        balance_drain_ratio=drain_ratio if 'drain_ratio' in locals() else 0.0,
                        spike_ratio=spike_ratio if 'spike_ratio' in locals() else 1.0
                    )
                except Exception as e:
                    print(f"[MEMO ANALYSIS ERROR] {e}", flush=True)

            # 4. Contextual Device Threat & Advisory Warning Analysis
            advisory_tier = "NONE"
            warning_dialog = None
            threat_narrative = None
            req_model = None

            is_primary_device = req.get("is_primary_device", True)
            if isinstance(req.get("device_context"), dict):
                if "is_primary_device" in req["device_context"]:
                    is_primary_device = req["device_context"]["is_primary_device"]

            threat_cat = "NONE"
            try:
                req_model = RiskAnalysisRequest(**req)
                if has_threat_context(req_model):
                    threat_narrative, threat_cat = build_threat_narrative(req_model)
                    if decision == "ALLOW":
                        decision = "ADVISORY_WARNING"
                        status = "ADVISORY_PENDING"
                        advisory_tier = "ADVISORY_WARNING"
                        wd = get_warning_dialog(threat_cat)
                        warning_dialog = wd.model_dump() if hasattr(wd, "model_dump") else wd.dict()
                        primary_flag = f"DEVICE_THREAT_{threat_cat}"
                        all_flags.append(primary_flag)
                    elif decision == "REQUIRE_2FA":
                        advisory_tier = "ADVISORY_WARNING"
                        wd = get_warning_dialog(threat_cat)
                        warning_dialog = wd.model_dump() if hasattr(wd, "model_dump") else wd.dict()
                        all_flags.append(f"DEVICE_THREAT_{threat_cat}")
                elif memo_analysis and (memo_analysis.get("is_anomaly") or memo_analysis.get("typology", "none") != "none"):
                    typology = memo_analysis.get("typology", "other")
                    threat_cat = "MEMO_SCAM_PATTERN"
                    if decision == "ALLOW":
                        decision = "ADVISORY_WARNING"
                        status = "ADVISORY_PENDING"
                        advisory_tier = "ADVISORY_WARNING"
                        wd = get_warning_dialog("MEMO_SCAM_PATTERN")
                        warning_dialog = wd.model_dump() if hasattr(wd, "model_dump") else wd.dict()
                        primary_flag = f"SCAM_TYPOLOGY_{typology.upper()}"
                        all_flags.append(primary_flag)
                    elif decision == "REQUIRE_2FA":
                        advisory_tier = "ADVISORY_WARNING"
                        wd = get_warning_dialog("MEMO_SCAM_PATTERN")
                        warning_dialog = wd.model_dump() if hasattr(wd, "model_dump") else wd.dict()
                        all_flags.append(f"SCAM_TYPOLOGY_{typology.upper()}")
            except Exception as e:
                print(f"[THREAT EVAL ERROR] {e}", flush=True)

            if threat_cat == "NONE":
                if decision == "BLOCK":
                    threat_cat = gate0_reason if gate0_reason else "CRITICAL_FRAUD"
                elif decision == "REQUIRE_2FA":
                    threat_cat = "ELEVATED_RISK"

            # 5. Laya Cause of Suspicion Synthesis
            if laya_engine_instance is not None:
                cause_of_suspicion = laya_engine_instance.determine_cause_of_suspicion(
                    threat_category=threat_cat,
                    threat_narrative=threat_narrative,
                    memo=memo,
                    geo_signals=geo_signals,
                    spike_ratio=spike_ratio if 'spike_ratio' in locals() else 1.0,
                    flags=all_flags
                )
            else:
                cause_of_suspicion = f"Evaluated fraud risk score of {fraud_score}/100 with flag {primary_flag}."

            # 6. Automated AMLC SAR/STR Draft Trigger
            sar_draft_created = False
            sar_report_id = None
            is_sar_candidate = (
                decision == "BLOCK"
                or threat_cat in ["MEMORY_HOOKING_TAMPER", "PACKET_INSPECTION_MITM", "REMOTE_ACCESS_MALWARE"]
                or fraud_score >= 80
            )
            if is_sar_candidate:
                sar_report_id = f"SAR-{datetime.now(timezone.utc).strftime('%Y%m%d')}-{tx_id}"
                dev_ctx = req.get("device_context", {}) if isinstance(req.get("device_context"), dict) else {}
                sar_tx_row = {
                    "transaction_id": tx_id,
                    "user_id": user_id,
                    "amount_php": amount,
                    "spike_ratio": spike_ratio if 'spike_ratio' in locals() else 1.0,
                    "balance_drain_ratio": drain_ratio if 'drain_ratio' in locals() else 0.0,
                    "memo": memo,
                    "velocity_kmh": geo_signals["velocity_kmh"],
                    "is_vpn": geo_signals["is_vpn_detected"],
                    "rooted": req.get("rooted", False) or dev_ctx.get("rooted", False),
                    "hooking": req.get("hooking", False) or dev_ctx.get("hooking", False) or (threat_cat == "MEMORY_HOOKING_TAMPER"),
                    "emulator": req.get("emulator", False) or dev_ctx.get("emulator", False),
                    "tampered": req.get("tampered", False),
                    "attestation_verdict": req.get("attestation_verdict", "PASS"),
                    "remote_app_active": req.get("remote_app_active", False) or dev_ctx.get("remote_app_active", False) or (threat_cat == "REMOTE_ACCESS_MALWARE"),
                    "screen_sharing": dev_ctx.get("media_projection", {}).get("is_screen_sharing", False) if isinstance(dev_ctx.get("media_projection"), dict) else False,
                    "active_call": req.get("active_call", False) or (dev_ctx.get("telephony", {}).get("call_state", "IDLE") != "IDLE" if isinstance(dev_ctx.get("telephony"), dict) else False),
                    "call_state": dev_ctx.get("telephony", {}).get("call_state", "IDLE") if isinstance(dev_ctx.get("telephony"), dict) else "IDLE",
                    "running_packages": dev_ctx.get("running_packages", []),
                    "active_accessibility_services": dev_ctx.get("active_accessibility_services", []),
                    "detected_threats": dev_ctx.get("detected_threats", []),
                    "threat_category": threat_cat,
                    "cause_of_suspicion": cause_of_suspicion,
                }
                sar_verdict = {
                    "action": decision,
                    "primary_reason": primary_flag,
                    "gate_used": "TWO_STAGE_RISK_ENGINE" if not gate0_action else "GATE_0_HARD_RULES",
                    "fraud_score": float(fraud_score),
                    "threat_category": threat_cat,
                    "cause_of_suspicion": cause_of_suspicion,
                }
                try:
                    trigger_sar_async(sar_tx_row, sar_verdict)
                    sar_draft_created = True
                except Exception as sar_err:
                    print(f"[SAR TRIGGER ERROR] {sar_err}", flush=True)

            # Enqueue Async Reviewer for enriched threat context or elevated S2 risk (ignoring memo)
            review_enqueued = False
            if decision != "BLOCK" and (threat_narrative is not None or p_fraud >= 0.15):
                narrative_payload = threat_narrative or f"Amount: PHP {amount:,.2f} | Spike: {spike_ratio:.1f}x"
                transfer_store.save_transfer(
                    transaction_id=tx_id,
                    user_id=user_id,
                    account_id=account_id,
                    target_account_id=target_account_id,
                    amount=amount,
                    memo=narrative_payload,
                    s2_action=decision,
                    s2_score=p_fraud,
                    tabular_features=row_dict if 'row_dict' in locals() else {}
                )
                review_enqueued = worker_pool.enqueue_review(
                    transaction_id=tx_id,
                    s2_action=decision,
                    s2_score=p_fraud,
                    memo=narrative_payload,
                    amount=amount,
                    tabular_data=row_dict if 'row_dict' in locals() else {}
                )

            # 7. Out-of-band & Biometric Authorization Mapping (Zero SMS OTP for Transactions)
            if decision == "BLOCK":
                auth_method = "NONE_BLOCKED"
            elif decision == "REQUIRE_2FA":
                auth_method = "STEP_UP_BIOMETRIC_PLUS_MPIN" if is_primary_device else "STEP_UP_PUSH_PLUS_MPIN"
            else:  # ALLOW or ADVISORY_WARNING
                auth_method = "BIOMETRIC_PRIMARY" if is_primary_device else "PUSH_NOTIFICATION_PRIMARY"

            elapsed_ms = (time.perf_counter() - start_time) * 1000.0

            # Attach tags to Datadog APM span
            if span:
                span.set_tag("transaction.id", tx_id)
                span.set_tag("customer.id", user_id)
                span.set_tag("account.id", account_id)
                span.set_tag("transaction.amount", amount)
                span.set_tag("transaction.memo", memo)
                span.set_tag("risk.decision", decision)
                span.set_tag("risk.status", status)
                span.set_tag("risk.review_enqueued", review_enqueued)
                span.set_tag("risk.fraud_score", fraud_score)

            # Emit Structured Datadog Output Log
            status_level = "info" if decision == "ALLOW" else "warn"
            log_payload = {
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "status": status_level,
                "service": DD_SERVICE,
                "env": DD_ENV,
                "version": DD_VERSION,
                "logger": "risk_service.transaction_output",
                "message": f"TRANSACTION_VERDICT [{decision}] [{status}] TxId={tx_id} Amount=PHP{amount:,.2f} Score={fraud_score}/100 SAR={sar_report_id}",
                "dd": {"trace_id": trace_id, "span_id": span_id},
                "transaction": {
                    "id": tx_id,
                    "account_id": account_id,
                    "user_id": user_id,
                    "amount": amount,
                    "memo": memo,
                    "decision": decision,
                    "status": status,
                    "review_enqueued": review_enqueued,
                    "fraud_score": fraud_score
                },
                "evaluation_time_ms": round(elapsed_ms, 2)
            }
            sys.stdout.write(json.dumps(log_payload) + "\n")
            sys.stdout.flush()

            return {
                "transaction_id": tx_id,
                "decision": decision,
                "status": status,
                "review_enqueued": review_enqueued,
                "settlement_window_seconds": SETTLEMENT_WINDOW_SECONDS,
                "fraud_score": fraud_score,
                "is_anomaly": is_anomaly,
                "anomaly_probability": anomaly_prob,
                "primary_flag": primary_flag,
                "all_flags": all_flags,
                "advisory_tier": advisory_tier,
                "warning_dialog": warning_dialog,
                "threat_narrative": threat_narrative,
                "threat_category": threat_cat,
                "cause_of_suspicion": cause_of_suspicion,
                "sar_draft_created": sar_draft_created,
                "sar_report_id": sar_report_id,
                "auth_method": auth_method,
                "metrics": {
                    "distance_from_home_km": geo_signals["distance_from_home_km"],
                    "velocity_kmh": geo_signals["velocity_kmh"],
                    "is_impossible_travel": geo_signals["is_impossible_travel"],
                    "is_vpn_detected": geo_signals["is_vpn_detected"],
                    "spike_ratio": spike_ratio if 'spike_ratio' in locals() else 1.0
                },
                "customer_summary": {
                    "user_id": customer.get("user_id"),
                    "full_name": customer.get("full_name"),
                    "average_transfer": avg_amount,
                    "home_location": home_coords.get("label", "Unknown")
                },
                "evaluation_time_ms": round(elapsed_ms, 2),
                "memo_analysis": memo_analysis
            }
        finally:
            if span:
                span.finish()

    def _handle_simulate(self, scenario_name: str) -> Dict[str, Any]:
        scenarios = {
            "normal": {
                "user_id": "usr-1001-cst-001",
                "account_id": "acc-2001-sav-001",
                "target_account_id": "acc-2002-chk-001",
                "amount": 1500.00,
                "memo": "lunch payment",
                "latitude": 14.5547,
                "longitude": 121.0200
            },
            "impossible_travel": {
                "user_id": "usr-1003-cst-003",
                "account_id": "acc-2003-sav-002",
                "target_account_id": "acc-2001-sav-001",
                "amount": 15000.00,
                "memo": "business transfer",
                "latitude": 1.3521,
                "longitude": 103.8198
            },
            "scam_memo": {
                "user_id": "usr-1002-cst-002",
                "account_id": "acc-2002-chk-001",
                "target_account_id": "acc-2001-sav-001",
                "amount": 38000.00,
                "memo": "urgent crypto release fee for investment profit",
                "latitude": 14.6760,
                "longitude": 121.0437
            }
        }
        if scenario_name not in scenarios:
            return {"error": f"Unknown scenario '{scenario_name}'. Valid: {list(scenarios.keys())}"}
        return self._handle_analyze(scenarios[scenario_name])


def run_server(port: int = 8084):
    server_address = ("0.0.0.0", port)
    httpd = ThreadingHTTPServer(server_address, RiskRequestHandler)
    print(f"[STARTUP] Decoupled Risk Engine listening on port {port} (Datadog APM={TRACING_AVAILABLE})...", flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("[SHUTDOWN] Stopping risk engine...", flush=True)
        worker_pool.shutdown()
        httpd.server_close()


if __name__ == "__main__":
    run_server(8084)
