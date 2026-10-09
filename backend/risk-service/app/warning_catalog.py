"""
Warning Catalog for Contextual In-App Scam Advisories.
Generates tailored, human-readable scam intervention warnings for retail banking clients.
Designed to break the psychological coercion of live phone calls, remote-access malware,
and purpose/account mismatches without causing disruptive hard blocks on innocent users.
"""

from typing import Dict, Any, Optional
from .models import WarningDialogModel

# Standard warning templates categorized by primary threat vector
WARNING_TEMPLATES: Dict[str, Dict[str, Any]] = {
    "MEMORY_HOOKING_TAMPER": {
        "title": "Runtime Memory Hooking Tool Detected",
        "threat_category": "MEMORY_HOOKING_TAMPER",
        "body_message": (
            "A dynamic binary instrumentation or memory manipulation framework (such as Frida or Xposed) "
            "is operating on this device. These tools can alter application security checks and intercept private banking data. "
            "Close all debugging and hooking frameworks before proceeding."
        ),
        "checkbox_acknowledgment_text": "I confirm no unauthorized debugging or instrumentation tools are active.",
        "recommended_action": "TERMINATE_TAMPER_FRAMEWORK",
        "mandatory_read_delay_seconds": 3
    },
    "PACKET_INSPECTION_MITM": {
        "title": "Network Packet Capture Tool Detected",
        "threat_category": "PACKET_INSPECTION_MITM",
        "body_message": (
            "A network packet interception or proxy tool (such as HTTP Canary, Charles, or Mitmproxy) "
            "was detected on this device. These utilities can capture sensitive authorization tokens and financial information. "
            "Disable packet capture tools to protect your funds."
        ),
        "checkbox_acknowledgment_text": "I acknowledge the network security alert and confirm my connection is secure.",
        "recommended_action": "TERMINATE_INSPECTION_TOOL",
        "mandatory_read_delay_seconds": 3
    },
    "REMOTE_ACCESS_MALWARE": {
        "title": "Active Screen Sharing or Remote App Detected",
        "threat_category": "REMOTE_ACCESS_MALWARE",
        "body_message": (
            "An active screen-sharing or remote-assistance application is running on your device. "
            "Bank personnel and legitimate organizations will NEVER ask you to share your screen, "
            "install remote-support tools, or move your money to 'secure' an account. "
            "If someone is guiding your actions right now, stop immediately."
        ),
        "checkbox_acknowledgment_text": "I confirm no one is remotely viewing or controlling my screen.",
        "recommended_action": "CLOSE_REMOTE_APP",
        "mandatory_read_delay_seconds": 3
    },
    "LIVE_CALL_COERCION": {
        "title": "Active Phone Call Scam Warning",
        "threat_category": "LIVE_CALL_COERCION",
        "body_message": (
            "You are currently on an active voice call while transferring funds to a newly added recipient. "
            "Impersonators often pose as law enforcement, bank fraud staff, or customer service and "
            "stay on the line to pressure you into transferring funds immediately. "
            "Hang up and independently verify before sending money."
        ),
        "checkbox_acknowledgment_text": "I confirm I am not being instructed by someone on an active phone call.",
        "recommended_action": "HANG_UP_CALL",
        "mandatory_read_delay_seconds": 3
    },
    "PURPOSE_ACCOUNT_MISMATCH": {
        "title": "Account Type & Purpose Discrepancy",
        "threat_category": "PURPOSE_ACCOUNT_MISMATCH",
        "body_message": (
            "You selected 'Bills Payment' or 'Official Business', but the destination account belongs "
            "to an individual personal savings account created recently. "
            "Legitimate utility providers, government agencies, and merchant platforms do not receive "
            "bill payments via personal peer-to-peer accounts."
        ),
        "checkbox_acknowledgment_text": "I acknowledge that I am sending funds to an individual person, not an official biller.",
        "recommended_action": "VERIFY_RECIPIENT",
        "mandatory_read_delay_seconds": 3
    },
    "EXTERNAL_CLIPBOARD_PASTE": {
        "title": "Account Number Pasted from External App",
        "threat_category": "EXTERNAL_CLIPBOARD_PASTE",
        "body_message": (
            "This account number was copied directly from a messaging application. "
            "If someone you met on Telegram, WhatsApp, or Facebook instructed you to send this money "
            "for an online task deposit, crypto commission, or prize release fee, this transfer cannot be reversed."
        ),
        "checkbox_acknowledgment_text": "I know this recipient personally and am not sending money for an online task.",
        "recommended_action": "PROCEED_WITH_CAUTION",
        "mandatory_read_delay_seconds": 3
    },
    "MEMO_SCAM_PATTERN": {
        "title": "Suspicious Payment Note / Scam Warning",
        "threat_category": "MEMO_SCAM_PATTERN",
        "body_message": (
            "The notes in this transfer match phrasing frequently used in advance-fee prize, "
            "unauthorized investment, or crypto release scams. "
            "If you were asked to pay a 'release fee' or 'processing charge' to unlock profits, stop."
        ),
        "checkbox_acknowledgment_text": "I understand this transfer is non-refundable and not an advance fee.",
        "recommended_action": "CANCEL_TRANSFER",
        "mandatory_read_delay_seconds": 3
    },
    "GENERAL_ADVISORY": {
        "title": "Security Verification Required",
        "threat_category": "GENERAL_ADVISORY",
        "body_message": (
            "Unusual activity detected for this transaction. Please double-check the recipient name, "
            "account number, and amount carefully before confirming."
        ),
        "checkbox_acknowledgment_text": "I verify that all transfer details are accurate.",
        "recommended_action": "PROCEED_WITH_CAUTION",
        "mandatory_read_delay_seconds": 2
    }
}


def get_warning_dialog(threat_category: str, custom_message: Optional[str] = None) -> WarningDialogModel:
    """
    Returns a structured WarningDialogModel for the given threat category.
    """
    cat = threat_category.upper().strip()
    template = WARNING_TEMPLATES.get(cat, WARNING_TEMPLATES["GENERAL_ADVISORY"])

    body = custom_message if custom_message else template["body_message"]

    return WarningDialogModel(
        title=template["title"],
        threat_category=template["threat_category"],
        body_message=body,
        checkbox_acknowledgment_text=template["checkbox_acknowledgment_text"],
        recommended_action=template["recommended_action"],
        mandatory_read_delay_seconds=template["mandatory_read_delay_seconds"]
    )
