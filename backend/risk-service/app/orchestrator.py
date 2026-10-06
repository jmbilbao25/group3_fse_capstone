"""
Transfer Orchestrator:
Coordinates the two-stage retail banking transfer risk flow.
Owns customer flow, warning modal presentation, cool-off pause, step-up authentication,
execution simulation, and async event dispatch.
The risk engine only scores and recommends; it never moves money.
"""

import time
import logging
from typing import Dict, Any, Optional

logger = logging.getLogger("transfer_orchestrator")

from app.two_stage import (
    ACTION_TIERS,
    DISPLAY_MAPPING,
    to_display_action,
    compute_final_action,
    get_warning_template
)


class TransferOrchestrator:
    """
    Orchestrates funds transfers according to the Two-Stage Risk Architecture:
    1. Stage A (SYNC, budget < 200ms): /risk/decision -> a0
    2. Stage B (SYNC-BOUNDED, default timeout 1500ms): /risk/memo-check -> warning & tier
    3. Action Handling: Cancel, Pause (10 min), Continue
    4. Cool-off pause for HIGH tier
    5. Step-up authentication (in-app approval / biometric) when final_action >= REQUIRE_2FA
    6. Simulated ledger execution (never real money)
    7. Asynchronous event dispatch: /risk/events (fire-and-forget)
    """

    def __init__(
        self,
        risk_service_client: Optional[Any] = None,
        timeout_ms: float = 1500.0,
        cool_off_seconds: float = 10.0,
        default_language: str = "en"
    ):
        self.client = risk_service_client
        self.timeout_ms = timeout_ms
        self.cool_off_seconds = cool_off_seconds
        self.default_language = default_language
        self.fallbacks_recorded: int = 0
        self.transfers_executed: int = 0
        self.transfers_blocked: int = 0
        self.transfers_paused: int = 0
        self.transfers_cancelled: int = 0

    def process_transfer(
        self,
        transfer: Dict[str, Any],
        device_context: Optional[Dict[str, Any]] = None,
        user_action_input: Optional[str] = None,       # "continued", "cancelled", "paused"
        stepup_result_input: Optional[str] = None,     # "success", "failure"
        language: Optional[str] = None,
        force_timeout: bool = False,
        force_error: bool = False
    ) -> Dict[str, Any]:
        """
        Executes the full two-stage orchestration sequence for a transfer request.
        """
        lang = language or self.default_language
        dev_ctx = device_context or {}
        orchestration_trace = []

        # =========================================================================
        # Stage A: Fast Synchronous Risk Decision (Gate 0 + S2 XGBoost)
        # =========================================================================
        orchestration_trace.append({"stage": "STAGE_A_START", "timestamp": time.time()})
        stage_a_res = self._call_stage_a(transfer, dev_ctx)
        orchestration_trace.append({
            "stage": "STAGE_A_COMPLETE",
            "decision_id": stage_a_res["decision_id"],
            "a0": stage_a_res["action"],
            "memo_check_required": stage_a_res["memo_check_required"],
            "latency_ms": stage_a_res.get("latency_ms", 0.0)
        })

        decision_id = stage_a_res["decision_id"]
        a0 = stage_a_res["action"]
        memo_check_required = stage_a_res["memo_check_required"]

        # Default state prior to Stage B
        stage_b_res = {
            "decision_id": decision_id,
            "typology": "none",
            "typology_prob": 0.0,
            "tier": "NONE",
            "final_action": a0,
            "display_action": to_display_action(a0),
            "modal_template_id": None,
            "warning_text": None,
            "language": lang,
            "timed_out": False,
            "cached": False,
            "latency_ms": 0.0
        }

        # =========================================================================
        # Stage B: Sync-Bounded Typology & Warning Check (if required)
        # =========================================================================
        if memo_check_required:
            # Customer-facing transitional state: "Checking your transfer..."
            orchestration_trace.append({
                "stage": "CHECKING_TRANSFER_SCREEN",
                "message": "Checking your transfer...",
                "timestamp": time.time()
            })

            # Check timeout or error simulation
            if force_timeout:
                self.fallbacks_recorded += 1
                stage_b_res["timed_out"] = True
                stage_b_res["final_action"] = compute_final_action(a0, timed_out=True)
                stage_b_res["display_action"] = to_display_action(stage_b_res["final_action"])
                orchestration_trace.append({"stage": "STAGE_B_TIMEOUT_FALLBACK", "final_action": a0})
            elif force_error:
                self.fallbacks_recorded += 1
                stage_b_res["final_action"] = compute_final_action(a0, is_error=True)
                stage_b_res["display_action"] = to_display_action(stage_b_res["final_action"])
                orchestration_trace.append({"stage": "STAGE_B_ERROR_FALLBACK", "final_action": a0})
            else:
                try:
                    stage_b_res = self._call_stage_b(decision_id, lang)
                    orchestration_trace.append({
                        "stage": "STAGE_B_COMPLETE",
                        "tier": stage_b_res["tier"],
                        "typology": stage_b_res["typology"],
                        "final_action": stage_b_res["final_action"]
                    })
                except Exception as e:
                    # Safe fallback: NanoJev failure must NEVER cause transfer failure
                    self.fallbacks_recorded += 1
                    stage_b_res["timed_out"] = True
                    stage_b_res["final_action"] = compute_final_action(a0, is_error=True)
                    stage_b_res["display_action"] = to_display_action(stage_b_res["final_action"])
                    orchestration_trace.append({"stage": "STAGE_B_EXCEPTION_FALLBACK", "error": str(e)})

        final_action = stage_b_res["final_action"]
        tier = stage_b_res.get("tier", "NONE")
        warning_shown = (tier in ("MEDIUM", "HIGH")) and (final_action != "BLOCK")
        cool_off_triggered = (tier == "HIGH") and (final_action != "BLOCK")

        # =========================================================================
        # Warning Screen & Action Button Processing
        # =========================================================================
        # Available actions on warning: "Cancel and verify", "Pause for 10 minutes", "Continue"
        user_action = user_action_input or ("continued" if warning_shown else "none")
        transfer_status = "PENDING"
        stepup_required = (ACTION_TIERS[final_action] >= ACTION_TIERS["REQUIRE_2FA"]) and (final_action != "BLOCK")
        stepup_executed = False
        stepup_verdict = "skipped"

        if final_action == "BLOCK":
            # S2 BLOCK is never downgraded and offers no dismiss/continue option
            transfer_status = "BLOCKED"
            user_action = "blocked"
            self.transfers_blocked += 1
            orchestration_trace.append({"stage": "TERMINAL_BLOCK", "reason": "S2_OR_STAGE_B_BLOCK"})
        elif user_action == "cancelled":
            # Customer cancels: payment aborted, security maintained
            transfer_status = "CANCELLED_BY_CUSTOMER"
            self.transfers_cancelled += 1
            orchestration_trace.append({"stage": "WARNING_ACTION_CANCELLED"})
        elif user_action == "paused":
            # Customer pauses: transfer placed on 10-minute hold
            transfer_status = "PAUSED_10_MIN"
            self.transfers_paused += 1
            orchestration_trace.append({"stage": "WARNING_ACTION_PAUSED", "pause_duration_seconds": 600})
        else:
            # Customer continued (or no warning needed)
            if cool_off_triggered:
                orchestration_trace.append({
                    "stage": "COOL_OFF_PAUSE",
                    "cool_off_seconds": self.cool_off_seconds,
                    "requirement": "CONFIRM_OR_TIMER"
                })

            if stepup_required:
                # Require step-up authentication (in-app biometric / approval, NEVER SMS/email OTP)
                orchestration_trace.append({"stage": "STEP_UP_AUTHENTICATION_PROMPT"})
                stepup_executed = True
                stepup_verdict = stepup_result_input if stepup_result_input is not None else "success"

                if stepup_verdict == "success":
                    transfer_status = "EXECUTED_SIMULATED"
                    self.transfers_executed += 1
                    orchestration_trace.append({"stage": "STEP_UP_SUCCESS", "status": transfer_status})
                else:
                    transfer_status = "FAILED_AUTHENTICATION"
                    orchestration_trace.append({"stage": "STEP_UP_FAILED", "status": transfer_status})
            else:
                transfer_status = "EXECUTED_SIMULATED"
                self.transfers_executed += 1
                orchestration_trace.append({"stage": "TRANSFER_EXECUTED", "status": transfer_status})

        # =========================================================================
        # Asynchronous Event Ingestion (Fire-and-forget)
        # =========================================================================
        event_payload = {
            "decision_id": decision_id,
            "user_action": user_action,
            "stepup_result": stepup_verdict,
            "final_action": final_action
        }
        self._dispatch_async_event(event_payload)
        orchestration_trace.append({"stage": "ASYNC_EVENT_DISPATCHED", "event": event_payload})

        return {
            "decision_id": decision_id,
            "transfer_status": transfer_status,
            "stage_a": {
                "a0": a0,
                "display_a0": to_display_action(a0),
                "s2_score": stage_a_res.get("s2_score", 0),
                "memo_present": stage_a_res.get("memo_present", False),
                "memo_check_required": memo_check_required,
                "latency_ms": stage_a_res.get("latency_ms", 0.0)
            },
            "stage_b": {
                "typology": stage_b_res.get("typology", "none"),
                "typology_prob": stage_b_res.get("typology_prob", 0.0),
                "tier": tier,
                "final_action": final_action,
                "display_final_action": to_display_action(final_action),
                "modal_template_id": stage_b_res.get("modal_template_id"),
                "warning_text": stage_b_res.get("warning_text"),
                "timed_out": stage_b_res.get("timed_out", False),
                "cached": stage_b_res.get("cached", False),
                "latency_ms": stage_b_res.get("latency_ms", 0.0)
            },
            "user_flow": {
                "warning_shown": warning_shown,
                "cool_off_triggered": cool_off_triggered,
                "user_action": user_action,
                "stepup_required": stepup_required,
                "stepup_executed": stepup_executed,
                "stepup_verdict": stepup_verdict
            },
            "orchestration_trace": orchestration_trace
        }

    def _call_stage_a(self, transfer: Dict[str, Any], device_context: Dict[str, Any]) -> Dict[str, Any]:
        """Calls Stage A internally or via HTTP."""
        if self.client is not None and hasattr(self.client, "evaluate_stage_a"):
            from app.models import StageADecisionRequest
            req = StageADecisionRequest(transfer=transfer, device_context=device_context)
            res = self.client.evaluate_stage_a(req)
            return res.model_dump() if hasattr(res, "model_dump") else (res.dict() if hasattr(res, "dict") else res)

        # Standalone in-process fallback using global main
        from app.main import evaluate_stage_a
        from app.models import StageADecisionRequest
        req = StageADecisionRequest(transfer=transfer, device_context=device_context)
        res = evaluate_stage_a(req)
        return res.model_dump() if hasattr(res, "model_dump") else (res.dict() if hasattr(res, "dict") else res)

    def _call_stage_b(self, decision_id: str, language: str) -> Dict[str, Any]:
        """Calls Stage B internally or via HTTP."""
        if self.client is not None and hasattr(self.client, "evaluate_stage_b"):
            from app.models import StageBMemoCheckRequest
            req = StageBMemoCheckRequest(decision_id=decision_id, language=language)
            res = self.client.evaluate_stage_b(req)
            return res.model_dump() if hasattr(res, "model_dump") else (res.dict() if hasattr(res, "dict") else res)

        from app.main import evaluate_stage_b
        from app.models import StageBMemoCheckRequest
        req = StageBMemoCheckRequest(decision_id=decision_id, language=language)
        res = evaluate_stage_b(req)
        return res.model_dump() if hasattr(res, "model_dump") else (res.dict() if hasattr(res, "dict") else res)

    def _dispatch_async_event(self, event_data: Dict[str, Any]):
        """Dispatches fire-and-forget event."""
        try:
            if self.client is not None and hasattr(self.client, "record_risk_event"):
                from app.models import RiskEventRequest
                req = RiskEventRequest(**event_data)
                self.client.record_risk_event(req)
            else:
                from app.main import record_risk_event
                from app.models import RiskEventRequest
                req = RiskEventRequest(**event_data)
                record_risk_event(req)
        except Exception as e:
            logger.warning(f"Async event dispatch failed: {e}")
