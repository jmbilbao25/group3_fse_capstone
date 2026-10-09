"""
Unit and Integration Tests for Laya e-KYC Vision & Decision Pipeline (Task 3).
Verifies:
1. Tier A Auto-Approve (Confidence >= 90%, Face >= 0.85, Liveness >= 0.80)
2. Tier B Manual Maker-Checker Review (Slight name discrepancy or borderline confidence)
3. Tier C Auto-Reject on biometric mismatch, presentation attack, or expired ID
4. Correctness Property 1: Facial cosine similarity boundedness in [0.0, 1.0]
5. End-to-End FastAPI endpoint POST /api/v1/kyc/evaluate
"""

import os
import sys
import pytest
from starlette.testclient import TestClient

# Ensure risk-service root is in sys.path
_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
_SERVICE_ROOT = os.path.join(_REPO_ROOT, "backend", "risk-service")
if _SERVICE_ROOT not in sys.path:
    sys.path.insert(0, _SERVICE_ROOT)
if _REPO_ROOT not in sys.path:
    sys.path.insert(0, _REPO_ROOT)

from app.kyc.storage_adapter import MockBlobStorageAdapter
from app.kyc.document_ocr import DocumentOcrEngine
from app.kyc.face_matcher import FaceMatcher
from app.kyc.liveness_detector import LivenessDetector
from app.kyc.kyc_evaluator import KycEvaluator, KycEvaluationRequest, KycEvaluationResponse
from app.main import app, kyc_evaluator


@pytest.fixture
def mock_storage():
    adapter = MockBlobStorageAdapter()
    # 1. Matching front ID for Juan Dela Cruz (PhilID with valid format)
    adapter.set_blob(
        "users/U101/KYC-001/id_front.jpg",
        b"PHILID REPUBLIKA NG PILIPINAS\nPCN: 1234-5678-9012-3456\nNAME: JUAN DELA CRUZ\nDOB: 1990-05-15\nPERSON_A_FACE_DATA"
    )
    # Matching selfie for Juan Dela Cruz
    adapter.set_blob(
        "users/U101/KYC-001/selfie.jpg",
        b"LIVE_SELFIE_PERSON_A_FACE_DATA_TEXTURE_HIGH_VARIANCE"
    )

    # 2. Slight name discrepancy (Maria Clara Santos vs Maria Santos)
    adapter.set_blob(
        "users/U102/KYC-002/id_front.jpg",
        b"DRIVERS_LICENSE REPUBLIKA NG PILIPINAS\nNO: N02-18-091234\nNAME: MARIA CLARA SANTOS\nDOB: 1995-10-20\nEXP: 2029-10-20\nPERSON_B_FACE_DATA"
    )
    adapter.set_blob(
        "users/U102/KYC-002/selfie.jpg",
        b"LIVE_SELFIE_PERSON_B_FACE_DATA"
    )

    # 3. Biometric Mismatch (ID has Person C, selfie has Person D)
    adapter.set_blob(
        "users/U103/KYC-003/id_front.jpg",
        b"PASSPORT REPUBLIKA NG PILIPINAS\nDOC: P1234567A\nNAME: PEDRO PENDUKO\nDOB: 1988-03-12\nEXP: 2030-03-12\nPERSON_C_FACE_DATA"
    )
    adapter.set_blob(
        "users/U103/KYC-003/selfie.jpg",
        b"LIVE_SELFIE_PERSON_D_FACE_DATA"
    )

    # 4. Presentation Attack / Screen Replay Spoof
    adapter.set_blob(
        "users/U104/KYC-004/id_front.jpg",
        b"UMID REPUBLIKA NG PILIPINAS\nCRN: 1234-5678901-2\nNAME: ANA REYES\nDOB: 1992-08-08\nPERSON_E_FACE_DATA"
    )
    adapter.set_blob(
        "users/U104/KYC-004/selfie.jpg",
        b"SPOOF_SCREEN_REPLAY_ATTACK_MOIRE_GRID_DETECTED_PERSON_E"
    )

    # 5. Expired Driver's License
    adapter.set_blob(
        "users/U105/KYC-005/id_front.jpg",
        b"DRIVERS_LICENSE REPUBLIKA NG PILIPINAS\nNO: A01-15-123456\nNAME: CARLOS YULO\nDOB: 2000-02-16\nEXP: 2021-02-16\nPERSON_F_FACE_DATA"
    )
    adapter.set_blob(
        "users/U105/KYC-005/selfie.jpg",
        b"LIVE_SELFIE_PERSON_F_FACE_DATA"
    )

    return adapter


@pytest.fixture
def evaluator(mock_storage):
    return KycEvaluator(storage_adapter=mock_storage)


