"""Tests for:
1. OAG Anti-Spoofing (64-bit dHash, PostGIS 150m Buffered Geofence, Impossible Velocity, FCHV Attendance Sheet)
2. Urban Utility Risk Modifiers (KUKL Water Rationing & Solid Waste Collection Lag)
3. Monsoon Surge GPU Circuit Breaker (HTTP 202 Fallback), PostGIS ST_AsMVT Vector Tiles & ETag Delta Sync
4. Kathmandu <-> Hetauda Seismic DR Read-Replica Routing & OCC PKCS#7 Digital Signatures
5. ITU/WMO CAP 1.2 Mass-Alert XML Feed & NHRC De-Identified Research Export API
"""

from __future__ import annotations

import io
import xml.etree.ElementTree as ET

import pytest
from httpx import AsyncClient
from PIL import Image, ImageDraw

from app.services.auth_service import get_dev_last_otp
from app.services.gpu_circuit_breaker import get_gpu_circuit_breaker


async def _login_as(client: AsyncClient, phone: str) -> dict[str, str]:
    await client.post("/api/v1/auth/request-otp", json={"phone": phone})
    otp = get_dev_last_otp(phone)
    assert otp is not None
    ver = await client.post(
        "/api/v1/auth/verify-otp", json={"phone": phone, "otp": otp}
    )
    assert ver.status_code == 200
    return {"Authorization": f"Bearer {ver.json()['access_token']}"}


