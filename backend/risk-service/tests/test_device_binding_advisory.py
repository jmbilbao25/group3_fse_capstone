"""
Unit and Integration Tests for Device Binding, Advisory Warnings, and Zero SMS OTP Transaction Security.

Validates:
1. Routine transfer on primary device -> ALLOW, auth_method=BIOMETRIC_PRIMARY.
2. Routine transfer on secondary device -> ALLOW, auth_method=PUSH_NOTIFICATION_PRIMARY.
3. Blank memo + AnyDesk remote access -> ADVISORY_WARNING, auth_method=BIOMETRIC_PRIMARY, warning_dialog populated.
4. Blank memo + Active phone call -> ADVISORY_WARNING, auth_method=BIOMETRIC_PRIMARY, warning_dialog populated.
5. Purpose mismatch (Bills payment to personal account) -> ADVISORY_WARNING.
6. Impossible travel velocity -> BLOCK, auth_method=NONE_BLOCKED.
7. Elevated tabular risk -> REQUIRE_2FA, auth_method=STEP_UP_BIOMETRIC_PLUS_MPIN (primary) or STEP_UP_PUSH_PLUS_MPIN (secondary).
8. NanoJev direct engine evaluation with threat narrative and category.
"""

import os
import sys
import pytest
from starlette.testclient import TestClient

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
_SERVICE_ROOT = os.path.join(_REPO_ROOT, "backend", "risk-service")
if _SERVICE_ROOT not in sys.path:
    sys.path.insert(0, _SERVICE_ROOT)
if _REPO_ROOT not in sys.path:
    sys.path.insert(0, _REPO_ROOT)

from app.main import app
from app.nanojev_engine import NanoJevEngine
from app.threat_builder import has_threat_context, detect_threat_category, build_threat_narrative
from app.models import (
    RiskAnalysisRequest,
    DeviceThreatContext,
    MediaProjectionState,
    TelephonyState,
    InteractionContext,
    CounterpartyContext
)

client = TestClient(app)


def test_routine_transfer_primary_device():
    """Clean transfer on primary device requires local biometric authentication."""
    payload = {
        "user_id": "usr-1001-cst-001",
        "account_id": "acc-2001-sav-001",
        "target_account_id": "acc-2002-chk-001",
        "amount": 1200.0,
        "memo": "grocery payment",
        "latitude": 14.5995,
        "longitude": 120.9842,
        "is_primary_device": True
    }
    resp = client.post("/api/v1/risk/analyze", json=payload)
    assert resp.status_code == 200
    data = resp.json()

    assert data["decision"] == "ALLOW"
    assert data["auth_method"] == "BIOMETRIC_PRIMARY"
    assert data["advisory_tier"] == "NONE"
    assert data["warning_dialog"] is None


def test_routine_transfer_secondary_device():
    """Clean transfer on secondary device dispatches push notification to primary device."""
    payload = {
        "user_id": "usr-1001-cst-001",
        "account_id": "acc-2001-sav-001",
        "target_account_id": "acc-2002-chk-001",
        "amount": 1200.0,
        "memo": "utility payment",
        "latitude": 14.5995,
        "longitude": 120.9842,
        "is_primary_device": False
    }
    resp = client.post("/api/v1/risk/analyze", json=payload)
    assert resp.status_code == 200
    data = resp.json()

    assert data["decision"] == "ALLOW"
    assert data["auth_method"] == "PUSH_NOTIFICATION_PRIMARY"
    assert data["advisory_tier"] == "NONE"


def test_blank_memo_with_anydesk_triggers_advisory_warning():
    """Blank memo with active AnyDesk triggers ADVISORY_WARNING, preserving warning-only policy."""
    payload = {
        "user_id": "usr-1001-cst-001",
        "account_id": "acc-2001-sav-001",
        "target_account_id": "acc-2002-chk-001",
        "amount": 1500.0,
        "memo": "",  # Blank memo
        "latitude": 14.5995,
        "longitude": 120.9842,
        "is_primary_device": True,
        "device_context": {
            "device_model": "Xiaomi Redmi 9A",
            "is_primary_device": True,
            "active_accessibility_services": [
                "com.anydesk.anydeskandroid",
                "accessibility_remote_support"
            ],
            "media_projection": {
                "is_screen_sharing": True,
                "virtual_display_count": 1
            }
        }
    }
    resp = client.post("/api/v1/risk/analyze", json=payload)
    assert resp.status_code == 200
    data = resp.json()

    assert data["decision"] == "ADVISORY_WARNING"
    assert data["advisory_tier"] == "ADVISORY_WARNING"
    assert data["auth_method"] == "BIOMETRIC_PRIMARY"
    assert data["warning_dialog"] is not None
    assert data["warning_dialog"]["threat_category"] == "REMOTE_ACCESS_MALWARE"
    assert "screen" in data["warning_dialog"]["body_message"].lower()


