# Implementation Tasks: Mobile e-KYC with Laya Vision Engine & Azurite Storage

## Overview

This document defines actionable, sequential engineering tasks for implementing the mobile e-KYC subsystem. Each task cites corresponding requirements and design sections and concludes with a test-driven verification gate.

---

## Tasks

### Task 1: Storage Infrastructure Setup (Azurite in Docker Compose)
- **Goal**: Provision local Azure Blob Storage emulation via Azurite so development and automated tests run without cloud dependencies.
- **Traceability**: _Requirements: REQ-2.4, REQ-2.5; Design: Section 1.1, Section 2_
- **Steps**:
  1. Add the `azurite-storage` service to `infrastructure/docker-compose.yml` using `mcr.microsoft.com/azure-storage/azurite:latest`.
  2. Map port `10000:10000` (Blob service) and mount persistent volume `azurite_data:/data`.
  3. Attach the container to the existing `banking-net` network.
  4. Create an initialization script or container hook to auto-create the `kyc-vault` container on startup.
- **Verification Gate**:
  - Run `docker compose up -d azurite-storage` and verify port 10000 accepts HTTP requests with exit code 0.

---

### Task 2: Account Service Upload Intent & SAS Token Generation
- **Goal**: Enable authenticated mobile clients to request time-bounded, pre-signed upload SAS tokens for identity documents and selfies.
- **Traceability**: _Requirements: REQ-2.1, REQ-2.2, REQ-2.3, REQ-2.6; Design: Section 3.1, Section 4 (Property 2)_
- **Steps**:
  1. Add `azure-storage-blob` dependency to `backend/account-service/pom.xml`.
  2. Implement `BlobStorageAdapter` interface and an `AzuriteBlobStorageService` implementation configured via `application.properties`.
  3. Create DTOs: `KycUploadIntentRequest` and `KycUploadIntentResponse` containing SAS URLs for `id_front`, `id_back`, and `selfie`.
  4. Implement `POST /api/v1/kyc/upload-intent` in `KycController.java` with JWT authentication and strict 300-second expiration.
  5. Add unit and integration tests in `KycControllerTest.java` verifying SAS token generation and expiration bounds.
- **Verification Gate**:
  - Run `mvn test -Dtest=KycControllerTest` in `backend/account-service` and verify all tests pass with exit code 0.

---

### Task 3: Laya KYC Vision & Decision Pipeline in Risk Service
- **Goal**: Implement the Python-based e-KYC evaluation endpoint performing OCR extraction, biometric face embedding comparison, and rule-based tier decisioning.
- **Traceability**: _Requirements: REQ-3.1, REQ-3.2, REQ-3.3, REQ-3.4, REQ-4.1 - REQ-4.5, REQ-5.1, REQ-5.2; Design: Section 1.2, Section 3.2, Section 4 (Properties 1 & 3)_
- **Steps**:
  1. Create module `backend/risk-service/app/kyc/` with:
     - `document_ocr.py`: Document layout classifier and regex/OCR extractor for Philippine IDs (PhilID, Driver's License, Passport MRZ, UMID).
     - `face_matcher.py`: Face detection, crop, and ArcFace 512-D cosine similarity calculator with deterministic offline fallback fixtures.
     - `liveness_detector.py`: Passive Presentation Attack Detection scoring ($S_{\text{live}} \in [0.0, 1.0]$).
     - `kyc_evaluator.py`: Composite score calculator ($C_{\text{kyc}}$) enforcing Tier A, Tier B, and Tier C thresholds.
  2. Implement endpoint `POST /api/v1/kyc/evaluate` in `backend/risk-service/app/main.py`.
  3. Write comprehensive unit and edge-case tests in `backend/risk-service/tests/test_kyc_pipeline.py` asserting:
     - High confidence match auto-approves ($C_{\text{kyc}} \ge 90$).
     - Slight name difference routes to manual review ($70 \le C_{\text{kyc}} < 90$).
     - Face mismatch or spoofing results in outright rejection ($C_{\text{kyc}} < 70$).
- **Verification Gate**:
  - Run `pytest backend/risk-service/tests/test_kyc_pipeline.py` and verify 100% pass rate.

---

### Task 4: Account Service Orchestration & Maker-Checker Integration
- **Goal**: Connect `account-service` to the Laya KYC evaluation endpoint, mutate user statuses accordingly, and populate the compliance Maker-Checker queue.
- **Traceability**: _Requirements: REQ-5.3, REQ-5.4, REQ-5.5; Design: Section 1.2, Section 5_
- **Steps**:
  1. Create a `KycClient` in `backend/account-service` to call `POST /api/v1/kyc/evaluate` on `risk-service:8084`.
  2. Implement `POST /api/v1/kyc/verify` in `KycController.java` accepting the `submissionId`.
  3. When `APPROVED`: atomically transition `UserEntity.status` to `ACTIVE` and `kyc_status` to `VERIFIED`.
  4. When `PENDING_REVIEW`: transition `kyc_status` to `PENDING_REVIEW` with review reason, making it available on `GET /api/v1/kyc/pending`.
  5. When `REJECTED`: transition `kyc_status` to `REJECTED` and record rejection reason.
  6. Write integration tests in `KycServiceTest.java` verifying state machine transitions.
- **Verification Gate**:
  - Run `mvn test -Dtest=KycServiceTest` in `backend/account-service` with exit code 0.

---

### Task 5: Flutter Mobile e-KYC Capture Flow & Storage Streaming
- **Goal**: Implement the customer-facing mobile verification flow in `aurabank_app` adhering to Aura Bank design tokens.
- **Traceability**: _Requirements: REQ-1.1 - REQ-1.6; Design: Section 1.1, Section 5_
- **Steps**:
  1. Create `aurabank_app/lib/screens/kyc_wizard_screen.dart`:
     - Step 1: ID Type Selector bottom sheet (PhilID, Driver's License, Passport, UMID, Postal ID).
     - Step 2: Camera Viewfinder with CR80 card aspect ratio guidance overlay (Front and Back).
     - Step 3: Selfie Oval Frame with liveness instructions ("Position face in oval").
  2. Implement `KycService.dart` in Flutter:
     - Calls `POST /api/v1/kyc/upload-intent` to retrieve pre-signed SAS URLs.
     - Uploads binary image buffers directly to Azurite/Azure Blob Storage via HTTP PUT.
     - Calls `POST /api/v1/kyc/verify` and displays instant verdict or pending notice.
  3. Add navigation entry point to KYC from `profile_screen.dart` or `settings_screen.dart`.
  4. Validate compliance with Aura Bank design tokens (pure white surfaces, royal violet buttons, zero technical jargon).
- **Verification Gate**:
  - Run `flutter analyze` inside `aurabank_app` and verify zero errors and zero warnings.