def _make_distinct_test_jpeg(pattern_variant: int = 1) -> bytes:
    """Create a synthetic breeding-site JPEG with a distinct spatial luminance pattern for 64-bit dHash."""
    img = Image.new("RGB", (96, 96), color=(20, 40, 60))
    draw = ImageDraw.Draw(img)
    if pattern_variant == 1:
        # Left-to-right bright diagonal stripes
        for i in range(0, 96, 12):
            draw.rectangle([i, 0, i + 5, 96], fill=(240, 220, 180))
    else:
        # Top-left checkerboard blocks
        for y in range(0, 96, 24):
            for x in range(0, 96, 24):
                if ((x // 24) + (y // 24)) % 2 == 0:
                    draw.rectangle([x, y, x + 18, y + 18], fill=(250, 250, 250))
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=92)
    return buf.getvalue()


@pytest.mark.asyncio
async def test_oag_anti_spoofing_phash_geofence_velocity_and_fchv_sheet(
    client: AsyncClient,
) -> None:
    """Test 64-bit dHash recycled photo rejection, PostGIS 150m geofence, velocity quarantine & OAG FCHV sheet."""
    get_gpu_circuit_breaker().set_telemetry(vram_utilization_pct=40.0, gpu_node_online=True)
    fchv_headers = await _login_as(client, "+9779841000017")

    # 1. First upload of breeding-site photo succeeds (200 OK)
    img_bytes_1 = _make_distinct_test_jpeg(pattern_variant=1)
    scan1 = await client.post(
        "/api/v1/scan-breeding-site",
        headers=fchv_headers,
        files={"image": ("tire1.jpg", img_bytes_1, "image/jpeg")},
        data={"composite_ward_id": "NP-P3-D27-30608-W17"},
    )
    assert scan1.status_code == 200

    # 2. Re-uploading the exact/near-identical photo is rejected by 64-bit dHash (Hamming <= 8)
    scan_dup = await client.post(
        "/api/v1/scan-breeding-site",
        headers=fchv_headers,
        files={"image": ("whatsapp_resaved.jpg", img_bytes_1, "image/jpeg")},
        data={"composite_ward_id": "NP-P3-D27-30608-W17"},
    )
    assert scan_dup.status_code == 422
    assert "OAG Anti-Spoofing Violation" in str(scan_dup.json())

    # 3. Genuine field inspection inside Ward 17 geofence (27.7124, 85.3065) -> CREATED
    valid_insp = await client.post(
        "/api/v1/inspections",
        headers=fchv_headers,
        json={
            "client_submission_uuid": "uuid-oag-genuine-001",
            "composite_ward_id": "NP-P3-D27-30608-W17",
            "houses_inspected": 8,
            "houses_infested": 2,
            "wet_containers_inspected": 16,
            "positive_containers": 3,
            "latitude": 27.7124,
            "longitude": 85.3065,
        },
    )
    assert valid_insp.status_code == 201
    assert valid_insp.json()["status"] == "CREATED"

    # 4. Desk-reporting / Impossible-velocity spoof: logging 25 houses 1 second later from identical GPS
    velocity_spoof = await client.post(
        "/api/v1/inspections",
        headers=fchv_headers,
        json={
            "client_submission_uuid": "uuid-oag-velocity-spoof-002",
            "composite_ward_id": "NP-P3-D27-30608-W17",
            "houses_inspected": 25,
            "houses_infested": 5,
            "wet_containers_inspected": 40,
            "positive_containers": 10,
            "latitude": 27.7124,
            "longitude": 85.3065,
        },
    )
    assert velocity_spoof.status_code == 201
    assert velocity_spoof.json()["status"] == "QUARANTINED_SUPERVISOR_REVIEW"
    assert "Desk-Reporting Velocity Anomaly" in (
        velocity_spoof.json()["spoof_quarantine_reason"] or ""
    )

    # 5. Geofence spoof: submitting for Ward 17 while physically far outside Ward 17 (e.g., Bhaktapur 27.6710, 85.4298)
    geofence_spoof = await client.post(
        "/api/v1/inspections",
        headers=fchv_headers,
        json={
            "client_submission_uuid": "uuid-oag-geofence-spoof-003",
            "composite_ward_id": "NP-P3-D27-30608-W17",
            "houses_inspected": 5,
            "houses_infested": 1,
            "wet_containers_inspected": 10,
            "positive_containers": 2,
            "latitude": 27.6710,
            "longitude": 85.4298,
        },
    )
    assert geofence_spoof.status_code == 201
    assert geofence_spoof.json()["status"] == "QUARANTINED_SUPERVISOR_REVIEW"
    assert "ST_Contains(ward_geom_buffered_150m" in (
        geofence_spoof.json()["spoof_quarantine_reason"] or ""
    )

    # 6. Verify Supervisor Review Queue & OAG Verified FCHV Attendance Sheet
    chief_headers = await _login_as(client, "+9779851130608")
    q_resp = await client.get(
        "/api/v1/oag-audit/supervisor-queue?palika_code=30608", headers=chief_headers
    )
    assert q_resp.status_code == 200
    assert q_resp.json()["quarantined_count"] >= 2

    oag_resp = await client.get(
        "/api/v1/oag-audit/fchv-attendance/30608", headers=chief_headers
    )
    assert oag_resp.status_code == 200
    oag_body = oag_resp.json()
    assert "Office of the Auditor General" in oag_body["audit_authority"]
    assert len(oag_body["oag_sha256_integrity_digest"]) == 64
    w17_fchv = next(
        r for r in oag_body["staff_attendance_rows"] if r["staff_id"] == "staff-fchv-kmc-w17"
    )
    assert w17_fchv["geofence_verified_submissions"] == 1
    assert w17_fchv["quarantined_spoof_attempts"] == 2
    assert w17_fchv["oag_verified_allowance_npr"] > 0


@pytest.mark.asyncio
async def test_urban_utility_water_rationing_and_waste_lag_modifiers(
    client: AsyncClient,
) -> None:
    """Test KUKL piped water rationing interval & monsoon waste lag container-storage risk modifier."""
    chief_headers = await _login_as(client, "+9779851130608")
    resp = await client.put(
        "/api/v1/wards/NP-P3-D27-30608-W10/infrastructure-profile",
        headers=chief_headers,
        json={
            "water_supply_interval_days": 7,
            "waste_collection_lag_days": 5,
            "utility_provider": "KUKL Baneshwor Branch",
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["utility_storage_multiplier"] >= 1.25
    assert body["adjusted_composite_risk"] > body["previous_composite_risk"]


@pytest.mark.asyncio
async def test_monsoon_gpu_circuit_breaker_mvt_tiles_and_delta_sync(
    client: AsyncClient,
) -> None:
    """Test GPU Circuit Breaker (HTTP 202 fallback), PostGIS ST_AsMVT binary tiles & ETag delta sync."""
    chief_headers = await _login_as(client, "+9779851130608")
    fchv_headers = await _login_as(client, "+9779841000017")

    # 1. Trip GPU Circuit Breaker by setting VRAM utilization to 94.5% (>= 90% threshold)
    cb_resp = await client.post(
        "/api/v1/system/gpu-circuit-breaker",
        headers=chief_headers,
        json={
            "vram_utilization_pct": 94.5,
            "gpu_node_online": True,
            "consecutive_failures": 0,
        },
    )
    assert cb_resp.status_code == 200
    assert cb_resp.json()["circuit_state"] == "OPEN"

    try:
        # 2. Upload distinct image while circuit breaker is OPEN -> HTTP 202 Accepted immediately
        img_bytes_2 = _make_distinct_test_jpeg(pattern_variant=2)
        surge_resp = await client.post(
            "/api/v1/scan-breeding-site",
            headers=fchv_headers,
            files={"image": ("surge_tire.jpg", img_bytes_2, "image/jpeg")},
            data={"composite_ward_id": "NP-P3-D27-30608-W17"},
        )
        assert surge_resp.status_code == 202
        surge_body = surge_resp.json()
        assert surge_body["status"] == "QUEUED_CIRCUIT_BREAKER_202"
        assert surge_body["circuit_state"] == "OPEN"
        assert "Bti" in surge_body["recommended_larvicide"]

        # Poll job status
        job_id = surge_body["job_id"]
        job_resp = await client.get(
            f"/api/v1/inspections/vision-jobs/{job_id}", headers=fchv_headers
        )
        assert job_resp.status_code == 200
        assert job_resp.json()["job_id"] == job_id
    finally:
        # Reset circuit breaker back to normal (42% VRAM)
        get_gpu_circuit_breaker().set_telemetry(
            vram_utilization_pct=42.0, gpu_node_online=True
        )

    # 3. PostGIS ST_AsMVT binary Mapbox Vector Tile endpoint
    mvt_resp = await client.get("/api/v1/gis/tiles/12/3018/1725.mvt?palika_code=30608")
    assert mvt_resp.status_code == 200
    assert mvt_resp.headers["content-type"] == "application/vnd.mapbox-vector-tile"
    assert b"nepal_wards" in mvt_resp.content

    # 4. Rural 3G Delta Sync (< 15 KB) + ETag 304 Not Modified
    delta_resp = await client.get("/api/v1/wards/delta-sync?palika_code=30608")
    assert delta_resp.status_code == 200
    assert len(delta_resp.content) < 15 * 1024
    etag = delta_resp.headers["etag"]

    cached_resp = await client.get(
        "/api/v1/wards/delta-sync?palika_code=30608",
        headers={"If-None-Match": etag},
    )
    assert cached_resp.status_code == 304


@pytest.mark.asyncio
async def test_hetauda_dr_status_occ_digital_signature_cap_xml_and_nhrc_export(
    client: AsyncClient,
) -> None:
    """Test Hetauda DR read-replica status, OCC PKCS#7 signature, CAP 1.2 XML feed & NHRC export."""
    chief_headers = await _login_as(client, "+9779851130608")

    # 1. Kathmandu <-> Hetauda DR Status
    dr_resp = await client.get("/api/v1/system/dr-status", headers=chief_headers)
    assert dr_resp.status_code == 200
    dr_body = dr_resp.json()
    assert dr_body["read_replica_routing_active"] is True
    assert dr_body["target_rpo_minutes"] == 5

    # 2. OCC Digital Signature (Electronic Transactions Act 2063) PKCS#7 manifest & PDF trailer
    sig_resp = await client.post(
        "/api/v1/palika/30608/gioms-tippani-sign",
        headers=chief_headers,
        json={"occ_token_serial": "OCC-NP-G3-TOKEN-2083-7788"},
    )
    assert sig_resp.status_code == 200
    sig_body = sig_resp.json()
    assert sig_body["pdf_subfilter"] == "/adbe.pkcs7.detached"
    assert "Office of the Controller of Certification" in sig_body["certification_authority"]

    pdf_resp = await client.get(
        "/api/v1/palika/30608/gioms-tippani-pdf", headers=chief_headers
    )
    assert pdf_resp.status_code == 200
    assert b"/SubFilter /adbe.pkcs7.detached" in pdf_resp.content

    # 3. ITU/WMO CAP 1.2 Mass-Alert XML Feed
    cap_resp = await client.get("/api/v1/cap/alerts.xml?palika_code=30608")
    assert cap_resp.status_code == 200
    assert "application/xml" in cap_resp.headers["content-type"]
    root = ET.fromstring(cap_resp.text)
    assert root.tag == "{urn:oasis:names:tc:emergency:cap:1.2}alert"
    assert "डेंगु" in cap_resp.text
    assert "1115" in cap_resp.text

    # 4. NHRC De-Identified Research Export (403 without key, 200 with valid NHRC key)
    unauth_nhrc = await client.get("/api/v1/research/anonymized-dataset?palika_code=30608")
    assert unauth_nhrc.status_code == 403

    csv_nhrc = await client.get(
        "/api/v1/research/anonymized-dataset?palika_code=30608&export_format=csv",
        headers={"X-NHRC-Research-Key": "nhrc-nepal-ethics-2083-key"},  # gitleaks:allow
    )
    assert csv_nhrc.status_code == 200
    assert "NHRC_DEIDENTIFIED_500M_JITTER_ZERO_PII" in csv_nhrc.text
    assert "jittered_lat_500m" in csv_nhrc.text


@pytest.mark.asyncio
async def test_six_pillars_mock_gps_block_st_dwithin_enc_sms_outbreak_brief_and_it_helpdesk(
    client: AsyncClient,
) -> None:
    """
    Test all 6 Sovereign Field & Executive Pillars end-to-end:
    1. Mock GPS & Device Time-Tamper Hard Block (HTTP 422) + PostGIS ST_DWithin(100m) Household Anchor + Cryptographic EXIF Signature.
    2. Karnali Standard >24h Encrypted SMS Token (`ENC31115:...`) via Sparrow/Aakash SMS gateway.
    3. Dual BS Devanagari & Gregorian AD official label (`२०८३ ... | YYYY-MM-DD`).
    4. 1-Tap Singha Durbar GIOMS 'Official Ward Outbreak Brief' PDF & Client-to-Server Blockchain Audit Mirror.
    5. Direct 1-Tap Frontline Worker Escalation to Palika IT Officer.
    """
    from app.api.v1.sms_gateway import encode_encrypted_sms_token

    fchv_headers = await _login_as(client, "+9779841000017")
    chief_headers = await _login_as(client, "+9779851130608")

    # Pillar 1A: Mock GPS location app detected -> HTTP 422 Hard Block
    mock_gps_resp = await client.post(
        "/api/v1/inspections",
        headers=fchv_headers,
        json={
            "client_submission_uuid": "uuid-mock-gps-blocked-001",
            "composite_ward_id": "NP-P3-D27-30608-W17",
            "houses_inspected": 10,
            "houses_infested": 2,
            "wet_containers_inspected": 20,
            "positive_containers": 4,
            "latitude": 27.7124,
            "longitude": 85.3065,
            "is_mock_location_detected": True,
        },
    )
    assert mock_gps_resp.status_code == 422
    assert "Fake GPS / Mock Location App detected" in str(mock_gps_resp.json())

    # Pillar 1B: Device clock manually tampered -> HTTP 422 Hard Block
    time_tamper_resp = await client.post(
        "/api/v1/inspections",
        headers=fchv_headers,
        json={
            "client_submission_uuid": "uuid-time-tamper-blocked-002",
            "composite_ward_id": "NP-P3-D27-30608-W17",
            "houses_inspected": 10,
            "houses_infested": 2,
            "wet_containers_inspected": 20,
            "positive_containers": 4,
            "latitude": 27.7124,
            "longitude": 85.3065,
            "is_device_time_tampered": True,
            "device_clock_drift_seconds": 950.0,
        },
    )
    assert time_tamper_resp.status_code == 422
    assert "Device system time manually modified" in str(time_tamper_resp.json())

    # Pillar 1C: PostGIS ST_DWithin(100m) Household Anchor check (> 100m away from reported household)
    dwithin_spoof = await client.post(
        "/api/v1/inspections",
        headers=fchv_headers,
        json={
            "client_submission_uuid": "uuid-dwithin-100m-violation-003",
            "composite_ward_id": "NP-P3-D27-30608-W17",
            "houses_inspected": 6,
            "houses_infested": 1,
            "wet_containers_inspected": 12,
            "positive_containers": 2,
            "latitude": 27.7124,
            "longitude": 85.3065,
            "target_household_lat": 27.7155,
            "target_household_lng": 85.3065,
        },
    )
    assert dwithin_spoof.status_code == 201
    assert dwithin_spoof.json()["status"] == "QUARANTINED_SUPERVISOR_REVIEW"
    assert "ST_DWithin(household_anchor, gps_point, 100.0m) failed" in (
        dwithin_spoof.json()["spoof_quarantine_reason"] or ""
    )

    # Pillar 2: Karnali Standard Encrypted >24h SMS Token (`ENC31115:...`) via Dual-SIM
    enc_token = encode_encrypted_sms_token(
        composite_ward_id="NP-P3-D27-30608-W17",
        houses_inspected=28,
        positive_containers=9,
        rdt_positive=2,
    )
    assert enc_token.startswith("ENC31115:")
    sms_enc_resp = await client.post(
        "/api/v1/webhooks/sms-ingest",
        json={
            "sender_phone": "+9779841000017",
            "shortcode": "31115",
            "sms_text": enc_token,
            "telecom_provider": "SPARROW_SMS",
            "sim_slot_carrier": "NCELL_SIM2",
        },
    )
    assert sms_enc_resp.status_code == 200
    sms_body = sms_enc_resp.json()
    assert sms_body["status"] == "INGESTED"
    assert sms_body["parsed_houses_inspected"] == 28
    assert sms_body["parsed_positive_containers"] == 9
    assert sms_body["disease_flag"] == "ENC31115_24H_URGENT_SYNC"
    assert "|" in sms_body["bs_ad_official_label"]

    # Pillar 4A: 1-Tap "Generate Official Ward Outbreak Brief" (Singha Durbar GIOMS Tippani)
    brief_resp = await client.post(
        "/api/v1/palika/wards/NP-P3-D27-30608-W17/outbreak-brief",
        headers=chief_headers,
    )
    assert brief_resp.status_code == 200
    brief_body = brief_resp.json()
    assert brief_body["cao_tippani_reference_no"].startswith("GIOMS-OUTBREAK-")
    assert brief_body["bti_kilograms_required"] > 0
    assert "|" in brief_body["bs_ad_official_label"]

    brief_pdf = await client.get(
        "/api/v1/palika/wards/NP-P3-D27-30608-W17/outbreak-brief-pdf",
        headers=chief_headers,
    )
    assert brief_pdf.status_code == 200
    assert brief_pdf.headers["content-type"] == "application/pdf"
    assert b"%OCC-NEPAL-ET-ACT-2063-WARD-OUTBREAK-BRIEF-PKCS7" in brief_pdf.content

    # Pillar 4B: Client-to-Server Tamper-Evident Audit Chain Mirror & Verification
    mirror_resp = await client.post(
        "/api/v1/oag-audit/mirror-client-chain",
        headers=chief_headers,
        json={
            "client_entry_id": "client-seq-004",
            "action_type": "RRT_VAN_DISPATCHED",
            "target_resource_id": "RRT-KMC-01->NP-P3-D27-30608-W17",
            "prev_hash": "a" * 64,
            "entry_hash": "b" * 64,
            "payload_summary": {"vehicle_id": "RRT-KMC-01", "bti_kg": 28.5},
        },
    )
    assert mirror_resp.status_code == 200
    assert mirror_resp.json()["status"] == "MIRRORED_TO_IDMC_WORM_LEDGER"

    verify_chain_resp = await client.get(
        "/api/v1/oag-audit/verify-chain", headers=chief_headers
    )
    assert verify_chain_resp.status_code == 200
    assert verify_chain_resp.json()["valid"] is True

    # Pillar 6: 1-Tap Frontline Worker Escalation & Feedback to Palika IT Officer
    it_resp = await client.post(
        "/api/v1/palika/it-feedback",
        headers=fchv_headers,
        json={
            "composite_ward_id": "NP-P3-D27-30608-W17",
            "issue_category": "GPS_WARD_BOUNDARY_DISCREPANCY",
            "description": "Courtyard boundary near Chhetrapati Bahal needs 20m polygon adjustment.",
            "device_model": "Redmi 12C (4GB RAM)",
        },
    )
    assert it_resp.status_code == 201
    it_body = it_resp.json()
    assert it_body["status"] == "ROUTED_TO_PALIKA_IT_OFFICER"
    assert "सूचना प्रविधि अधिकृत" in it_body["acknowledgement_ne"]


@pytest.mark.asyncio
async def test_military_grade_vault_mtls_aes256_rotation_and_wazuh_soc_pipeline(
    client: AsyncClient,
) -> None:
    """
    Verify all 4 Military-Grade DevSecOps & SOC Pillars:
    1. HashiCorp Vault: Zero static .env in production + 60-minute (3600s) ephemeral PostgreSQL DB leases.
    2. In-Transit & At-Rest Encryption: TLS 1.3 only + mTLS (CERT_REQUIRED) across FastAPI/PostGIS/vLLM,
       and rotating Master Key AES-256-GCM re-encrypting inspector phone numbers at the application level.
    3. Wazuh 24/7 SIEM SOC: Pokhara Ward Health Officer attempting login from a Kathmandu IP 50x in 1 min
       automatically blacklists the IP (HTTP 403), revokes their JWT (HTTP 401), and alerts DoIT SysAdmin.
    4. DevSecOps CI/CD Pipeline configs (.github/workflows/devsecops.yml & .gitlab-ci.yml) include Bandit,
       SonarQube, and Trivy.
    """
    from pathlib import Path

    from sqlalchemy import select

    from app.core.security import decrypt_field_aes256gcm, extract_token_key_id
    from app.db.models import StaffUser
    from app.db.session import get_session_factory

    chief_headers = await _login_as(client, "+9779851130608")

    # 1. HashiCorp Vault 60-Minute Ephemeral DB Credentials & Zero-.env Policy
    vault_resp = await client.get(
        "/api/v1/security/vault-lease-status", headers=chief_headers
    )
    assert vault_resp.status_code == 200
    v_body = vault_resp.json()
    assert v_body["ephemeral_db_credentials_ttl_seconds"] == 3600
    assert v_body["ephemeral_db_credentials_ttl_minutes"] == 60
    assert v_body["zero_dotenv_policy"]["static_dotenv_mounted_in_prod"] is False
    first_lease_id = v_body["active_database_lease"]["lease_id"]
    first_user = v_body["active_database_lease"]["ephemeral_username"]
    assert first_user.startswith("v_mohp_")

    rot_vault_resp = await client.post(
        "/api/v1/security/vault-rotate-db-lease", headers=chief_headers
    )
    assert rot_vault_resp.status_code == 200
    rot_v_body = rot_vault_resp.json()
    assert rot_v_body["active_database_lease"]["lease_id"] != first_lease_id
    assert rot_v_body["active_database_lease"]["lease_duration_seconds"] == 3600

    # 2A. TLS 1.3 Only + Mutual TLS (mTLS) Mesh Verification
    mtls_resp = await client.get(
        "/api/v1/security/mtls-tls13-status", headers=chief_headers
    )
    assert mtls_resp.status_code == 200
    mtls_body = mtls_resp.json()["in_transit_security"]
    assert mtls_body["tls_protocol_enforced"] == "TLSv1.3_ONLY"
    assert mtls_body["minimum_tls_version"] == "TLSv1_3"
    assert mtls_body["maximum_tls_version"] == "TLSv1_3"
    assert mtls_body["legacy_tls_1_0_1_1_1_2_disabled"] is True
    assert mtls_body["mtls_peer_certificate_required"] is True

    # 2B. Rotating Master Key AES-256-GCM Column Re-Encryption on Inspector Phone Numbers
    rot_key_resp = await client.post(
        "/api/v1/security/rotate-master-key",
        headers=chief_headers,
        json={"reason": "OAG_ANNUAL_CRYPTOGRAPHIC_KEY_ROTATION"},
    )
    assert rot_key_resp.status_code == 200
    rk_body = rot_key_resp.json()
    new_kid = rk_body["active_kid"]
    assert new_kid.startswith("mk-2083-v")
    assert rk_body["rewrapped_staff_phone_rows"] >= 7

    factory = get_session_factory()
    async with factory() as session:
        sita = (
            await session.execute(
                select(StaffUser).where(StaffUser.id == "staff-fchv-kmc-w17")
            )
        ).scalar_one()
        assert sita.phone_encrypted.startswith(f"v2:{new_kid}:")
        assert extract_token_key_id(sita.phone_encrypted) == new_kid
        assert decrypt_field_aes256gcm(sita.phone_encrypted) == "+9779841000017"

    # 3. Wazuh 24/7 SIEM SOC: Ward Health Officer from Pokhara attacked from Kathmandu IP 50x in 1 min
    who_headers = await _login_as(client, "+9779851000303")
    me_before = await client.get("/api/v1/auth/me", headers=who_headers)
    assert me_before.status_code == 200

    attacker_kathmandu_ip = "202.45.144.99"
    wazuh_resp = await client.post(
        "/api/v1/security/wazuh-soc/evaluate-login-event",
        headers=chief_headers,
        json={
            "staff_id": "staff-who-lmc-w03",
            "staff_role": "WARD_HEALTH_OFFICER",
            "client_ip": attacker_kathmandu_ip,
            "origin_city": "Pokhara",
            "attempt_city": "Kathmandu",
            "attempts_in_last_minute": 50,
            "elapsed_minutes_since_origin_login": 1.0,
        },
    )
    assert wazuh_resp.status_code == 200
    w_body = wazuh_resp.json()
    assert w_body["anomaly_detected"] is True
    assert w_body["ip_blacklisted"] is True
    assert w_body["blacklisted_ip"] == attacker_kathmandu_ip
    assert w_body["jwt_revoked"] is True
    assert w_body["doit_sysadmin_alerted"] is True
    assert w_body["wazuh_alert"]["rule"]["level"] == 15

    # Verify the compromised officer's JWT is immediately revoked (HTTP 401)
    me_after = await client.get("/api/v1/auth/me", headers=who_headers)
    assert me_after.status_code == 401

    # Verify any request from the blacklisted Kathmandu IP is blocked with HTTP 403
    blocked_req = await client.get(
        "/healthz", headers={"X-Forwarded-For": attacker_kathmandu_ip}
    )
    assert blocked_req.status_code == 403
    assert "Wazuh 24/7 SOC Active Response" in blocked_req.text

    # 4. Verify DevSecOps SAST/DAST CI/CD Pipeline configs (Bandit, SonarQube, Trivy)
    repo_root = Path(__file__).resolve().parents[2]
    gh_workflow = (repo_root / ".github" / "workflows" / "devsecops.yml").read_text()
    gitlab_ci = (repo_root / ".gitlab-ci.yml").read_text()
    for tool_marker in ("bandit", "sonarqube", "trivy"):
        assert tool_marker in gh_workflow.lower()
        assert tool_marker in gitlab_ci.lower()


@pytest.mark.asyncio
async def test_citizen_transparency_portal_read_only_sanitized_dashboard(
    client: AsyncClient,
) -> None:
    """
    Verify the read-only Citizen Transparency Portal (`citizen.nidaniq.com.np`):
    - Accessible publicly without authentication.
    - Displays '1,420 Breeding Sites Neutralized This Month' and 'Current Ward Safety Status'.
    - Strips 100% of sensitive fields (inspector IDs, phone numbers, exact household GPS, vehicle plates).
    - Serves interactive HTML5 dashboard at `/citizen-portal` and `/api/v1/public/citizen-transparency/portal.html`.
    """
    from pathlib import Path

    from app.services.citizen_transparency_service import STRIPPED_SENSITIVE_FIELDS

    # 1. Public JSON API (no auth headers required)
    resp = await client.get("/api/v1/public/citizen-transparency?palika_code=30608")
    assert resp.status_code == 200
    body = resp.json()
    assert body["portal_domain"] == "citizen.nidaniq.com.np"
    assert body["access_mode"] == "READ_ONLY_PUBLIC_SANITIZED"
    assert "1,420 Breeding Sites Neutralized This Month" in body["headline_banner_en"]
    assert body["breeding_sites_neutralized_this_month"] >= 1420
    assert body["current_ward_safety_header_en"] == "Current Ward Safety Status"
    assert len(body["wards"]) >= 6

    # Ensure zero sensitive fields leak anywhere in the ward cards
    for ward_item in body["wards"]:
        assert "current_ward_safety_status" in ward_item
        assert "breeding_sites_neutralized_this_month" in ward_item
        for forbidden_key in STRIPPED_SENSITIVE_FIELDS:
            assert forbidden_key not in ward_item

    # 2. Interactive HTML5 Web Dashboard (`/citizen-portal`)
    html_resp = await client.get("/citizen-portal")
    assert html_resp.status_code == 200
    assert "text/html" in html_resp.headers["content-type"]
    assert html_resp.headers["x-portal-domain"] == "citizen.nidaniq.com.np"
    html_text = html_resp.text
    assert "1,420 Breeding Sites Neutralized This Month" in html_text
    assert "Current Ward Safety Status" in html_text
    assert "citizen.nidaniq.com.np" in html_text

    # 3. Standalone static web bundle (`citizen_portal/index.html`)
    repo_root = Path(__file__).resolve().parents[2]
    static_html = (repo_root / "citizen_portal" / "index.html").read_text(encoding="utf-8")
    assert "1,420 Breeding Sites Neutralized This Month" in static_html
    assert "Current Ward Safety Status" in static_html


@pytest.mark.asyncio
async def test_hybrid_phone_auth_zero_cost_email_verification_rate_limit_and_worm_audit(
    client: AsyncClient,
) -> None:
    """
    Verify Architecture Directive: Zero-Cost Notifications & Hybrid Authentication:
    1. Auth endpoints (`/api/v1/auth/request-otp` & `/verify-otp`) strictly accept +977 Phone ONLY
       and reject email login payloads (`HTTP 422`).
    2. `POST /api/v1/users/me/email` links email (`is_email_verified = False`), sends 6-digit SMTP OTP,
       and enforces max 3 requests per hour per user (`HTTP 429` on 4th request).
    3. `POST /api/v1/users/me/email/verify` validates the 15-minute TTL Email OTP, sets
       `is_email_verified = True`, and writes a WORM `audit_logs` record (`ACTION: EMAIL_VERIFIED`).
    4. `NotificationService` routes `SLA_BREACH`, `RRT_DISPATCHED`, and `DAILY_RISK_REPORT` via
       HTML Email (with Bikram Sambat date & Nepal Gov branding) ONLY when `is_email_verified == True`,
       and NEVER invokes the Sparrow/Aakash SMS gateway (`sms_gateway_used == False`).
    """
    from sqlalchemy import select

    from app.db.models import WormAuditLog
    from app.db.session import get_session_factory
    from app.services.notification_service import (
        get_dev_last_email_otp,
        get_dispatched_email_outbox,
    )

    # 1. Reject Email Login on `/api/v1/auth/request-otp`
    bad_email_login = await client.post(
        "/api/v1/auth/request-otp",
        json={"email": "doc@kmc.gov.np", "phone": "+9779851130608"},
    )
    assert bad_email_login.status_code == 422

    bad_email_as_phone = await client.post(
        "/api/v1/auth/request-otp",
        json={"phone": "doc@kmc.gov.np"},
    )
    assert bad_email_as_phone.status_code == 422

    # Login via +977 Phone OTP as Palika Health Chief (`staff-chief-kmc-30608`)
    chief_headers = await _login_as(client, "+9779851130608")

    # 2. Before linking email, system alerts route to IN_APP_PUSH only (Zero Email, Zero SMS)
    pre_alert = await client.post(
        "/api/v1/users/me/notifications/route-event",
        headers=chief_headers,
        json={
            "event_type": "SLA_BREACH",
            "title_en": "Ward 17 Escalation SLA Breach (48h)",
            "title_ne": "वडा १७ गुनासो ४८ घण्टा म्याद नाघ्यो",
            "summary_en": "Immediate action required on Ward 17 larval hotspot.",
            "summary_ne": "वडा १७ मा तत्काल लार्भा नष्ट कार्य आवश्यक।",
        },
    )
    assert pre_alert.status_code == 200
    pre_body = pre_alert.json()
    assert pre_body["email_dispatched"] is False
    assert pre_body["routed_channels"] == ["IN_APP_PUSH"]
    assert pre_body["sms_gateway_used"] is False
    assert pre_body["sms_cost_npr"] == 0.0

    # 3. Link Official Email (`POST /api/v1/users/me/email`)
    link_resp = await client.post(
        "/api/v1/users/me/email",
        headers=chief_headers,
        json={"email": "doc@kmc.gov.np"},
    )
    assert link_resp.status_code == 200
    l_body = link_resp.json()
    assert l_body["email"] == "doc@kmc.gov.np"
    assert l_body["is_email_verified"] is False
    assert l_body["ttl_seconds"] == 900

    email_otp = get_dev_last_email_otp("staff-chief-kmc-30608")
    assert email_otp is not None and len(email_otp) == 6

    # Verify unverified email still does NOT receive system alert emails
    unverified_alert = await client.post(
        "/api/v1/users/me/notifications/route-event",
        headers=chief_headers,
        json={"event_type": "DAILY_RISK_REPORT"},
    )
    assert unverified_alert.status_code == 200
    assert unverified_alert.json()["email_dispatched"] is False
    assert unverified_alert.json()["email_skip_reason"] == "EMAIL_NOT_VERIFIED"

    # 4. Verify Email OTP (`POST /api/v1/users/me/email/verify`)
    ver_resp = await client.post(
        "/api/v1/users/me/email/verify",
        headers=chief_headers,
        json={"email_otp": email_otp},
    )
    assert ver_resp.status_code == 200
    v_body = ver_resp.json()
    assert v_body["status"] == "EMAIL_VERIFIED"
    assert v_body["email"] == "doc@kmc.gov.np"
    assert v_body["is_email_verified"] is True

    # Confirm WORM audit ledger recorded `"ACTION": "EMAIL_VERIFIED"`
    factory = get_session_factory()
    async with factory() as session:
        audit_row = (
            await session.execute(
                select(WormAuditLog)
                .where(WormAuditLog.event_type == "EMAIL_VERIFIED")
                .order_by(WormAuditLog.seq_id.desc())
                .limit(1)
            )
        ).scalar_one()
        assert '"ACTION":"EMAIL_VERIFIED"' in audit_row.canonical_payload
        assert '"NEW_VALUE":"doc@kmc.gov.np"' in audit_row.canonical_payload

    # 5. Now that `is_email_verified == True`, system events route via HTML Email + In-App Push (Zero SMS)
    post_alert = await client.post(
        "/api/v1/users/me/notifications/route-event",
        headers=chief_headers,
        json={
            "event_type": "RRT_DISPATCHED",
            "title_en": "RRT Van BA-2-JHA-4101 Dispatched to Ward 17",
            "title_ne": "वडा १७ मा RRT भ्यान परिचालन",
            "summary_en": "Bti biological larviciding initiated.",
            "summary_ne": "जैविक Bti लार्भिसाइड अभियान सुरु।",
        },
    )
    assert post_alert.status_code == 200
    post_body = post_alert.json()
    assert post_body["email_dispatched"] is True
    assert post_body["routed_channels"] == ["SMTP_EMAIL", "IN_APP_PUSH"]
    assert post_body["sms_gateway_used"] is False
    assert post_body["sms_cost_npr"] == 0.0

    outbox = get_dispatched_email_outbox()
    assert len(outbox) >= 2
    latest_email = outbox[-1]
    assert latest_email["to_email"] == "doc@kmc.gov.np"
    assert latest_email["sms_gateway_used"] is False
    assert "नेपाल सरकार" in latest_email["html_body"]
    assert "२०८३" in latest_email["html_body"]

    # 6. Anti-Spam Sliding-Window Rate Limit: max 3 `POST /api/v1/users/me/email` per hour per user
    req2 = await client.post(
        "/api/v1/users/me/email",
        headers=chief_headers,
        json={"email": "doc2@kmc.gov.np"},
    )
    assert req2.status_code == 200
    req3 = await client.post(
        "/api/v1/users/me/email",
        headers=chief_headers,
        json={"email": "doc3@kmc.gov.np"},
    )
    assert req3.status_code == 200
    req4_blocked = await client.post(
        "/api/v1/users/me/email",
        headers=chief_headers,
        json={"email": "doc4@kmc.gov.np"},
    )
    assert req4_blocked.status_code == 429
    assert (
        req4_blocked.json()["detail"]["error"] == "EMAIL_OTP_RATE_LIMIT_EXCEEDED"
    )


@pytest.mark.asyncio
async def test_dynamic_spatial_context_location_aware_routing_and_15m_isr_cache(
    client: AsyncClient,
) -> None:
    """
    Verify Architecture Directive: Dynamic Spatial Context & Location-Aware Routing:
    1. `GET /api/v1/spatial/resolve?lat={lat}&lng={lng}` resolves Pokhara (`28.2096, 83.9595`)
       to `NP-P4-D40-40307-W06` (`पोखरा महानगरपालिका`), Bharatpur/Chitwan (`27.6833, 84.4333`)
       to `NP-P3-D35-30902-W10` (`भरतपुर महानगरपालिका`), and KMC Ward 17 (`27.7124, 85.3065`)
       to `NP-P3-D27-30608-W17` (`काठमाडौँ महानगरपालिका`), while rejecting `0.0, 0.0` with
       `HTTP 404 SELECT_YOUR_PALIKA` (Strict Zero Defaulting).
    2. `GET /api/v1/public/ward/{composite_ward_id}/stats` returns 14-day Breteau Index trends,
       active Search & Destroy counts, nearest NHFR hospital (`ST_Distance`), and 15-minute
       (`900s` TTL) cache (`X-Ward-Cache: MISS` -> `HIT`).
    3. `GET /api/v1/dashboards/context` rejects missing spatial context (`HTTP 400 SELECT_YOUR_PALIKA`)
       and sorts NHFR hospitals and RRT units by `ST_Distance` from `(lat, lng)`.
    4. Next.js Citizen Transparency Portal (`citizen_portal/`) implements 15-minute ISR
       (`revalidate = 900`), `generateStaticParams` (top 100 high-risk urban wards),
       Browser Geolocation (`navigator.geolocation`), and MapLibre GL `map.fitBounds()`.
    """
    from pathlib import Path

    # 1A. Resolve Pokhara coordinates -> must NOT default to Kathmandu
    pkr_resp = await client.get("/api/v1/spatial/resolve?lat=28.2096&lng=83.9595")
    assert pkr_resp.status_code == 200
    pkr = pkr_resp.json()
    assert pkr["composite_ward_id"] == "NP-P4-D40-40307-W06"
    assert pkr["ward_no"] == 6
    assert pkr["palika_code"] == "40307"
    assert pkr["palika_name_np"] == "पोखरा महानगरपालिका"
    assert pkr["risk_tier"] in ("HIGH", "CRITICAL_TIER_1", "MODERATE", "SAFE")
    assert "ST_Contains" in pkr["spatial_query_engine"]

    # 1B. Resolve Kathmandu Ward 17 coordinates
    kmc_resp = await client.get("/api/v1/spatial/resolve?lat=27.7124&lng=85.3065")
    assert kmc_resp.status_code == 200
    kmc = kmc_resp.json()
    assert kmc["composite_ward_id"] == "NP-P3-D27-30608-W17"
    assert kmc["ward_no"] == 17
    assert kmc["palika_code"] == "30608"
    assert kmc["palika_name_np"] == "काठमाडौँ महानगरपालिका"

    # 1C. Outside Nepal (0.0, 0.0) -> HTTP 404 SELECT_YOUR_PALIKA (Zero Defaulting)
    out_resp = await client.get("/api/v1/spatial/resolve?lat=0.0&lng=0.0")
    assert out_resp.status_code == 404
    assert out_resp.json()["detail"]["onboarding_action"] == "SELECT_YOUR_PALIKA"

    # 2. Public Ward Stats & 15-Minute (900s) Cache grouped by ward_id
    stats_miss = await client.get("/api/v1/public/ward/NP-P3-D27-30608-W17/stats")
    assert stats_miss.status_code == 200
    assert stats_miss.headers["x-ward-cache"] == "MISS"
    assert stats_miss.headers["x-cache-ttl-seconds"] == "900"
    s_body = stats_miss.json()
    assert s_body["composite_ward_id"] == "NP-P3-D27-30608-W17"
    assert len(s_body["breteau_index_14d_trend"]) == 14
    assert s_body["active_search_and_destroy_count"] >= 1
    assert s_body["nearest_nhfr_hospital"] is not None
    assert s_body["cache_ttl_seconds"] == 900

    stats_hit = await client.get("/api/v1/public/ward/NP-P3-D27-30608-W17/stats")
    assert stats_hit.status_code == 200
    assert stats_hit.headers["x-ward-cache"] == "HIT"
    assert stats_hit.json()["cache_status"] == "HIT"

    # 3. Context-Scoped Dashboard Feed: Zero Defaulting & ST_Distance sorting
    missing_ctx = await client.get("/api/v1/dashboards/context")
    assert missing_ctx.status_code == 400
    assert missing_ctx.json()["detail"]["onboarding_action"] == "SELECT_YOUR_PALIKA"

    ctx_pkr = await client.get(
        "/api/v1/dashboards/context?palika_code=40307&lat=28.2096&lng=83.9595"
    )
    assert ctx_pkr.status_code == 200
    ctx_body = ctx_pkr.json()
    assert ctx_body["palika_code"] == "40307"
    assert ctx_body["nearest_nhfr_hospital"]["palika_code"] == "40307"
    hospitals = ctx_body["nhfr_hospitals_by_distance"]
    assert len(hospitals) >= 2
    assert hospitals[0]["distance_meters"] <= hospitals[1]["distance_meters"]

    # 4. Verify Next.js ISR & MapLibre GL files in `citizen_portal/`
    repo_root = Path(__file__).resolve().parents[2]
    isr_page = (
        repo_root
        / "citizen_portal"
        / "app"
        / "ward"
        / "[composite_ward_id]"
        / "page.tsx"
    ).read_text(encoding="utf-8")
    assert "export const revalidate = 900" in isr_page
    assert "export async function generateStaticParams" in isr_page

    loc_header = (
        repo_root / "citizen_portal" / "components" / "LocationContextHeader.tsx"
    ).read_text(encoding="utf-8")
    assert "navigator.geolocation" in loc_header
    assert "Select Your Palika" in loc_header

    maplibre_view = (
        repo_root / "citizen_portal" / "components" / "WardMapLibreView.tsx"
    ).read_text(encoding="utf-8")
    assert "/api/v1/gis/tiles/{z}/{x}/{y}.mvt" in maplibre_view
    assert "map.fitBounds" in maplibre_view
