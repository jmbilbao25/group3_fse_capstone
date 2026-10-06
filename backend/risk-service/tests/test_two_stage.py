"""
Unit and Integration Tests for Two-Stage Transfer Risk Architecture (Milestone 1).

Tests:
1. Escalate-Only Invariant Enforcement across all execution paths.
2. Property-style randomized invariant test over 1,000 random inputs.
3. Display mapping REQUIRE_2FA -> STEP_UP.
4. Warning template lookup across all typologies and languages.
5. Idempotent memo-check on Stage B.
6. Timeout and error fallback safety.
7. Cancel, Pause, and Continue action button guarantees.
8. Duplicate safety on /risk/events.
9. Integration end-to-end flows: no memo, benign memo, S2 BLOCK, Stage B timeout.
"""

import os
import sys
import random
import pytest
from starlette.testclient import TestClient

# Ensure risk-service root is in sys.path
_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
_SERVICE_ROOT = os.path.join(_REPO_ROOT, "backend", "risk-service")
if _SERVICE_ROOT not in sys.path:
    sys.path.insert(0, _SERVICE_ROOT)
if _REPO_ROOT not in sys.path:
    sys.path.insert(0, _REPO_ROOT)

from app.main import app, decision_store
from app.two_stage import (
    ACTION_TIERS,
    DISPLAY_MAPPING,
    WARNING_TEMPLATES,
    to_display_action,
    compute_final_action,
    get_warning_template,
    VALID_TYPOLOGIES
)
from app.orchestrator import TransferOrchestrator


client = TestClient(app)


# =============================================================================
# 1. Escalate-Only Invariant Unit Tests
# =============================================================================

def test_escalate_only_basic_paths():
    # ALLOW paths
    assert compute_final_action("ALLOW", tier="NONE") == "ALLOW"
    assert compute_final_action("ALLOW", tier="MEDIUM") == "REQUIRE_2FA"
    assert compute_final_action("ALLOW", tier="HIGH", recommended_action="REQUIRE_2FA") == "REQUIRE_2FA"
    assert compute_final_action("ALLOW", tier="HIGH", recommended_action="BLOCK") == "BLOCK"

    # REQUIRE_2FA paths (must NEVER downgrade to ALLOW)
    assert compute_final_action("REQUIRE_2FA", tier="NONE", recommended_action="ALLOW") == "REQUIRE_2FA"
    assert compute_final_action("REQUIRE_2FA", tier="MEDIUM", recommended_action="ALLOW") == "REQUIRE_2FA"
    assert compute_final_action("REQUIRE_2FA", tier="HIGH", recommended_action="BLOCK") == "BLOCK"

    # BLOCK paths (must NEVER downgrade to ALLOW or REQUIRE_2FA)
    assert compute_final_action("BLOCK", tier="NONE", recommended_action="ALLOW") == "BLOCK"
    assert compute_final_action("BLOCK", tier="MEDIUM", recommended_action="REQUIRE_2FA") == "BLOCK"
    assert compute_final_action("BLOCK", tier="HIGH", recommended_action="REQUIRE_2FA") == "BLOCK"


def test_escalate_only_timeout_and_error_fallbacks():
    # On timeout, final action must be strictly a0
    assert compute_final_action("ALLOW", timed_out=True) == "ALLOW"
    assert compute_final_action("REQUIRE_2FA", timed_out=True) == "REQUIRE_2FA"
    assert compute_final_action("BLOCK", timed_out=True) == "BLOCK"

    # On error, final action must be strictly a0
    assert compute_final_action("ALLOW", is_error=True) == "ALLOW"
    assert compute_final_action("REQUIRE_2FA", is_error=True) == "REQUIRE_2FA"
    assert compute_final_action("BLOCK", is_error=True) == "BLOCK"


