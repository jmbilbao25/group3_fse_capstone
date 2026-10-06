"""
Generates high-resolution architecture and testing workflow diagrams
for embedding into the Excel report.
"""

import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as patches

def create_architecture_diagram(output_path: str):
    fig, ax = plt.subplots(figsize=(15, 8.5), dpi=300)
    fig.patch.set_facecolor("#F8FAFC")
    ax.set_facecolor("#F8FAFC")
    ax.set_xlim(0, 15)
    ax.set_ylim(0, 8.5)
    ax.axis("off")

    # Title Banner
    ax.text(7.5, 8.1, "HYBRID RISK ENGINE ARCHITECTURE & TEST PIPELINE", 
            ha="center", va="center", fontsize=18, fontweight="bold", color="#1B365D", family="sans-serif")
    ax.text(7.5, 7.7, "Gate 0 Deterministic Rules -> XGBoost (Always) -> NanoJev Escalate-Only (Memo-Present) -> Async SAR", 
            ha="center", va="center", fontsize=11, color="#4B6B94", family="sans-serif")

    # Helper function for drawing rounded styled cards
    def draw_card(x, y, w, h, title, subtitle, items, bg_color="#FFFFFF", border_color="#CBD5E1", header_color="#1B365D"):
        # Shadow
        shadow = patches.FancyBboxPatch((x + 0.05, y - 0.05), w, h, boxstyle="round,pad=0.1,rounding_size=0.15",
                                        facecolor="#000000", alpha=0.06, edgecolor="none")
        ax.add_patch(shadow)
        # Card Body
        box = patches.FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.1,rounding_size=0.15",
                                    facecolor=bg_color, edgecolor=border_color, linewidth=1.5)
        ax.add_patch(box)
        # Title
        ax.text(x + w/2, y + h - 0.35, title, ha="center", va="center", fontsize=11, fontweight="bold", color=header_color)
        if subtitle:
            ax.text(x + w/2, y + h - 0.65, subtitle, ha="center", va="center", fontsize=8.5, color="#64748B", style="italic")
        # Items
        cur_y = y + h - (1.05 if subtitle else 0.75)
        for it in items:
            ax.text(x + 0.25, cur_y, f"• {it}", ha="left", va="center", fontsize=8.5, color="#334155")
            cur_y -= 0.32

    # Card 1: Input Payload
    draw_card(0.6, 4.4, 2.8, 2.7, "1. INCOMING TRANSFER", "Mobile App -> API Gateway", 
              ["Amount & User Balance", "Payee Account & Age", "Mobile Device Context", "OS Security Patch Age", "Root / Hooking Flags", "Optional Transfer Memo"],
              bg_color="#FFFFFF", border_color="#93C5FD", header_color="#1D4ED8")

    # Card 2: Gate 0 Hard Rules
    draw_card(3.8, 4.4, 2.7, 2.7, "2. GATE 0 RULES", "Deterministic (<0.01 ms)", 
              ["Impossible Velocity (>800 km/h)", "Rooted on High Value (>PHP 50k)", "Failed Attestation Verdict", "Emulator / Debugger Active", "Immediate Hard BLOCK on Trip", "100% Precision Filter"],
              bg_color="#FFFFFF", border_color="#FCA5A5", header_color="#B91C1C")

    # Card 3: XGBoost Primary Engine
    draw_card(6.9, 4.4, 3.4, 2.7, "3. TABULAR XGBOOST (S2)", "Runs Always on Every Tx (~4 ms)", 
              ["Evaluates 10+ Features via Tree C-API", "Top SHAP: os_patch_age_days", "Top SHAP: balance_drain_ratio", "Thresholds: tau_2fa=0.40, tau_block=0.50", "Outputs Baseline Risk Tier a0", "PR-AUC: 0.9986 | ROC-AUC: 0.9997"],
              bg_color="#FFFFFF", border_color="#86EFAC", header_color="#15803D")

    # Card 4: NanoJev Semantic Engine
    draw_card(11.0, 4.4, 3.4, 2.7, "4. NANOJEV ENGINE (S4)", "Only When Memo Present (~30%)", 
              ["Local Qwen2.5-0.5B ONNX INT8 (488 MB)", "Runs on CPU without GPU hardware", "Single Forward Pass (~200 ms)", "Calibrated Softmax Logits (T=5.00)", "ECE Error: 0.495 -> 0.213", "Choices: ALLOW, 2FA, BLOCK"],
              bg_color="#FFFFFF", border_color="#C084FC", header_color="#7E22CE")

    # Card 5: Escalate-Only Combine Rule (Middle Lower)
    draw_card(6.9, 1.2, 3.4, 2.4, "5. ESCALATE-ONLY FUSION", "Rule: RiskTier(a*) >= RiskTier(a0)",
              ["Can raise risk tier (ALLOW -> 2FA -> BLOCK)", "Can NEVER lower an XGBoost verdict", "Prompt injection immune (0 downgrades)", "Cuts missed fraud from 4.4% to 2.2%", "Expected cost cut by 37% on C1"],
              bg_color="#EFF6FF", border_color="#3B82F6", header_color="#1D4ED8")

    # Card 6: Policy Decision & Output (Right Lower)
    draw_card(11.0, 1.2, 3.4, 2.4, "6. FINAL TRANSACTION ACTION", "Three-Tier Operational Policy",
              ["ALLOW: Instant settlement", "REQUIRE_2FA: Step-up OTP/biometrics", "BLOCK: Transaction rejected", "False block rate: 0.00% on C1", "Novel scam recall@1% FPR: 93.3%"],
              bg_color="#F0FDF4", border_color="#22C55E", header_color="#15803D")

    # Card 7: Asynchronous SAR Generator (Left Lower)
    draw_card(0.6, 1.2, 5.9, 2.4, "7. ASYNC SUSPICIOUS ACTIVITY REPORT (SAR) GENERATOR", "Regulatory Compliance (AMLC Auto-Drafting)",
              ["Triggered non-blockingly whenever action is BLOCK or high-confidence fraud alert", "Dispatches in 0.008 ms background thread pool without stalling transfer latency SLA", "Auto-drafts complete legal forensic narrative with timeline, device indicators, and typology", "Saves regulator-ready drafts directly to hybrid_bench/reports/sar_drafts/"],
              bg_color="#FFFBEB", border_color="#FCD34D", header_color="#B45309")

    # Connecting Arrows
    def draw_arrow(x1, y1, x2, y2, label="", color="#475569", connectionstyle="arc3,rad=0.0"):
        ax.annotate("", xy=(x2, y2), xytext=(x1, y1),
                    arrowprops=dict(arrowstyle="-|>", color=color, lw=2.0, mutation_scale=15, connectionstyle=connectionstyle))
        if label:
            mx, my = (x1 + x2)/2, (y1 + y2)/2
            ax.text(mx, my + 0.15, label, ha="center", va="center", fontsize=8.5, fontweight="bold", color=color,
                    bbox=dict(boxstyle="round,pad=0.2", facecolor="#F8FAFC", edgecolor="none"))

    draw_arrow(3.4, 5.75, 3.8, 5.75, color="#2563EB")
    draw_arrow(6.5, 5.75, 6.9, 5.75, label="pass", color="#16A34A")
    draw_arrow(10.3, 5.75, 11.0, 5.75, label="memo present", color="#7C3AED")
    
    # Arrow from XGBoost to Escalate-Only
    draw_arrow(8.6, 4.4, 8.6, 3.6, label="a0 tier", color="#2563EB")
    
    # Arrow from NanoJev to Escalate-Only
    draw_arrow(12.7, 4.4, 10.3, 2.4, label="calibrated logits", color="#7C3AED", connectionstyle="arc3,rad=0.15")

    # Arrow from Escalate-Only to Action Policy
    draw_arrow(10.3, 2.4, 11.0, 2.4, label="final a*", color="#16A34A")

    # Arrow from Policy to SAR
    draw_arrow(11.0, 1.8, 6.5, 1.8, label="if BLOCK / Fraud", color="#DC2626")

    # Legend / Badge at bottom
    ax.text(7.5, 0.4, "Formal Preregistration Hash: 0f546de2f9cd3b0fad44ebf92279b5d738cbc2b2e0d58f8c2bd2ffe9a5db5620 | CPU-Only Benchmark",
            ha="center", va="center", fontsize=8, color="#94A3B8")

    plt.tight_layout()
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    plt.savefig(output_path, dpi=300, facecolor=fig.get_facecolor(), edgecolor="none")
    plt.close()
    print(f"Generated architecture diagram at: {output_path}")

