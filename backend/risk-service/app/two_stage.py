"""
Two-Stage Flow Core: Invariant Enforcement, Tiers, Decision Store, and Warning Templates.

Stage A: Fast risk decision (Gate 0 + XGBoost S2).
Stage B: Sync-bounded typology memo check (NanoJev).
Async: Audit logging, SAR generation, and analyst queue.
"""

import time
import uuid
import threading
from typing import Dict, Any, Optional, Tuple, List

# Internal action enum values preserved for backward compatibility
ACTION_TIERS = {
    "ALLOW": 0,
    "ADVISORY_WARNING": 1,
    "REQUIRE_2FA": 2,
    "BLOCK": 3
}

# Customer-facing / API display mapping: REQUIRE_2FA -> STEP_UP
DISPLAY_MAPPING = {
    "ALLOW": "ALLOW",
    "ADVISORY_WARNING": "ADVISORY_WARNING",
    "REQUIRE_2FA": "STEP_UP",
    "BLOCK": "BLOCK"
}

VALID_ACTIONS = set(ACTION_TIERS.keys())
VALID_TIERS = {"NONE", "ADVISORY", "ADVISORY_WARNING", "MEDIUM", "HIGH"}
VALID_TYPOLOGIES = [
    "prize_or_fee_scam",
    "investment_scam",
    "romance_scam",
    "impersonation",
    "fake_invoice_or_selling_scam",
    "remote_access_malware",
    "live_call_coercion",
    "purpose_account_mismatch",
    "external_clipboard_paste",
    "other_suspicious",
    "none"
]

def to_display_action(action: str) -> str:
    """Maps internal enum (e.g. REQUIRE_2FA) to display name (STEP_UP)."""
    norm = str(action).upper().strip()
    return DISPLAY_MAPPING.get(norm, norm)


# =============================================================================
# 1. Escalate-Only Invariant Enforcement
# =============================================================================

def compute_final_action(
    a0: str,
    recommended_action: Optional[str] = None,
    tier: Optional[str] = None,
    timed_out: bool = False,
    is_error: bool = False
) -> str:
    """
    Computes final_action and strictly enforces the escalate-only safety invariant:
        RiskTier(final_action) >= RiskTier(a0)

    Guarantees across every execution path:
    1. Normal:
       - If tier is NONE or omitted: final_action = max_tier(a0, recommended_action or a0)
       - If tier is ADVISORY / ADVISORY_WARNING: final_action >= ADVISORY_WARNING
       - If tier is MEDIUM: final_action >= ADVISORY_WARNING
       - If tier is HIGH: final_action >= REQUIRE_2FA (or BLOCK if recommended or a0 is BLOCK)
    2. Timeout:
       - final_action = a0 (NanoJev timeout never alters or weakens a0)
    3. Error:
       - final_action = a0 (Error fallback always defaults safely to a0)
    4. a0 == 'BLOCK':
       - Can NEVER be downgraded under any circumstance.
    """
    s2_action_norm = str(a0).upper().strip()
    if s2_action_norm not in ACTION_TIERS:
        s2_action_norm = "ALLOW"

    # On timeout or error, safe fallback is exactly a0
    if timed_out or is_error:
        final_action = s2_action_norm
    else:
        # Determine candidate action from tier
        tier_norm = str(tier).upper().strip() if tier else "NONE"
        rec_norm = str(recommended_action).upper().strip() if recommended_action else s2_action_norm
        if rec_norm not in ACTION_TIERS:
            rec_norm = s2_action_norm

        if tier_norm == "HIGH":
            # High tier requires at least REQUIRE_2FA, or BLOCK if recommended or a0 is BLOCK
            cand_tier = max(ACTION_TIERS[s2_action_norm], ACTION_TIERS[rec_norm], ACTION_TIERS["REQUIRE_2FA"])
        elif tier_norm == "MEDIUM":
            # Medium tier requires at least REQUIRE_2FA
            cand_tier = max(ACTION_TIERS[s2_action_norm], ACTION_TIERS[rec_norm], ACTION_TIERS["REQUIRE_2FA"])
        elif tier_norm in ["ADVISORY", "ADVISORY_WARNING"]:
            # Advisory warning triggers tailored friction modal without hard blocking
            cand_tier = max(ACTION_TIERS[s2_action_norm], ACTION_TIERS[rec_norm], ACTION_TIERS["ADVISORY_WARNING"])
        else:
            # NONE tier: cannot downgrade a0
            cand_tier = max(ACTION_TIERS[s2_action_norm], ACTION_TIERS[rec_norm])

        # Reverse lookup action name
        tier_to_action = {0: "ALLOW", 1: "ADVISORY_WARNING", 2: "REQUIRE_2FA", 3: "BLOCK"}
        final_action = tier_to_action[cand_tier]

    # Explicit assertion of the invariant
    assert ACTION_TIERS[final_action] >= ACTION_TIERS[s2_action_norm], (
        f"Escalate-only invariant violated: {final_action} < {s2_action_norm}"
    )
    return final_action


