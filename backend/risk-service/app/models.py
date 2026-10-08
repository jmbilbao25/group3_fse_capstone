"""
Pydantic Schemas for Transfer Risk Analysis, Async Reviewer, and Analyst Desk.
"""

from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field


class Coordinates(BaseModel):
    latitude: float
    longitude: float
    label: Optional[str] = None


class RiskAnalysisRequest(BaseModel):
    transaction_id: Optional[str] = Field(default=None, description="Unique transaction identifier")
    user_id: Optional[str] = Field(default=None, description="User identifier (e.g. USR-1001)")
    account_id: str = Field(..., description="Source account identifier (e.g. ACC-100001)")
    target_account_id: str = Field(..., description="Destination account identifier")
    amount: float = Field(..., gt=0, description="Transfer amount in PHP")
    currency: str = Field(default="PHP", description="Currency code")
    memo: Optional[str] = Field(default="", description="Customer-provided transfer memo or note")

    # Device telemetry (optional, graceful degradation if not provided)
    latitude: Optional[float] = Field(default=None, description="Current device GPS latitude")
    longitude: Optional[float] = Field(default=None, description="Current device GPS longitude")
    ip_address: Optional[str] = Field(default=None, description="Client connection IP address")
    ip_latitude: Optional[float] = Field(default=None, description="Resolved IP geolocation latitude")
    ip_longitude: Optional[float] = Field(default=None, description="Resolved IP geolocation longitude")

    # Optional advanced telemetry overrides (for tests and benchmarks)
    rooted: Optional[bool] = Field(default=False)
    hooking: Optional[bool] = Field(default=False)
    emulator: Optional[bool] = Field(default=False)
    tampered: Optional[bool] = Field(default=False)
    attestation_verdict: Optional[str] = Field(default="PASS")
    mock_location: Optional[bool] = Field(default=False)
    is_vpn: Optional[bool] = Field(default=False)
    payee_age_days: Optional[float] = Field(default=90.0)
    new_payee: Optional[bool] = Field(default=False)
    remote_app_active: Optional[bool] = Field(default=False, description="True if remote screen/control app (AnyDesk, TeamViewer) is active")
    active_call: Optional[bool] = Field(default=False, description="True if voice call is active during transfer")

    # Device binding & channel metadata
    is_primary_device: Optional[bool] = Field(default=True, description="True if initiated on user's cryptographically bound primary device")
    device_id: Optional[str] = Field(default=None, description="Hardware device UUID or fingerprint")

    # Enriched Threat & Device Context for Advisory Warnings
    device_context: Optional["DeviceThreatContext"] = Field(default=None, description="Enriched mobile device threat telemetry")
    counterparty_context: Optional["CounterpartyContext"] = Field(default=None, description="Payee and purpose context")


class MediaProjectionState(BaseModel):
    is_screen_sharing: bool = False
    virtual_display_count: int = 0


class TelephonyState(BaseModel):
    call_state: str = "IDLE"  # IDLE, CALL_STATE_OFFHOOK, CALL_STATE_RINGING
    call_duration_seconds: float = 0.0


class InteractionContext(BaseModel):
    account_input_mode: str = "TYPED"  # TYPED, PASTED_FROM_EXTERNAL_APP, PASTED_FROM_CLIPBOARD
    clipboard_preview_snippet: Optional[str] = None
    time_spent_on_form_seconds: float = 10.0


class DeviceThreatContext(BaseModel):
    device_id: Optional[str] = None
    is_primary_device: bool = True
    primary_device_id: Optional[str] = None
    device_model: Optional[str] = None
    os_version: Optional[str] = None
    security_patch_date: Optional[str] = None
    installer_source: Optional[str] = None  # com.android.vending, com.android.chrome/download/apk, etc.
    active_accessibility_services: List[str] = Field(default_factory=list)
    running_packages: List[str] = Field(default_factory=list, description="Installed or running packages (e.g. com.anydesk, com.guoshi.httpcanary)")
    detected_threats: List[str] = Field(default_factory=list, description="Threat signatures detected on device")
    hooking: Optional[bool] = None
    rooted: Optional[bool] = None
    emulator: Optional[bool] = None
    remote_app_active: Optional[bool] = None
    active_call: Optional[bool] = None
    media_projection: Optional[MediaProjectionState] = None
    telephony: Optional[TelephonyState] = None
    interaction: Optional[InteractionContext] = None


