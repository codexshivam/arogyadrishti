"""Comprehensive unit + live integration test suite for Phase 2, 3, 4, and 5."""

from __future__ import annotations

import io
import json
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from PIL import Image, ImageDraw

_REPO_ROOT = Path(__file__).resolve().parents[2]
_BACKEND_DIR = _REPO_ROOT / "backend"
_SKILL_DIR = _REPO_ROOT / "skills" / "vector-surveillance-skill"
for p in (str(_REPO_ROOT), str(_BACKEND_DIR), str(_SKILL_DIR)):
    if p not in sys.path:
        sys.path.insert(0, p)

from app.core.config import Settings, get_settings
from app.core.security import scrub_pii_text
from app.main import app
from app.tools.gee_climate_tool.client import (
    compute_environmental_suitability,
    get_gee_client,
)
from app.tools.gmail_alert_tool.client import verify_email_and_mx
from app.tools.maps_routing_tool.client import (
    encode_polyline,
    get_maps_routing_client,
)
from app.tools.ogd_india_gov_tool.client import haversine_km
from app.tools.sheets_admin_tool.client import get_sheets_client
from app.tools.vision_paligemma_tool.client import (
    compute_composite_risk_score,
    get_ncvbdc_dosage_protocol,
)
from harness.gemma_agent_harness import GemmaAgentHarness
from harness.skill_executor import SkillExecutor

client = TestClient(app)


def _make_test_breeding_image() -> bytes:
    """Create a realistic synthetic image of an uncovered water drum with green algae."""
    img = Image.new("RGB", (320, 320), color=(40, 55, 65))
    draw = ImageDraw.Draw(img)
    draw.ellipse((40, 40, 280, 280), fill=(25, 85, 45), outline=(120, 130, 140), width=6)
    draw.rectangle((90, 110, 220, 195), fill=(30, 110, 50))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def test_sovereignty_and_pii_scrubber() -> None:
    settings = get_settings()
    assert settings.gcp_region in ("asia-south1", "asia-south2")
    with pytest.raises(ValueError, match="Data sovereignty violation"):
        Settings(GCP_REGION="us-central1")

    raw = "Call citizen at +91 9876543210 or email citizen@gmail.com or Aadhaar 1234 5678 9012"
    scrubbed = scrub_pii_text(raw)
    assert "9876543210" not in scrubbed
    assert "citizen@gmail.com" not in scrubbed
    assert "[REDACTED_PHONE]" in scrubbed
    assert "[REDACTED_EMAIL]" in scrubbed


def test_health_and_readiness_probes() -> None:
    r1 = client.get("/healthz")
    assert r1.status_code == 200
    assert r1.json()["region"] == "asia-south1"
    assert r1.headers["X-Cloud-Armor-Policy"] == "arogya-drishti-dpi-waf-south1"

    r2 = client.get("/readyz")
    assert r2.status_code == 200
    assert r2.json()["status"] == "ready"


def test_scientific_formulas_and_polyline() -> None:
    dist = haversine_km(30.7333, 76.7794, 30.7471, 76.7791)
    assert 1.0 <= dist <= 2.5

    e_gee = compute_environmental_suitability(29.5, 0.35, 0.42, 84.0)
    assert 0.80 <= e_gee <= 1.0

    v_field, comp, tier = compute_composite_risk_score(
        e_gee=e_gee, ward_breteau_index=35.5, i_vision=0.92
    )
    assert v_field > 0.65
    assert comp >= 0.70
    assert tier == "CRITICAL"

    inter, dosage = get_ncvbdc_dosage_protocol("Uncovered Overhead Tank", "CRITICAL")
    assert "Temephos 50% EC @ 1 ppm" in dosage
    assert "Pyrethrum" in inter

    poly = encode_polyline([(30.7333, 76.7794), (30.7471, 76.7791)])
    assert isinstance(poly, str) and len(poly) > 4


