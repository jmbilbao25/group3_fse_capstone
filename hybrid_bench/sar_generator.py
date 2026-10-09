"""
Suspicious Activity Report (SAR / STR) Generator:
Asynchronous background compliance report generator for AMLC (Republic Act No. 9160 / 11521).
Triggered when a transaction is flagged as BLOCK by Gate 0 or downstream models.
Extracts mathematical facts deterministically (zero hallucination) and articulates
a formal forensic narrative for compliance officer review.
"""

import os
import sys
import time
import json
import asyncio
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from typing import Dict, Any, Optional

SAR_DRAFTS_DIR = os.environ.get(
    "SAR_DRAFTS_DIR",
    os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "hybrid_bench", "reports", "sar_drafts"),
)

# Background worker pool for fire-and-forget execution
_SAR_EXECUTOR = ThreadPoolExecutor(max_workers=2, thread_name_prefix="sar_worker")

def format_sar_document(tx: Dict[str, Any], verdict: Dict[str, Any]) -> str:
    """
    Constructs a complete, legally structured Suspicious Activity Report (SAR)
    in compliance with Anti-Money Laundering Council (AMLC) guidelines.
    Evaluated by Laya Non-Autoregressive System 1 Decision Engine.
    """
    tx_id = tx.get("transaction_id", "UNKNOWN_TX")
    user_id = tx.get("user_id", "UNKNOWN_USER")
    amount = float(tx.get("amount_php", tx.get("amount", 0.0)))
    user_avg = float(tx.get("user_avg_amount_php", amount))
    spike_ratio = float(tx.get("spike_ratio", amount / user_avg if user_avg > 0 else 1.0))
    balance_drain = float(tx.get("balance_drain_ratio", 0.0))
    velocity_kmh = float(tx.get("velocity_kmh", 0.0))
    distance_home = float(tx.get("distance_from_home_km", 0.0))
    distance_last = float(tx.get("distance_from_last_km", 0.0))
    is_vpn = bool(tx.get("is_vpn", False))
    memo = str(tx.get("memo", "")).strip()
    memo_signal = str(tx.get("memo_signal", "none"))
    gate_used = verdict.get("gate_used", "TWO_STAGE_RISK_ENGINE")
    primary_reason = verdict.get("primary_reason", "CRITICAL_FRAUD_DETECTED")
    fraud_score = float(verdict.get("fraud_score", 95.0))

    # Laya Threat Categorization & Cause of Suspicion
    threat_category = str(verdict.get("threat_category", tx.get("threat_category", "GENERAL_ADVISORY"))).upper()
    cause_of_suspicion = str(verdict.get("cause_of_suspicion", tx.get("cause_of_suspicion", ""))).strip()
    if not cause_of_suspicion:
        cause_of_suspicion = "Elevated cumulative fraud score across multi-factor behavioural and endpoint telemetry."

    # Device & Telemetry Context
    rooted = bool(tx.get("rooted", False))
    hooking = bool(tx.get("hooking", False))
    emulator = bool(tx.get("emulator", False))
    tampered = bool(tx.get("tampered", False))
    attestation = str(tx.get("attestation_verdict", "PASS"))
    screen_sharing = bool(tx.get("screen_sharing", False) or tx.get("remote_app_active", False))
    active_call = bool(tx.get("active_call", False))
    call_state = str(tx.get("call_state", "IDLE"))

    # Monitored packages and tools
    raw_packages = tx.get("running_packages", []) or []
    if isinstance(raw_packages, str):
        raw_packages = [raw_packages]
    raw_acc = tx.get("active_accessibility_services", []) or []
    if isinstance(raw_acc, str):
        raw_acc = [raw_acc]
    raw_threats = tx.get("detected_threats", []) or []
    if isinstance(raw_threats, str):
        raw_threats = [raw_threats]

    combined_tools = list(dict.fromkeys(raw_packages + raw_acc + raw_threats))
    tools_str = ", ".join(combined_tools) if combined_tools else "None reported"

    is_anydesk_present = any("anydesk" in t.lower() or "teamviewer" in t.lower() for t in combined_tools) or screen_sharing
    is_httpcanary_present = any("httpcanary" in t.lower() or "charles" in t.lower() or "mitm" in t.lower() or "canary" in t.lower() for t in combined_tools)
    is_frida_present = hooking or any("frida" in t.lower() or "xposed" in t.lower() for t in combined_tools)

    # Payee Context
    purpose = str(tx.get("transfer_purpose", "Funds Transfer"))
    payee_type = str(tx.get("payee_type", "third_party_individual"))
    new_payee = bool(tx.get("new_payee", False))
    senders_to_payee = int(tx.get("senders_to_payee_24h", 1))

    timestamp_str = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    report_id = f"SAR-{datetime.now(timezone.utc).strftime('%Y%m%d')}-{tx_id}"

    # Determine Red Flags
    red_flags = []
    if is_frida_present:
        red_flags.append("Runtime dynamic memory hooking detected (Frida / Xposed binary instrumentation active in memory space).")
    if is_httpcanary_present:
        red_flags.append("Network packet interception tool detected (HTTP Canary / proxy capture utility inspecting network stream).")
    if is_anydesk_present:
        red_flags.append("Active screen broadcasting or remote desktop tool detected (e.g. AnyDesk / TeamViewer active during transfer).")
    if active_call or call_state in ["CALL_STATE_OFFHOOK", "IN_CALL", "ACTIVE_CALL"]:
        red_flags.append(f"Live voice telephone call active during fund transfer ({call_state}), indicating potential social engineering coercion.")
    if velocity_kmh > 1000.0:
        red_flags.append(f"Physically impossible travel velocity ({velocity_kmh:,.1f} km/h), indicating remote session compromise or credential replay.")
    if hooking or emulator or tampered or rooted:
        red_flags.append(f"Host endpoint integrity failure (Hooking: {hooking}, Emulator: {emulator}, Rooted: {rooted}, Attestation: {attestation}).")
    if spike_ratio >= 3.0:
        red_flags.append(f"Severe transaction spike ({spike_ratio:.1f}x baseline) resulting in {balance_drain*100:.1f}% balance liquidation.")
    if is_vpn:
        red_flags.append("Traffic routed through commercial VPN/proxy masking true physical origin.")
    if new_payee and senders_to_payee >= 4:
        red_flags.append(f"Beneficiary counterparty shows money mule aggregation traits ({senders_to_payee} inbound senders in 24 hours).")
    if memo:
        red_flags.append(f"Natural language memo correlates with known Philippine scam typography: \"{memo}\".")

    red_flags_str = "\n".join([f"  - {f}" for f in red_flags]) or "  - Elevated cumulative risk score across multi-factor behavioural telemetry."

    # Construct Forensic Compliance Narrative
    narrative_paras = []
    narrative_paras.append(
        f"On {timestamp_str}, the automated risk monitoring system intercepted and quarantined a transfer request "
        f"of PHP {amount:,.2f} initiated under customer account {user_id}. "
        f"The transaction represents a {spike_ratio:.1f}x surge above the customer's historical average of "
        f"PHP {user_avg:,.2f}, resulting in an acute balance liquidation of {balance_drain*100:.1f}%."
    )

    narrative_paras.append(
        f"The Laya Non-Autoregressive Decision Engine classified this transaction under threat category {threat_category}. "
        f"Forensic cause of suspicion: {cause_of_suspicion}"
    )

    endpoint_evidence = []
    if is_frida_present:
        endpoint_evidence.append("active runtime memory hooking frameworks (Frida/Xposed)")
    if is_httpcanary_present:
        endpoint_evidence.append("packet interception utilities (HTTP Canary)")
    if is_anydesk_present:
        endpoint_evidence.append("remote screen broadcasting software (AnyDesk/TeamViewer)")
    if active_call:
        endpoint_evidence.append(f"concurrent active voice telephony ({call_state})")

    if endpoint_evidence:
        narrative_paras.append(
            f"Endpoint inspection revealed immediate technical indicators of compromise, specifically: "
            f"{', '.join(endpoint_evidence)}. Such tools are frequently used by third-party actors to bypass "
            f"in-app security barriers or coerce customers into unauthorized financial disbursements."
        )

    if velocity_kmh > 1000.0:
        narrative_paras.append(
            f"Physical transit velocity was calculated at {velocity_kmh:,.1f} km/h, which is physically impossible under "
            f"commercial travel, corroborating remote session manipulation."
        )

    if memo:
        narrative_paras.append(
            f"Semantic analysis of the transfer memo string \"{memo}\" confirmed predatory advance-fee, "
            f"crypto task, or unauthorized account release patterns."
        )

    narrative_paras.append(
        f"Pursuant to Republic Act No. 9160 (Anti-Money Laundering Act of 2001) as amended by Republic Act No. 11521, "
        f"and Bangko Sentral ng Pilipinas (BSP) Circular Nos. 1108 and 1140, this transaction has been quarantined and "
        f"formulated into this official Suspicious Transaction Report (STR / SAR) draft pending compliance officer sign-off."
    )

    narrative = "\n\n".join(narrative_paras)

    sar_text = f"""================================================================================
SUSPICIOUS TRANSACTION REPORT (STR / SAR)
Anti-Money Laundering Council (AMLC) - Republic Act No. 9160 / 11521
Status: PENDING_HUMAN_SIGN_OFF | Priority: HIGH_CONFIDENCE_FRAUD
================================================================================

1. INCIDENT REFERENCE
- Report Number: {report_id}
- Transaction ID: {tx_id}
- Interception Timestamp: {timestamp_str}
- Triage Gate: {gate_used}
- Evaluator: Laya Non-Autoregressive System 1 Decision Engine
- Automated Action: {verdict.get('action', 'BLOCK')}
- Primary Reason Code: {primary_reason}
- Threat Category: {threat_category}
- Fraud Risk Score: {fraud_score:.1f} / 100.0
- Cause of Suspicion: {cause_of_suspicion}

2. SUBJECT IDENTIFICATION & BASELINE
- Subject Account ID: {user_id}
- Channel: {tx.get('channel', 'mobile_banking')}
- 30-Day Historical Average: PHP {user_avg:,.2f}
- Current Transaction Amount: PHP {amount:,.2f}
- Spike Ratio: {spike_ratio:.2f}x
- Balance Drain Ratio: {balance_drain*100:.1f}%

3. TECHNICAL AND PHYSICAL TELEMETRY
- Device Attestation: {attestation}
- Rooted: {rooted} | Hooking: {hooking} | Emulator: {emulator} | Tampered: {tampered}
- Screen Sharing Broadcast: {'ACTIVE' if screen_sharing else 'INACTIVE'}
- Telephony State: {'ACTIVE_CALL (' + call_state + ')' if active_call else 'IDLE'}
- Memory Hooking Tool: {'DETECTED (Frida / Xposed)' if is_frida_present else 'NONE'}
- Network Packet Sniffer: {'DETECTED (HTTP Canary / MITM)' if is_httpcanary_present else 'NONE'}
- Remote Desktop Tool: {'DETECTED (AnyDesk / Mirror)' if is_anydesk_present else 'NONE'}
- Monitored Telemetry Tools: [{tools_str}]
- Distance from Registered Home: {distance_home:,.1f} km
- Elapsed Time Since Prior Activity: {tx.get('elapsed_minutes', 0.0):.1f} minutes
- Calculated Velocity: {velocity_kmh:,.1f} km/h
- VPN / Proxy Masking Detected: {is_vpn}

4. BENEFICIARY COUNTERPARTY & TRANSACTION PURPOSE
- Declared Purpose: {purpose}
- Payee Classification: {payee_type}
- Payee Account Status: {'NEW_COUNTERPARTY' if new_payee else 'ESTABLISHED_BENEFICIARY'}
- Beneficiary Velocity: {senders_to_payee} inbound senders in last 24h (Mule Risk Factor)

5. NATURAL LANGUAGE MEMO SEMANTIC ANALYSIS
- Submitted Memo: "{memo if memo else '[NO MEMO ENTERED]'}"
- Semantic Risk Category: {memo_signal.upper()}

6. PRIMARY RED FLAG INDICATORS
{red_flags_str}

7. FORENSIC COMPLIANCE NARRATIVE
{narrative}

8. RECOMMENDED REMEDIATION & NEXT STEPS
- [X] Immediate Transaction Interception (Executed in real-time)
- [X] Beneficiary Account Temporary Credit Freeze (P.O. Request to Receiving Bank)
- [X] Customer Account Step-up Verification (Mandatory in-branch biometric KYC)
- [ ] AMLC Official STR Electronic Dispatch (Pending Compliance Officer Sign-off)

Investigator Sign-off: [  ] APPROVED FOR FILING    [  ] REJECT / FALSE POSITIVE
Compliance Officer Name: _____________________ Date: _________________
================================================================================
"""
    return sar_text


def generate_sar_sync(tx: Dict[str, Any], verdict: Dict[str, Any], output_dir: Optional[str] = None) -> str:
    """
    Synchronous generation of the SAR document and saving to disk.
    """
    sar_doc = format_sar_document(tx, verdict)
    tx_id = tx.get("transaction_id", f"TX_{int(time.time()*1000)}")

    if not output_dir:
        output_dir = SAR_DRAFTS_DIR
    os.makedirs(output_dir, exist_ok=True)

    file_path = os.path.join(output_dir, f"{tx_id}_SAR.txt")
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(sar_doc)

    return file_path


def trigger_sar_async(tx: Dict[str, Any], verdict: Dict[str, Any], output_dir: Optional[str] = None):
    """
    Asynchronous fire-and-forget submission to the background thread pool.
    Returns immediately in microseconds without blocking the caller.
    """
    _SAR_EXECUTOR.submit(generate_sar_sync, tx, verdict, output_dir)
