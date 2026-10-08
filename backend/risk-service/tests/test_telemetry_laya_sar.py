"""
Integration tests for enriched telemetry (AnyDesk, HTTP Canary, Frida/Xposed),
Laya threat categorization and cause of suspicion synthesis, and automated
AMLC SAR/STR compliance report drafting.
"""

import os
import sys
import json
import pytest
from starlette.testclient import TestClient

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
_SERVICE_ROOT = os.path.join(_REPO_ROOT, "backend", "risk-service")
if _SERVICE_ROOT not in sys.path:
    sys.path.insert(0, _SERVICE_ROOT)
if _REPO_ROOT not in sys.path:
    sys.path.insert(0, _REPO_ROOT)

from app.main import app
from hybrid_bench.sar_generator import format_sar_document, generate_sar_sync

client = TestClient(app)


def test_anydesk_telemetry_triggers_threat_and_sar():
    """
    Simulates a mobile transfer attempt while com.anydesk.anydeskandroid is running.
    Verifies that:
    1. Threat category is classified as REMOTE_ACCESS_MALWARE.
    2. Contextual warning dialog is populated for remote app detection.
    3. Laya identifies the cause of suspicion related to remote desktop/screen broadcasting.
    4. An automated AMLC SAR/STR draft is created and referenced.
    """
    payload = {
        "transaction_id": "TX-TEST-ANYDESK-001",
        "user_id": "USR-1001",
        "account_id": "acc-2001-sav-001",
        "target_account_id": "acc-2002-chk-001",
        "amount": 25000.0,
        "memo": "urgent transfer",
        "latitude": 14.5995,
        "longitude": 120.9842,
        "remote_app_active": True,
        "device_context": {
            "running_packages": ["com.anydesk.anydeskandroid", "com.android.chrome"],
            "active_accessibility_services": ["com.anydesk.anydeskandroid/.AnyDeskAccessibilityService"],
            "media_projection": {
                "is_screen_sharing": True,
                "virtual_display_count": 1
            }
        }
    }

    res = client.post("/api/v1/risk/analyze", json=payload)
    assert res.status_code == 200
    data = res.json()

    assert data["decision"] in ["ADVISORY_WARNING", "REQUIRE_2FA", "BLOCK"]
    assert data["threat_category"] == "REMOTE_ACCESS_MALWARE"
    assert "remote" in data["cause_of_suspicion"].lower() or "screen" in data["cause_of_suspicion"].lower()
    assert data["warning_dialog"] is not None
    assert data["warning_dialog"]["threat_category"] == "REMOTE_ACCESS_MALWARE"
    assert data["sar_draft_created"] is True
    assert data["sar_report_id"] is not None
    assert "TX-TEST-ANYDESK-001" in data["sar_report_id"]


def test_http_canary_mitm_inspection_triggers_threat_and_sar():
    """
    Simulates transfer request with packet capture / proxy utility (HTTP Canary).
    Verifies PACKET_INSPECTION_MITM classification, Laya cause of suspicion, and SAR generation.
    """
    payload = {
        "transaction_id": "TX-TEST-CANARY-002",
        "user_id": "USR-1001",
        "account_id": "acc-2001-sav-001",
        "target_account_id": "acc-2002-chk-001",
        "amount": 15000.0,
        "latitude": 14.5995,
        "longitude": 120.9842,
        "device_context": {
            "running_packages": ["com.guoshi.httpcanary", "com.android.vending"],
            "detected_threats": ["Network proxy / packet inspection tool active: com.guoshi.httpcanary"]
        }
    }

    res = client.post("/api/v1/risk/analyze", json=payload)
    assert res.status_code == 200
    data = res.json()

    assert data["threat_category"] == "PACKET_INSPECTION_MITM"
    assert "interception" in data["cause_of_suspicion"].lower() or "packet" in data["cause_of_suspicion"].lower()
    assert data["warning_dialog"] is not None
    assert data["warning_dialog"]["threat_category"] == "PACKET_INSPECTION_MITM"
    assert data["sar_draft_created"] is True
    assert data["sar_report_id"] is not None


