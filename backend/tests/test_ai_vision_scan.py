"""Test Suite 3: AI Vector Scan & GEE Climate Fusion integration tests.

Covers:
- Test Case 3.1: POST /api/v1/scan-breeding-site with test image byte stream, lat 30.7333, lng 76.7794.
- Test Case 3.2: Verify PII scrubbing, live GEE micro-climate (MODIS LST, Sentinel-2 NDWI),
  PaliGemma bounding boxes, dynamic composite risk score, and auto-dispatch logic.
"""

from __future__ import annotations

from fastapi.testclient import TestClient
from google.cloud import firestore


def test_ai_vector_scan_and_gee_fusion(
    client: TestClient,
    firestore_db: firestore.Client,
    test_breeding_image_bytes: bytes,
) -> None:
    """
    Test Cases 3.1 & 3.2:
    Execute POST /api/v1/scan-breeding-site with synthetic image.
    Assert GEE satellite bands, PaliGemma vision detections, and composite risk fusion.
    """
    files = {
        "image": ("test_drum.jpg", test_breeding_image_bytes, "image/jpeg"),
    }
    data = {
        "lat": "30.7333",
        "lng": "76.7794",
        "ward_id": "0404400017",
        "ward_lgd": "0404400017",
        "officer_uid": "officer_9915549458",
    }

    resp = client.post("/api/v1/scan-breeding-site", files=files, data=data)
    assert resp.status_code == 200, f"Expected 200 OK, got {resp.status_code}: {resp.text}"

    result = resp.json()
    assert "scan_id" in result
    scan_id = result["scan_id"]

    # 1. Bounding Boxes / Container Detection
    detections = result.get("detections") or result.get("bounding_boxes") or []
    assert isinstance(detections, list) and len(detections) > 0, "Expected at least 1 detected container/water body"
    first_det = detections[0]
    assert "label" in first_det or "container_type" in first_det
    assert "box_2d" in first_det or "bounding_box" in first_det

    # 2. DPDP Act & SafeSearch Sanitization Audit
    assert "dpdp_audit" in result
    audit = result["dpdp_audit"]
    assert audit.get("safesearch_passed") is True
    assert audit.get("sanitized_before_gcs_upload") is True

    # 2. Live GEE Micro-Climate Bands
    assert "gee_telemetry" in result
    gee = result["gee_telemetry"]
    assert "lst_celsius" in gee
    assert "ndwi" in gee
    assert gee["lst_celsius"] is not None
    assert gee["ndwi"] is not None
    assert 10.0 <= float(gee["lst_celsius"]) <= 45.0, "MODIS LST out of physical range"
    assert -1.0 <= float(gee["ndwi"]) <= 1.0, "Sentinel-2 NDWI out of physical range"

    # 3. Dynamic Composite Risk Score
    assert "composite_risk_score" in result
    comp_score = float(result["composite_risk_score"])
    assert 0.0 <= comp_score <= 1.0, f"Expected normalized composite score in [0, 1], got {comp_score}"
    assert result["risk_tier"] in ("CRITICAL", "HIGH", "MODERATE", "LOW")

    # 4. Check if auto-dispatch was activated for high/critical risk
    if comp_score >= 0.70:
        assert "auto_dispatch" in result or "assigned_van" in result
        auto_disp = result.get("auto_dispatch")
        if auto_disp:
            assert auto_disp.get("status") in ("DISPATCHED", "PENDING", "ASSIGNED")

    # 5. Verify Firestore ai_scans record
    scan_doc = firestore_db.collection("ai_scans").document(scan_id).get()
    assert scan_doc.exists, f"ai_scans/{scan_id} document not found in Firestore"
    scan_data = scan_doc.to_dict() or {}
    assert scan_data.get("ward_lgd") == "0404400017"

    # Clean up test scan from Firestore
    firestore_db.collection("ai_scans").document(scan_id).delete()