class TestKycPipeline:

    def test_tier_a_auto_approve(self, evaluator):
        """Should auto-approve with high confidence when ID, selfie, and metadata match."""
        req = KycEvaluationRequest(
            user_id="U101",
            submission_id="KYC-001",
            id_type="PHILID",
            front_blob_path="users/U101/KYC-001/id_front.jpg",
            selfie_blob_path="users/U101/KYC-001/selfie.jpg",
            declared_first_name="Juan",
            declared_last_name="Dela Cruz",
            declared_dob="1990-05-15",
        )

        res = evaluator.evaluate(req)

        assert res.decision == "APPROVED"
        assert res.confidence_score >= 90.0
        assert res.face_similarity >= 0.85
        assert res.liveness_score >= 0.80
        assert res.checks["id_template_valid"] is True
        assert res.checks["name_match"] is True
        assert res.checks["dob_match"] is True
        assert res.checks["liveness_passed"] is True
        assert res.checks["face_matched"] is True

    def test_tier_b_manual_review_slight_name_discrepancy(self, evaluator):
        """Should route to manual review (Tier B) when there is a slight name discrepancy."""
        req = KycEvaluationRequest(
            user_id="U102",
            submission_id="KYC-002",
            id_type="DRIVERS_LICENSE",
            front_blob_path="users/U102/KYC-002/id_front.jpg",
            selfie_blob_path="users/U102/KYC-002/selfie.jpg",
            declared_first_name="Maria",  # Declared Maria, ID has Maria Clara
            declared_last_name="Santos",
            declared_dob="1995-10-20",
        )

        res = evaluator.evaluate(req)

        assert res.decision == "PENDING_REVIEW"
        assert 70.0 <= res.confidence_score < 90.0
        assert "SLIGHT_NAME_DISCREPANCY" in res.flags
        assert any("discrepancy" in r.lower() for r in res.reasons)

    def test_tier_c_auto_reject_biometric_face_mismatch(self, evaluator):
        """Should outright reject when ID photo does not match selfie face."""
        req = KycEvaluationRequest(
            user_id="U103",
            submission_id="KYC-003",
            id_type="PASSPORT",
            front_blob_path="users/U103/KYC-003/id_front.jpg",
            selfie_blob_path="users/U103/KYC-003/selfie.jpg",
            declared_first_name="Pedro",
            declared_last_name="Penduko",
            declared_dob="1988-03-12",
        )

        res = evaluator.evaluate(req)

        assert res.decision == "REJECTED"
        assert res.face_similarity < 0.60
        assert "FACE_MISMATCH" in res.flags
        assert any("biometric" in r.lower() for r in res.reasons)

    def test_tier_c_auto_reject_presentation_attack(self, evaluator):
        """Should reject when presentation attack / screen replay is detected."""
        req = KycEvaluationRequest(
            user_id="U104",
            submission_id="KYC-004",
            id_type="UMID",
            front_blob_path="users/U104/KYC-004/id_front.jpg",
            selfie_blob_path="users/U104/KYC-004/selfie.jpg",
            declared_first_name="Ana",
            declared_last_name="Reyes",
            declared_dob="1992-08-08",
        )

        res = evaluator.evaluate(req)

        assert res.decision == "REJECTED"
        assert res.checks["liveness_passed"] is False
        assert res.liveness_score < 0.50
        assert "PRESENTATION_ATTACK_DETECTED" in res.flags

    def test_tier_c_auto_reject_expired_document(self, evaluator):
        """Should reject when government ID is expired."""
        req = KycEvaluationRequest(
            user_id="U105",
            submission_id="KYC-005",
            id_type="DRIVERS_LICENSE",
            front_blob_path="users/U105/KYC-005/id_front.jpg",
            selfie_blob_path="users/U105/KYC-005/selfie.jpg",
            declared_first_name="Carlos",
            declared_last_name="Yulo",
            declared_dob="2000-02-16",
        )

        res = evaluator.evaluate(req)

        assert res.decision == "REJECTED"
        assert "DOCUMENT_EXPIRED" in res.flags
        assert any("expired" in r.lower() for r in res.reasons)

    def test_correctness_property_1_cosine_boundedness(self):
        """
        Correctness Property 1 Invariant:
        For any two facial embeddings, cosine similarity is strictly in [0.0, 1.0].
        """
        matcher = FaceMatcher()
        for i in range(50):
            photo_a = f"PERSON_RANDOM_{i}_SALT_{os.urandom(8).hex()}".encode("utf-8")
            photo_b = f"PERSON_RANDOM_{i + 100}_SALT_{os.urandom(8).hex()}".encode("utf-8")
            result = matcher.compare_faces(photo_a, photo_b)
            assert 0.0 <= result.similarity_score <= 1.0, f"Score {result.similarity_score} out of bounds"

    def test_api_endpoint_post_kyc_evaluate(self, mock_storage):
        """Verifies POST /api/v1/kyc/evaluate HTTP endpoint in FastAPI."""
        kyc_evaluator.storage_adapter = mock_storage
        client = TestClient(app)

        payload = {
            "user_id": "U101",
            "submission_id": "KYC-001",
            "id_type": "PHILID",
            "front_blob_path": "users/U101/KYC-001/id_front.jpg",
            "selfie_blob_path": "users/U101/KYC-001/selfie.jpg",
            "declared_first_name": "Juan",
            "declared_last_name": "Dela Cruz",
            "declared_dob": "1990-05-15",
        }

        response = client.post("/api/v1/kyc/evaluate", json=payload)
        assert response.status_code == 200

        data = response.json()
        assert data["user_id"] == "U101"
        assert data["decision"] == "APPROVED"
        assert data["confidence_score"] >= 90.0
        assert "ocr_data" in data
        assert "checks" in data
