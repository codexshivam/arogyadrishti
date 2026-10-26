"""Comprehensive End-to-End Tests for the 8 Nationwide Nepal Scale Capabilities
and Complete Removal of Nagarik App SSO.
"""

from __future__ import annotations

import base64
import json
import zlib

import pytest
from httpx import AsyncClient

from app.api.v1.sms_gateway import compute_sms_hmac_signature
from app.core.config import get_settings
from app.db.models.staff_user import StaffUser
from app.services.auth_service import get_dev_last_otp


async def _login_as(client: AsyncClient, phone: str) -> dict[str, str]:
    await client.post("/api/v1/auth/request-otp", json={"phone": phone})
    otp = get_dev_last_otp(phone)
    assert otp is not None
    ver = await client.post(
        "/api/v1/auth/verify-otp", json={"phone": phone, "otp": otp}
    )
    assert ver.status_code == 200
    return {"Authorization": f"Bearer {ver.json()['access_token']}"}


@pytest.mark.asyncio
async def test_nagarik_app_sso_completely_removed(client: AsyncClient) -> None:
    """Verify Nagarik App SSO endpoint and ORM columns are 100% removed."""
    resp = await client.post(
        "/api/v1/auth/nagarik-sso",
        json={"oidc_id_token": "legacy", "nagarik_sub": "legacy"},
    )
    assert resp.status_code == 404
    assert not hasattr(StaffUser, "nagarik_sub")


@pytest.mark.asyncio
async def test_module1_multi_vector_and_137_statutory_sla_engine(
    client: AsyncClient,
) -> None:
    """Test all 5 EDCD vector programs and WHO/EDCD 1-3-7 Malaria & Kala-azar SLA escalation."""
    headers = await _login_as(client, "+9779851201115")

    # 1. Evaluate all 5 EDCD vector programs across ecological belts
    programs = [
        ("DENGUE_AEDES", "PAHAD_VALLEY", False),
        ("MALARIA_ANOPHELES", "TERAI", True),
        ("KALAAZAR_SANDFLY", "HIMAL_CORRIDOR", True),
        ("SCRUB_TYPHUS_MITE", "INNER_TERAI", False),
        ("JE_CULEX", "TERAI", False),
    ]
    for prog, belt, expects_137 in programs:
        eval_resp = await client.post(
            "/api/v1/multi-vector/evaluate",
            headers=headers,
            json={
                "composite_ward_id": "NP-P7-D71-70105-W04",
                "vector_program": prog,
                "ecological_belt": belt,
                "confirmed_rdt_cases_7d": 4,
            },
        )
        assert eval_resp.status_code == 200
        body = eval_resp.json()
        assert body["vector_program"] == prog
        assert body["requires_137_sla_tracking"] is expects_137
        assert "BS |" in body["bs_date"]

    # 2. Create a compliant Malaria 1-3-7 case and advance through Day-3 and Day-7
    c1_resp = await client.post(
        "/api/v1/multi-vector/1-3-7-cases",
        headers=headers,
        json={
            "disease": "MALARIA_ANOPHELES",
            "ecological_belt": "TERAI",
            "composite_ward_id": "NP-P7-D71-70105-W04",
            "reporting_facility_nhfr": "NHFR-70105-SETI-PH",
            "backdate_hours_for_simulation": 0.0,
        },
    )
    assert c1_resp.status_code == 200
    c1 = c1_resp.json()
    assert c1["current_stage"] == "DAY_1_NOTIFIED"
    assert c1["sla_breached"] is False

    # Advance to Day-3 Investigated
    d3_resp = await client.patch(
        f"/api/v1/multi-vector/1-3-7-cases/{c1['id']}",
        headers=headers,
        json={
            "stage": "DAY_3_INVESTIGATED",
            "case_classification": "INDIGENOUS",
            "foci_irs_llin_summary": "Case investigated within 48h.",
        },
    )
    assert d3_resp.status_code == 200
    assert d3_resp.json()["current_stage"] == "DAY_3_INVESTIGATED"

    # Advance to Day-7 Foci Completed
    d7_resp = await client.patch(
        f"/api/v1/multi-vector/1-3-7-cases/{c1['id']}",
        headers=headers,
        json={
            "stage": "DAY_7_FOCI_COMPLETED",
            "case_classification": "INDIGENOUS",
            "foci_irs_llin_summary": "Pyrethroid IRS in 50m ring + 45 LLIN bed-nets distributed.",
        },
    )
    assert d7_resp.status_code == 200
    assert d7_resp.json()["current_stage"] == "DAY_7_FOCI_COMPLETED"

    # 3. Simulate a Kala-azar case backdated 96h (> 72h Day-3 SLA) and verify automatic Provincial PHD escalation
    breach_resp = await client.post(
        "/api/v1/multi-vector/1-3-7-cases",
        headers=headers,
        json={
            "disease": "KALAAZAR_SANDFLY",
            "ecological_belt": "PAHAD_VALLEY",
            "composite_ward_id": "NP-P6-D61-60102-W03",
            "reporting_facility_nhfr": "NHFR-60102-KALIKOT-DH",
            "backdate_hours_for_simulation": 96.0,
        },
    )
    assert breach_resp.status_code == 200
    breach_body = breach_resp.json()
    assert breach_body["sla_breached"] is True
    assert breach_body["escalated_to_provincial_phd"] is True
    assert breach_body["current_stage"] == "SLA_BREACHED_ESCALATED"
    assert breach_body["escalation_ticket_code"].startswith("PHD-137-ESC-")


