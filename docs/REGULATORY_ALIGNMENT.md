# Regulatory alignment and AI governance

This document maps the two-stage transfer risk engine proof of concept to relevant Philippine banking regulations and AI governance standards. 

Important disclaimer: This repository is an academic and technical proof of concept developed in a simulation environment. Nothing in this implementation constitutes legal compliance certification under Philippine law or Bangko Sentral ng Pilipinas regulations. System capabilities are described as aligned with regulatory intent.

## 1. BSP Circular 1213 and the Anti-Financial Account Scamming Act (AFASA)

Republic Act No. 12010 (the Anti-Financial Account Scamming Act, or AFASA) and BSP Circular No. 1213 establish operational expectations for covered financial institutions to combat authorized push payment scams, social engineering, and money mule networks.

The table below maps specific provisions of Circular 1213 to technical mechanisms in this architecture, including an explicit gap analysis of prototype limitations.

| Regulatory expectation | Architectural mechanism | Prototype implementation | Production gap analysis |
| :--- | :--- | :--- | :--- |
| Real-time fraud monitoring across transaction velocity | Gate 0 rule evaluation and XGBoost tabular pipeline (Stage A) | Calculates physical velocity between successive device locations in km/h (`velocity_kmh`); blocks transfers with velocity exceeding 1,000 km/h. | Prototype operates on synthetic coordinates. Production systems require carrier cell-tower triangulation, telco location APIs, and historical user travel profiles. |
| Geolocation and IP discrepancy monitoring | Haversine distance engine and IP mismatch detection | Evaluates distance from primary residence (`distance_from_home_km`) and flags IP-to-GPS discrepancies over 500 km. | Prototype relies on mock IP coordinates; production requires dynamic IP reputation intelligence and commercial MaxMind/GeoIP databases. |
| Device integrity and environment attestation | Gate 0 hard security filter | Evaluates hardware signals: OS tampering, rooting/jailbreak flags, emulator detection, and Google Play Integrity verdicts. | Prototype receives boolean client payloads. Production systems require cryptographic server-side validation of hardware attestation tokens. |
| Phasing out SMS/email OTP for high-risk transfers | Step-up authentication display mapping (`STEP_UP`) | Internal `REQUIRE_2FA` enum is presented to customer flows strictly as in-app biometric confirmation or out-of-band approval. | Prototype simulates biometric prompt approval; production requires integration with FIDO2/WebAuthn infrastructure or mobile banking secure enclaves. |
| Targeted warnings for social engineering scams | Stage B NanoJev typology check and localized warning screens | Evaluates payment memos for 6 Philippine scam typologies; presents targeted warnings with Cancel and Pause actions. | Warning effectiveness on actual retail customers is unmeasured; production deployment requires longitudinal A/B testing and regulatory sandbox approval. |
| Reporting of suspicious transactions | Asynchronous AMLC SAR draft generator | Automatically generates AMLC-aligned draft Suspicious Transaction Reports in Markdown for all BLOCKED transfers and HIGH-tier scam warnings. | Drafts are generated locally for simulated compliance workflows; production requires XML/JSON formatting integrated with the AMLC Portal (goAML). |

## 2. Voluntary AI governance: STARS framework (BSP Memorandum M-2026-031)

BSP Memorandum M-2026-031 outlines voluntary AI governance principles for financial institutions under the STARS framework: Sustainability, Transparency, Accountability, Responsibility, and Security. The table below details how the two-stage risk engine implements each pillar.

| STARS pillar | Governance principle | Implementation in risk engine | Technical evidence |
| :--- | :--- | :--- | :--- |
| Sustainability | Deploy resource-efficient AI models compatible with institutional hardware constraints without excessive compute costs. | NanoJev is deployed as a quantized 8-bit ONNX model (Qwen2.5-0.5B INT8) running entirely on CPU. Employs a content-bound SHA256 prompt cache to eliminate redundant inference. | Benchmark p50 latency is ~0.4 ms for cached queries and ~220 ms for fresh queries, requiring no dedicated GPU infrastructure. |
| Transparency | Provide explainable model outputs and avoid opaque black-box decisions for customer-impacting controls. | NanoJev is constrained strictly to discrete logit classification across 7 predefined scam typologies. Free-form text generation is disabled. Stage A tabular decisions include top SHAP feature importances for compliance review. | No hallucinations; outputs map deterministically to pre-approved warning templates vetted across English, Tagalog, and Taglish. |
| Accountability | Maintain comprehensive audit trails and human oversight for automated risk interventions. | The orchestrator dispatches fire-and-forget event payloads to `/risk/events`. Decisions are stored in append-only JSONL files. High-risk transactions are routed to an analyst review queue. | Complete traceability from raw input features to Stage A score, Stage B typology, and customer acknowledgment state. |
| Responsibility | Ensure automated systems protect consumer welfare without introducing arbitrary denials or warning fatigue. | The escalate-only safety invariant prevents models from weakening security controls. Warnings are tiered (NONE, MEDIUM, HIGH) to avoid over-prompting routine transfers. | Warning fatigue is mitigated by suppressing modals when scam probability is below 0.35, keeping false warning rates on benign memos at 0.0%. |
| Security | Protect models and decision pipelines against adversarial tampering, prompt injection, and data leakage. | Gate 0 executes deterministic hard rules before neural evaluation. Stage B applies input sanitization, strips ChatML delimiters, and enforces strict boundary isolation on memo text. | Tested against 60 prompt injection vectors across 10 attack classes with 0 invariant downgrades and 100% security preservation. |