def test_live_sheets_admin_and_mx_tools() -> None:
    sheets = get_sheets_client()
    vans = sheets.get_vans_fleet("Chandigarh")
    assert len(vans) >= 1
    assert vans[0].vehicle_no != ""

    centers = sheets.get_health_centers(30.7333, 76.7794, radius_km=30.0)
    assert len(centers) >= 1

    contacts = sheets.list_all_staff_contacts()
    assert len(contacts) >= 1
    target = contacts[0]
    staff = sheets.lookup_authorized_staff(target.ward_or_village, target.lgd_code)
    assert staff.lgd_code == target.lgd_code
    assert "@" in staff.village_officer_email

    mx_host = verify_email_and_mx(staff.village_officer_email)
    assert isinstance(mx_host, str) and "." in mx_host


def test_live_gee_and_maps_routing_tools() -> None:
    gee_telemetry = get_gee_client().get_climate_suitability(30.7333, 76.7794)
    assert gee_telemetry.lst_celsius is not None
    assert gee_telemetry.rain_14d_mm is not None
    assert 0.0 <= gee_telemetry.environmental_suitability_score <= 1.0

    vans = get_sheets_client().get_vans_fleet("Chandigarh")
    route = get_maps_routing_client().select_fastest_van(30.7333, 76.7794, vans)
    assert route.eta_minutes >= 1
    assert route.distance_km >= 0.0
    assert len(route.encoded_polyline) > 3


def test_agent_skill_standard_and_harness() -> None:
    skill_md = (_SKILL_DIR / "SKILL.md").read_text(encoding="utf-8")
    assert "name: arogya-drishti-vector-surveillance" in skill_md
    assert "license: Apache-2.0" in skill_md
    assert "Temephos 50% EC" in skill_md

    schema = json.loads((_SKILL_DIR / "schema.json").read_text(encoding="utf-8"))
    tool_names = {t["function"]["name"] for t in schema["tools"]}
    assert tool_names == {
        "query_gee_microclimate",
        "compute_ward_entomological_indices",
        "dispatch_fogging_van",
        "trigger_emergency_ward_alert",
    }

    executor = SkillExecutor()
    with pytest.raises(ValueError, match="allow-list"):
        executor.execute("unauthorized_shell_tool", {})

    harness = GemmaAgentHarness(executor=executor)
    res = harness.run_chat_turn(
        user_message="Sector 22-B mein Temephos kitna dalna hai?",
        ward_village="Sector 22-B",
        lgd_code="0404400017",
    )
    assert len(res.reply_text) > 20
    assert len(res.tool_cards) >= 1