# =============================================================================
# 2. Warning Templates Catalogue
# =============================================================================

WARNING_TEMPLATES: Dict[str, Dict[str, str]] = {
    "prize_or_fee_scam": {
        "en": "You may be paying an advance-fee or raffle scam. Legitimate raffles, prizes, and promos never ask you to pay a claiming or processing fee first. Cancel this transfer and verify via official customer channels.",
        "tl": "Baka ito ay panloloko sa premyo o bayad. Ang mga lehitimong raffle o promo ay hindi kailanman humihingi ng paunang bayad bago makuha ang premyo. Kanselahin ang transfer at sumangguni sa opisyal na bangko.",
        "taglish": "Baka scam ang claiming fee o raffle prize na ito. Real promos and raffles will never ask you to pay first bago makuha ang reward. I-cancel ang transfer at i-check sa official app o hotline."
    },
    "investment_scam": {
        "en": "This transfer resembles a high-yield or crypto investment scam. Legitimate investment platforms never guarantee high, risk-free returns or demand urgent transfers to personal accounts. Cancel now and verify whether the entity is SEC-registered.",
        "tl": "Mukhang mapanlinlang na investment o crypto scam ito. Walang lehitimong negosyo ang nangangako ng garantisadong tubo o nag-aatas ng pera sa personal na account. Kanselahin ito at tiyaking rehistrado ang kompanya sa SEC.",
        "taglish": "Babala sa investment o crypto scheme. Legitimate investments never promise guaranteed instant returns o humihingi ng transfer sa personal bank account. I-cancel ang transfer at i-verify muna sa SEC kung lisensyado sila."
    },
    "romance_scam": {
        "en": "This payment looks like a romance or sweetheart scam. Scammers often build emotional relationships online and suddenly claim medical emergencies or travel fees. Stop and cancel this transfer; never send money to online contacts you haven't met.",
        "tl": "Maaaring isa itong romance scam. Madalas magkunwaring nagmamahal ang manloloko online bago humingi ng tulong para sa emergency o pamasahe. Itigil at kanselahin ito; huwag magpadala ng pera sa hindi mo pa personal na nakikita.",
        "taglish": "Warning sa posibleng romance scam. Karaniwang nagpapadala ng emergency drama o travel fee ang mga nakilala online para manghingi ng pera. I-cancel ang transfer na ito; huwag magpadala ng pera sa hindi mo pa personal na nakikilala."
    },
    "impersonation": {
        "en": "This transfer matches an impersonation scam. Your bank, police, or government agencies will never order you to transfer funds to a 'safe account' or pay for warrants. Cancel immediately and contact your bank's official hotline.",
        "tl": "Mukhang pekeng opisyal o bangko ang kausap mo. Hindi kailanman mag-uutos ang bangko, pulis, o gobyerno na maglipat ka sa 'safe account'. Kanselahin agad at tumawag sa opisyal na hotline ng iyong bangko.",
        "taglish": "Babala: posibleng nagpapanggap na bangko o pulis ang kausap mo. Your bank or government will never ask you to move money to a 'safe account'. I-cancel agad at tumawag lamang sa official hotline ng bangko."
    },
    "fake_invoice_or_selling_scam": {
        "en": "This looks like an online seller, delivery, or fake invoice scam. Fraudsters often demand upfront deposits or fake shipping fees for non-existent items. Cancel this transfer and transact only through verified marketplace platforms with buyer protection.",
        "tl": "Maaaring pekeng benta o delivery fee scam ito. Ang mga scammer ay madalas humihingi ng paunang bayad para sa mga pekeng produkto. Kanselahin ang transfer at makipag-transaksyon lamang sa mga lehitimong online store na may proteksyon.",
        "taglish": "Ingat sa fake invoice o online seller scam. Modus ng scammer ang humingi ng downpayment o advance shipping fee para sa pekeng order. I-cancel ang payment at mag-transact lamang sa mga verified marketplace na may customer protection."
    },
    "other_suspicious": {
        "en": "This transfer has unusual payment characteristics and high scam risk. Legitimate recipients never pressure you to send money immediately without verification. Cancel this transfer and confirm the recipient's identity through trusted, independent channels.",
        "tl": "Kakaiba at kahina-hinala ang mga detalye ng transfer na ito. Ang mga lehitimong transaksyon ay hindi nagmamadali nang walang tamang beripikasyon. Kanselahin ito at tiyakin muna ang pagkakakilanlan ng tatanggap sa ligtas na paraan.",
        "taglish": "May kahina-hinalang indicators ang transfer na ito. Hindi ka dapat minamadali sa pagpapadala ng pera nang walang sapat na verification. I-cancel ang transfer at tawagan muna ang receiver gamit ang totoong numero nila."
    }
}

