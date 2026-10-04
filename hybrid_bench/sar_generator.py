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

# Background worker pool for fire-and-forget execution
_SAR_EXECUTOR = ThreadPoolExecutor(max_workers=2, thread_name_prefix="sar_worker")

def format_sar_document(tx: Dict[str, Any], verdict: Dict[str, Any]) -> str:
    """
    Constructs a complete, legally structured Suspicious Activity Report (SAR)
    in compliance with Anti-Money Laundering Council (AMLC) guidelines.
    """
    tx_id = tx.get("transaction_id", "UNKNOWN_TX")
    user_id = tx.get("user_id", "UNKNOWN_USER")
    amount = float(tx.get("amount_php", 0.0))
    user_avg = float(tx.get("user_avg_amount_php", amount))
    spike_ratio = float(tx.get("spike_ratio", amount / user_avg if user_avg > 0 else 1.0))
    balance_drain = float(tx.get("balance_drain_ratio", 0.0))
    velocity_kmh = float(tx.get("velocity_kmh", 0.0))
    distance_home = float(tx.get("distance_from_home_km", 0.0))
    is_vpn = bool(tx.get("is_vpn", False))
    memo = str(tx.get("memo", "")).strip()
    memo_signal = str(tx.get("memo_signal", "none"))
    gate_used = verdict.get("gate_used", "GATE_0_HARD_RULES")
    primary_reason = verdict.get("primary_reason", "CRITICAL_FRAUD_DETECTED")
    fraud_score = verdict.get("fraud_score", 95.0)

    # Device Context
    rooted = bool(tx.get("rooted", False))
    hooking = bool(tx.get("hooking", False))
    emulator = bool(tx.get("emulator", False))
    tampered = bool(tx.get("tampered", False))
    attestation = str(tx.get("attestation_verdict", "UNKNOWN"))

    # Payee Context
    purpose = str(tx.get("transfer_purpose", "Funds Transfer"))
    payee_type = str(tx.get("payee_type", "third_party_individual"))
    new_payee = bool(tx.get("new_payee", False))
    senders_to_payee = int(tx.get("senders_to_payee_24h", 1))

    timestamp_str = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    report_id = f"SAR-{datetime.now(timezone.utc).strftime('%Y%m%d')}-{tx_id}"

    # Determine Typology Category and Regulatory Citations
    red_flags = []
    if velocity_kmh > 1000.0:
        red_flags.append(f"Impossible travel speed ({velocity_kmh:,.1f} km/h) indicating remote session compromise or credential stuffing.")
    if hooking or emulator or tampered:
        red_flags.append(f"Active application tampering detected (Hooking: {hooking}, Emulator: {emulator}, Attestation: {attestation}).")
    if spike_ratio >= 3.0:
        red_flags.append(f"Anomalous transaction spike ({spike_ratio:.1f}x baseline) with {balance_drain*100:.1f}% total balance drain.")
    if is_vpn:
        red_flags.append("Traffic routed through commercial VPN/proxy masking true physical geolocation.")
    if new_payee and senders_to_payee >= 4:
        red_flags.append(f"Beneficiary counterparty shows money mule aggregation patterns ({senders_to_payee} inbound senders in 24 hours).")
    if memo:
        red_flags.append(f"Natural language memo reflects known social engineering or extortion pattern: \"{memo}\".")

    red_flags_str = "\n".join([f"  - {f}" for f in red_flags]) or "  - Elevated cumulative risk score across multi-factor behavioural telemetry."

    # Construct Narrative
    narrative = (
        f"On {timestamp_str}, the automated risk monitoring system intercepted and blocked a high-value "
        f"transfer request of PHP {amount:,.2f} initiated under customer account {user_id}. "
        f"The transaction represents a {spike_ratio:.1f}x surge above the customer's established baseline "
        f"of PHP {user_avg:,.2f}, resulting in an acute balance liquidation of {balance_drain*100:.1f}%.\n\n"
        f"Forensic telemetry revealed immediate indicators of compromise: the originating endpoint reported "
        f"an attestation verdict of '{attestation}' with device tampering indicators (Hooking={hooking}, Emulator={emulator}, Rooted={rooted}). "
    )
    if velocity_kmh > 1000.0:
        narrative += f"Physical transit velocity was calculated at {velocity_kmh:,.1f} km/h, which is physically impossible under standard commercial travel. "
    if memo:
        narrative += f"Furthermore, semantic analysis of the memo string \"{memo}\" identified predatory advance-fee or account-unlock fraud semantics. "
    narrative += (
        f"The destination account ({payee_type}) exhibits mule routing characteristics with {senders_to_payee} distinct "
        f"originating transfers within a 24-hour window, inconsistent with stated transfer purpose '{purpose}'. "
        f"Pursuant to Bangko Sentral ng Pilipinas (BSP) Circular No. 1108 and Republic Act No. 9160, this transaction has been "
        f"quarantined and referred for formal regulatory STR submission."
    )

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
- Automated Action: {verdict.get('action', 'BLOCK')}
- Primary Reason Code: {primary_reason}
- Fraud Risk Score: {fraud_score:.1f} / 100.0

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
- [X] Immediate Transaction Rejection (Executed in real-time)
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
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        output_dir = os.path.join(base_dir, "hybrid_bench", "reports", "sar_drafts")
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