def test_api_endpoints_end_to_end() -> None:
    sheets = get_sheets_client()
    contacts = sheets.list_all_staff_contacts()
    assert len(contacts) >= 1
    sample_staff = contacts[0]
    sample_phone = sample_staff.village_officer_phone or "+919915549455"
    sample_lgd = sample_staff.lgd_code
    sample_ward = sample_staff.ward_or_village

    # 1. Verify staff
    r_auth = client.post(
        "/api/v1/auth/verify-staff",
        json={"uid": f"officer_{sample_phone}", "phone": sample_phone},
    )
    assert r_auth.status_code == 200
    assert r_auth.json()["status"] == "STAFF_VERIFIED"

    # 2. Centers, Vans, Contacts, Stats
    r_centers = client.get("/api/v1/centers?lat=30.7333&lng=76.7794")
    assert r_centers.status_code == 200
    assert r_centers.json()["count"] >= 1

    r_vans = client.get("/api/v1/vans?lat=30.7333&lng=76.7794")
    assert r_vans.status_code == 200
    assert r_vans.json()["count"] >= 1

    r_contacts = client.get(f"/api/v1/contacts?district_lgd={sample_lgd}")
    assert r_contacts.status_code == 200
    assert r_contacts.json()["count"] >= 1

    r_stats = client.get(f"/api/v1/stats?lgd_code={sample_lgd}")
    assert r_stats.status_code == 200
    assert "weekly_trends" in r_stats.json()
    assert "ihip_fhir_observation_bundle" in r_stats.json()

    # 3. Public DPI Risk Index
    r_risk = client.get(f"/api/v1/risk-index?lat=30.7333&lng=76.7794&lgd_code={sample_lgd}")
    assert r_risk.status_code == 200
    risk_data = r_risk.json()
    assert risk_data["risk_tier"] in ("CRITICAL", "HIGH", "MODERATE", "LOW")
    assert "satellite_telemetry_gee" in risk_data

    # 4. Scan Breeding Site (multipart upload)
    img_bytes = _make_test_breeding_image()
    r_scan = client.post(
        "/api/v1/scan-breeding-site",
        data={"lat": "30.7333", "lng": "76.7794", "ward_lgd": sample_lgd},
        files={"image": ("breeding_drum.jpg", img_bytes, "image/jpeg")},
    )
    assert r_scan.status_code == 200
    scan_json = r_scan.json()
    assert scan_json["dpdp_audit"]["sanitized_before_gcs_upload"] is True
    assert scan_json["image_gcs_uri"].startswith("gs://")

    # 5. Agent Chat
    r_chat = client.post(
        "/api/v1/agent/chat",
        json={
            "uid": f"officer_{sample_lgd}",
            "message": f"Found 14 discarded tires with stagnant rainwater in {sample_ward}. What is the immediate protocol?",
            "ward_village": sample_ward,
            "lgd_code": sample_lgd,
            "latitude": 30.7333,
            "longitude": 76.7794,
        },
    )
    assert r_chat.status_code == 200
    assert len(r_chat.json()["tool_cards"]) >= 1


def test_chandigarh_live_endpoints() -> None:
    # 1. Locations / Wards (all 35 hydrated Chandigarh wards)
    r_wards = client.get("/api/v1/locations/wards")
    assert r_wards.status_code == 200
    w_json = r_wards.json()
    assert w_json["count"] == 35
    assert len(w_json["wards"]) == 35
    first_ward = w_json["wards"][0]
    assert "04044" in first_ward["lgd_code"]
    assert "Chandigarh" in first_ward["district"]

    # 2. Ward Stats with 12 weeks
    r_stats = client.get(f"/api/v1/stats/ward/{first_ward['lgd_code']}?weeks=12")
    assert r_stats.status_code == 200
    s_json = r_stats.json()
    assert s_json["ward_info"]["ward_id"] == first_ward["lgd_code"]
    assert s_json["weekly_trends"]["time_window_weeks"] == 12
    assert len(s_json["weekly_trends"]["x_labels"]) == 12
    assert len(s_json["weekly_trends"]["datasets"]["bi"]) == 12
    assert "core_surveillance_metrics" in s_json
    assert "who_nvbdcp_evaluation" in s_json
    assert "recommended_interventions" in s_json
    assert "ai_interventions" in s_json

    # 3. Map Surveillance
    r_map = client.get("/api/v1/map/surveillance")
    assert r_map.status_code == 200
    m_json = r_map.json()
    assert len(m_json["ward_polygons"]) >= 35
    assert len(m_json["breeding_markers"]) >= 1

    # 4. Support Directory & Tickets
    r_supp = client.get("/api/v1/support/directory-and-tickets")
    assert r_supp.status_code == 200
    sup_json = r_supp.json()
    assert len(sup_json["nodal_officers"]) >= 3
    assert len(sup_json["emergency_hotlines"]) >= 3

    # 5. Export ReportLab PDF & CSV
    r_pdf = client.get(f"/api/v1/stats/export-report?ward_id={first_ward['lgd_code']}&weeks=8&format=pdf")
    assert r_pdf.status_code == 200
    assert r_pdf.headers["content-type"] == "application/pdf"
    assert len(r_pdf.content) > 500

    r_csv = client.get(f"/api/v1/stats/export-report?ward_id={first_ward['lgd_code']}&weeks=8&format=csv")
    assert r_csv.status_code == 200
    assert "text/csv" in r_csv.headers["content-type"]
    assert b"Breteau_Index" in r_csv.content