def test_frida_memory_hooking_triggers_threat_and_sar():
    """
    Simulates transfer request where dynamic binary instrumentation (Frida / Xposed) is detected.
    Verifies MEMORY_HOOKING_TAMPER classification, Laya cause of suspicion, and SAR generation.
    """
    payload = {
        "transaction_id": "TX-TEST-FRIDA-003",
        "user_id": "USR-1001",
        "account_id": "acc-2001-sav-001",
        "target_account_id": "acc-2002-chk-001",
        "amount": 10000.0,
        "hooking": True,
        "latitude": 14.5995,
        "longitude": 120.9842,
        "device_context": {
            "hooking": True,
            "detected_threats": ["Frida Dynamic Instrumentation Server Detected on port 27042"]
        }
    }

    res = client.post("/api/v1/risk/analyze", json=payload)
    assert res.status_code == 200
    data = res.json()

    assert data["threat_category"] == "MEMORY_HOOKING_TAMPER"
    assert "memory" in data["cause_of_suspicion"].lower() or "instrumentation" in data["cause_of_suspicion"].lower()
    assert data["warning_dialog"] is not None
    assert data["warning_dialog"]["threat_category"] == "MEMORY_HOOKING_TAMPER"
    assert data["sar_draft_created"] is True
    assert data["sar_report_id"] is not None


def test_active_phone_call_coercion_threat():
    """
    Simulates transfer request during an active phone call to a newly added payee.
    Verifies LIVE_CALL_COERCION classification and Laya cause of suspicion.
    """
    payload = {
        "transaction_id": "TX-TEST-CALL-004",
        "user_id": "USR-1001",
        "account_id": "acc-2001-sav-001",
        "target_account_id": "acc-2002-chk-001",
        "amount": 5000.0,
        "active_call": True,
        "latitude": 14.5995,
        "longitude": 120.9842,
        "device_context": {
            "telephony": {
                "call_state": "CALL_STATE_OFFHOOK",
                "call_duration_seconds": 180.0
            }
        }
    }

    res = client.post("/api/v1/risk/analyze", json=payload)
    assert res.status_code == 200
    data = res.json()

    assert data["threat_category"] == "LIVE_CALL_COERCION"
    assert "phone" in data["cause_of_suspicion"].lower() or "call" in data["cause_of_suspicion"].lower() or "coercion" in data["cause_of_suspicion"].lower()
    assert data["warning_dialog"] is not None
    assert data["warning_dialog"]["threat_category"] == "LIVE_CALL_COERCION"


def test_sar_document_formatting_content():
    """
    Verifies that the generated AMLC SAR document includes:
    1. AMLC Republic Act No. 9160 / 11521 reference.
    2. Laya Non-Autoregressive Decision Engine as evaluator.
    3. Categorized threat and cause of suspicion.
    4. Technical telemetry on AnyDesk, HTTP Canary, and Frida.
    """
    tx = {
        "transaction_id": "TX-SAR-VERIFY-101",
        "user_id": "usr-1001-cst-001",
        "amount": 75000.0,
        "user_avg_amount_php": 2000.0,
        "spike_ratio": 37.5,
        "balance_drain_ratio": 0.90,
        "memo": "urgent processing fee unlock crypto",
        "running_packages": ["com.anydesk.anydeskandroid", "com.guoshi.httpcanary"],
        "screen_sharing": True,
        "active_call": True,
        "call_state": "CALL_STATE_OFFHOOK",
        "hooking": True,
        "threat_category": "REMOTE_ACCESS_MALWARE",
        "cause_of_suspicion": "Remote screen broadcast or control assistance application actively operating during financial movement."
    }
    verdict = {
        "action": "BLOCK",
        "primary_reason": "CRITICAL_FRAUD_DETECTED",
        "fraud_score": 98.0,
        "threat_category": "REMOTE_ACCESS_MALWARE",
        "cause_of_suspicion": tx["cause_of_suspicion"]
    }

    doc = format_sar_document(tx, verdict)

    assert "Anti-Money Laundering Council (AMLC) - Republic Act No. 9160 / 11521" in doc
    assert "Evaluator: Laya Non-Autoregressive System 1 Decision Engine" in doc
    assert "Threat Category: REMOTE_ACCESS_MALWARE" in doc
    assert "Cause of Suspicion:" in doc
    assert "Remote screen broadcast" in doc
    assert "Screen Sharing Broadcast: ACTIVE" in doc
    assert "Memory Hooking Tool: DETECTED" in doc
    assert "Network Packet Sniffer: DETECTED" in doc
    assert "Remote Desktop Tool: DETECTED" in doc
    assert "Telephony State: ACTIVE_CALL" in doc