class CounterpartyContext(BaseModel):
    payee_account_type: Optional[str] = None  # INDIVIDUAL_SAVINGS, MERCHANT, CORPORATE
    payee_age_hours: Optional[float] = None
    is_first_interaction: bool = False
    sender_assigned_nickname: Optional[str] = None
    transfer_purpose: Optional[str] = None  # BILLS_PAYMENT, INVESTMENT, PERSONAL_TRANSFER, etc.


class WarningDialogModel(BaseModel):
    title: str
    threat_category: str  # REMOTE_ACCESS, LIVE_CALL_COERCION, PURPOSE_MISMATCH, CLIPBOARD_COERCION, GENERAL_SCAM
    body_message: str
    checkbox_acknowledgment_text: str
    recommended_action: str  # HANG_UP_CALL, VERIFY_RECIPIENT, CANCEL_TRANSFER, PROCEED_WITH_CAUTION
    mandatory_read_delay_seconds: int = 3


class RiskMetrics(BaseModel):
    distance_from_home_km: float
    distance_from_last_km: float
    elapsed_minutes: float
    velocity_kmh: float
    is_impossible_travel: bool
    is_high_speed_transit: bool
    ip_discrepancy_km: float
    is_vpn_detected: bool
    spike_ratio: float


class RiskAnalysisResponse(BaseModel):
    transaction_id: str
    decision: str = Field(..., description="Decision: ALLOW, ADVISORY_WARNING, REQUIRE_2FA, or BLOCK")
    fraud_score: int = Field(..., ge=0, le=100, description="Calibrated risk score between 0 and 100")
    is_anomaly: bool
    anomaly_probability: float
    primary_flag: str
    all_flags: List[str]
    metrics: RiskMetrics
    customer_summary: Dict[str, Any]
    evaluation_time_ms: float

    # Contextual Advisory Warning and Authorization channel fields
    advisory_tier: Optional[str] = Field(default="NONE", description="NONE, ADVISORY_WARNING, or STEP_UP_2FA")
    warning_dialog: Optional[WarningDialogModel] = Field(default=None, description="Contextual warning modal payload if triggered")
    threat_narrative: Optional[str] = Field(default=None, description="Synthesized device and context threat narrative")
    auth_method: str = Field(
        default="BIOMETRIC_PRIMARY",
        description="Transaction authorization channel: BIOMETRIC_PRIMARY, PUSH_NOTIFICATION_PRIMARY, STEP_UP_BIOMETRIC_PLUS_MPIN, STEP_UP_PUSH_PLUS_MPIN, or NONE_BLOCKED"
    )

    # Async second-look reviewer fields
    status: Optional[str] = Field(default="SETTLED", description="Settlement status: PENDING_SETTLEMENT, HELD, SETTLED, BLOCKED")
    review_enqueued: Optional[bool] = Field(default=False, description="True if transfer was enqueued for async second-look review")
    settlement_window_seconds: Optional[float] = Field(default=60.0, description="Simulated settlement holding window")
    memo_analysis: Optional[Dict[str, Any]] = Field(default=None, description="Real-time synchronous memo analysis (typology, probability, consistency)")

    # Laya threat categorization and AMLC compliance reporting fields
    threat_category: Optional[str] = Field(default=None, description="Primary threat category identified by Laya")
    cause_of_suspicion: Optional[str] = Field(default=None, description="Primary cause of suspicion evaluated by Laya AI")
    sar_draft_created: Optional[bool] = Field(default=False, description="True if an automated AMLC SAR/STR draft was generated")
    sar_report_id: Optional[str] = Field(default=None, description="Reference ID for generated AMLC SAR report")


class AnalystDecisionRequest(BaseModel):
    case_id: str = Field(..., description="Case ID (e.g. CASE-TX-1001)")
    transaction_id: str = Field(..., description="Target transaction ID")
    decision: str = Field(..., description="CONFIRM_FRAUD or DISMISS")
    analyst_id: Optional[str] = Field(default="ANALYST_01", description="Identifier of the reviewing analyst")
    notes: Optional[str] = Field(default="", description="Forensic notes or justification")


