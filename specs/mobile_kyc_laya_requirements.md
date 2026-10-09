# Requirements: Mobile e-KYC Verification with Laya Vision Engine & Azurite Storage

## 1. Domain Glossary

- **PhilID / ePhilID**: Philippine Identification System card or paper QR document issued by the Philippine Statistics Authority (PSA).
- **CR80 Standard**: The international standard dimensions (85.60 mm x 53.98 mm) for financial cards and government identity cards.
- **Laya KYC Engine**: The automated document classification, OCR parsing, and biometric verification module within the risk intelligence subsystem.
- **Presentation Attack Detection (PAD)**: Automated anti-spoofing mechanism detecting paper printouts, screen replays, or physical masks during selfie capture.
- **ArcFace 1:1 Biometric Verification**: Deep metric learning model producing 512-dimensional facial embedding vectors compared via cosine similarity.
- **Shared Access Signature (SAS)**: Time-bounded, cryptographically signed URI granting scoped upload permissions to Azurite (local) or Azure Blob Storage (cloud) without leaking master access keys.
- **Sensitive Personal Information (SPI)**: Government ID images and biometric vectors governed by the Philippine Data Privacy Act of 2012 (Republic Act No. 10173).
- **Maker-Checker Compliance Queue**: The compliance fallback workflow mandated by Bangko Sentral ng Pilipinas (BSP) Circulars 958 and 1022 where borderline submissions are queued for administrative review.
- **KYC Tiers**:
  - `TIER_0_UNVERIFIED`: Limited trial access; outbound fund transfers disabled.
  - `TIER_1_PENDING`: KYC submitted, undergoing automated verification or maker-checker review.
  - `TIER_2_VERIFIED`: Full retail banking capabilities unlocked (daily transfer limit up to PHP 50,000.00).
  - `TIER_REJECTED`: Submission rejected due to fraud signals or document illegibility.

---

## 2. Scope Boundaries

- **In-Scope**:
  - Mobile UI capture flow in Flutter (`aurabank_app`): ID type picker, ID viewfinder with card aspect ratio guides, and selfie capture with oval alignment frame.
  - Local Azurite storage service added to `infrastructure/docker-compose.yml` for emulating Azure Blob Storage.
  - Ephemeral pre-signed upload intent endpoint in `backend/account-service` generating 300-second SAS tokens.
  - Automated KYC extraction and biometric decision endpoint in `backend/risk-service` (`POST /api/v1/kyc/evaluate`).
  - Document OCR extraction (Full Name, Date of Birth, ID Number, Expiry).
  - 1:1 facial biometric matching between the ID portrait crop and the live selfie.
  - Three-tier automated decision logic: Auto-Approve (score >= 90%), Manual Review (70% <= score < 90%), Auto-Reject (score < 70%).
  - Integration with the existing `account-service` Maker-Checker endpoints (`/api/v1/kyc/pending`, `/api/v1/kyc/{userId}/approve`, `/api/v1/kyc/{userId}/reject`).
- **Deferred / Future Sprints**:
  - Cryptographic RSA signature verification of the PhilID QR code payload against the PSA public key registry.
  - Near Field Communication (NFC) chip reading for biometric Philippine passports.
- **Out-of-Scope**:
  - Replacing existing core banking ledger mutations or payment clearing.
  - Physical hardware biometric fingerprint readers.

---

## 3. Structured Requirements & EARS Acceptance Criteria

### Requirement 1: Mobile Identity Document & Selfie Capture
**User Story**: As a prospective Aura Bank retail customer, I want to capture my Philippine government ID and a live selfie through my mobile camera, so that I can upgrade my account to full transfer capability without visiting a physical branch.

- **Ubiquitous Criteria**:
  - `REQ-1.1`: THE mobile application SHALL support selection of at least five Philippine government ID types: `PHILID`, `DRIVERS_LICENSE`, `PASSPORT`, `UMID`, and `POSTAL_ID`.
  - `REQ-1.2`: THE mobile ID capture screen SHALL display a rectangular viewfinder overlay adhering to the CR80 card aspect ratio (1.586:1).
  - `REQ-1.3`: THE mobile selfie capture screen SHALL render an oval facial alignment mask with clear positioning instructions.
- **Event-Driven Criteria**:
  - `REQ-1.4`: WHEN the customer selects `PASSPORT`, THE mobile application SHALL request only front identity page capture.
  - `REQ-1.5`: WHEN the customer selects `PHILID` or `DRIVERS_LICENSE`, THE mobile application SHALL require both front and back captures before proceeding to selfie verification.
- **Unwanted Behavior Criteria**:
  - `REQ-1.6`: IF the captured image has a resolution below 720p or fails on-device blur thresholds, THEN THE mobile application SHALL prompt the customer to retake the photo with improved lighting before proceeding.

---

### Requirement 2: Ephemeral Pre-Signed Storage Upload
**User Story**: As a bank security architect, I want mobile clients to upload KYC images directly to isolated blob storage using short-lived SAS tokens, so that customer identity files are stored securely without exposing long-lived cloud credentials to client devices.

- **Ubiquitous Criteria**:
  - `REQ-2.1`: THE `account-service` SHALL expose `POST /api/v1/kyc/upload-intent` requiring a valid customer JWT.
  - `REQ-2.2`: THE upload intent response SHALL provide pre-signed SAS upload URLs for `id_front`, `id_back` (optional), and `selfie` with an expiry window of exactly 300 seconds.
  - `REQ-2.3`: THE storage engine SHALL isolate blobs inside a private container named `kyc-vault` using path format `users/{userId}/{submissionId}/{documentType}.jpg`.
