"""
Threat Narrative Builder:
Parses raw device telemetry, accessibility services, media projection, call states,
counterparty metadata, and clipboard traces into a normalized natural language narrative
for NanoJev contextual evaluation.
"""

from typing import Tuple, Optional, List, Dict, Any
import re
from .models import RiskAnalysisRequest, DeviceThreatContext, CounterpartyContext

# Suspicious keywords in accessibility service packages and running tools
REMOTE_KEYWORDS = [
    "anydesk", "teamviewer", "rustdesk", "quickconnect", "screenhelper",
    "remote", "support", "airmirror", "vnc", "screenstream", "mirror"
]

# Suspicious package installer sources
UNOFFICIAL_INSTALLERS = [
    "chrome", "browser", "download", "telegram", "whatsapp", "apk", "packageinstaller"
]


# Suspicious keywords in payment memo and transfer narratives
SCAM_MEMO_KEYWORDS = [
    "crypto", "bitcoin", "investment", "guaranteed", "profit", "task", "commission",
    "bail", "police", "remote", "support fee", "it remote", "release fee",
    "processing fee", "unlock", "raffle", "lottery", "prize", "pampadulas", "customs",
    "meralco", "electricity bill", "telegram"
]


def has_threat_context(request: RiskAnalysisRequest) -> bool:
    """
    Returns True if any unstructured threat signals or counterparty anomalies are present.
    Allows clean routine transfers to bypass the neural model and stay on the sub-20ms path.
    """
    # 1. Check Device Context
    dev = request.device_context
    if dev:
        # Remote-access accessibility tools
        if dev.active_accessibility_services:
            for s in dev.active_accessibility_services:
                s_lower = s.lower()
                if any(kw in s_lower for kw in REMOTE_KEYWORDS):
                    return True
        
        # Screen sharing / mirroring
        if dev.media_projection and dev.media_projection.is_screen_sharing:
            return True

        # Live voice call in progress
        if dev.telephony and (
            dev.telephony.call_state in ["CALL_STATE_OFFHOOK", "IN_CALL", "ACTIVE_CALL", "CALL_ACTIVE"]
            or (dev.telephony.call_state and dev.telephony.call_state.upper() not in ["IDLE", "NONE", ""])
        ):
            return True

        # Sideloaded APK origin
        if dev.installer_source:
            ins_lower = dev.installer_source.lower()
            if any(ui in ins_lower for ui in UNOFFICIAL_INSTALLERS) and "vending" not in ins_lower:
                return True

        # Account pasted from external app
        if dev.interaction and dev.interaction.account_input_mode in ["PASTED_FROM_EXTERNAL_APP", "PASTED_FROM_CLIPBOARD", "PASTED"]:
            return True

    # 2. Check Counterparty Context
    cp = request.counterparty_context
    if cp:
        # Purpose vs Payee Type Mismatch (e.g. Bills payment to personal account)
        purpose = (cp.transfer_purpose or "").upper()
        acct_type = (cp.payee_account_type or "").upper()
        if "BILL" in purpose and ("INDIVIDUAL" in acct_type or "SAVING" in acct_type):
            return True

        # Very new payee (< 24 hours) with nickname
        if cp.payee_age_hours is not None and cp.payee_age_hours < 24.0:
            if cp.sender_assigned_nickname:
                return True

    # 3. Check Memo Semantics
    memo_lower = (request.memo or "").lower()
    if any(kw in memo_lower for kw in SCAM_MEMO_KEYWORDS):
        return True

    return False


