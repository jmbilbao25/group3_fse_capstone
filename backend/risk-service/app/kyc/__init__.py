"""
Laya Vision & e-KYC Decision Engine Module.
Provides document OCR, ArcFace 512-D facial matching, passive liveness detection,
and BSP-compliant three-tier automated KYC evaluation.
"""

from app.kyc.storage_adapter import BlobStorageAdapter, AzuriteBlobStorageAdapter, MockBlobStorageAdapter
from app.kyc.document_ocr import DocumentOcrEngine, OcrResult
from app.kyc.face_matcher import FaceMatcher, FaceMatchResult
from app.kyc.liveness_detector import LivenessDetector, LivenessResult
from app.kyc.kyc_evaluator import KycEvaluator, KycEvaluationRequest, KycEvaluationResponse

__all__ = [
    "BlobStorageAdapter",
    "AzuriteBlobStorageAdapter",
    "MockBlobStorageAdapter",
    "DocumentOcrEngine",
    "OcrResult",
    "FaceMatcher",
    "FaceMatchResult",
    "LivenessDetector",
    "LivenessResult",
    "KycEvaluator",
    "KycEvaluationRequest",
    "KycEvaluationResponse",
]
