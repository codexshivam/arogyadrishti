"""Tests for Nepal +977 OTP, Pre-OTP Whitelist Gate, Lockout, EdDSA JWTs, Ward/Palika Isolation, and ULV Policy Gate."""

from __future__ import annotations

import pytest
from httpx import AsyncClient

from app.core.security import create_asymmetric_jwt, normalize_nepal_phone
from app.services.auth_service import get_dev_last_otp


def test_nepal_phone_normalization_and_validation() -> None:
    assert normalize_nepal_phone("+9779841000017") == "+9779841000017"
    assert normalize_nepal_phone("9851000017") == "+9779851000017"
    assert normalize_nepal_phone("977-9801234567") == "+9779801234567"

    # Reject non-Nepali or land-line numbers
    with pytest.raises(ValueError):
        normalize_nepal_phone("+14155552671")
    with pytest.raises(ValueError):
        normalize_nepal_phone("+97714253396")


def test_symmetric_hs256_jwt_strictly_rejected() -> None:
    with pytest.raises(ValueError, match="symmetric HMAC JWT"):
        create_asymmetric_jwt(
            subject_id="staff-who-kmc-w17",
            role="ward_health_officer",
            province_code=3,
            district_code=27,
            palika_code="30608",
            assigned_wards=["NP-P3-D27-30608-W17"],
            algorithm="HS256",
        )


@pytest.mark.asyncio
async def test_unwhitelisted_phone_rejected_with_403_before_sms(
    client: AsyncClient,
) -> None:
    resp = await client.post(
        "/api/v1/auth/request-otp",
        json={"phone": "+9779809999999"},
    )
    assert resp.status_code == 403
    assert "Staff Whitelist" in resp.json()["detail"]


@pytest.mark.asyncio
async def test_otp_generation_rate_limit_and_brute_force_lockout(
    client: AsyncClient,
) -> None:
    # Whitelisted Ward 12 FCHV phone: +9779841000012
    phone = "+9779841000012"

    # 1st OTP request succeeds
    r1 = await client.post("/api/v1/auth/request-otp", json={"phone": phone})
    assert r1.status_code == 200
    assert r1.json()["status"] == "OTP_SENT"
    assert "BS" in r1.json()["bs_date"]

    # 5 failed verification attempts trigger 30m (1800s) lockout (HTTP 429)
    for attempt in range(1, 5):
        bad = await client.post(
            "/api/v1/auth/verify-otp",
            json={"phone": phone, "otp": "000000"},
        )
        assert bad.status_code == 401
        assert f"{attempt}/5" in bad.json()["detail"]

    fifth = await client.post(
        "/api/v1/auth/verify-otp",
        json={"phone": phone, "otp": "000000"},
    )
    assert fifth.status_code == 429
    assert fifth.json()["detail"]["error"] == "OTP_BRUTE_FORCE_LOCKOUT"

    # Subsequent OTP request while locked out also returns 429
    locked_req = await client.post("/api/v1/auth/request-otp", json={"phone": phone})
    assert locked_req.status_code == 429


