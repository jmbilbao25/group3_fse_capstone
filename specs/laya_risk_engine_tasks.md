# Implementation Tasks: Laya Decision Engine Integration

## Phase 1: Environment & Dependency Setup
- [x] **Task 1.1**: Install `laya` package in the Python virtual environment using `uv`.
  _Requirements: REQ-1.1, Design: Section 2_
  - Run `uv pip install laya --python .venv\Scripts\python.exe`.
  - Verify that `import laya` and `from laya import Router, Agent` execute cleanly.

---

## Phase 2: Engine Implementation & Adapter Seam
- [ ] **Task 2.1**: Implement `backend/risk-service/app/laya_engine.py`.
  _Requirements: REQ-1.1, REQ-1.2, REQ-1.3, Design: Section 3_
  - Implement `LayaEngine` class with `evaluate()` method matching `NanoJevEngine` parameter signature.
  - Formulate structured Laya question schemas:
    - `verdict` (`choice` over `ALLOW`, `REQUIRE_2FA`, `BLOCK`).
    - `typology` (`choice` over the 7 Philippine banking typologies).
    - `anomaly` (`noul` boolean probability).
    - `fraud_score` (`score` between 0 and 100).
  - Implement deterministic Gate 0 fast-path bypass (< 0.1 ms).
  - Implement robust offline fallback when Laya checkpoint is not locally cached, ensuring instant testability.

- [ ] **Task 2.2**: Update `backend/risk-service/app/nanojev_engine.py` as a backward-compatible facade.
  _Requirements: REQ-1.1, Design: Section 3_
  - Forward calls from `NanoJevEngine` to `LayaEngine` (or wrap seamlessly).
  - Ensure zero regressions for any legacy imports.

---

## Phase 3: Integration into Server and Async Reviewer
- [ ] **Task 3.1**: Integrate `LayaEngine` into `backend/risk-service/app/server.py` and `app/main.py`.
  _Requirements: REQ-1.1, REQ-1.2, Design: Section 1_
  - Update service startup to initialize `LayaEngine` alongside or as the primary neural engine.
  - Update `/health` endpoint to reflect Laya engine status.

- [ ] **Task 3.2**: Implement `LayaSecondLookEngine` in `backend/risk-service/app/reviewer.py`.
  _Requirements: REQ-2.1, REQ-2.4, REQ-3.1, Design: Section 3_
  - Provide asynchronous second-look review functionality using Laya's structured predictions.
  - Enforce `enforce_escalate_only()` to mathematically guarantee invariant $\text{RiskTier}(a_{\text{final}}) \ge \text{RiskTier}(a_0)$.

---

## Phase 4: Automated Testing & Verification
- [ ] **Task 4.1**: Run full existing test suite in `backend/risk-service/tests/`.
  _Requirements: REQ-1.1, REQ-2.1, REQ-3.1, Design: Section 5_
  - Execute `pytest tests/test_two_stage.py -v`.
  - Execute `pytest tests/test_device_binding_advisory.py -v`.
  - Execute `pytest tests/test_async_reviewer.py -v`.
  - Execute `pytest tests/test_api_integration.py -v`.
  - Confirm all 36 tests pass cleanly with 0 failures.

- [ ] **Task 4.2**: Verify benchmark latency and generate comparative evidence.
  _Requirements: REQ-1.2, Design: Section 2_
  - Benchmark Laya forward pass latency vs Qwen ONNX baseline.
  - Confirm execution time meets the synchronous budget.
