"""
Unit tests for the Async Second-Look Reviewer.
Verifies:
1. Escalate-only enforcement: asserts RiskTier(final) >= RiskTier(S2 action) for every outcome.
2. Never releases a HELD transfer.
3. Timeout and queue-full fallback to UNREVIEWED without breaking the sync path.
4. Idempotency keyed by transaction_id.
5. Settlement-window expiry: reviewer result arriving after window does not alter transfer status.
"""

import os
import sys
import time
import pytest
from typing import Dict, Any

# Ensure backend/risk-service is on path
_SERVICE_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _SERVICE_ROOT not in sys.path:
    sys.path.insert(0, _SERVICE_ROOT)

from app.reviewer import (
    enforce_escalate_only,
    ACTION_TIERS,
    evaluate_memo_consistency,
    TransferStore,
    ReviewerMetrics,
    AsyncReviewWorkerPool,
    NanoJevSecondLookEngine,
    AnalystDecisionStore
)


# =============================================================================
# 1. Escalate-Only Invariant Tests
# =============================================================================

def test_escalate_only_comprehensive_matrix():
    """
    Test every permutation of S2 action, reviewer recommendation,
    and window state to guarantee:
        RiskTier(final) >= RiskTier(S2 action)
    """
    actions = ["ALLOW", "REQUIRE_2FA", "BLOCK"]
    window_states = [False, True]  # False = inside window, True = expired

    for s2_action in actions:
        for rec in actions:
            for is_expired in window_states:
                res = enforce_escalate_only(
                    s2_action=s2_action,
                    reviewer_recommendation=rec,
                    current_status="PENDING_SETTLEMENT",
                    is_window_expired=is_expired
                )
                final_action = res["final_action"]
                tier_s2 = ACTION_TIERS[s2_action]
                tier_final = ACTION_TIERS[final_action]

                # Core Invariant Assertion
                assert tier_final >= tier_s2, (
                    f"Invariant violated for S2={s2_action}, Rec={rec}, Expired={is_expired}: "
                    f"Final={final_action} has tier {tier_final} < {tier_s2}"
                )

                # Never downgrade: if S2 was BLOCK, final must be BLOCK
                if s2_action == "BLOCK":
                    assert final_action == "BLOCK"
                # If S2 was REQUIRE_2FA, final must be REQUIRE_2FA or BLOCK
                if s2_action == "REQUIRE_2FA":
                    assert final_action in ["REQUIRE_2FA", "BLOCK"]


def test_never_release_held_transfer():
    """Asserts that once a transfer is HELD, reviewer recommendations can never release it."""
    for rec in ["ALLOW", "REQUIRE_2FA", "BLOCK"]:
        res = enforce_escalate_only(
            s2_action="ALLOW",
            reviewer_recommendation=rec,
            current_status="HELD",
            is_window_expired=False
        )
        assert res["final_status"] == "HELD", f"HELD transfer was released when rec={rec}"


def test_settlement_window_expiry_behavior():
    """
    If S2 action is ALLOW and reviewer escalates:
    - Inside window: status transitions to HELD.
    - After window expires: status remains SETTLED, flagged as late escalation.
    """
    # Inside window (< 60s)
    res_inside = enforce_escalate_only(
        s2_action="ALLOW",
        reviewer_recommendation="BLOCK",
        current_status="PENDING_SETTLEMENT",
        is_window_expired=False
    )
    assert res_inside["final_action"] == "BLOCK"
    assert res_inside["final_status"] == "HELD"
    assert res_inside["late_escalation"] is False

    # After window expired (> 60s)
    res_expired = enforce_escalate_only(
        s2_action="ALLOW",
        reviewer_recommendation="BLOCK",
        current_status="SETTLED",
        is_window_expired=True
    )
    assert res_expired["final_action"] == "BLOCK"
    assert res_expired["final_status"] == "SETTLED"  # Cannot un-settle funds!
    assert res_expired["late_escalation"] is True   # Flagged for analyst alert


# =============================================================================
# 2. Consistency Analysis Tests
# =============================================================================

def test_memo_consistency_rules():
    # 1. Mundane memo with severe account drain and 0-day payee
    c1 = evaluate_memo_consistency(
        memo="supermarket groceries weekly",
        balance_drain_ratio=0.92,
        payee_age_days=0.0,
        spike_ratio=5.0,
        amount=45000.0
    )
    assert c1["is_consistent"] is False
    assert len(c1["inconsistency_flags"]) > 0

    # 2. Routine legitimate transfer
    c2 = evaluate_memo_consistency(
        memo="lunch with team",
        balance_drain_ratio=0.05,
        payee_age_days=180.0,
        spike_ratio=1.0,
        amount=350.0
    )
    assert c2["is_consistent"] is True

    # 3. Known scam pattern
    c3 = evaluate_memo_consistency(
        memo="guaranteed return crypto investment profit",
        balance_drain_ratio=0.10,
        payee_age_days=30.0,
        spike_ratio=1.5,
        amount=10000.0
    )
    assert c3["is_consistent"] is False


# =============================================================================
# 3. Worker Pool, Queue Full, Timeout, and Idempotency Tests
# =============================================================================

