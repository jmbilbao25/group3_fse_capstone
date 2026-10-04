# Benchmark Data Card: Synthetic Banking Risk Dataset

## 1. Dataset Overview

This dataset was generated specifically to benchmark the simplified **Gate 0 -> XGBoost -> NanoJev (Escalate-Only)** risk engine architecture for Philippine retail bank transfers.
All data is synthetic, version-stamped, and deterministically reproducible from `hybrid_bench/config.yaml`.

### Split Summary and Hash Manifest

| Split | Total Rows | Unique Users | Fraud Rate | Memo-Present Rate | Parquet SHA256 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `T` | 600 | 176 | 18.0% (108) | 32.5% (195) | `b7734e81be6658f3...` |
| `V` | 200 | 58 | 15.0% (30) | 27.5% (55) | `7fa334912c726883...` |
| `C1` | 300 | 85 | 15.0% (45) | 29.7% (89) | `f148e1ef0ced58c4...` |
| `C2` | 300 | 88 | 15.0% (45) | 31.3% (94) | `d7d98c6cae703763...` |
| `C3` | 1,000 | 285 | 1.5% (15) | 30.5% (305) | `2af4755563e9f3cc...` |
| `C4` | 100 | 29 | 15.0% (15) | 33.0% (33) | `27230bb32b50f280...` |

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
