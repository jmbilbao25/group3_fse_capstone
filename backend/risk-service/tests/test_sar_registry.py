import os, importlib
from fastapi.testclient import TestClient


def test_sar_drafts_list_and_detail(tmp_path, monkeypatch):
    from hybrid_bench import sar_generator
    from app import sar_registry
    monkeypatch.setattr(sar_registry, "SAR_DRAFTS_DIR", str(tmp_path))
    tx = {"transaction_id": "TX-GEO-1", "user_id": "usr-1001-cst-001", "amount_php": 5000.0,
          "velocity_kmh": 128000.0, "distance_from_last_km": 10742.0, "elapsed_minutes": 5.0}
    verdict = {"action": "BLOCK", "primary_reason": "IMPOSSIBLE_TRAVEL_VELOCITY", "fraud_score": 97.0}
    sar_generator.generate_sar_sync(tx, verdict, output_dir=str(tmp_path))

    rows = sar_registry.list_reports()
    assert len(rows) == 1 and rows[0]["transaction_id"] == "TX-GEO-1"
    assert rows[0]["reason_code"] == "IMPOSSIBLE_TRAVEL_VELOCITY"
    detail = sar_registry.get_report("TX-GEO-1")
    assert "SUSPICIOUS TRANSACTION REPORT" in detail["document"]
    assert sar_registry.get_report("TX-NOPE") is None
    try:
        sar_registry.get_report("../etc/passwd")
        assert False, "path traversal must be rejected"
    except ValueError:
        pass


def test_sar_four_eyes(tmp_path, monkeypatch):
    from hybrid_bench import sar_generator
    from app import sar_registry
    import pytest
    monkeypatch.setattr(sar_registry, "SAR_DRAFTS_DIR", str(tmp_path))
    sar_generator.generate_sar_sync({"transaction_id": "TX-4E"}, {"action": "BLOCK"}, output_dir=str(tmp_path))
    sar_registry.review_report("TX-4E", "maker", "RECOMMEND_FILE", "geo hop")
    with pytest.raises(sar_registry.SarReviewError, match="Four-eyes"):
        sar_registry.review_report("TX-4E", "maker", "CONFIRM")
    done = sar_registry.review_report("TX-4E", "checker", "CONFIRM")
    assert done["review"]["status"] == "FILED"
    assert [h["by"] for h in done["review"]["history"]] == ["maker", "checker"]