@pytest.mark.asyncio
async def test_module2_2g_gsm_sms_shortcode_gateway(client: AsyncClient) -> None:
    """Test 2G feature phone compact SMS and compressed Base64 Flutter fallback on shortcode 31115."""
    settings = get_settings()
    fchv_phone = "+9779841000017"
    sms_text = "VEC W17 H25 P7 RDT2"
    sig = compute_sms_hmac_signature(
        fchv_phone, sms_text, settings.sms_webhook_hmac_secret
    )

    # 1. Valid 2G compact SMS from whitelisted FCHV
    resp = await client.post(
        "/api/v1/webhooks/sms-ingest",
        headers={"X-Sms-Signature": sig},
        json={
            "sender_phone": fchv_phone,
            "shortcode": "31115",
            "sms_text": sms_text,
            "telecom_provider": "SPARROW_SMS",
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "INGESTED"
    assert body["composite_ward_id"] == "NP-P3-D27-30608-W17"
    assert body["parsed_houses_inspected"] == 25
    assert body["parsed_positive_containers"] == 7
    assert body["parsed_rdt_positive"] == 2
    assert body["breteau_index_bi"] == 28.0
    assert "खोज र नष्ट गर" in body["reply_sms_unicode_ne"]

    # 2. Duplicate SMS is idempotently ignored
    dup_resp = await client.post(
        "/api/v1/webhooks/sms-ingest",
        headers={"X-Sms-Signature": sig},
        json={
            "sender_phone": fchv_phone,
            "shortcode": "31115",
            "sms_text": sms_text,
            "telecom_provider": "SPARROW_SMS",
        },
    )
    assert dup_resp.status_code == 200
    assert dup_resp.json()["status"] == "DUPLICATE_IGNORED"

    # 3. Compressed Base64 Flutter offline SMS fallback (`B64:...`)
    compressed_bytes = zlib.compress(
        json.dumps({"w": 12, "h": 40, "p": 10, "rdt": 3, "flag": "MALARIA_RDT"}).encode("utf-8")
    )
    b64_sms = "B64:" + base64.b64encode(compressed_bytes).decode("ascii")
    b64_sig = compute_sms_hmac_signature(
        "+9779841000012", b64_sms, settings.sms_webhook_hmac_secret
    )
    b64_resp = await client.post(
        "/api/v1/webhooks/sms-ingest",
        headers={"X-Sms-Signature": b64_sig},
        json={
            "sender_phone": "+9779841000012",
            "shortcode": "31115",
            "sms_text": b64_sms,
            "telecom_provider": "AAKASH_SMS",
        },
    )
    assert b64_resp.status_code == 200
    assert b64_resp.json()["status"] == "INGESTED"
    assert b64_resp.json()["breteau_index_bi"] == 25.0

    # 4. Unregistered +977 number is rejected with 403 Forbidden
    unauth_resp = await client.post(
        "/api/v1/webhooks/sms-ingest",
        json={
            "sender_phone": "+9779849999999",
            "shortcode": "31115",
            "sms_text": "VEC W17 H20 P5 RDT1",
            "telecom_provider": "SPARROW_SMS",
        },
    )
    assert unauth_resp.status_code == 403


@pytest.mark.asyncio
async def test_module3_bipad_disaster_and_dhm_weather_fusion(
    client: AsyncClient,
) -> None:
    """Test NDRRMA BIPAD flood/landslide alert + DHM AWS ground weather fusion and 14-day multiplier."""
    headers = await _login_as(client, "+9779851130608")
    resp = await client.post(
        "/api/v1/disaster-weather/fuse-ward",
        headers=headers,
        json={
            "composite_ward_id": "NP-P3-D27-30608-W17",
            "river_corridor": "TRISHULI",
            "bipad_flood_inundation_alert": True,
            "bipad_landslide_alert": True,
            "dhm_aws_station_id": "DHM-AWS-TRISHULI-204",
            "dhm_ground_rainfall_24h_mm": 162.0,
            "dhm_ground_temp_celsius": 28.5,
            "satellite_chirps_rainfall_mm": 54.0,
            "satellite_modis_lst_celsius": 21.0,
            "baseline_composite_risk": 62.0,
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["cloud_shadow_bias_corrected"] is True
    assert body["post_disaster_multiplier"] == 1.65
    assert body["outbreak_window_days"] == 14
    assert body["adjusted_dengue_risk"] >= 90.0
    assert body["adjusted_scrub_typhus_risk"] >= 90.0
    assert body["palika_chief_pre_alert_dispatched"] is True


@pytest.mark.asyncio
async def test_module4_cross_border_poe_health_desk_surveillance(
    client: AsyncClient,
) -> None:
    """Test Cross-Border PoE Health Desk RDT-positive destination routing & Zero-PII enforcement."""
    headers = await _login_as(client, "+9779851201115")

    # 1. Valid Zero-PII PoE surveillance submission at Gaddachauki Health Desk
    resp = await client.post(
        "/api/v1/poe/surveillance",
        headers=headers,
        json={
            "poe_desk_code": "GADDACHAUKI_MAHENDRANAGAR",
            "disease": "MALARIA_ANOPHELES",
            "rdt_result": "POSITIVE_PF_RDT",
            "origin_zone": "Western Cross-Border Transit Sector",
            "destination_province_code": 7,
            "destination_district_code": 69,
            "destination_palika_code": "70701",
            "destination_ward_no": 4,
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["destination_composite_ward_id"] == "NP-P7-D69-70701-W04"
    assert body["destination_alert_dispatched"] is True
    assert body["alert_ticket_code"].startswith("POE-ALERT-")

    # 2. Reject PoE payload containing traveler PII (Individual Privacy Act 2075)
    pii_resp = await client.post(
        "/api/v1/poe_surveillance",
        headers=headers,
        json={
            "poe_desk_code": "KAKARBHITTA",
            "disease": "DENGUE_AEDES",
            "citizen_name": "Forbidden Traveler Name",
            "destination_palika_code": "10104",
            "destination_ward_no": 2,
        },
    )
    assert pii_resp.status_code == 422


@pytest.mark.asyncio
async def test_module5_elmis_supply_chain_and_phlmc_stockout_predictor(
    client: AsyncClient,
) -> None:
    """Test MoHP eLMIS 14-day burn-rate forecast and automatic PHLMC requisition generation."""
    headers = await _login_as(client, "+9779851130608")
    resp = await client.get("/api/v1/elmis/forecast/30608", headers=headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body["palika_code"] == "30608"
    assert "PHLMC Hetauda" in body["phlmc_hub_name"]
    assert len(body["commodities"]) == 9
    assert len(body["auto_requisitions"]) >= 1
    req0 = body["auto_requisitions"][0]
    assert req0["requisition_id"].startswith("ELMIS-REQ-")
    assert req0["quantity_requested"] > 0


@pytest.mark.asyncio
async def test_module6_and_8_lab_resistance_gate_and_regional_languages(
    client: AsyncClient,
) -> None:
    """Test NPHL serotype shift, VBDRTC insecticide resistance gating, and 7-province regional languages."""
    headers = await _login_as(client, "+9779851130608")

    # 1. Register NPHL Teku Serotype Shift (DENV-1 -> DENV-2)
    sero_resp = await client.post(
        "/api/v1/lab/serotype-shift",
        headers=headers,
        json={
            "lab_center": "NPHL_TEKU",
            "province_code": 3,
            "district_code": 27,
            "previous_serotype": "DENV-1",
            "dominant_serotype": "DENV-2",
        },
    )
    assert sero_resp.status_code == 200
    assert sero_resp.json()["serotype_shift_detected"] is True
    assert sero_resp.json()["ade_surge_multiplier"] == 1.45

    # 2. Register VBDRTC Hetauda WHO Tube Bioassay showing < 90% mortality for TEMEPHOS_50_EC
    bio_resp = await client.post(
        "/api/v1/lab/insecticide-resistance",
        headers=headers,
        json={
            "lab_center": "VBDRTC_HETAUDA",
            "province_code": 3,
            "district_code": 27,
            "vector_species": "Aedes aegypti",
            "chemical_tested": "TEMEPHOS_50_EC",
            "bioassay_mortality_pct": 78.5,
        },
    )
    assert bio_resp.status_code == 200
    assert bio_resp.json()["resistance_status"] == "CONFIRMED_RESISTANCE"
    assert "Bti" in bio_resp.json()["recommended_substitute"]

    # 3. Query Gemma Copilot across regional languages (Maithili, Bhojpuri, Tharu, Newari, Nepali)
    # and verify VBDRTC resistance gate blocks Temephos and switches to Bti (5 g / 10 m²)
    for lang in ("ne", "mai", "bho", "thr", "new", "en"):
        chat_resp = await client.post(
            "/api/v1/copilot/chat",
            headers=headers,
            json={
                "query": "ड्रम मा temephos हाल्ने कि के गर्ने?",
                "composite_ward_id": "NP-P3-D27-30608-W17",
                "preferred_language": lang,
            },
        )
        assert chat_resp.status_code == 200
        c_body = chat_resp.json()
        assert c_body["language_resolved"] == lang
        assert "5 g / 10 m²" in c_body["answer_regional"]
        assert "1115" in c_body["answer_regional"]
        dose_trace = next(
            t for t in c_body["tool_traces"] if t["tool_name"] == "compute_edcd_larvicide_dose"
        )
        assert dose_trace["output"]["vbdtrc_resistance_override"] is True
        assert dose_trace["output"]["resisted_chemical_blocked"] == "TEMEPHOS_50_EC"


@pytest.mark.asyncio
async def test_module7_gioms_tippani_pdf_and_sutra_fiscal_planner(
    client: AsyncClient,
) -> None:
    """Test Shrawan–Ashadh SuTRA Municipal Assembly Budget Plan and Singha Durbar GIOMS Tippani PDF."""
    headers = await _login_as(client, "+9779851130608")

    # 1. JSON Fiscal Budget Plan
    plan_resp = await client.get(
        "/api/v1/palika/30608/fiscal-budget-plan", headers=headers
    )
    assert plan_resp.status_code == 200
    plan = plan_resp.json()
    assert plan["palika_code"] == "30608"
    assert plan["sutra_budget_head_code"] == "SuTRA-27213-EDCD-VECTOR-CONTROL"
    assert "Shrawan 1" in plan["budget_cycle_window_bs"]
    assert len(plan["ward_allocations"]) == 32
    assert plan["total_estimated_budget_npr"] > 0

    # 2. Alias endpoint `/api/v1/palika/annual-budget-forecast`
    alias_resp = await client.get(
        "/api/v1/palika/annual-budget-forecast?palika_code=30608", headers=headers
    )
    assert alias_resp.status_code == 200

    # 3. Official Singha Durbar GIOMS Tippani PDF binary download
    pdf_resp = await client.get(
        "/api/v1/palika/30608/gioms-tippani-pdf", headers=headers
    )
    assert pdf_resp.status_code == 200
    assert pdf_resp.headers["content-type"] == "application/pdf"
    assert "X-GIOMS-Reference" in pdf_resp.headers
    assert pdf_resp.content.startswith(b"%PDF-1.4")