def test_active_phone_call_triggers_advisory_warning():
    """Active phone call during fund transfer triggers live call coercion warning."""
    payload = {
        "user_id": "usr-1001-cst-001",
        "account_id": "acc-2001-sav-001",
        "target_account_id": "acc-2002-chk-001",
        "amount": 2500.0,
        "memo": "",
        "latitude": 14.5995,
        "longitude": 120.9842,
        "is_primary_device": True,
        "device_context": {
            "is_primary_device": True,
            "telephony": {
                "call_state": "CALL_STATE_OFFHOOK",
                "call_duration_seconds": 180.0
            }
        }
    }
    resp = client.post("/api/v1/risk/analyze", json=payload)
    assert resp.status_code == 200
    data = resp.json()

    assert data["decision"] == "ADVISORY_WARNING"
    assert data["advisory_tier"] == "ADVISORY_WARNING"
    assert data["warning_dialog"] is not None
    assert data["warning_dialog"]["threat_category"] == "LIVE_CALL_COERCION"
    assert "call" in data["warning_dialog"]["title"].lower()


def test_purpose_and_account_mismatch():
    """Bills payment sent to a personal savings account triggers mismatch warning."""
    payload = {
        "user_id": "usr-1001-cst-001",
        "account_id": "acc-2001-sav-001",
        "target_account_id": "acc-2002-chk-001",
        "amount": 3500.0,
        "latitude": 14.5995,
        "longitude": 120.9842,
        "is_primary_device": True,
        "counterparty_context": {
            "transfer_purpose": "BILLS_PAYMENT",
            "payee_account_type": "INDIVIDUAL_SAVINGS",
            "payee_age_hours": 12.0
        }
    }
    resp = client.post("/api/v1/risk/analyze", json=payload)
    assert resp.status_code == 200
    data = resp.json()

    assert data["decision"] == "ADVISORY_WARNING"
    assert data["advisory_tier"] == "ADVISORY_WARNING"
    assert data["warning_dialog"]["threat_category"] == "PURPOSE_ACCOUNT_MISMATCH"


def test_impossible_travel_remains_hard_block():
    """Gate 0 impossible travel remains an unprompted hard BLOCK."""
    payload = {
        "user_id": "usr-1003-cst-003",
        "account_id": "acc-2003-sav-002",
        "target_account_id": "acc-2001-sav-001",
        "amount": 15000.0,
        "latitude": 1.3521,  # Singapore coordinates vs home in Manila
        "longitude": 103.8198,
        "is_primary_device": True
    }
    resp = client.post("/api/v1/risk/analyze", json=payload)
    assert resp.status_code == 200
    data = resp.json()

    assert data["decision"] == "BLOCK"
    assert data["auth_method"] == "NONE_BLOCKED"


def test_step_up_auth_methods_by_device_role():
    """Elevated risk requires step-up (Biometric + MPIN on primary, Push + MPIN on secondary)."""
    # Primary device
    payload_primary = {
        "user_id": "usr-1001-cst-001",
        "account_id": "acc-2001-sav-001",
        "target_account_id": "acc-2002-chk-001",
        "amount": 25000.0,
        "latitude": 14.5995,
        "longitude": 120.9842,
        "rooted": True,
        "new_payee": True,
        "is_primary_device": True
    }
    resp_pri = client.post("/api/v1/risk/analyze", json=payload_primary)
    assert resp_pri.status_code == 200
    data_pri = resp_pri.json()
    assert data_pri["decision"] == "REQUIRE_2FA"
    assert data_pri["auth_method"] == "STEP_UP_BIOMETRIC_PLUS_MPIN"

    # Secondary device
    payload_secondary = dict(payload_primary)
    payload_secondary["is_primary_device"] = False
    resp_sec = client.post("/api/v1/risk/analyze", json=payload_secondary)
    assert resp_sec.status_code == 200
    data_sec = resp_sec.json()
    assert data_sec["decision"] == "REQUIRE_2FA"
    assert data_sec["auth_method"] == "STEP_UP_PUSH_PLUS_MPIN"


def test_nanojev_engine_direct_advisory_warning():
    """NanoJev engine evaluates threat narrative and produces ADVISORY_WARNING."""
    engine = NanoJevEngine()
    req = RiskAnalysisRequest(
        account_id="acc-2001-sav-001",
        target_account_id="acc-2002-chk-001",
        amount=2000.0,
        memo="",
        device_context=DeviceThreatContext(
            device_model="Infinix Hot 11",
            active_accessibility_services=["com.teamviewer.host.market"],
            media_projection=MediaProjectionState(is_screen_sharing=True)
        )
    )
    narrative, category = build_threat_narrative(req)
    assert category == "REMOTE_ACCESS_MALWARE"
    assert "Screen Mirroring: ACTIVE" in narrative

    result = engine.evaluate(
        amount=2000.0,
        avg_amount=2000.0,
        memo="",
        geo_signals={"is_impossible_travel": False, "distance_from_home_km": 1.0, "is_vpn_detected": False},
        threat_narrative=narrative,
        threat_category=category
    )
    assert result["decision"] == "ADVISORY_WARNING"
    assert result["advisory_tier"] == "ADVISORY_WARNING"
    assert result["warning_dialog"] is not None
    assert result["warning_dialog"]["threat_category"] == "REMOTE_ACCESS_MALWARE"