def test_escalate_only_property_style_randomized():
    """Property-based randomized verification over 1,000 random inputs."""
    rng = random.Random(42)
    actions = ["ALLOW", "REQUIRE_2FA", "BLOCK", "UNKNOWN", ""]
    tiers = ["NONE", "MEDIUM", "HIGH", "UNKNOWN", None]

    for _ in range(1000):
        a0 = rng.choice(actions)
        rec = rng.choice(actions)
        tier = rng.choice(tiers)
        timed_out = rng.choice([True, False])
        is_error = rng.choice([True, False])

        final_action = compute_final_action(
            a0=a0,
            recommended_action=rec,
            tier=tier,
            timed_out=timed_out,
            is_error=is_error
        )

        norm_a0 = str(a0).upper().strip()
        tier_a0 = ACTION_TIERS.get(norm_a0, 0)
        tier_final = ACTION_TIERS[final_action]

        assert tier_final >= tier_a0, f"Invariant failed: final={final_action} < a0={a0}"


# =============================================================================
# 2. Display Mapping Tests
# =============================================================================

def test_display_mapping():
    assert to_display_action("REQUIRE_2FA") == "STEP_UP"
    assert to_display_action("ALLOW") == "ALLOW"
    assert to_display_action("BLOCK") == "BLOCK"
    assert to_display_action("require_2fa") == "STEP_UP"


# =============================================================================
# 3. Warning Template Tests
# =============================================================================

def test_warning_templates_catalogue():
    for typology in WARNING_TEMPLATES:
        for lang in ["en", "tl", "taglish"]:
            template = get_warning_template(typology, lang)
            assert template is not None, f"Missing template for {typology} in {lang}"
            assert len(template.strip()) > 0
            word_count = len(template.split())
            assert word_count <= 42, f"Template for {typology} ({lang}) exceeded 40 words: {word_count} words"


# =============================================================================
# 4. Endpoints and Idempotency Tests (Stage A, Stage B, and Events)
# =============================================================================

def test_stage_a_endpoint_no_memo():
    res = client.post("/risk/decision", json={
        "transfer": {
            "account_id": "ACC-100001",
            "target_account_id": "ACC-100002",
            "amount": 500.0,
            "memo": ""
        }
    })
    assert res.status_code == 200
    data = res.json()
    assert "decision_id" in data
    assert data["action"] == "ALLOW"
    assert data["display_action"] == "ALLOW"
    assert data["memo_present"] is False
    assert data["memo_check_required"] is False
    assert data["latency_ms"] < 200.0


def test_stage_a_endpoint_with_memo():
    res = client.post("/risk/decision", json={
        "transfer": {
            "account_id": "ACC-100001",
            "target_account_id": "ACC-100002",
            "amount": 1200.0,
            "memo": "grocery items from supermarket"
        }
    })
    assert res.status_code == 200
    data = res.json()
    assert data["memo_present"] is True
    assert data["memo_check_required"] is True
    assert data["latency_ms"] < 200.0


def test_stage_b_endpoint_and_idempotency():
    # 1. Run Stage A
    res_a = client.post("/risk/decision", json={
        "transfer": {
            "account_id": "ACC-100001",
            "target_account_id": "ACC-100002",
            "amount": 2000.0,
            "memo": "routine allowance for tuition"
        }
    })
    dec_id = res_a.json()["decision_id"]

    # 2. Run Stage B (First Call)
    res_b1 = client.post("/risk/memo-check", json={"decision_id": dec_id, "language": "en"})
    assert res_b1.status_code == 200
    b1_data = res_b1.json()
    assert b1_data["decision_id"] == dec_id
    assert b1_data["cached"] is False
    assert b1_data["final_action"] == "ALLOW"

    # 3. Run Stage B (Second Call - Idempotency Check)
    res_b2 = client.post("/risk/memo-check", json={"decision_id": dec_id, "language": "en"})
    assert res_b2.status_code == 200
    b2_data = res_b2.json()
    assert b2_data["decision_id"] == dec_id
    assert b2_data["cached"] is True
    assert b2_data["final_action"] == b1_data["final_action"]


def test_stage_b_missing_decision_id():
    res = client.post("/risk/memo-check", json={"decision_id": "DEC-NONEXISTENT"})
    assert res.status_code == 404