@pytest.mark.asyncio
async def test_eddsa_jwt_ward_and_palika_isolation_and_ulv_gate(
    client: AsyncClient,
) -> None:
    # Authenticate Ward 17 Health Officer (+9779851000017)
    who_phone = "+9779851000017"
    req_otp = await client.post("/api/v1/auth/request-otp", json={"phone": who_phone})
    assert req_otp.status_code == 200
    otp_code = get_dev_last_otp(who_phone)
    assert otp_code is not None and len(otp_code) == 6

    ver_resp = await client.post(
        "/api/v1/auth/verify-otp",
        json={"phone": who_phone, "otp": otp_code},
    )
    assert ver_resp.status_code == 200
    token_data = ver_resp.json()
    assert token_data["algorithm"] == "EdDSA"
    who_token = token_data["access_token"]
    who_headers = {"Authorization": f"Bearer {who_token}"}

    # Ward 17 Health Officer CAN read KMC Ward 17 risk
    w17_resp = await client.get(
        "/api/v1/wards/NP-P3-D27-30608-W17/risk", headers=who_headers
    )
    assert w17_resp.status_code == 200
    assert w17_resp.json()["composite_ward_id"] == "NP-P3-D27-30608-W17"

    # Ward 17 Health Officer CANNOT read KMC Ward 10 risk (403 Forbidden)
    w10_resp = await client.get(
        "/api/v1/wards/NP-P3-D27-30608-W10/risk", headers=who_headers
    )
    assert w10_resp.status_code == 403

    # Ward 17 Health Officer CANNOT read Lalitpur Metro Ward 3 risk (403 Forbidden)
    lmc_resp = await client.get(
        "/api/v1/wards/NP-P3-D28-30805-W03/risk", headers=who_headers
    )
    assert lmc_resp.status_code == 403

    # Ward 17 Health Officer can dispatch Search & Destroy RRT in Ward 17
    rrt_resp = await client.post(
        "/api/v1/rrt/dispatch",
        headers=who_headers,
        json={
            "composite_ward_id": "NP-P3-D27-30608-W17",
            "target_lat": 27.7124,
            "target_lng": 85.3065,
            "water_surface_sqm": 40.0,
        },
    )
    assert rrt_resp.status_code == 200
    assert rrt_resp.json()["dispatch_type"] == "SEARCH_AND_DESTROY"
    assert rrt_resp.json()["plate_number"].startswith("BA-2-JHA-")

    # Ward 17 Health Officer is FORBIDDEN (403) from triggering ULV space-spraying override
    ulv_forbidden = await client.post(
        "/api/v1/rrt/ulv-override",
        headers=who_headers,
        json={
            "composite_ward_id": "NP-P3-D27-30608-W17",
            "target_lat": 27.7124,
            "target_lng": 85.3065,
            "ewars_confirmed_cases": 14,
            "breteau_index": 35.0,
            "statutory_justification": "Attempted ULV by Ward Officer",
        },
    )
    assert ulv_forbidden.status_code == 403

    # Now authenticate KMC Palika Health Chief (+9779851130608)
    chief_phone = "+9779851130608"
    await client.post("/api/v1/auth/request-otp", json={"phone": chief_phone})
    chief_otp = get_dev_last_otp(chief_phone)
    assert chief_otp is not None
    chief_ver = await client.post(
        "/api/v1/auth/verify-otp",
        json={"phone": chief_phone, "otp": chief_otp},
    )
    chief_headers = {"Authorization": f"Bearer {chief_ver.json()['access_token']}"}

    # Palika Health Chief is REJECTED (422) if BI < 30 or EWARS cases == 0
    ulv_low_bi = await client.post(
        "/api/v1/rrt/ulv-override",
        headers=chief_headers,
        json={
            "composite_ward_id": "NP-P3-D27-30608-W17",
            "target_lat": 27.7124,
            "target_lng": 85.3065,
            "ewars_confirmed_cases": 5,
            "breteau_index": 22.0,
            "statutory_justification": "Routine fogging request with BI below 30 threshold",
        },
    )
    assert ulv_low_bi.status_code == 422

    # Palika Health Chief succeeds when EWARS cases > 0 AND BI >= 30
    ulv_ok = await client.post(
        "/api/v1/rrt/ulv-override",
        headers=chief_headers,
        json={
            "composite_ward_id": "NP-P3-D27-30608-W17",
            "target_lat": 27.7124,
            "target_lng": 85.3065,
            "ewars_confirmed_cases": 14,
            "breteau_index": 34.5,
            "statutory_justification": "Confirmed EWARS hospital cluster in Chhetrapati + BI 34.5 >= 30",
        },
    )
    assert ulv_ok.status_code == 200
    assert ulv_ok.json()["dispatch_type"] == "ULV_FOCAL_OVERRIDE"
