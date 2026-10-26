"""Tests for Idempotent Offline FCHV Batch Sync, NHFR Facilities, Gemma 4 Copilot, DHIS2 Push, and 7-Tab Ledger Export."""

from __future__ import annotations

import pytest
from httpx import AsyncClient

from app.services.auth_service import get_dev_last_otp


@pytest.mark.asyncio
async def test_idempotent_offline_fchv_batch_sync_and_interoperability(
    client: AsyncClient,
) -> None:
    # Authenticate Ward 17 FCHV (+9779841000017)
    fchv_phone = "+9779841000017"
    await client.post("/api/v1/auth/request-otp", json={"phone": fchv_phone})
    otp = get_dev_last_otp(fchv_phone)
    assert otp is not None
    ver = await client.post(
        "/api/v1/auth/verify-otp", json={"phone": fchv_phone, "otp": otp}
    )
    fchv_headers = {"Authorization": f"Bearer {ver.json()['access_token']}"}

    batch_items = [
        {
            "client_submission_uuid": "offline-bahal-uuid-1001",
            "composite_ward_id": "NP-P3-D27-30608-W17",
            "houses_inspected": 25,
            "houses_infested": 4,
            "wet_containers_inspected": 40,
            "positive_containers": 8,
            "pupae_count": 12,
            "household_occupants_inspected": 80,
            "houses_searched_destroyed": 25,
            "container_type": "discarded_vehicle_tire",
            "water_matrix": "stagnant_pool_or_tire",
            "larvae_detected": True,
            "instar_stage": "III-IV",
            "larvicide_applied": "Bti WP 1.0 g/m2",
            "larvicide_dosage_mg": 8000.0,
            "latitude": 27.71242,
            "longitude": 85.30654,
            "notes": "Chhetrapati inner courtyard bahal tire stack cleared.",
        },
        {
            "client_submission_uuid": "offline-bahal-uuid-1002",
            "composite_ward_id": "NP-P3-D27-30608-W17",
            "houses_inspected": 20,
            "houses_infested": 2,
            "wet_containers_inspected": 30,
            "positive_containers": 3,
            "pupae_count": 5,
            "household_occupants_inspected": 60,
            "houses_searched_destroyed": 20,
            "container_type": "uncovered_plastic_drum",
            "water_matrix": "clean_non_potable",
            "larvae_detected": True,
            "instar_stage": "I-II",
            "larvicide_applied": "Temephos 50% EC @ 1 ppm",
            "larvicide_dosage_mg": 200.0,
            "latitude": 27.71288,
            "longitude": 85.30691,
            "notes": "Dhalko rooftop plastic drums scrubbed and covered.",
        },
    ]

    # First batch submission creates 2 records
    b1 = await client.post(
        "/api/v1/inspections/batch",
        headers=fchv_headers,
        json={"inspections": batch_items},
    )
    assert b1.status_code == 200
    b1_data = b1.json()
    assert b1_data["total_received"] == 2
    assert b1_data["created_count"] == 2
    assert b1_data["duplicate_ignored_count"] == 0
    assert all("BS" in r["bs_date"] for r in b1_data["receipts"])

    # Second replay of the same batch + 1 new item -> 2 DUPLICATE_IGNORED, 1 CREATED
    replay_items = batch_items + [
        {
            **batch_items[0],
            "client_submission_uuid": "offline-bahal-uuid-1003",
        }
    ]
    b2 = await client.post(
        "/api/v1/inspections/batch",
        headers=fchv_headers,
        json={"inspections": replay_items},
    )
    assert b2.status_code == 200
    b2_data = b2.json()
    assert b2_data["total_received"] == 3
    assert b2_data["created_count"] == 1
    assert b2_data["duplicate_ignored_count"] == 2

    # Verify total stored rows in Ward 17 is exactly 3 (zero duplicates)
    list_resp = await client.get(
        "/api/v1/inspections?composite_ward_id=NP-P3-D27-30608-W17",
        headers=fchv_headers,
    )
    assert list_resp.status_code == 200
    assert list_resp.json()["count"] == 3

    # Test NHFR Nearby Facilities (Teku Hospital, Bir Hospital, UHPCs, 1115 hotline)
    fac_resp = await client.get(
        "/api/v1/facilities/nearby?lat=27.6948&lng=85.3049&radius_km=5.0"
    )
    assert fac_resp.status_code == 200
    fac_data = fac_resp.json()
    assert fac_data["hello_swasthya_hotline"] == "1115"
    assert any("Teku" in f["name_en"] for f in fac_data["facilities"])

    # Test Bilingual Gemma 4 Copilot with deterministic tool execution trace
    chat_resp = await client.post(
        "/api/v1/copilot/chat",
        headers=fchv_headers,
        json={
            "query": "क्षेत्रपाटी वडा १७ मा टायरमा लार्भा भेटियो, कति Bti हाल्ने र DHIS2 रिपोर्ट के छ?",
            "composite_ward_id": "NP-P3-D27-30608-W17",
            "language": "ne",
        },
    )
    assert chat_resp.status_code == 200
    chat_body = chat_resp.json()
    tool_names = [t["tool_name"] for t in chat_body["tool_traces"]]
    assert "query_ward_risk" in tool_names
    assert "compute_edcd_larvicide_dose" in tool_names
    assert "find_nearest_rrt_and_route" in tool_names
    assert "lookup_nhfr_health_centers" in tool_names
    assert "draft_dhis2_ward_report" in tool_names

    # Authenticate Palika Health Chief (+9779851130608) to test DHIS2 push & 7-Tab Ledger export
    chief_phone = "+9779851130608"
    await client.post("/api/v1/auth/request-otp", json={"phone": chief_phone})
    chief_otp = get_dev_last_otp(chief_phone)
    assert chief_otp is not None
    chief_ver = await client.post(
        "/api/v1/auth/verify-otp", json={"phone": chief_phone, "otp": chief_otp}
    )
    chief_headers = {"Authorization": f"Bearer {chief_ver.json()['access_token']}"}

    dhis2_resp = await client.post(
        "/api/v1/dhis2/push",
        headers=chief_headers,
        json={
            "palika_code": "30608",
            "composite_ward_ids": ["NP-P3-D27-30608-W17"],
            "period_iso": "2026W43",
        },
    )
    assert dhis2_resp.status_code == 200
    assert dhis2_resp.json()["status"] == "SYNCED_TO_IHMIS_OUTBOX"

    ledger_json_resp = await client.get(
        "/api/v1/ledger/export?palika_code=30608&format=json",
        headers=chief_headers,
    )
    assert ledger_json_resp.status_code == 200
    assert len(ledger_json_resp.json()["sheet_tabs"]) == 7

    ledger_xlsx_resp = await client.get(
        "/api/v1/ledger/export?palika_code=30608&format=xlsx",
        headers=chief_headers,
    )
    assert ledger_xlsx_resp.status_code == 200
    assert "X-Ledger-SHA256" in ledger_xlsx_resp.headers
