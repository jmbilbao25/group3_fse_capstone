# 2,000-Transaction Benchmark Dataset

This directory contains the ground-truth transaction dataset used to benchmark the three risk evaluation engines:
1. Traditional Rules-Only (No AI)
2. Pure Qwen2.5-0.5B (All AI)
3. Cascading Two-Gate (Gate 0 Deterministic + Gate 1 Neural Qwen)

## Dataset Files

- **JSON Format**: [`benchmark_dataset_2000.json`](./benchmark_dataset_2000.json) (Includes full metadata, customer profiles, and transaction records).
- **CSV Format**: [`benchmark_dataset_2000.csv`](./benchmark_dataset_2000.csv) (Tabular format with 2,000 rows and 26 features, ready for pandas, Excel, or SQL).

## Categorical Breakdown

| Category | Count | Ground-Truth Verdict | Key Scenario Features |
| :--- | :--- | :--- | :--- |
| **1. Routine Everyday** | 1,400 (70%) | `ALLOW` | Groceries, bills, lunch, transit within 5 km of home; spike ratio < 0.95x; clean memo. Gate 0 resolves in 0.12ms. |
| **2. Legitimate Edge Cases** | 300 (15%) | `ALLOW` / `REQUIRE_2FA` | Baguio road trip (210 km driving at 40 km/h), condo association dues, O'Reilly crypto textbook, attorney fees, university tuition. |
| **3. Physical Fraud (Impossible Travel)** | 100 (5%) | `BLOCK` | Tokyo, Singapore, Frankfurt, Sydney transactions appearing 10 to 25 minutes after Manila activity (speed > 1,000 km/h). |
| **4. Social Engineering & Scams** | 200 (10%) | `BLOCK` / `REQUIRE_2FA` | Crypto profit release fees, prize promo fees, 40% monthly guaranteed Ponzi, frozen wallet unlock fees, money mule transfers, VPN spoofing. |

## Feature Schema

| Field Name | Type | Description |
| :--- | :--- | :--- |
| `transaction_id` | String | Unique identifier (`TX-CAT1-0001` to `TX-CAT4-2000`) |
| `category` | String | Benchmark partition (Category 1 to 4) |
| `ground_truth_verdict` | String | Expected ground-truth banking verdict (`ALLOW`, `REQUIRE_2FA`, `BLOCK`) |
| `user_id` | String | Customer profile identifier |
| `customer_name` | String | Customer name |
| `customer_home_city` | String | Customer registered residence |
| `amount_php` | Float | Transaction amount in Philippine Pesos |
| `user_avg_amount_php` | Float | Customer historical baseline average amount |
| `spike_ratio` | Float | Transaction amount relative to baseline (`amount / avg_amount`) |
| `memo` | String | Natural language memo entered by the user |
| `current_lat`, `current_lon` | Float | GPS coordinates of the transaction |
| `home_lat`, `home_lon` | Float | Customer registered home GPS coordinates |
| `prev_lat`, `prev_lon` | Float | Location of the immediate preceding transaction |
| `elapsed_minutes` | Float | Minutes since preceding transaction |
| `distance_from_home_km` | Float | Spherical Haversine distance to home coordinates |
| `distance_from_prev_km` | Float | Spherical Haversine distance to preceding transaction coordinates |
| `velocity_kmh` | Float | Physical travel speed (`distance_from_prev_km / elapsed_hours`) |
| `is_vpn` | Boolean | Flag indicating IP/VPN proxy detection |
| `is_impossible_travel` | Boolean | Flag indicating physical velocity > 800 km/h |
| `rules_only_verdict` | String | Decision rendered by traditional banking rules |
| `rules_only_correct` | Boolean | Whether traditional rules verdict matched ground truth |
| `two_gate_verdict` | String | Decision rendered by Cascading Two-Gate architecture |
| `two_gate_path` | String | Gate attribution: `GATE_0_FAST_PATH` (< 0.1ms) or `GATE_1_NEURAL_QWEN` (~110ms) |
| `two_gate_correct` | Boolean | Whether Cascading Two-Gate verdict matched ground truth |
| `pure_qwen_verdict` | String | Decision rendered by Pure Qwen neural model |
| `pure_qwen_path` | String | Execution route (`GATE_1_NEURAL_QWEN`) |
| `pure_qwen_correct` | Boolean | Whether Pure Qwen verdict matched ground truth |

## Overall Performance Comparison

| Metric | Rules-Only (No AI) | Pure Qwen (All AI) | Cascading Two-Gate |
| :--- | :--- | :--- | :--- |
| **Accuracy (Overall)** | 88.0% (1,760/2,000) | 97.0% (1,940/2,000) | 97.0% (1,940/2,000) |
| **False Positive Rate** | 14.1% (240/1,700) | 3.5% (60/1,700) | 3.5% (60/1,700) |
| **False Negative Rate** | 0.0% (0/300) | 0.0% (0/300) | 0.0% (0/300) |
| **Average Latency** | 0.12ms | 112.50ms | 28.21ms |
| **Throughput (1 Core)** | ~8,300 TPS | ~8.9 TPS | ~35.4 TPS |
| **Gate 0 Triage Ratio** | 100% (All rules) | 0% (All neural) | 75.0% (1,500/2,000 in < 0.1ms) |

For subsequent evaluation comparing generative neural models with the non-autoregressive encoder architecture (Laya), refer to [`hybrid_bench/reports/laya_benchmark_results.json`](file:///c:/Users/JLB83807/The%20Vault/workspaces/FSE-Capstone/hybrid_bench/reports/laya_benchmark_results.json) where Laya achieves 0.10 ms P99 latency and real-time synchronous memo analysis.
