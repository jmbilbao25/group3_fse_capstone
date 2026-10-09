"""
SAR/STR register for the compliance console.

Laya drafts reports as text files (hybrid_bench/sar_generator.py). This module
reads them back and parses the fields compliance needs to triage. The human
maker/checker sign-off is owned by the admin service and stored in the admin
schema; until then it is kept in a sidecar next to each draft.
"""

import os
import re
from datetime import datetime, timezone
from typing import Dict, List, Optional

from hybrid_bench.sar_generator import SAR_DRAFTS_DIR

_FIELD = re.compile(r"^- ([^:]+):\s*(.*)$")

# Parsed label -> API key
_KEYS = {
    "Report Number": "report_number",
    "Transaction ID": "transaction_id",
    "Interception Timestamp": "intercepted_at",
    "Triage Gate": "triage_gate",
    "Automated Action": "automated_action",
    "Primary Reason Code": "reason_code",
    "Fraud Risk Score": "risk_score",
    "Subject Account ID": "subject_account",
    "Current Transaction Amount": "amount",
    "Calculated Velocity": "velocity",
    "Distance from Registered Home": "distance_from_home",
    "Declared Purpose": "purpose",
    "Submitted Memo": "memo",
}


def _path(tx_id: str, suffix: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9_\-]+", tx_id):
        raise ValueError("Invalid transaction id")
    return os.path.join(SAR_DRAFTS_DIR, f"{tx_id}_SAR{suffix}")


def _parse(text: str) -> Dict[str, str]:
    out: Dict[str, str] = {}
    for line in text.splitlines():
        m = _FIELD.match(line.strip())
        if m and m.group(1) in _KEYS:
            out[_KEYS[m.group(1)]] = m.group(2).strip().strip('"')
    narrative = re.search(r"7\. FORENSIC COMPLIANCE NARRATIVE\n(.*?)\n\n8\.", text, re.S)
    out["narrative"] = narrative.group(1).strip() if narrative else ""
    flags = re.search(r"6\. PRIMARY RED FLAG INDICATORS\n(.*?)\n\n7\.", text, re.S)
    out["red_flags"] = [f.strip("- ").strip() for f in flags.group(1).splitlines() if f.strip()] if flags else []
    return out


def _summary(tx_id: str, text: str, mtime: float) -> Dict:
    fields = _parse(text)
    return {
        **{k: v for k, v in fields.items() if k not in ("narrative", "red_flags")},
        "transaction_id": fields.get("transaction_id", tx_id),
        "created_at": datetime.fromtimestamp(mtime, timezone.utc).isoformat(),
        "review": review_state(tx_id),
    }


def list_reports() -> List[Dict]:
    if not os.path.isdir(SAR_DRAFTS_DIR):
        return []
    rows = []
    for name in os.listdir(SAR_DRAFTS_DIR):
        if not name.endswith("_SAR.txt"):
            continue
        tx_id = name[: -len("_SAR.txt")]
        full = os.path.join(SAR_DRAFTS_DIR, name)
        with open(full, encoding="utf-8") as f:
            rows.append(_summary(tx_id, f.read(), os.path.getmtime(full)))
    rows.sort(key=lambda r: r["created_at"], reverse=True)
    return rows


def get_report(tx_id: str) -> Optional[Dict]:
    p = _path(tx_id, ".txt")
    if not os.path.exists(p):
        return None
    with open(p, encoding="utf-8") as f:
        text = f.read()
    return {
        **_summary(tx_id, text, os.path.getmtime(p)),
        **{k: v for k, v in _parse(text).items() if k in ("narrative", "red_flags")},
        "document": text,
    }


# -----------------------------------------------------------------------------
# Human sign-off. DRAFT -> maker recommends FILE/DISMISS -> PENDING_CHECKER ->
# a different checker CONFIRMs (FILED/DISMISSED) or RETURNs (DRAFT).
# shortcut: JSON sidecar per draft; moves to AURA_ADMIN.review_cases with the
# schema split (ADR-001).
# -----------------------------------------------------------------------------
import json
import threading

_LOCK = threading.Lock()


class SarReviewError(ValueError):
    pass


def review_state(tx_id: str) -> Dict:
    p = _path(tx_id, ".review.json")
    if not os.path.exists(p):
        return {"status": "DRAFT", "history": []}
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def review_report(tx_id: str, reviewer_id: str, action: str, note: str = "") -> Dict:
    if not reviewer_id:
        raise SarReviewError("reviewer_id is required")
    if not os.path.exists(_path(tx_id, ".txt")):
        raise KeyError(tx_id)
    with _LOCK:
        state = review_state(tx_id)
        now = datetime.now(timezone.utc).isoformat()
        if action in ("RECOMMEND_FILE", "RECOMMEND_DISMISS"):
            if state["status"] != "DRAFT":
                raise SarReviewError(f"Report is {state['status']}; only drafts take a recommendation")
            if action == "RECOMMEND_DISMISS" and not note.strip():
                raise SarReviewError("A reason is required to dismiss a report")
            state.update(status="PENDING_CHECKER",
                         maker={"id": reviewer_id, "recommendation": action.split("_")[1], "note": note, "at": now})
        elif action in ("CONFIRM", "RETURN"):
            if state["status"] != "PENDING_CHECKER":
                raise SarReviewError(f"Report is {state['status']}; nothing to check")
            if state["maker"]["id"] == reviewer_id:
                raise SarReviewError("Four-eyes rule: a different reviewer must check this recommendation")
            state["checker"] = {"id": reviewer_id, "action": action, "note": note, "at": now}
            if action == "CONFIRM":
                state["status"] = "FILED" if state["maker"]["recommendation"] == "FILE" else "DISMISSED"
            else:
                state["status"] = "DRAFT"
        else:
            raise SarReviewError(f"Unknown action {action}")
        state.setdefault("history", []).append({"by": reviewer_id, "action": action, "note": note, "at": now})
        with open(_path(tx_id, ".review.json"), "w", encoding="utf-8") as f:
            json.dump(state, f, indent=2)
    return get_report(tx_id)
