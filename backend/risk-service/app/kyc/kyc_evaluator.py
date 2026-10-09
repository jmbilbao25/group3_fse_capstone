"""
Laya e-KYC Decision Evaluator & Orchestration Pipeline.
Computes composite KYC risk confidence and classifies into:
  - Tier A: APPROVED (Auto-Approve, Confidence >= 90%, Face >= 0.85, Liveness >= 0.80)
  - Tier B: PENDING_REVIEW (Manual Maker-Checker Review, 70% <= Confidence < 90%)
  - Tier C: REJECTED (Outright Rejection, Confidence < 70% or Fraud Flags)
"""

import logging
from typing import Dict, List, Optional
from pydantic import BaseModel, Field

from app.kyc.document_ocr import DocumentOcrEngine, OcrResult
from app.kyc.face_matcher import FaceMatcher, FaceMatchResult
from app.kyc.liveness_detector import LivenessDetector, LivenessResult
from app.kyc.storage_adapter import BlobStorageAdapter, AzuriteBlobStorageAdapter

logger = logging.getLogger(__name__)


class KycEvaluationRequest(BaseModel):
    user_id: str
    submission_id: str
    id_type: str
    front_blob_path: str
    back_blob_path: Optional[str] = None
    selfie_blob_path: str
    declared_first_name: str
    declared_last_name: str
    declared_dob: Optional[str] = None
    ocr_override_text: Optional[str] = None


class KycEvaluationResponse(BaseModel):
    user_id: str
    submission_id: str
    decision: str  # "APPROVED" | "PENDING_REVIEW" | "REJECTED"
    confidence_score: float = Field(ge=0.0, le=100.0)
    face_similarity: float = Field(ge=0.0, le=1.0)
    liveness_score: float = Field(ge=0.0, le=1.0)
    ocr_data: Dict
    checks: Dict
    flags: List[str]
    reasons: List[str]


