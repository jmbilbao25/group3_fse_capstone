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
    decision: str = Field(..., description="Decision: ALLOW, REQUIRE_2FA, or BLOCK")
    fraud_score: int = Field(..., ge=0, le=100, description="Calibrated risk score between 0 and 100")
    is_anomaly: bool
    anomaly_probability: float
    primary_flag: str
    all_flags: List[str]
    metrics: RiskMetrics
    customer_summary: Dict[str, Any]
    evaluation_time_ms: float

    # New async second-look reviewer fields
    status: Optional[str] = Field(default="SETTLED", description="Settlement status: PENDING_SETTLEMENT, HELD, SETTLED, BLOCKED")
    review_enqueued: Optional[bool] = Field(default=False, description="True if transfer was enqueued for async second-look review")
    settlement_window_seconds: Optional[float] = Field(default=60.0, description="Simulated settlement holding window")


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
