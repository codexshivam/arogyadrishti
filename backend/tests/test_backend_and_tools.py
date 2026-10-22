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
        e_gee=e_gee, ward_breteau_index=34.0, i_vision=0.92
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

    staff = sheets.lookup_authorized_staff("Sector 22-B", "04055001")
    assert staff.lgd_code == "04055001"
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
        lgd_code="04055001",
    )
    assert len(res.reply_text) > 20
    assert len(res.tool_cards) >= 1


def test_api_endpoints_end_to_end() -> None:
    # 1. Verify staff
    r_auth = client.post(
        "/api/v1/auth/verify-staff",
        json={"uid": "test_officer_01", "phone": "+919915549455"},
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

    r_contacts = client.get("/api/v1/contacts?district_lgd=04055001")
    assert r_contacts.status_code == 200
    assert r_contacts.json()["count"] >= 1

    r_stats = client.get("/api/v1/stats?lgd_code=04055001")
    assert r_stats.status_code == 200
    assert "weekly_trends" in r_stats.json()
    assert "ihip_fhir_observation_bundle" in r_stats.json()

    # 3. Public DPI Risk Index
    r_risk = client.get("/api/v1/risk-index?lat=30.7333&lng=76.7794&lgd_code=04055001")
    assert r_risk.status_code == 200
    risk_data = r_risk.json()
    assert risk_data["risk_tier"] in ("CRITICAL", "HIGH", "MODERATE", "LOW")
    assert "satellite_telemetry_gee" in risk_data

    # 4. Scan Breeding Site (multipart upload)
    img_bytes = _make_test_breeding_image()
    r_scan = client.post(
        "/api/v1/scan-breeding-site",
        data={"lat": "30.7333", "lng": "76.7794", "ward_lgd": "04055001"},
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
            "uid": "officer_kunal_04055001",
            "message": "Found 14 discarded tires with stagnant rainwater in Sector 22-B. What is the immediate protocol?",
            "ward_village": "Sector 22-B",
            "lgd_code": "04055001",
            "latitude": 30.7333,
            "longitude": 76.7794,
        },
    )
    assert r_chat.status_code == 200
    assert len(r_chat.json()["tool_cards"]) >= 1