def create_comparison_chart(output_path: str):
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5.5), dpi=300)
    fig.patch.set_facecolor("#F8FAFC")

    systems = ["S1 (Tuned Rules)", "S2 (XGBoost Only)", "S3 (XGB + TF-IDF)", "S4 (XGB + NanoJev)", "S5 (NanoJev Only)"]
    costs = [507034.53, 89696.37, 89696.37, 56546.08, 911534.71]
    missed_fraud = [26.67, 4.44, 4.44, 2.22, 40.00]
    colors = ["#94A3B8", "#3B82F6", "#60A5FA", "#16A34A", "#EF4444"]

    # 1. Cost Bar Chart
    bars1 = ax1.bar(systems, [c/1000 for c in costs], color=colors, width=0.55, edgecolor="#334155", linewidth=0.8)
    ax1.set_facecolor("#FFFFFF")
    ax1.grid(axis="y", linestyle="--", alpha=0.5, color="#CBD5E1")
    ax1.set_ylabel("Expected Cost per 1,000 Transfers (Thousand PHP)", fontsize=10, fontweight="bold", color="#1E293B")
    ax1.set_title("Operational Fraud Cost (Lower is Better)", fontsize=12, fontweight="bold", color="#1B365D", pad=12)
    ax1.set_xticklabels(systems, rotation=18, ha="right", fontsize=9, fontweight="medium")

    for bar in bars1:
        yval = bar.get_height()
        ax1.text(bar.get_x() + bar.get_width()/2, yval + 15, f"PHP {yval*1000:,.0f}", 
                 ha="center", va="bottom", fontsize=8.5, fontweight="bold", color="#1E293B")

    # Callout for S4 cost savings
    ax1.annotate("37% Cost Reduction\nvs XGBoost Alone", xy=(3, 56.5), xytext=(2.2, 350),
                 arrowprops=dict(facecolor="#16A34A", shrink=0.08, width=1.5, headwidth=7),
                 fontsize=9, fontweight="bold", color="#15803D", bbox=dict(boxstyle="round,pad=0.3", facecolor="#DCFCE7", edgecolor="#86EFAC"))

    # 2. Missed Fraud Rate Chart
    bars2 = ax2.bar(systems, missed_fraud, color=colors, width=0.55, edgecolor="#334155", linewidth=0.8)
    ax2.set_facecolor("#FFFFFF")
    ax2.grid(axis="y", linestyle="--", alpha=0.5, color="#CBD5E1")
    ax2.set_ylabel("Missed Fraud Rate (%)", fontsize=10, fontweight="bold", color="#1E293B")
    ax2.set_title("Missed Fraud Rate (Lower is Better)", fontsize=12, fontweight="bold", color="#1B365D", pad=12)
    ax2.set_xticklabels(systems, rotation=18, ha="right", fontsize=9, fontweight="medium")

    for bar in bars2:
        yval = bar.get_height()
        ax2.text(bar.get_x() + bar.get_width()/2, yval + 0.8, f"{yval:.2f}%", 
                 ha="center", va="bottom", fontsize=8.5, fontweight="bold", color="#1E293B")

    # Callout for S4 missed fraud cut
    ax2.annotate("Cuts Missed Fraud in Half\n(4.44% -> 2.22%)", xy=(3, 2.22), xytext=(1.8, 18),
                 arrowprops=dict(facecolor="#16A34A", shrink=0.08, width=1.5, headwidth=7),
                 fontsize=9, fontweight="bold", color="#15803D", bbox=dict(boxstyle="round,pad=0.3", facecolor="#DCFCE7", edgecolor="#86EFAC"))

    plt.tight_layout()
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    plt.savefig(output_path, dpi=300, facecolor=fig.get_facecolor(), edgecolor="none")
    plt.close()
    print(f"Generated systems comparison chart at: {output_path}")

if __name__ == "__main__":
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)))
    target_diag = os.path.join(out_dir, "testing_architecture_diagram.png")
    create_architecture_diagram(target_diag)
    target_chart = os.path.join(out_dir, "systems_comparison_chart.png")
    create_comparison_chart(target_chart)

