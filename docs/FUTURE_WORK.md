# Future work and research directions

This document outlines key technical limitations of the current proof of concept and specifies prioritized engineering and research directions for subsequent iterations.

## 1. Counterparty and money mule graph features

The current risk engine evaluates outgoing transactions primarily using sender-side behavioral telemetry and device context (such as velocity, balance drain ratio, and historical amount spikes). While sender features detect account takeover effectively, authorized scam detection requires counterparty visibility.

Future development should incorporate destination account signals:
- Inward velocity: The count and frequency of incoming transfers to the destination account within rolling 1-hour and 24-hour windows.
- Account age and KYC tier: Identifying recipient accounts registered within the past 14 days or operating at basic unverified wallet tiers.
- Rapid fund dispersion: Monitoring destination accounts that immediately withdraw or transfer incoming funds within minutes of receipt, a hallmark of money mule networks.
- Graph community detection: Integrating graph embeddings or PageRank algorithms to identify connected clusters of mule accounts across interbank rails.

## 2. Real customer behavioral validation and warning fatigue

A foundational assumption of this architecture is that specific, actionable warnings (with Cancel and Pause options) alter customer behavior more effectively than passive warning text. However, customer behavioral responses in this project are simulated.

Recommended next steps include:
- A/B testing in a controlled regulatory sandbox: Measuring actual customer click-through and cancellation rates when presented with targeted typology warnings versus generic security disclaimers.
- Longitudinal warning fatigue studies: Tracking whether repeated presentations of MEDIUM-tier warnings reduce customer compliance over 30-day and 90-day intervals.
- Optimal cool-off duration research: Determining whether a 10-minute pause provides sufficient cognitive decompression for scam victims without generating excessive customer dissatisfaction.

## 3. Supervised fine-tuning and domain adaptation for NanoJev

Multi-split benchmark evaluation demonstrated that the zero-shot Qwen2.5-0.5B model exhibits pronounced token frequency bias toward common words (such as "prize"), yielding low standalone macro-F1 scores (0.0159 to 0.0999) compared to the in-distribution TF-IDF baseline (0.9151).

To address this limitation without expanding model parameter size:
- Supervised fine-tuning (SFT): Fine-tuning Qwen2.5-0.5B on domain-specific Philippine banking memos using Low-Rank Adaptation (LoRA) or QLoRA, training the model directly on classification tokens.
- Analyst feedback distillation: Re-training the model periodically on verified case labels recorded in the analyst decision store (`data/analyst_decisions.jsonl`).
- Calibrated linear classification heads: Training a lightweight linear probe on top of frozen Qwen hidden layer representations, combining transformer semantic comprehension with calibrated class weights.

## 4. Native speaker linguistic review and dialect expansion

The current warning templates and synthetic memos were generated using representative Philippine English, Tagalog, and Taglish phrases common in online scams. However:
- Native speaker review: Warning copy should undergo formal review by native Filipino linguists, compliance officers, and consumer protection advocates to maximize clarity and urgent comprehension.
- Regional dialect coverage: Expanding warning templates and typology definitions to cover major Philippine regional languages, including Cebuano, Ilocano, and Hiligaynon, which are widely spoken across retail banking customer bases outside Metro Manila.