def test_epidemiology_math_and_email_themes() -> None:
    from app.core.epidemiology_math import (
        compute_entomological_indices,
        compute_gee_suitability,
    )
    from app.tools.gmail_alert_tool.client import (
        build_arogya_drishti_email_html,
        get_email_theme_by_metrics,
    )

    # 1. Zero inspection returns exact 0.0
    zero = compute_entomological_indices(0, 0, 0, 0)
    assert zero["house_index_pct"] == 0.0
    assert zero["container_index_pct"] == 0.0
    assert zero["breteau_index"] == 0.0

    # 2. Real indices
    indices = compute_entomological_indices(150, 15, 300, 36, 12)
    assert indices["house_index_pct"] == 10.0
    assert indices["container_index_pct"] == 12.0
    assert indices["breteau_index"] == 24.0
    assert indices["pupal_demographic_index"] == 0.08

    # 3. GEE suitability
    gee = compute_gee_suitability(lst_celsius=29.0, ndwi=0.25, ndvi=0.55, rain_14d_mm=90.0)
    assert 0.85 <= gee["environmental_suitability_score"] <= 1.0

    # 4. Multi-tier visual email themes and subject formats
    t1 = get_email_theme_by_metrics(3.2, 28.0)
    assert t1["tier"] == "LOW / SAFE"
    assert t1["header_bg"] == "#1B5E20"
    s1, h1 = build_arogya_drishti_email_html(
        "Ward 2", "0404400002", "Dr. Suman", 3.2, 1.5, 2.0, 180, 420, 6, 26.0, -0.3, 40.0, 28.0, "Routine", 30.75, 76.79
    )
    assert s1 == "ArogyaDrishti - BI (3.2) in your Region"
    assert "#1B5E20" in h1

    t2 = get_email_theme_by_metrics(11.4, 52.0)
    assert t2["tier"] == "MODERATE RISK"
    assert t2["header_bg"] == "#E65100"
    s2, _ = build_arogya_drishti_email_html(
        "Ward 10", "0404400010", "Dr. Parmjit", 11.4, 4.5, 6.0, 180, 420, 20, 28.0, -0.2, 80.0, 52.0, "Targeted Temephos", 30.72, 76.78
    )
    assert s2 == "ArogyaDrishti - BI (11.4) in your Region"

    t3 = get_email_theme_by_metrics(36.5, 84.0)
    assert t3["tier"] == "CRITICAL OUTBREAK"
    assert t3["header_bg"] == "#4A0E0E"
    s3, _ = build_arogya_drishti_email_html(
        "Ward 17", "0404400017", "Dr. Inderjit", 36.5, 14.0, 18.0, 180, 420, 66, 30.0, -0.1, 110.0, 84.0, "Emergency Fogging", 30.73, 76.77
    )
    assert s3 == "ArogyaDrishti - BI (36.5) in your Region"


def test_daily_cron_digest_sync() -> None:
    # Trigger on-demand daily digest & GEE sync endpoint
    r_cron = client.post("/api/v1/cron/daily-digest-and-gee-sync")
    assert r_cron.status_code == 200
    res = r_cron.json()
    assert res["status"] in (
        "DAILY_SYNC_COMPLETED",
        "MORNING_DIGESTS_DISPATCHED",
        "MORNING_FUSION_PIPELINE_COMPLETED",
        "NO_WARDS_FOUND",
    )
    assert "timestamp_utc" in res


