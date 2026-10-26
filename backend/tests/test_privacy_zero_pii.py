"""Tests for Nepal Individual Privacy Act 2075: EXIF GPS Stripping, Portrait/ID Rejection, Citizen PII Block, and K-Anonymity."""

from __future__ import annotations

import io

import pytest
from httpx import AsyncClient
from PIL import Image

from app.core.security import strip_exif_and_validate_image
from app.services.auth_service import get_dev_last_otp


def _create_jpeg_with_exif_gps_and_tag(comment_tag: str = "outdoor_tire_scan") -> bytes:
    img = Image.new("RGB", (64, 64), color=(40, 110, 160))
    exif = img.getexif()
    # Tag 271 = Make, Tag 272 = Model, Tag 270 = ImageDescription, Tag 34853 = GPSInfo
    exif[271] = "FieldCameraCorp"
    exif[272] = "NepalFieldScanner-X1"
    exif[270] = comment_tag
    exif[34853] = {1: "N", 2: (27, 42, 44), 3: "E", 4: (85, 18, 23)}
    buf = io.BytesIO()
    img.save(buf, format="JPEG", exif=exif.tobytes())
    return buf.getvalue()


def test_exif_gps_and_device_metadata_stripped_in_memory() -> None:
    raw_jpeg = _create_jpeg_with_exif_gps_and_tag("discarded_tire_courtyard")
    # Confirm input has EXIF
    with Image.open(io.BytesIO(raw_jpeg)) as before_img:
        assert len(before_img.getexif()) > 0

    sanitized_bytes, meta = strip_exif_and_validate_image(raw_jpeg)
    assert meta["had_exif_before_strip"] is True
    assert meta["remaining_exif_tags"] == 0
    assert meta["exif_stripped"] is True

    # Confirm output bytes have zero EXIF tags
    with Image.open(io.BytesIO(sanitized_bytes)) as after_img:
        assert len(after_img.getexif()) == 0


def test_human_portrait_and_nagarikta_id_image_rejected() -> None:
    portrait_jpeg = _create_jpeg_with_exif_gps_and_tag("human_portrait_citizen_face")
    with pytest.raises(ValueError, match="Individual Privacy Act 2075 Violation"):
        strip_exif_and_validate_image(portrait_jpeg)


@pytest.mark.asyncio
async def test_citizen_pii_rejected_in_inspection_and_vision_endpoints(
    client: AsyncClient,
) -> None:
    # Authenticate Ward 17 FCHV (+9779841000017)
    phone = "+9779841000017"
    await client.post("/api/v1/auth/request-otp", json={"phone": phone})
    otp = get_dev_last_otp(phone)
    assert otp is not None
    ver = await client.post(
        "/api/v1/auth/verify-otp", json={"phone": phone, "otp": otp}
    )
    headers = {"Authorization": f"Bearer {ver.json()['access_token']}"}

    # 1. Reject forbidden citizen PII field (`nagarikta_no` / `citizen_name`)
    pii_field_resp = await client.post(
        "/api/v1/inspections",
        headers=headers,
        json={
            "client_submission_uuid": "uuid-pii-test-001",
            "composite_ward_id": "NP-P3-D27-30608-W17",
            "houses_inspected": 10,
            "houses_infested": 2,
            "wet_containers_inspected": 20,
            "positive_containers": 4,
            "latitude": 27.7124,
            "longitude": 85.3065,
            "nagarikta_no": "27-01-75-12345",
        },
    )
    assert pii_field_resp.status_code == 422
    assert "Individual Privacy Act 2075" in str(pii_field_resp.json())

    # 2. Reject Nepali Citizenship Number pattern embedded inside `notes`
    pii_notes_resp = await client.post(
        "/api/v1/inspections",
        headers=headers,
        json={
            "client_submission_uuid": "uuid-pii-test-002",
            "composite_ward_id": "NP-P3-D27-30608-W17",
            "houses_inspected": 10,
            "houses_infested": 2,
            "wet_containers_inspected": 20,
            "positive_containers": 4,
            "latitude": 27.7124,
            "longitude": 85.3065,
            "notes": "House owner citizenship 27-01-75-98765 inspected",
        },
    )
    assert pii_notes_resp.status_code == 422

    # 3. Valid breeding-site vision scan strips EXIF and returns bilingual EDCD protocol
    valid_jpeg = _create_jpeg_with_exif_gps_and_tag("waterlogged_tire_bahal")
    scan_resp = await client.post(
        "/api/v1/scan-breeding-site",
        headers=headers,
        files={"image": ("tire_scan.jpg", valid_jpeg, "image/jpeg")},
        data={"composite_ward_id": "NP-P3-D27-30608-W17"},
    )
    assert scan_resp.status_code == 200
    scan_body = scan_resp.json()
    assert scan_body["exif_stripped"] is True
    assert "खोज र नष्ट गर" in scan_body["edcd_intervention_ne"]

    # 4. Public risk map enforces Spatial K-Anonymity (250m grid centroids only, no exact household GPS)
    pub_resp = await client.get("/api/v1/public/risk-map?palika_code=30608")
    assert pub_resp.status_code == 200
    pub_json = pub_resp.json()
    assert pub_json["ward_count"] == 32
    assert "encrypted_gps_coords" not in str(pub_json)