def detect_threat_category(request: RiskAnalysisRequest) -> str:
    """
    Identifies the primary threat category from request signals.
    """
    dev = request.device_context
    cp = request.counterparty_context
    memo = (request.memo or "").lower()

    # Priority 1: Remote-Access / Screen Sharing
    if dev and dev.active_accessibility_services:
        for s in dev.active_accessibility_services:
            if any(kw in s.lower() for kw in REMOTE_KEYWORDS):
                return "REMOTE_ACCESS_MALWARE"

    if dev and dev.media_projection and dev.media_projection.is_screen_sharing:
        return "REMOTE_ACCESS_MALWARE"

    if "remote" in memo or "support fee" in memo or "anydesk" in memo or "teamviewer" in memo:
        return "REMOTE_ACCESS_MALWARE"

    # Priority 2: Live Phone Call Coercion
    if dev and dev.telephony and (
        dev.telephony.call_state in ["CALL_STATE_OFFHOOK", "IN_CALL", "ACTIVE_CALL", "CALL_ACTIVE"]
        or (dev.telephony.call_state and dev.telephony.call_state.upper() not in ["IDLE", "NONE", ""])
    ):
        return "LIVE_CALL_COERCION"

    if "bail" in memo or "police" in memo:
        return "LIVE_CALL_COERCION"

    # Priority 3: Purpose / Account Mismatch
    if cp:
        purpose = (cp.transfer_purpose or "").upper()
        acct_type = (cp.payee_account_type or "").upper()
        if "BILL" in purpose and ("INDIVIDUAL" in acct_type or "SAVING" in acct_type):
            return "PURPOSE_ACCOUNT_MISMATCH"

    if "meralco" in memo or "electricity bill" in memo:
        return "PURPOSE_ACCOUNT_MISMATCH"

    # Priority 4: External Clipboard Paste
    if dev and dev.interaction and dev.interaction.account_input_mode in ["PASTED_FROM_EXTERNAL_APP", "PASTED_FROM_CLIPBOARD", "PASTED"]:
        return "EXTERNAL_CLIPBOARD_PASTE"

    # Priority 5: Memo Typology Patterns
    if any(kw in memo for kw in ["crypto", "bitcoin", "guaranteed", "profit", "investment", "task", "commission", "prize", "lottery"]):
        return "MEMO_SCAM_PATTERN"

    return "GENERAL_ADVISORY"


def build_threat_narrative(request: RiskAnalysisRequest) -> Tuple[str, str]:
    """
    Builds a structured natural language threat narrative for NanoJev prompt injection.
    Excludes free-form user memos, relying strictly on device, behavioral, and counterparty telemetry.
    Returns (threat_narrative, primary_threat_category).
    """
    lines: List[str] = []
    category = detect_threat_category(request)

    lines.append(f"Amount: PHP {request.amount:,.2f}")

    dev = request.device_context
    if dev:
        if dev.device_model:
            patch_str = f" (Patch: {dev.security_patch_date})" if dev.security_patch_date else ""
            lines.append(f"Device: {dev.device_model}{patch_str}")

        if dev.installer_source:
            lines.append(f"App Origin: {dev.installer_source}")

        if dev.active_accessibility_services:
            services_str = ", ".join(dev.active_accessibility_services)
            lines.append(f"Accessibility Services Active: [{services_str}]")

        if dev.media_projection and dev.media_projection.is_screen_sharing:
            lines.append("Screen Mirroring: ACTIVE (Virtual display broadcasting)")

        if dev.telephony and dev.telephony.call_state != "IDLE":
            lines.append(f"Phone State: {dev.telephony.call_state} (Duration: {dev.telephony.call_duration_seconds:.0f}s)")

        if dev.interaction:
            lines.append(f"Input Mode: {dev.interaction.account_input_mode} (Form duration: {dev.interaction.time_spent_on_form_seconds:.1f}s)")
            if dev.interaction.clipboard_preview_snippet:
                lines.append(f"Clipboard Context: \"{dev.interaction.clipboard_preview_snippet}\"")

    cp = request.counterparty_context
    if cp:
        acct_str = cp.payee_account_type or "Unknown"
        age_str = f" ({cp.payee_age_hours:.1f} hours old)" if cp.payee_age_hours is not None else ""
        lines.append(f"Payee Account Type: {acct_str}{age_str}")
        if cp.transfer_purpose:
            lines.append(f"Transfer Purpose Selected: {cp.transfer_purpose}")
        if cp.sender_assigned_nickname:
            lines.append(f"Beneficiary Nickname: \"{cp.sender_assigned_nickname}\"")

    narrative = "\n".join(lines)
    return narrative, category
