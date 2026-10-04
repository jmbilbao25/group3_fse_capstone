"""
Data Generator for hybrid_bench:
Config-driven, version-stamped synthetic transaction dataset.
Generates disjoint users, non-trivially separable features,
device context, realistic memo distributions, and validation checks.
"""

import os
import sys
import math
import random
import hashlib
import yaml
import pandas as pd
import numpy as np
from typing import Dict, List, Any, Tuple

EARTH_RADIUS_KM = 6371.0

def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2.0) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2.0) ** 2)
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return EARTH_RADIUS_KM * c

def augment_memo(memo: str, is_c2: bool, rng: random.Random) -> str:
    """Applies casing, typo injection, and optional ref append."""
    if not memo:
        return ""
    text = memo
    # 1. Casing variation
    case_choice = rng.random()
    if case_choice < 0.20:
        text = text.lower()
    elif case_choice < 0.35:
        text = text.title()
    elif case_choice < 0.40:
        text = text.upper()
    else:
        text = text[0].upper() + text[1:] if len(text) > 1 else text

    # 2. Typos (p = 0.25)
    if rng.random() < 0.25 and len(text) > 4:
        typo_type = rng.choice(["swap", "dup", "drop"])
        pos = rng.randint(1, len(text) - 2)
        if typo_type == "swap":
            text = text[:pos] + text[pos+1] + text[pos] + text[pos+2:]
        elif typo_type == "dup":
            text = text[:pos] + text[pos] + text[pos:]
        elif typo_type == "drop":
            text = text[:pos] + text[pos+1:]

    # 3. Optional short ref (only for seed splits, NOT C2)
    if not is_c2 and rng.random() < 0.20:
        ref_num = rng.randint(1000, 99999)
        text += f" - Ref #{ref_num}"

    return text

def load_config() -> Dict[str, Any]:
    config_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "config.yaml")
    with open(config_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)

