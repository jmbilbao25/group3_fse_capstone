"""
Gate 0 Deterministic Hard Rules:
Ultra-fast (< 0.1ms) deterministic security filter based on physical velocity,
device tampering, emulator execution, and mock location spoofing.
Thresholds are config-driven from config.yaml.
Logs firing counts and precision across splits.
"""

import os
import yaml
from typing import Dict, Any, Optional, Tuple, List
import pandas as pd
from hybrid_bench.sar_generator import trigger_sar_async

class Gate0Filter:
    """
    Deterministic Gate 0 evaluator with exact reason codes.
    Config-driven thresholds.
    """

    def __init__(self, config_path: Optional[str] = None):
        if not config_path:
            config_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.yaml")

        with open(config_path, "r", encoding="utf-8") as f:
            cfg = yaml.safe_load(f)

        g0_cfg = cfg.get("gate0_thresholds", {})
        self.velocity_block_kmh = float(g0_cfg.get("velocity_kmh_block", 1000.0))
        self.high_val_php = float(g0_cfg.get("high_value_amount_php", 50000.0))
        self.med_val_php = float(g0_cfg.get("med_value_amount_php", 15000.0))
        self.mock_dist_km = float(g0_cfg.get("mock_location_distance_km", 150.0))

    def evaluate_row(self, row: Dict[str, Any], trigger_async_sar: bool = False) -> Tuple[Optional[str], Optional[str]]:
        """
        Evaluates a single transaction row.
        Returns:
            (action, reason_code) where action is 'BLOCK', 'REQUIRE_2FA', or None (pass to XGBoost).
        """
        velocity = float(row.get("velocity_kmh", 0.0))
        amount = float(row.get("amount_php", 0.0))
        rooted = bool(row.get("rooted", False))
        hooking = bool(row.get("hooking", False))
        emulator = bool(row.get("emulator", False))
        dev_new = bool(row.get("device_id_new", False))
        attestation = str(row.get("attestation_verdict", "UNKNOWN")).upper()
        mock_loc = bool(row.get("mock_location", False))
        dist_home = float(row.get("distance_from_home_km", 0.0))

        # Rule 1: Impossible travel speed > 1000 km/h -> BLOCK
        if velocity > self.velocity_block_kmh:
            action, reason = "BLOCK", "IMPOSSIBLE_TRAVEL_VELOCITY"
            if trigger_async_sar:
                trigger_sar_async(row, {"action": action, "primary_reason": reason, "gate_used": "GATE_0_HARD_RULES", "fraud_score": 100.0})
            return action, reason

        # Rule 2: Active hooking or runtime memory tampering -> BLOCK immediately (Zero tolerance)
        if hooking:
            action, reason = "BLOCK", "SUSPICIOUS_DEVICE_ENVIRONMENT"
            if trigger_async_sar:
                trigger_sar_async(row, {"action": action, "primary_reason": reason, "gate_used": "GATE_0_HARD_RULES", "fraud_score": 100.0})
            return action, reason

        if emulator and amount >= self.high_val_php:
            action, reason = "BLOCK", "CRITICAL_DEVICE_TAMPERING_HIGH_VALUE"
            if trigger_async_sar:
                trigger_sar_async(row, {"action": action, "primary_reason": reason, "gate_used": "GATE_0_HARD_RULES", "fraud_score": 98.0})
            return action, reason

        # Rule 3: Rooted on newly registered device with elevated amount >= 15k PHP -> REQUIRE_2FA
        if rooted and dev_new and amount >= self.med_val_php:
            return "REQUIRE_2FA", "ROOTED_NEW_DEVICE_ELEVATED_AMOUNT"

        # Rule 4: Attestation FAILED with elevated amount >= 15k PHP -> REQUIRE_2FA
        if attestation == "FAILED" and amount >= self.med_val_php:
            return "REQUIRE_2FA", "FAILED_DEVICE_ATTESTATION"

        # Rule 5: Mock location active and far from registered home (> 150 km) -> REQUIRE_2FA
        if mock_loc and dist_home > self.mock_dist_km:
            return "REQUIRE_2FA", "MOCK_LOCATION_SPOOFING"

        # Passed Gate 0 (no hard constraint triggered)
        return None, None

    def evaluate_dataframe(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Batch evaluates a DataFrame and returns columns:
        gate0_action, gate0_reason, gate0_passed
        """
        actions = []
        reasons = []
        passed = []

        records = df.to_dict("records")
        for r in records:
            act, rsn = self.evaluate_row(r, trigger_async_sar=False)
            actions.append(act)
            reasons.append(rsn)
            passed.append(act is None)

        res_df = df.copy()
        res_df["gate0_action"] = actions
        res_df["gate0_reason"] = reasons
        res_df["gate0_passed"] = passed
        return res_df

    def audit_split(self, df: pd.DataFrame, split_name: str) -> Dict[str, Any]:
        """
        Computes firing counts and precision per rule.
        """
        evaluated = self.evaluate_dataframe(df)
        total = len(evaluated)
        fired_mask = ~evaluated["gate0_passed"]
        total_fired = int(fired_mask.sum())

        rule_stats = {}
        for reason in [
            "IMPOSSIBLE_TRAVEL_VELOCITY",
            "CRITICAL_DEVICE_TAMPERING_HIGH_VALUE",
            "ROOTED_NEW_DEVICE_ELEVATED_AMOUNT",
            "FAILED_DEVICE_ATTESTATION",
            "MOCK_LOCATION_SPOOFING"
        ]:
            subset = evaluated[evaluated["gate0_reason"] == reason]
            count = len(subset)
            fraud_count = int(subset["is_fraud"].sum()) if count > 0 else 0
            precision = (fraud_count / count) if count > 0 else 1.0
            rule_stats[reason] = {
                "fired_count": count,
                "fraud_count": fraud_count,
                "precision": round(precision, 4)
            }

        overall_fraud_in_fired = int(evaluated[fired_mask]["is_fraud"].sum()) if total_fired > 0 else 0
        overall_prec = (overall_fraud_in_fired / total_fired) if total_fired > 0 else 1.0

        return {
            "split": split_name,
            "total_transactions": total,
            "gate0_fired_count": total_fired,
            "gate0_fired_pct": round(total_fired / total * 100.0, 2),
            "gate0_pass_count": total - total_fired,
            "gate0_pass_pct": round((total - total_fired) / total * 100.0, 2),
            "overall_precision": round(overall_prec, 4),
            "rule_breakdown": rule_stats
        }