def get_warning_template(typology: str, language: str = "en") -> Optional[str]:
    """Retrieves warning template text for a typology in the requested language."""
    typ_norm = str(typology).lower().strip()
    lang_norm = str(language).lower().strip()
    if typ_norm not in WARNING_TEMPLATES:
        return None
    lang_dict = WARNING_TEMPLATES[typ_norm]
    return lang_dict.get(lang_norm, lang_dict.get("en"))


# =============================================================================
# 3. Decision Store for Stage A and Stage B Idempotency
# =============================================================================

class DecisionStore:
    """
    Thread-safe in-memory store for Stage A risk decisions and Stage B memo checks.
    Guarantees idempotency per decision_id.
    """

    def __init__(self):
        self._lock = threading.Lock()
        self.decisions: Dict[str, Dict[str, Any]] = {}
        self.memo_checks: Dict[str, Dict[str, Any]] = {}
        self.events: List[Dict[str, Any]] = []

    def save_stage_a_decision(
        self,
        decision_id: str,
        action: str,
        s2_score: int,
        memo_present: bool,
        memo_check_required: bool,
        transfer: Dict[str, Any],
        device_context: Dict[str, Any],
        latency_ms: float
    ) -> Dict[str, Any]:
        with self._lock:
            if decision_id in self.decisions:
                return self.decisions[decision_id]

            rec = {
                "decision_id": decision_id,
                "action": action,
                "display_action": to_display_action(action),
                "s2_score": s2_score,
                "memo_present": memo_present,
                "memo_check_required": memo_check_required,
                "transfer": transfer,
                "device_context": device_context,
                "latency_ms": latency_ms,
                "created_at": time.time()
            }
            self.decisions[decision_id] = rec
            return rec

    def get_decision(self, decision_id: str) -> Optional[Dict[str, Any]]:
        with self._lock:
            return self.decisions.get(decision_id)

    def save_memo_check(self, decision_id: str, result: Dict[str, Any]) -> Dict[str, Any]:
        with self._lock:
            self.memo_checks[decision_id] = result
            return result

    def get_memo_check(self, decision_id: str) -> Optional[Dict[str, Any]]:
        with self._lock:
            return self.memo_checks.get(decision_id)

    def record_event(self, event_data: Dict[str, Any]) -> Dict[str, Any]:
        with self._lock:
            # Check for duplicate events by (decision_id, user_action)
            for existing in self.events:
                if (
                    existing.get("decision_id") == event_data.get("decision_id")
                    and existing.get("user_action") == event_data.get("user_action")
                ):
                    return {"status": "DUPLICATE_ACCEPTED", "event_id": existing.get("event_id")}

            event_id = f"EVT-{uuid.uuid4().hex[:8].upper()}"
            record = dict(event_data)
            record["event_id"] = event_id
            record["received_at"] = time.time()
            self.events.append(record)
            return {"status": "RECORDED", "event_id": event_id}