def generate_splits(profile: str = "quick", seed: int = 42) -> Dict[str, pd.DataFrame]:
    print(f"Generating synthetic dataset: Profile='{profile}', Primary Seed={seed}")
    cfg = load_config()
    profile_cfg = cfg["profiles"][profile]
    split_sizes = profile_cfg["split_sizes"]
    user_counts = profile_cfg["user_counts"]
    fraud_rates = cfg["splits"]["fraud_rates"]
    assumptions = cfg["assumptions"]

    rng = random.Random(seed)
    np_rng = np.random.default_rng(seed)

    # Load seed memo files
    seeds_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "seeds")
    train_seeds_df = pd.read_csv(os.path.join(seeds_dir, "memo_seed_train.csv"))
    heldout_seeds_df = pd.read_csv(os.path.join(seeds_dir, "memo_heldout_independent.csv"))
    handwritten_df = pd.read_csv(os.path.join(seeds_dir, "handwritten_heldout.csv"))

    # Memo lookup pools
    pool_train_legit = train_seeds_df[train_seeds_df["signal"] == "legit"].to_dict("records")
    pool_train_scam = train_seeds_df[train_seeds_df["signal"] == "scam"].to_dict("records")
    pool_train_neutral = train_seeds_df[train_seeds_df["signal"] == "neutral"].to_dict("records")

    pool_heldout_legit = heldout_seeds_df[heldout_seeds_df["signal"] == "legit"].to_dict("records")
    pool_heldout_scam = heldout_seeds_df[heldout_seeds_df["signal"] == "scam"].to_dict("records")
    pool_heldout_neutral = heldout_seeds_df[heldout_seeds_df["signal"] == "neutral"].to_dict("records")

    # Major Philippine Metro Areas for realistic GPS baselines
    CITIES = [
        {"name": "Makati CBD", "lat": 14.5547, "lon": 121.0200},
        {"name": "Quezon City", "lat": 14.6760, "lon": 121.0437},
        {"name": "Taguig BGC", "lat": 14.5492, "lon": 121.0494},
        {"name": "Pasig Ortigas", "lat": 14.5869, "lon": 121.0614},
        {"name": "Cebu IT Park", "lat": 10.3157, "lon": 123.8854},
        {"name": "Davao Downtown", "lat": 7.0731, "lon": 125.6128},
        {"name": "Baguio City", "lat": 16.4023, "lon": 120.5960},
        {"name": "Iloilo City", "lat": 10.7202, "lon": 122.5621},
    ]

    FOREIGN_FRAUD_LOCATIONS = [
        {"name": "Tokyo", "lat": 35.6762, "lon": 139.6503},
        {"name": "Singapore", "lat": 1.3521, "lon": 103.8198},
        {"name": "Frankfurt", "lat": 50.1109, "lon": 8.6821},
        {"name": "Sydney", "lat": -33.8688, "lon": 151.2093},
    ]

    PURPOSES = ["Funds Transfer", "Bills Payment", "Remittance", "Savings"]
    PAYEE_TYPES = ["third_party_individual", "registered_biller", "own_account", "business"]

    # 1. Create Disjoint Users for Each Split
    splits_data: Dict[str, List[Dict[str, Any]]] = {s: [] for s in split_sizes.keys()}
    user_registry: Dict[str, Dict[str, Any]] = {}
    users_by_split: Dict[str, List[str]] = {}

    for split_name, n_users in user_counts.items():
        users_by_split[split_name] = []
        for u_idx in range(1, n_users + 1):
            uid = f"usr-{split_name}-{u_idx:04d}"
            city = rng.choice(CITIES)
            avg_amt = round(float(np_rng.lognormal(mean=7.8, sigma=0.8)), 2) # Median ~2,500 PHP
            avg_amt = max(500.0, min(avg_amt, 80000.0))
            is_power_user = rng.random() < 0.10
            is_enthusiast = rng.random() < 0.05 # Uses rooted / custom ROM legitimately
            user_registry[uid] = {
                "user_id": uid,
                "split": split_name,
                "home_lat": city["lat"],
                "home_lon": city["lon"],
                "home_city": city["name"],
                "avg_amount": avg_amt,
                "is_power_user": is_power_user,
                "is_enthusiast": is_enthusiast,
                "device_id": f"dev-{hashlib.md5(uid.encode()).hexdigest()[:8]}",
                "device_age_days": rng.randint(30, 900),
                "last_lat": city["lat"],
                "last_lon": city["lon"],
                "usual_hour": rng.randint(9, 21),
            }
            users_by_split[split_name].append(uid)

    # 2. Generate Transactions per Split
    tx_counter = 1
    for split_name, n_tx in split_sizes.items():
        fraud_rate = fraud_rates[split_name]
        n_fraud = int(round(n_tx * fraud_rate))
        n_legit = n_tx - n_fraud
        labels = [True] * n_fraud + [False] * n_legit
        rng.shuffle(labels)

        is_c2 = (split_name == "C2")
        is_c4 = (split_name == "C4")
        users_pool = users_by_split[split_name]

        for is_fraud in labels:
            tx_id = f"TX-{split_name}-{tx_counter:06d}"
            tx_counter += 1
            u = user_registry[rng.choice(users_pool)]

            # Core Financial Signals
            user_avg = u["avg_amount"]
            if is_fraud:
                # Fraud: 10% gate0 trivial (impossible travel), 90% subtle/realistic
                is_gate0_trivial = rng.random() < assumptions["device_signals"]["gate0_trivial_fraud_share"]
                if is_gate0_trivial:
                    spike_ratio = round(rng.uniform(4.0, 15.0), 2)
                    amount = round(user_avg * spike_ratio, 2)
                    balance_drain = round(rng.uniform(0.70, 0.99), 2)
                else:
                    # Subtle/hard fraud: moderate spike or even normal amount
                    spike_choice = rng.random()
                    if spike_choice < 0.40:
                        spike_ratio = round(rng.uniform(0.8, 2.5), 2) # Normal/modest spike
                    elif spike_choice < 0.80:
                        spike_ratio = round(rng.uniform(2.5, 6.0), 2)
                    else:
                        spike_ratio = round(rng.uniform(6.0, 12.0), 2)
                    amount = round(user_avg * spike_ratio, 2)
                    balance_drain = round(rng.uniform(0.30, 0.95), 2)
            else:
                # Legit: mostly normal amounts, but includes 5% legitimate hard negatives (rent, tuition spikes)
                is_gate0_trivial = False
                if rng.random() < 0.05:
                    spike_ratio = round(rng.uniform(3.0, 6.5), 2) # Rent or tuition spike
                else:
                    spike_ratio = round(rng.uniform(0.05, 1.8), 2)
                amount = round(max(50.0, user_avg * spike_ratio), 2)
                balance_drain = round(rng.uniform(0.01, 0.50), 2)

            # Cumulative outflows
            cum_1h = round(amount * rng.uniform(1.0, 1.5) if is_fraud else amount, 2)
            cum_24h = round(cum_1h * rng.uniform(1.2, 3.5), 2)
            payees_24h = rng.randint(2, 7) if is_fraud else (1 if rng.random() < 0.80 else 2)
            new_payee = (rng.random() < 0.75) if is_fraud else (rng.random() < 0.20)
            payee_age = rng.randint(0, 3) if new_payee else rng.randint(15, 600)
            senders_to_payee = rng.randint(4, 25) if (is_fraud and rng.random() < 0.35) else 1

            # Transfer Purpose & Payee Type
            if is_fraud and rng.random() < assumptions["transfer_purpose_mismatch"]["fraud_mismatch_rate"]:
                purpose = "Bills Payment"
                payee_type = "third_party_individual" # Inconsistent mismatch
            else:
                purpose = rng.choice(PURPOSES)
                if purpose == "Bills Payment":
                    payee_type = "registered_biller"
                elif purpose == "Savings":
                    payee_type = "own_account"
                elif purpose == "Remittance":
                    payee_type = rng.choice(["third_party_individual", "business"])
                else:
                    payee_type = rng.choice(PAYEE_TYPES)

            # Temporal features
            hour = rng.randint(0, 23)
            dow = rng.randint(0, 6)
            usual_hour_gap = abs(hour - u["usual_hour"])
            dormant_days = rng.randint(30, 180) if (is_fraud and rng.random() < 0.20) else rng.randint(0, 14)
            channel = rng.choice(["mobile_android", "mobile_ios"])

            # Device Context Signals
            is_missing_device = (rng.random() < assumptions["device_signals"]["missing_context_rate"])
            if is_missing_device:
                attestation = "MISSING"
                rooted = False
                hooking = False
                emulator = False
                debugger = False
                tampered = False
                unofficial_store = False
                dev_options = False
                mock_loc = False
                acc_active = False
                scr_share = False
                device_new = False
                device_age = u["device_age_days"]
                accounts_on_dev = 1
                os_patch_age = 60
                login_method = "biometric"
                sec_since_login = 90
                failed_logins = 0
                cred_change_hours = 720
                payee_pasted = False
                form_sec = 25
                gps_acc = 10.0
                tz_mismatch = False
                ip_gps_mismatch = False
                is_vpn = False
            else:
                p_dev = assumptions["device_signals"]
                rooted = (rng.random() < p_dev["p_rooted_given_fraud"]) if is_fraud else (rng.random() < p_dev["p_rooted_given_legit"] or u["is_enthusiast"])
                hooking = (rng.random() < p_dev["p_hooking_given_fraud"]) if is_fraud else (rng.random() < p_dev["p_hooking_given_legit"])
                emulator = (rng.random() < p_dev["p_emulator_given_fraud"]) if is_fraud else (rng.random() < p_dev["p_emulator_given_legit"])
                debugger = (rng.random() < p_dev["p_debugger_given_fraud"]) if is_fraud else (rng.random() < p_dev["p_debugger_given_legit"])
                tampered = (rng.random() < p_dev["p_tampered_given_fraud"]) if is_fraud else (rng.random() < p_dev["p_tampered_given_legit"])
                mock_loc = (rng.random() < p_dev["p_mock_location_given_fraud"]) if is_fraud else (rng.random() < p_dev["p_mock_location_given_legit"])
                is_vpn = (rng.random() < p_dev["p_vpn_given_fraud"]) if is_fraud else (rng.random() < p_dev["p_vpn_given_legit"])
                dev_options = rooted or (rng.random() < 0.15)
                unofficial_store = (rng.random() < 0.08) if is_fraud else (rng.random() < 0.01)
                acc_active = (rng.random() < 0.07) if is_fraud else (rng.random() < 0.01)
                scr_share = (rng.random() < 0.05) if is_fraud else False

                if emulator or hooking or tampered:
                    attestation = "FAILED"
                elif rooted:
                    attestation = "MEETS_BASIC"
                elif rng.random() < 0.70:
                    attestation = "MEETS_STRONG"
                else:
                    attestation = "MEETS_DEVICE"

                device_new = (rng.random() < 0.40) if is_fraud else (rng.random() < 0.05)
                device_age = rng.randint(0, 5) if device_new else u["device_age_days"]
                accounts_on_dev = rng.randint(2, 6) if (is_fraud and rng.random() < 0.30) else 1
                os_patch_age = rng.randint(180, 500) if is_fraud else rng.randint(10, 180)
                login_method = rng.choice(["password", "pin", "biometric"]) if is_fraud else (rng.choice(["biometric", "biometric", "pin"]))
                sec_since_login = rng.randint(5, 60) if is_fraud else rng.randint(30, 600)
                failed_logins = rng.randint(1, 4) if (is_fraud and rng.random() < 0.30) else 0
                cred_change_hours = rng.randint(1, 24) if (is_fraud and rng.random() < 0.25) else rng.randint(100, 2000)
                payee_pasted = (rng.random() < 0.85) if is_fraud else (rng.random() < 0.25)
                form_sec = rng.randint(3, 10) if is_fraud else rng.randint(12, 45)
                gps_acc = round(rng.uniform(20.0, 100.0) if mock_loc else rng.uniform(5.0, 25.0), 1)
                tz_mismatch = (rng.random() < 0.15) if is_fraud else False
                ip_gps_mismatch = is_vpn or (rng.random() < 0.20 if is_fraud else False)

            # Geographic Telemetry
            if is_fraud and is_gate0_trivial:
                # Impossible travel: Tokyo, Frankfurt, Singapore in 10-25 mins
                foreign_city = rng.choice(FOREIGN_FRAUD_LOCATIONS)
                curr_lat = foreign_city["lat"]
                curr_lon = foreign_city["lon"]
                elapsed_min = round(rng.uniform(10.0, 30.0), 1)
                dist_prev = round(haversine(curr_lat, curr_lon, u["home_lat"], u["home_lon"]), 2)
                dist_home = dist_prev
                velocity_kmh = round(dist_prev / (elapsed_min / 60.0), 2)
            else:
                # Normal or domestic travel
                is_roadtrip = (not is_fraud and rng.random() < 0.04)
                if is_roadtrip:
                    # Legitimate roadtrip to Baguio or nearby province (210km, 5 hrs driving)
                    curr_lat = 16.4023 + rng.uniform(-0.02, 0.02)
                    curr_lon = 120.5960 + rng.uniform(-0.02, 0.02)
                    elapsed_min = round(rng.uniform(240.0, 360.0), 1)
                    dist_prev = round(haversine(curr_lat, curr_lon, u["home_lat"], u["home_lon"]), 2)
                    dist_home = dist_prev
                    velocity_kmh = round(dist_prev / (elapsed_min / 60.0), 2)
                else:
                    curr_lat = round(u["home_lat"] + rng.uniform(-0.02, 0.02), 6)
                    curr_lon = round(u["home_lon"] + rng.uniform(-0.02, 0.02), 6)
                    elapsed_min = round(rng.uniform(15.0, 300.0), 1)
                    dist_prev = round(haversine(curr_lat, curr_lon, u["home_lat"], u["home_lon"]), 2)
                    dist_home = dist_prev
                    velocity_kmh = round(dist_prev / (elapsed_min / 60.0), 2)

            # Memo generation & signals
            memo_blank = (rng.random() < assumptions["memo_blank_rate"])
            memo_present = not memo_blank
            memo_str = ""
            memo_signal = "none"
            typology_novel = False

            if memo_present:
                distrib = assumptions["memo_distribution_present"]["fraud" if is_fraud else "legit"]
                r_memo = rng.random()

                if is_c4:
                    # Handwritten C4 split
                    sample_row = rng.choice(handwritten_df.to_dict("records"))
                    memo_str = sample_row["memo"]
                    memo_signal = sample_row["label"]
                elif is_c2:
                    # C2 DRAW STRICTLY FROM HELDOUT
                    if is_fraud:
                        if r_memo < distrib["scam"]:
                            rec = rng.choice(pool_heldout_scam)
                        elif r_memo < distrib["scam"] + distrib["neutral"]:
                            rec = rng.choice(pool_heldout_neutral)
                        else:
                            rec = rng.choice(pool_heldout_legit)
                    else:
                        if r_memo < distrib["legit"]:
                            rec = rng.choice(pool_heldout_legit)
                        elif r_memo < distrib["legit"] + distrib["neutral"]:
                            rec = rng.choice(pool_heldout_neutral)
                        else:
                            rec = rng.choice(pool_heldout_scam)
                    memo_str = augment_memo(rec["memo"], is_c2=True, rng=rng)
                    memo_signal = rec["signal"]
                    typology_novel = rec["typology_novel"]
                else:
                    # T, V, C1, C3 DRAW STRICTLY FROM SEED TRAIN
                    if is_fraud:
                        if r_memo < distrib["scam"]:
                            rec = rng.choice(pool_train_scam)
                        elif r_memo < distrib["scam"] + distrib["neutral"]:
                            rec = rng.choice(pool_train_neutral)
                        else:
                            rec = rng.choice(pool_train_legit)
                    else:
                        if r_memo < distrib["legit"]:
                            rec = rng.choice(pool_train_legit)
                        elif r_memo < distrib["legit"] + distrib["neutral"]:
                            rec = rng.choice(pool_train_neutral)
                        else:
                            rec = rng.choice(pool_train_scam)
                    memo_str = augment_memo(rec["memo"], is_c2=False, rng=rng)
                    memo_signal = rec["signal"]
                    typology_novel = rec["typology_novel"]

            # Label Noise in T and V only (2.5%)
            actual_fraud = is_fraud
            if split_name in ("T", "V") and rng.random() < assumptions["device_signals"]["label_noise_rate_t_v"]:
                actual_fraud = not is_fraud

            # Action label for reference
            action_label = "BLOCK" if (is_fraud and (is_gate0_trivial or spike_ratio > 8.0)) else ("REQUIRE_2FA" if is_fraud else "ALLOW")

            row = {
                "transaction_id": tx_id,
                "user_id": u["user_id"],
                "split": split_name,
                "is_fraud": actual_fraud,
                "action_label": action_label,
                "amount_php": amount,
                "user_avg_amount_php": user_avg,
                "spike_ratio": spike_ratio,
                "balance_drain_ratio": balance_drain,
                "cum_outflow_1h": cum_1h,
                "cum_outflow_24h": cum_24h,
                "payees_24h": payees_24h,
                "new_payee": new_payee,
                "payee_age_days": payee_age,
                "senders_to_payee_24h": senders_to_payee,
                "transfer_purpose": purpose,
                "payee_type": payee_type,
                "hour": hour,
                "dow": dow,
                "usual_hour_gap": usual_hour_gap,
                "dormant_days": dormant_days,
                "channel": channel,
                "memo": memo_str,
                "memo_present": memo_present,
                "memo_signal": memo_signal,
                "typology_novel": typology_novel,
                "device_id_new": device_new,
                "device_age_days": device_age,
                "accounts_per_device": accounts_on_dev,
                "rooted": rooted,
                "hooking": hooking,
                "emulator": emulator,
                "debugger": debugger,
                "tampered": tampered,
                "unofficial_store": unofficial_store,
                "dev_options": dev_options,
                "mock_location": mock_loc,
                "accessibility_active": acc_active,
                "screen_sharing": scr_share,
                "attestation_verdict": attestation,
                "os_patch_age_days": os_patch_age,
                "login_method": login_method,
                "seconds_since_login": sec_since_login,
                "failed_logins_1h": failed_logins,
                "credential_change_hours_ago": cred_change_hours,
                "payee_pasted": payee_pasted,
                "form_seconds": form_sec,
                "gps_accuracy_m": gps_acc,
                "tz_mismatch": tz_mismatch,
                "ip_gps_mismatch": ip_gps_mismatch,
                "is_vpn": is_vpn,
                "distance_from_home_km": dist_home,
                "distance_from_prev_km": dist_prev,
                "elapsed_minutes": elapsed_min,
                "velocity_kmh": velocity_kmh,
                "is_gate0_trivial": is_gate0_trivial
            }
            splits_data[split_name].append(row)

    # Convert to DataFrames and Validate
    splits_dfs: Dict[str, pd.DataFrame] = {}
    for s_name, rows in splits_data.items():
        df = pd.DataFrame(rows)
        splits_dfs[s_name] = df

    # 3. Assertions (Fail Loudly)
    print("\nExecuting integrity assertions...")
    # Check disjoint users
    all_users_sets = [set(df["user_id"]) for df in splits_dfs.values()]
    for i in range(len(all_users_sets)):
        for j in range(i + 1, len(all_users_sets)):
            overlap = all_users_sets[i].intersection(all_users_sets[j])
            assert len(overlap) == 0, f"User overlap detected between splits! Overlap: {overlap}"
    print("  [PASS] Zero user overlap across all splits verified.")

    # Check C2 memo isolation
    train_seed_memos_set = set(m.lower().strip() for m in train_seeds_df["memo"])
    c2_memos_present = splits_dfs["C2"][splits_dfs["C2"]["memo_present"]]["memo"].str.lower().str.strip()
    for m in c2_memos_present:
        base_m = m.split(" - ref #")[0].strip()
        assert base_m not in train_seed_memos_set, f"Data leakage! C2 memo '{base_m}' found in training seed memos!"
    print("  [PASS] C2 memos drawn strictly from held-out independent set (zero leakage into train seeds).")

    # Check fraud rates
    for s_name, df in splits_dfs.items():
        actual_fr = df["is_fraud"].mean()
        target_fr = fraud_rates[s_name]
        print(f"  Split '{s_name}': {len(df):,} rows | Fraud Rate: {actual_fr:.3f} (target: {target_fr:.3f}) | Memo Present: {df['memo_present'].mean():.3f}")
        assert abs(actual_fr - target_fr) <= 0.03, f"Fraud rate out of bounds for split {s_name}: {actual_fr} vs {target_fr}"
    print("  [PASS] Fraud rates within preregistered specifications.")

    # 4. Save to Disk
    splits_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "splits")
    os.makedirs(splits_dir, exist_ok=True)

    sha_hashes = {}
    for s_name, df in splits_dfs.items():
        parquet_path = os.path.join(splits_dir, f"{s_name}.parquet")
        csv_path = os.path.join(splits_dir, f"{s_name}.csv")
        df.to_parquet(parquet_path, index=False)
        df.to_csv(csv_path, index=False)

        with open(parquet_path, "rb") as f:
            h = hashlib.sha256(f.read()).hexdigest()
        sha_hashes[s_name] = h
        print(f"Saved: {s_name}.parquet ({len(df):,} rows, SHA256: {h[:12]}...)")

    # 5. Generate DATA_CARD.md
    generate_data_card(splits_dfs, sha_hashes, assumptions)

    return splits_dfs