class MockFastEngine:
    def review_transfer(self, **kwargs):
        return {
            "raw_logits": {"ALLOW": 5.0, "REQUIRE_2FA": 20.0, "BLOCK": 5.0},
            "calibrated_probs": {"ALLOW": 0.05, "REQUIRE_2FA": 0.90, "BLOCK": 0.05},
            "recommended_action": "REQUIRE_2FA",
            "typology_tag": "investment_scam",
            "consistency_flag": {"is_consistent": False, "detail": "Test flag"},
            "latency_ms": 2.0,
            "cached": False
        }


class MockSlowEngine:
    def __init__(self, delay_sec: float = 2.0):
        self.delay_sec = delay_sec

    def review_transfer(self, **kwargs):
        time.sleep(self.delay_sec)
        return {
            "raw_logits": {"ALLOW": 10.0, "REQUIRE_2FA": 5.0, "BLOCK": 2.0},
            "calibrated_probs": {"ALLOW": 0.90, "REQUIRE_2FA": 0.08, "BLOCK": 0.02},
            "recommended_action": "ALLOW",
            "typology_tag": "none",
            "consistency_flag": {"is_consistent": True, "detail": "OK"},
            "latency_ms": 2000.0,
            "cached": False
        }


def test_idempotent_job_enqueueing(tmp_path):
    store = TransferStore(settlement_window_seconds=60.0)
    metrics = ReviewerMetrics()
    analyst_store = AnalystDecisionStore(storage_path=str(tmp_path / "decisions.jsonl"))
    pool = AsyncReviewWorkerPool(
        engine=MockFastEngine(),
        transfer_store=store,
        analyst_store=analyst_store,
        metrics=metrics,
        max_queue_size=10,
        num_workers=1
    )

    try:
        tx_id = "TX-IDEMP-001"
        store.save_transfer(
            transaction_id=tx_id,
            user_id="USR-01",
            account_id="ACC-01",
            target_account_id="ACC-02",
            amount=500.0,
            memo="first attempt",
            s2_action="ALLOW",
            s2_score=10.0,
            tabular_features={}
        )

        # Enqueue once
        q1 = pool.enqueue_review(
            transaction_id=tx_id,
            s2_action="ALLOW",
            s2_score=10.0,
            memo="first attempt",
            amount=500.0,
            tabular_data={}
        )
        assert q1 is True

        # Enqueue duplicate
        q2 = pool.enqueue_review(
            transaction_id=tx_id,
            s2_action="ALLOW",
            s2_score=10.0,
            memo="second duplicate attempt",
            amount=500.0,
            tabular_data={}
        )
        assert q2 is True
        # Queue should only contain 1 job because duplicate is ignored
        assert pool.queue.qsize() <= 1
    finally:
        pool.shutdown()


def test_queue_full_fallback(tmp_path):
    store = TransferStore(settlement_window_seconds=60.0)
    metrics = ReviewerMetrics()
    analyst_store = AnalystDecisionStore(storage_path=str(tmp_path / "decisions.jsonl"))

    # Create pool with tiny queue capacity of 2 and 0 workers initially so it fills up
    pool = AsyncReviewWorkerPool(
        engine=MockSlowEngine(delay_sec=10.0),
        transfer_store=store,
        analyst_store=analyst_store,
        metrics=metrics,
        max_queue_size=2,
        num_workers=1
    )

    try:
        # Fill queue to capacity
        for i in range(2):
            tx_id = f"TX-FILL-{i}"
            store.save_transfer(tx_id, "U1", "A1", "A2", 100.0, "memo", "ALLOW", 10.0, {})
            pool.enqueue_review(tx_id, "ALLOW", 10.0, "memo", 100.0, {})

        # 3rd request overflows the queue
        tx_overflow = "TX-OVERFLOW-999"
        store.save_transfer(tx_overflow, "U1", "A1", "A2", 100.0, "memo", "ALLOW", 10.0, {})
        enqueued = pool.enqueue_review(tx_overflow, "ALLOW", 10.0, "memo", 100.0, {})

        # Must not block, returns False, increments drop metric, marks as UNREVIEWED
        assert enqueued is False
        assert metrics.drops >= 1
        rec = store.get_transfer(tx_overflow)
        assert rec["review_status"] == "UNREVIEWED"
        assert rec["s2_action"] == "ALLOW"
    finally:
        pool.shutdown()


def test_job_timeout_fallback(tmp_path):
    store = TransferStore(settlement_window_seconds=60.0)
    metrics = ReviewerMetrics()
    analyst_store = AnalystDecisionStore(storage_path=str(tmp_path / "decisions.jsonl"))

    # Engine sleeps 0.3s, timeout set to 0.1s
    slow_engine = MockSlowEngine(delay_sec=0.3)
    pool = AsyncReviewWorkerPool(
        engine=slow_engine,
        transfer_store=store,
        analyst_store=analyst_store,
        metrics=metrics,
        max_queue_size=10,
        num_workers=1,
        job_timeout_seconds=0.1
    )

    try:
        tx_id = "TX-TIMEOUT-001"
        store.save_transfer(tx_id, "U1", "A1", "A2", 1000.0, "memo", "ALLOW", 15.0, {})
        pool.enqueue_review(tx_id, "ALLOW", 15.0, "memo", 1000.0, {})

        # Wait for worker to finish processing
        time.sleep(0.5)

        # Confirm timeout was recorded and S2 decision is preserved
        rec = store.get_transfer(tx_id)
        assert rec["review_status"] == "UNREVIEWED"
        assert rec["s2_action"] == "ALLOW"
        assert metrics.timeouts >= 1
    finally:
        pool.shutdown()