def test_support_ticket_assignment_and_email_template() -> None:
    from app.tools.gmail_alert_tool.client import build_ticket_assignment_email_html

    subject, html = build_ticket_assignment_email_html(
        ticket_id="TICK-TEST-001",
        ward_name="Ward 17: Sector 22, Sector 23",
        category="Outbreak Cluster Flare-up",
        severity_sla="Critical (2h SLA)",
        observation_notes="High breeding index detected in coolers.",
        assigned_officer_name="Kunal Yadav",
        timestamp_utc="2026-10-22T12:00:00Z",
        lat=30.7333,
        lng=76.7794,
    )

    assert subject == "Ticket assigned to you - Arogya Drishti"
    assert "TICK-TEST-001" in html
    assert "Ward 17" in html
    assert "ArogyaDrishti App | Powered by Team Rocket" in html
    assert "#7F1D1D" in html  # Crimson header
    assert "google.com/maps" in html
    # Zero-blue color policy verification: no blue colors
    for blue_hex in ["#0000FF", "#1E40AF", "#2563EB", "#3B82F6", "#60A5FA", "#93C5FD"]:
        assert blue_hex not in html

    # Test POST /api/v1/support/tickets endpoint
    resp = client.post(
        "/api/v1/support/tickets",
        json={
            "ward_id": "0404400017",
            "ward_name": "Ward 17: Sector 22, Sector 23",
            "category": "Larval Stagnant Water Outbreak",
            "severity_sla": "Critical (2h SLA)",
            "observation_notes": "Larvae swarm observed in uncovered plastic drum.",
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "TICKET_CREATED"
    assert "ticket_id" in data
    assert data["ticket"]["assigned_nodal_officer"] is not None
    assert data["ticket"]["officer_email"] in ["academyxshivam@gmail.com", "chaudharyishwor143@gmail.com"]

    # Test Ward 1 (Wards 1-9 -> academyxshivam@gmail.com)
    r_w1 = client.post(
        "/api/v1/support/tickets",
        json={"ward_id": "0404400001", "ward_name": "Ward 1: Manimajra", "category": "Equipment"},
    )
    assert r_w1.status_code == 200
    assert r_w1.json()["ticket"]["officer_email"] in [
        "academyxshivam@gmail.com",
        "si.mpathak.mcc@chd.gov.in",
    ]

    # Test Ward 20 (universal district rep email or assigned sanitary inspector)
    r_w20 = client.post(
        "/api/v1/support/tickets",
        json={"ward_id": "0404400020", "ward_name": "Ward 20: Industrial Area Phase II", "category": "Equipment"},
    )
    assert r_w20.status_code == 200
    assert r_w20.json()["ticket"]["officer_email"] in [
        "academyxshivam@gmail.com",
        "si.sukhwinders.mcc@chd.gov.in",
        "chaudharyraul07@gmail.com",
    ]

    # Test Ward 30 (universal district rep email or assigned sanitary inspector)
    r_w30 = client.post(
        "/api/v1/support/tickets",
        json={"ward_id": "0404400030", "ward_name": "Ward 30: Sector 41", "category": "Equipment"},
    )
    assert r_w30.status_code == 200
    assert r_w30.json()["ticket"]["officer_email"] in [
        "academyxshivam@gmail.com",
        "si.jagdishc.mcc@chd.gov.in",
        "si.jkaur.mcc@chd.gov.in",
        "ay5589370@gmail.com",
    ]

    from app.tools.gmail_alert_tool.client import send_ward_operational_email
    assert callable(send_ward_operational_email)


def test_van_lifecycle_and_chemical_decrement() -> None:
    from app.tools.sheets_admin_tool.client import decrement_chemical_stock

    assert decrement_chemical_stock("Pyrethrum 2% Extract (40 L)", 5) == "Pyrethrum 2% Extract (35 L)"
    assert decrement_chemical_stock("Bti WP (30 kg)", 5) == "Bti WP (25 kg)"
    assert decrement_chemical_stock("Temephos 50% EC (4 L)", 5) == "Temephos 50% EC (0 L)"

    # Test PATCH /api/v1/vans/{van_id}/resolve endpoint
    resp = client.patch("/api/v1/vans/VAN-01/resolve?decrement_stock_amount=5")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "VAN_RESOLVED"
    assert data["van_id"] == "VAN-01"
    assert data["new_status"] == "Available"