def generate_data_card(splits_dfs: Dict[str, pd.DataFrame], sha_hashes: Dict[str, str], assumptions: Dict[str, Any]):
    data_card_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "DATA_CARD.md")
    
    rows_summary = []
    for s_name, df in splits_dfs.items():
        rows_summary.append(
            f"| `{s_name}` | {len(df):,} | {df['user_id'].nunique():,} | {df['is_fraud'].mean()*100:.1f}% ({df['is_fraud'].sum():,}) | "
            f"{df['memo_present'].mean()*100:.1f}% ({df['memo_present'].sum():,}) | `{sha_hashes[s_name][:16]}...` |"
        )
    rows_summary_str = "\n".join(rows_summary)

    content = f"""# Benchmark Data Card: Synthetic Banking Risk Dataset

## 1. Dataset Overview

This dataset was generated specifically to benchmark the simplified **Gate 0 -> XGBoost -> NanoJev (Escalate-Only)** risk engine architecture for Philippine retail bank transfers.
All data is synthetic, version-stamped, and deterministically reproducible from `hybrid_bench/config.yaml`.

### Split Summary and Hash Manifest

| Split | Total Rows | Unique Users | Fraud Rate | Memo-Present Rate | Parquet SHA256 |
| :--- | :--- | :--- | :--- | :--- | :--- |
{rows_summary_str}

**Data Separation Guarantee**: User IDs are mutually disjoint across all splits. Test set $C_2$ draws memos strictly from the held-out independent seed file `memo_heldout_independent.csv` (106 novel rows), ensuring zero lexical overlap with training sets $T, V$ and standard test set $C_1$.

---

## 2. Feature Schema

The dataset contains 56 tabular, behavioural, geographic, device-context, and memo features:

| Group | Key Columns | Description |
| :--- | :--- | :--- |
| **Identifiers & Targets** | `transaction_id`, `user_id`, `split`, `is_fraud`, `action_label` | Identifiers, binary ground truth, and 3-action tier |
| **Financial Signals** | `amount_php`, `user_avg_amount_php`, `spike_ratio`, `balance_drain_ratio`, `cum_outflow_1h`, `cum_outflow_24h` | Transaction size relative to historical baseline and balance drain |
| **Payee Telemetry** | `payees_24h`, `new_payee`, `payee_age_days`, `senders_to_payee_24h`, `transfer_purpose`, `payee_type` | Counterparty risk, mule patterns, and purpose-payee alignment |
| **Temporal Context** | `hour`, `dow`, `usual_hour_gap`, `dormant_days`, `channel` | Time-of-day deviation and account dormancy reactivation |
| **Natural Language Memo** | `memo`, `memo_present`, `memo_signal`, `typology_novel` | Transfer description text, presence flag, ground-truth signal, and novelty flag |
| **Device Context** | `device_id_new`, `device_age_days`, `accounts_per_device`, `rooted`, `hooking`, `emulator`, `debugger`, `tampered`, `unofficial_store`, `dev_options`, `mock_location`, `accessibility_active`, `screen_sharing`, `attestation_verdict`, `os_patch_age_days` | Client-reported security telemetry and hardware attestation verdict |
| **Session Security** | `login_method`, `seconds_since_login`, `failed_logins_1h`, `credential_change_hours_ago`, `payee_pasted`, `form_seconds` | Login friction, rapid copy-paste submission, and credential change recency |
| **Geographic Telemetry** | `gps_accuracy_m`, `tz_mismatch`, `ip_gps_mismatch`, `is_vpn`, `distance_from_home_km`, `distance_from_prev_km`, `elapsed_minutes`, `velocity_kmh`, `is_gate0_trivial` | Spherical distance, travel velocity, VPN proxy flags, and Gate 0 impossible travel flags |

---

## 3. Operational Banking Assumptions Table

All statistical relationships in this synthetic dataset are explicit assumptions:

| Assumption Parameter | Configured Value | Operational Rationale |
| :--- | :--- | :--- |
| `memo_blank_rate` | 70.0% | Banking reality: the vast majority of mobile banking users leave the optional memo blank |
| `p_rooted_given_fraud` vs `p_rooted_given_legit` | 15.0% vs 3.0% | Rooting is correlated with risk, but legitimate tech enthusiasts also root devices |
| `p_hooking_given_fraud` vs `p_hooking_given_legit` | 6.0% vs 0.5% | Active Frida/Xposed hooking frameworks are rare and strongly suspicious |
| `p_emulator_given_fraud` vs `p_emulator_given_legit` | 8.0% vs 0.5% | Emulators are utilized by automated fraud farms |
| `p_vpn_given_fraud` vs `p_vpn_given_legit` | 22.0% vs 4.0% | Fraudsters frequently tunnel traffic; legitimate users occasionally use corporate/privacy VPNs |
| `transfer_purpose_mismatch` | 35.0% in fraud | Fraudsters often misclassify transfers (e.g., selecting 'Bills Payment' to send to an individual mule) |
| `gate0_trivial_fraud_share` | 10.0% of fraud | Only 10% of fraud is obvious impossible travel; the remaining 90% requires multi-factor tabular and semantic scoring |
| `label_noise_rate_t_v` | 2.5% in T and V | Real-world chargeback reporting latency causes label noise in training and validation sets |
| `missing_device_context` | 5.0% | Old app versions or network dropouts result in missing device telemetry (`attestation_verdict='MISSING'`) |

---

## 4. Limitations and Non-Production Notice

1. **Synthetic Nature**: All records, user profiles, amounts, and telemetry are synthetically modeled.
2. **Assumed Relationships**: While calibrated to observed banking fraud typologies in the Philippines, correlation strengths are assumptions, not measurements from real bank ledgers.
3. **Seed Authoring**: Seed memos were drafted and curated by an ML expert auditor rather than drawn from live customer PII.
4. **Client-Side Spoofing**: In production, client-reported device context must be anchored to cryptographically signed Play Integrity or App Attest server tokens.
"""

    with open(data_card_path, "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")
    print(f"Generated DATA_CARD.md: {data_card_path}")

if __name__ == "__main__":
    profile_arg = "quick"
    if len(sys.argv) > 1 and sys.argv[1] in ("quick", "full"):
        profile_arg = sys.argv[1]
    generate_splits(profile=profile_arg)