class ReviewerMetricsResponse(BaseModel):
    queue_depth: int
    drops: int
    timeouts: int
    reviews_completed: int
    escalations: int
    escalation_rate_pct: float
    time_to_review_p50_ms: float
    time_to_review_p95_ms: float
    inference_p50_ms: float
    inference_p95_ms: float


# =============================================================================
# Two-Stage Flow Schemas (Stage A, Stage B, and Events)
# =============================================================================

class StageADecisionRequest(BaseModel):
    transfer: Optional[Dict[str, Any]] = Field(default=None, description="Transfer parameters (amount, memo, account_id, etc.)")
    device_context: Optional[Dict[str, Any]] = Field(default=None, description="Device and geolocation telemetry")
    # Top-level fallback fields for convenience
    transaction_id: Optional[str] = Field(default=None)
    user_id: Optional[str] = Field(default=None)
    account_id: Optional[str] = Field(default=None)
    target_account_id: Optional[str] = Field(default=None)
    amount: Optional[float] = Field(default=None)
    memo: Optional[str] = Field(default="")


class StageADecisionResponse(BaseModel):
    decision_id: str
    action: str = Field(..., description="S2 baseline action: ALLOW, ADVISORY_WARNING, REQUIRE_2FA, or BLOCK")
    display_action: str = Field(..., description="Customer-facing display action (REQUIRE_2FA mapped to STEP_UP)")
    s2_score: int = Field(..., ge=0, le=100)
    memo_present: bool
    memo_check_required: bool
    threat_check_required: Optional[bool] = Field(default=False, description="True if device threat signals require contextual advisory evaluation")
    advisory_tier: Optional[str] = Field(default="NONE", description="NONE, ADVISORY_WARNING, or STEP_UP_2FA")
    warning_dialog: Optional[WarningDialogModel] = Field(default=None, description="Contextual warning modal payload if triggered")
    auth_method: Optional[str] = Field(
        default="BIOMETRIC_PRIMARY",
        description="Transaction authorization channel: BIOMETRIC_PRIMARY, PUSH_NOTIFICATION_PRIMARY, STEP_UP_BIOMETRIC_PLUS_MPIN, or STEP_UP_PUSH_PLUS_MPIN"
    )
    latency_ms: float


class StageBMemoCheckRequest(BaseModel):
    decision_id: str
    language: Optional[str] = Field(default="en", description="Preferred warning language (en, tl, taglish)")


class StageBMemoCheckResponse(BaseModel):
    decision_id: str
    typology: str = Field(default="none")
    typology_prob: float = Field(default=0.0)
    tier: str = Field(default="NONE", description="Risk tier: NONE, MEDIUM, or HIGH")
    advisory_tier: Optional[str] = Field(default="NONE", description="NONE, ADVISORY_WARNING, or STEP_UP_2FA")
    final_action: str = Field(..., description="Escalate-only action: ALLOW, ADVISORY_WARNING, REQUIRE_2FA, or BLOCK")
    display_action: str = Field(..., description="Display action (STEP_UP instead of REQUIRE_2FA)")
    modal_template_id: Optional[str] = Field(default=None)
    warning_text: Optional[str] = Field(default=None)
    warning_dialog: Optional[WarningDialogModel] = Field(default=None, description="Structured contextual warning dialog")
    threat_category: Optional[str] = Field(default="none")
    language: str = Field(default="en")
    timed_out: bool = Field(default=False)
    cached: bool = Field(default=False)
    latency_ms: float = Field(default=0.0)


class RiskEventRequest(BaseModel):
    decision_id: str
    user_action: str = Field(..., description="continued, cancelled, paused, or dismissed")
    stepup_result: Optional[str] = Field(default="skipped", description="success, failure, or skipped")
    final_action: str = Field(..., description="Final executed action")


class RiskEventResponse(BaseModel):
    status: str
    event_id: str
    sar_drafted: bool = Field(default=False)
    analyst_queued: bool = Field(default=False)