- **State-Driven Criteria**:
  - `REQ-2.4`: WHILE running in the local Docker environment, THE system SHALL direct uploads to the local Azurite emulator on port 10000.
  - `REQ-2.5`: WHILE running in the production cloud environment, THE system SHALL direct uploads to Azure Blob Storage encrypted with AES-256 server-side encryption.
- **Unwanted Behavior Criteria**:
  - `REQ-2.6`: IF an upload attempt occurs after the 300-second SAS token expiration, THEN THE storage service SHALL reject the request with HTTP 403 Forbidden.

---

### Requirement 3: Automated Document Inspection & OCR Extraction
**User Story**: As an automated onboarding pipeline, I want Laya KYC to classify the ID card and extract typed identity attributes via OCR, so that account verification can occur in real time without manual data entry.

- **Ubiquitous Criteria**:
  - `REQ-3.1`: THE Laya KYC engine SHALL extract Full Name, Date of Birth, ID Number, and Expiry Date from supported Philippine ID documents.
  - `REQ-3.2`: THE Laya KYC engine SHALL validate document ID number formats against published Philippine issuing authority patterns (e.g., Driver's License format `[A-Z][0-9]{2}-[0-9]{2}-[0-9]{6}`).
- **Event-Driven Criteria**:
  - `REQ-3.3`: WHEN processing a Philippine Passport, THE engine SHALL parse the two-line Machine Readable Zone (MRZ) and verify checksum digits for document number, birthdate, and expiration date.
- **Unwanted Behavior Criteria**:
  - `REQ-3.4`: IF the document cannot be classified as a supported ID type or OCR confidence is below 60%, THEN THE engine SHALL mark the document verification status as `DOC_UNRECOGNIZED` and assign an OCR confidence score of 0.

---

### Requirement 4: 1:1 Facial Biometric Verification & Liveness
**User Story**: As a fraud prevention officer, I want the system to mathematically match the live selfie against the ID portrait photo, so that fraudsters cannot register accounts using stolen identity cards.

- **Ubiquitous Criteria**:
  - `REQ-4.1`: THE Laya KYC engine SHALL crop the portrait photograph from the verified ID document image.
  - `REQ-4.2`: THE engine SHALL generate 512-dimensional biometric feature embeddings for both the cropped ID photo and the live selfie.
  - `REQ-4.3`: THE engine SHALL compute the cosine similarity score ($S_{\text{face}} \in [0.0, 1.0]$) between the ID face embedding and the selfie face embedding.
- **State-Driven Criteria**:
  - `REQ-4.4`: WHILE evaluating the live selfie, THE engine SHALL compute a Presentation Attack Detection score ($S_{\text{live}} \in [0.0, 1.0]$) to reject printed photos and digital screen replays.
- **Unwanted Behavior Criteria**:
  - `REQ-4.5`: IF no face is detected in either the ID crop or the selfie, THEN THE engine SHALL immediately set $S_{\text{face}} = 0.0$ and return reason `FACE_NOT_DETECTED`.

---

### Requirement 5: Three-Tier Decision Engine & Maker-Checker Routing
**User Story**: As a compliance manager, I want automated decisions to route high-confidence submissions immediately while queuing borderline cases for human review, so that our bank complies with BSP e-KYC regulations while delivering an instant onboarding experience.

- **Ubiquitous Criteria**:
  - `REQ-5.1`: THE Laya KYC engine SHALL calculate a composite KYC Confidence Score ($C_{\text{kyc}} \in [0, 100]$):
    $$C_{\text{kyc}} = 0.40 \cdot (S_{\text{face}} \cdot 100) + 0.30 \cdot (S_{\text{live}} \cdot 100) + 0.20 \cdot (\text{Conf}_{\text{ocr}} \cdot 100) + 0.10 \cdot (\text{Match}_{\text{name}} \cdot 100)$$
  - `REQ-5.2`: THE system SHALL enforce the three-tier decision boundaries:
    - **Tier A (Auto-Approve)**: $C_{\text{kyc}} \ge 90$ AND $S_{\text{face}} \ge 0.85$ AND $S_{\text{live}} \ge 0.90$.
    - **Tier B (Manual Review)**: $70 \le C_{\text{kyc}} < 90$ OR $0.70 \le S_{\text{face}} < 0.85$.
    - **Tier C (Auto-Reject)**: $C_{\text{kyc}} < 70$ OR hard fraud signal detected.
- **Event-Driven Criteria**:
  - `REQ-5.3`: WHEN Tier A is satisfied, THE system SHALL update the customer status to `ACTIVE`, promote KYC status to `VERIFIED`, and notify the mobile application within 5 seconds.
  - `REQ-5.4`: WHEN Tier B is triggered, THE system SHALL set KYC status to `PENDING_REVIEW` and insert the submission into the compliance maker-checker queue accessible via `GET /api/v1/kyc/pending`.
- **Unwanted Behavior Criteria**:
  - `REQ-5.5`: IF the applicant name extracted by OCR conflicts with the account registration name (Levenshtein distance similarity < 0.60), THEN THE system SHALL prevent auto-approval and force either Tier B manual review or Tier C rejection.