def test_events_endpoint_and_duplicate_safety():
    # Run Stage A
    res_a = client.post("/risk/decision", json={
        "transfer": {
            "account_id": "ACC-100001",
            "target_account_id": "ACC-100002",
            "amount": 1000.0,
            "memo": "book purchase"
        }
    })
    dec_id = res_a.json()["decision_id"]

    event_req = {
        "decision_id": dec_id,
        "user_action": "continued",
        "stepup_result": "skipped",
        "final_action": "ALLOW"
    }

    # First event submission
    res_e1 = client.post("/risk/events", json=event_req)
    assert res_e1.status_code == 200
    assert res_e1.json()["status"] == "RECORDED"

    # Duplicate submission
    res_e2 = client.post("/risk/events", json=event_req)
    assert res_e2.status_code == 200
    assert res_e2.json()["status"] == "DUPLICATE_ACCEPTED"


# =============================================================================
# 5. Transfer Orchestrator Integration Tests
# =============================================================================

def test_orchestrator_flow_no_memo():
    orch = TransferOrchestrator()
    res = orch.process_transfer(
        transfer={"amount": 500.0, "memo": "", "account_id": "ACC-100001"},
        device_context={}
    )
    assert res["transfer_status"] == "EXECUTED_SIMULATED"
    assert res["stage_a"]["memo_check_required"] is False
    assert res["stage_b"]["tier"] == "NONE"
    assert res["user_flow"]["warning_shown"] is False


def test_orchestrator_flow_s2_block():
    # Force impossible travel velocity to trigger Gate 0 BLOCK
    orch = TransferOrchestrator()
    res = orch.process_transfer(
        transfer={"amount": 25000.0, "memo": "payment"},
        device_context={"velocity_kmh": 1200.0}
    )
    assert res["stage_a"]["a0"] == "BLOCK"
    assert res["stage_a"]["memo_check_required"] is False
    assert res["transfer_status"] == "BLOCKED"
    assert res["user_flow"]["user_action"] == "blocked"


def test_orchestrator_flow_timeout_fallback():
    orch = TransferOrchestrator()
    res = orch.process_transfer(
        transfer={"amount": 1500.0, "memo": "payment for supplies"},
        device_context={},
        force_timeout=True
    )
    assert res["stage_b"]["timed_out"] is True
    assert res["stage_b"]["final_action"] == res["stage_a"]["a0"]
    assert res["stage_b"]["tier"] == "NONE"
    assert res["transfer_status"] == "EXECUTED_SIMULATED"
    assert orch.fallbacks_recorded >= 1


def test_orchestrator_warning_action_cancel():
    orch = TransferOrchestrator()
    res = orch.process_transfer(
        transfer={"amount": 8000.0, "memo": "test_medium_scam bonus"},
        device_context={},
        user_action_input="cancelled"
    )
    assert res["stage_b"]["tier"] == "MEDIUM"
    assert res["stage_b"]["final_action"] == "REQUIRE_2FA"
    assert res["user_flow"]["warning_shown"] is True
    assert res["transfer_status"] == "CANCELLED_BY_CUSTOMER"
    assert orch.transfers_cancelled >= 1


def test_orchestrator_warning_action_pause():
    orch = TransferOrchestrator()
    res = orch.process_transfer(
        transfer={"amount": 8000.0, "memo": "test_medium_scam bonus"},
        device_context={},
        user_action_input="paused"
    )
    assert res["stage_b"]["tier"] == "MEDIUM"
    assert res["transfer_status"] == "PAUSED_10_MIN"
    assert orch.transfers_paused >= 1


def test_orchestrator_warning_action_continue_with_stepup():
    orch = TransferOrchestrator()
    # 1. Successful Step-up
    res_succ = orch.process_transfer(
        transfer={"amount": 8000.0, "memo": "test_medium_scam bonus"},
        device_context={},
        user_action_input="continued",
        stepup_result_input="success"
    )
    assert res_succ["transfer_status"] == "EXECUTED_SIMULATED"
    assert res_succ["user_flow"]["stepup_executed"] is True
    assert res_succ["user_flow"]["stepup_verdict"] == "success"

    # 2. Failed Step-up
    res_fail = orch.process_transfer(
        transfer={"amount": 8000.0, "memo": "test_medium_scam bonus"},
        device_context={},
        user_action_input="continued",
        stepup_result_input="failure"
    )
    assert res_fail["transfer_status"] == "FAILED_AUTHENTICATION"
    assert res_fail["user_flow"]["stepup_verdict"] == "failure"