class KycEvaluator:
    """Composite Multi-Modal e-KYC Evaluation Engine."""

    def __init__(
        self,
        storage_adapter: Optional[BlobStorageAdapter] = None,
        ocr_engine: Optional[DocumentOcrEngine] = None,
        face_matcher: Optional[FaceMatcher] = None,
        liveness_detector: Optional[LivenessDetector] = None,
    ):
        self.storage_adapter = storage_adapter or AzuriteBlobStorageAdapter()
        self.ocr_engine = ocr_engine or DocumentOcrEngine()
        self.face_matcher = face_matcher or FaceMatcher()
        self.liveness_detector = liveness_detector or LivenessDetector()

    def evaluate(self, request: KycEvaluationRequest) -> KycEvaluationResponse:
        """Executes end-to-end e-KYC evaluation across OCR, facial match, and liveness."""
        logger.info(f"Initiating Laya KYC evaluation for user {request.user_id}, submission {request.submission_id}")

        all_flags: List[str] = []
        reasons: List[str] = []

        # 1. Fetch document and selfie image blobs
        try:
            front_bytes = self.storage_adapter.fetch_image_bytes(request.front_blob_path)
            selfie_bytes = self.storage_adapter.fetch_image_bytes(request.selfie_blob_path)
        except Exception as e:
            logger.error(f"Error fetching blobs: {e}")
            return KycEvaluationResponse(
                user_id=request.user_id,
                submission_id=request.submission_id,
                decision="REJECTED",
                confidence_score=0.0,
                face_similarity=0.0,
                liveness_score=0.0,
                ocr_data={},
                checks={"storage_accessible": False},
                flags=["STORAGE_FETCH_ERROR"],
                reasons=[f"Unable to read identity documents from secure vault: {str(e)}"],
            )

        # 2. Document Layout & OCR Analysis
        ocr_result: OcrResult = self.ocr_engine.evaluate_document(
            image_bytes=front_bytes,
            id_type=request.id_type,
            declared_first_name=request.declared_first_name,
            declared_last_name=request.declared_last_name,
            declared_dob=request.declared_dob,
            ocr_override_text=request.ocr_override_text,
        )
        all_flags.extend(ocr_result.flags)

        # 3. Biometric Facial Verification (ID Crop vs Live Selfie)
        face_result: FaceMatchResult = self.face_matcher.compare_faces(
            id_photo_bytes=front_bytes,
            selfie_photo_bytes=selfie_bytes,
        )
        all_flags.extend(face_result.flags)

        # 4. Passive Presentation Attack Detection (Liveness)
        liveness_result: LivenessResult = self.liveness_detector.evaluate_liveness(
            selfie_bytes=selfie_bytes
        )
        all_flags.extend(liveness_result.flags)

        # 5. Composite Score Calculation (Property 3 in Design Spec)
        # C_kyc = (0.40 * S_face + 0.35 * S_ocr + 0.25 * S_live) * 100
        composite_score = (
            0.40 * face_result.similarity_score
            + 0.35 * ocr_result.ocr_confidence
            + 0.25 * liveness_result.liveness_score
        ) * 100.0
        composite_score = max(0.0, min(100.0, round(composite_score, 2)))

        # 6. Structured Checks
        checks = {
            "id_template_valid": ocr_result.id_template_valid,
            "name_match": ocr_result.name_match,
            "dob_match": ocr_result.dob_match,
            "liveness_passed": liveness_result.liveness_passed,
            "face_matched": face_result.similarity_score >= 0.85,
        }

        # 7. Three-Tier Decisioning (Tier A, Tier B, Tier C)
        decision: str

        # Tier C: Hard Auto-Reject Triggers (Collect all relevant reasons)
        if not liveness_result.liveness_passed:
            reasons.append("Liveness verification failed: Potential presentation attack detected.")
        if face_result.similarity_score < 0.60:
            reasons.append("Biometric verification failed: Selfie does not match the photo on the government ID.")
        if "DOCUMENT_EXPIRED" in all_flags:
            reasons.append("Submitted government ID has expired.")
        if "NAME_MISMATCH" in all_flags:
            reasons.append("Name on identity document does not match account registration details.")
        if composite_score < 70.0 and not reasons:
            reasons.append(f"Composite confidence score ({composite_score}%) is below minimum acceptance threshold.")

        if reasons:
            decision = "REJECTED"

        # Tier A: Auto-Approve Requirements
        elif (
            composite_score >= 90.0
            and face_result.similarity_score >= 0.85
            and liveness_result.liveness_passed
            and ocr_result.id_template_valid
            and ocr_result.name_match
            and ocr_result.dob_match
        ):
            decision = "APPROVED"
            reasons.append("Automated verification successfully completed with high confidence.")

        # Tier B: Manual Compliance Review (Maker-Checker Queue)
        else:
            decision = "PENDING_REVIEW"
            if "SLIGHT_NAME_DISCREPANCY" in all_flags:
                reasons.append("Minor discrepancy detected between declared name and document name.")
            if face_result.similarity_score < 0.85:
                reasons.append(f"Borderline facial similarity score ({round(face_result.similarity_score, 2)}).")
            if not ocr_result.dob_match:
                reasons.append("Date of birth could not be conclusively validated from document layout.")
            if not reasons:
                reasons.append(f"Application confidence ({composite_score}%) requires standard compliance officer sign-off.")

        logger.info(f"KYC Evaluation decision for {request.user_id}: {decision} (Score: {composite_score}%)")

        return KycEvaluationResponse(
            user_id=request.user_id,
            submission_id=request.submission_id,
            decision=decision,
            confidence_score=composite_score,
            face_similarity=face_result.similarity_score,
            liveness_score=liveness_result.liveness_score,
            ocr_data={
                "full_name": ocr_result.full_name,
                "dob": ocr_result.dob,
                "id_number": ocr_result.id_number,
                "expiry_date": ocr_result.expiry_date,
                "ocr_confidence": ocr_result.ocr_confidence,
                "name_match_score": ocr_result.name_match_score,
            },
            checks=checks,
            flags=all_flags,
            reasons=reasons,
        )
