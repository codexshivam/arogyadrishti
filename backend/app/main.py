"""FastAPI entry point for Arogya Drishti National Vector Surveillance DPI Backend."""

from __future__ import annotations

import json
import logging
import os
import sys
import time
import uuid
from collections.abc import AsyncGenerator
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Literal

from fastapi import (
    Depends,
    FastAPI,
    File,
    Form,
    Header,
    Query,
    Request,
    Response,
    UploadFile,
    status,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from google.cloud import firestore
from google.oauth2.service_account import Credentials
from pydantic import BaseModel, Field
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

# Ensure repo root is on sys.path so skills/vector-surveillance-skill is importable
_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))
_HARNESS_DIR = _REPO_ROOT / "skills" / "vector-surveillance-skill"
if str(_HARNESS_DIR) not in sys.path:
    sys.path.insert(0, str(_HARNESS_DIR))

from harness.gemma_agent_harness import GemmaAgentHarness

from app.core.config import Settings, get_settings
from app.core.exceptions import ArogyaException, register_exception_handlers
from app.core.security import (
    optional_firebase_jwt,
    scrub_pii_text,
    set_officer_custom_claims,
)
from app.tools.gee_climate_tool import get_gee_client
from app.tools.gmail_alert_tool import get_email_alert_client
from app.tools.maps_routing_tool import encode_polyline, get_maps_routing_client
from app.tools.sheets_admin_tool import get_sheets_client
from app.tools.vision_paligemma_tool import (
    BreedingSiteScanResult,
    compute_composite_risk_score,
    get_ncvbdc_dosage_protocol,
    get_vision_client,
)

logging.basicConfig(
    level=logging.INFO,
    format='{"severity": "%(levelname)s", "logger": "%(name)s", "message": "%(message)s"}',
)
logger = logging.getLogger("arogya_drishti.main")

settings = get_settings()
limiter = Limiter(key_func=get_remote_address)

app = FastAPI(
    title="Arogya Drishti — National Vector-Borne Disease Surveillance DPI API",
    description=(
        "Government of India (NCVBDC / ICMR / IHIP / DPDP Act 2023) production backend "
        "integrating Cloud Firestore, Google Sheets v4 Master Ledger, Google Earth Engine (GEE), "
        "Google Maps Routes API v2, Open-Weight Gemma 4 / PaliGemma Vision, and data.gov.in OGD."
    ),
    version="1.0.0",
)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)  # type: ignore[arg-type]
register_exception_handlers(app)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

# In-memory idempotency cache backed by Firestore `dispatches` collection
_IDEMPOTENCY_CACHE: dict[str, dict[str, Any]] = {}


def get_firestore_db(cfg: Settings = Depends(get_settings)) -> firestore.Client:
    """Return authenticated Firestore Native client in asia-south1."""
    cred_path = cfg.google_application_credentials or os.getenv(
        "GOOGLE_APPLICATION_CREDENTIALS", ""
    )
    if cred_path and os.path.exists(cred_path):
        creds = Credentials.from_service_account_file(cred_path)
        return firestore.Client(project=cfg.gcp_project_id, credentials=creds)
    return firestore.Client(project=cfg.gcp_project_id)


@app.middleware("http")
async def security_and_cloud_armor_headers(
    request: Request, call_next: Any
) -> Response:
    """Enforce CERT-In, OWASP MASVS, and Cloud Armor security headers on every response."""
    start = time.perf_counter()
    trace_header = request.headers.get("X-Cloud-Trace-Context", uuid.uuid4().hex)
    trace_id = trace_header.split("/")[0]

    response: Response = await call_next(request)
    elapsed_ms = round((time.perf_counter() - start) * 1000.0, 2)

    response.headers["Strict-Transport-Security"] = (
        "max-age=63072000; includeSubDomains; preload"
    )
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["X-Cloud-Armor-Policy"] = "arogya-drishti-dpi-waf-south1"
    response.headers["X-Data-Residency-Region"] = settings.gcp_region
    response.headers["X-Trace-Id"] = trace_id
    response.headers["X-Response-Time-Ms"] = str(elapsed_ms)
    return response


# ---------------------------------------------------------------------------
# Health & Readiness Probes
# ---------------------------------------------------------------------------


@app.get("/healthz", tags=["System"])
def healthz() -> dict[str, Any]:
    """Liveness check for Cloud Run."""
    return {
        "status": "ok",
        "service": "arogya-drishti-dpi-backend",
        "region": settings.gcp_region,
        "timestamp_utc": datetime.now(UTC).isoformat(),
    }


@app.get("/readyz", tags=["System"])
def readyz() -> dict[str, Any]:
    """Readiness check validating sovereign region and configuration."""
    return {
        "status": "ready",
        "project_id": settings.gcp_project_id,
        "region": settings.gcp_region,
        "master_sheet_configured": bool(settings.master_spreadsheet_id),
        "maps_configured": bool(settings.google_maps_api_key),
        "gemma_model": settings.gemma_model_id,
        "gemini_model": settings.gemini_model_id,
    }


# ---------------------------------------------------------------------------
# Endpoint 1: Staff Verification & Custom JWT Claims (`POST /api/v1/auth/verify-staff`)
# ---------------------------------------------------------------------------


class StaffVerifyRequest(BaseModel):
    uid: str = Field(..., min_length=1)
    phone: str | None = None
    email: str | None = None


@app.post("/api/v1/auth/verify-staff", tags=["Auth"])
def verify_staff_endpoint(
    payload: StaffVerifyRequest,
    db: firestore.Client = Depends(get_firestore_db),
) -> dict[str, Any]:
    """Cross-check officer phone/email against 3_Staff_Directory in Google Sheets and mint Custom JWT Claims."""
    sheets = get_sheets_client()
    staff_record = sheets.verify_staff_by_phone_or_email(
        phone=payload.phone, email=payload.email
    )
    role = "asha_field_officer"
    claims: dict[str, Any] = {
        "role": role,
        "assigned_lgd_code": staff_record.lgd_code,
        "ward_village": staff_record.ward_or_village,
        "authorized_staff": True,
    }
    try:
        claims = set_officer_custom_claims(
            uid=payload.uid,
            role=role,
            assigned_lgd_code=staff_record.lgd_code,
            ward_village=staff_record.ward_or_village,
            settings=settings,
        )
    except Exception as exc:
        logger.warning(
            "Custom claim assignment note (user UID %s may be a local session): %s",
            scrub_pii_text(payload.uid),
            exc,
        )

    profile = {
        "uid": payload.uid,
        "name": staff_record.village_officer_name,
        "email": staff_record.village_officer_email,
        "phone": staff_record.village_officer_phone,
        "ward_village": staff_record.ward_or_village,
        "district": staff_record.district,
        "state": staff_record.state,
        "assigned_lgd_code": staff_record.lgd_code,
        "district_rep_name": staff_record.district_rep_name,
        "district_rep_phone": staff_record.district_rep_phone,
        "district_rep_email": staff_record.district_rep_email,
        "role": role,
        "verified_at_utc": datetime.now(UTC).isoformat(),
    }
    try:
        db.collection("users").document(payload.uid).set(profile, merge=True)
    except Exception as exc:
        logger.warning("Firestore user profile sync note: %s", exc)

    return {
        "status": "STAFF_VERIFIED",
        "claims": claims,
        "officer_profile": profile,
    }


# ---------------------------------------------------------------------------
# Endpoint 2: Modal Action Dispatch (`POST /api/v1/dispatch-action`)
# ---------------------------------------------------------------------------


class DispatchActionPayload(BaseModel):
    officer_uid: str = Field(..., min_length=1)
    action_type: Literal["REQUEST_VAN", "SEND_ALERT"]
    ward_village: str = Field(..., min_length=1)
    district_lgd: str = Field(default="04055001")
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)
    notes: str = Field(default="Immediate field vector intervention requested.")
    idempotency_key: str | None = None


@app.post("/api/v1/dispatch-action", tags=["Dispatch"])
def handle_dispatch_action(
    payload: DispatchActionPayload,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    db: firestore.Client = Depends(get_firestore_db),
    _jwt: dict[str, Any] | None = Depends(optional_firebase_jwt),
) -> dict[str, Any]:
    """Handle Request Van and Send Alert modal actions with idempotency protection."""
    idem_key = (idempotency_key or payload.idempotency_key or "").strip()
    if idem_key and idem_key in _IDEMPOTENCY_CACHE:
        return {**_IDEMPOTENCY_CACHE[idem_key], "idempotent_replay": True}

    sheets = get_sheets_client()
    contacts = sheets.lookup_authorized_staff(
        ward_village=payload.ward_village, district_lgd=payload.district_lgd
    )
    dispatch_id = (
        f"DSP-{idem_key[:10].upper()}"
        if idem_key
        else f"DSP-{uuid.uuid4().hex[:8].upper()}"
    )
    now_utc = datetime.now(UTC)

    firestore_record: dict[str, Any] = {
        "dispatch_id": dispatch_id,
        "officer_uid": payload.officer_uid,
        "action_type": payload.action_type,
        "ward_village": payload.ward_village,
        "district_lgd": contacts.lgd_code or payload.district_lgd,
        "location": firestore.GeoPoint(payload.latitude, payload.longitude),
        "latitude": payload.latitude,
        "longitude": payload.longitude,
        "notes": scrub_pii_text(payload.notes),
        "timestamp": now_utc,
        "contacts_notified": contacts.model_dump(),
    }

    if payload.action_type == "REQUEST_VAN":
        vans = sheets.get_vans_fleet(ward_or_district=payload.ward_village)
        optimal_van = get_maps_routing_client().select_fastest_van(
            target_lat=payload.latitude,
            target_lng=payload.longitude,
            vans=vans,
        )
        van_req_row = sheets.log_van_request(
            request_id=dispatch_id,
            officer_uid=payload.officer_uid,
            ward_village=payload.ward_village,
            target_lat=payload.latitude,
            target_lng=payload.longitude,
            assigned_van_id=optimal_van.van_id,
            vehicle_no=optimal_van.vehicle_no,
            driver_phone=optimal_van.driver_phone,
            maps_eta_mins=optimal_van.eta_minutes,
            distance_km=optimal_van.distance_km,
            van_row_index=optimal_van.row_index,
            status_label="Dispatched",
        )
        firestore_record["assigned_van"] = optimal_van.model_dump()
        firestore_record["sheet_row"] = van_req_row.model_dump()
        db.collection("dispatches").document(dispatch_id).set(firestore_record)

        result = {
            "status": "VAN_ASSIGNED",
            "dispatch_id": dispatch_id,
            "van_details": optimal_van.model_dump(),
            "notified_contacts": contacts.model_dump(),
        }
        if idem_key:
            _IDEMPOTENCY_CACHE[idem_key] = result
        return result

    # action_type == "SEND_ALERT"
    gee = get_gee_client().get_climate_suitability(
        lat=payload.latitude, lng=payload.longitude
    )
    ward_bi = _get_ward_breteau_index(db, contacts.lgd_code or payload.district_lgd)
    receipt = get_email_alert_client().send_emergency_alert(
        to_email=contacts.village_officer_email,
        cc_email=contacts.district_rep_email,
        ward_village=payload.ward_village,
        lat=payload.latitude,
        lng=payload.longitude,
        notes=payload.notes,
        severity="CRITICAL",
        breteau_index=ward_bi,
        gee_risk_score=gee.environmental_suitability_score,
        lst_celsius=gee.lst_celsius,
        rain_14d_mm=gee.rain_14d_mm,
        district_rep_phone=contacts.district_rep_phone,
    )
    alert_row = sheets.log_alert_dispatch(
        alert_id=dispatch_id,
        ward_village=payload.ward_village,
        severity="CRITICAL",
        breteau_index=ward_bi,
        gee_risk_score=gee.environmental_suitability_score,
        emailed_to=contacts.village_officer_email,
        district_rep_notified=f"{contacts.district_rep_name} ({contacts.district_rep_phone})",
        action_notes=payload.notes,
    )
    firestore_record["email_receipt"] = receipt.model_dump()
    firestore_record["sheet_row"] = alert_row.model_dump()
    db.collection("dispatches").document(dispatch_id).set(firestore_record)

    result = {
        "status": "ALERT_SENT",
        "dispatch_id": dispatch_id,
        "notified": contacts.model_dump(),
        "email_receipt": receipt.model_dump(),
    }
    if idem_key:
        _IDEMPOTENCY_CACHE[idem_key] = result
    return result


def _get_ward_breteau_index(db: firestore.Client, lgd_code: str) -> float:
    """Compute live ward Breteau Index from Firestore field_logs."""
    try:
        docs = list(
            db.collection("field_logs")
            .where(filter=firestore.FieldFilter("lgd_code", "==", lgd_code))
            .limit(20)
            .stream()
        )
        if not docs:
            docs = list(db.collection("field_logs").limit(10).stream())
        h_insp = sum(int((d.to_dict() or {}).get("houses_inspected") or 0) for d in docs)
        c_pos = sum(int((d.to_dict() or {}).get("containers_positive") or 0) for d in docs)
        if h_insp > 0:
            return round((c_pos / h_insp) * 100.0, 2)
    except Exception as exc:
        logger.warning("Ward BI lookup fallback: %s", exc)
    return 34.0


# ---------------------------------------------------------------------------
# Endpoint 3: AI Vector Breeding Site Scanner (`POST /api/v1/scan-breeding-site`)
# ---------------------------------------------------------------------------


@app.post(
    "/api/v1/scan-breeding-site",
    response_model=BreedingSiteScanResult,
    tags=["Vision & GEE"],
)
async def scan_breeding_site(
    image: UploadFile = File(...),
    lat: float = Form(...),
    lng: float = Form(...),
    ward_lgd: str = Form(default="04055001"),
    db: firestore.Client = Depends(get_firestore_db),
) -> BreedingSiteScanResult:
    """DPDP face/plate redaction -> GCS upload -> Gemma 4 / Gemini Vision -> GEE fusion -> auto escalation."""
    raw_bytes = await image.read()
    if not raw_bytes or len(raw_bytes) > 15 * 1024 * 1024:
        raise ArogyaException(
            title="Invalid Image Payload",
            detail="Uploaded image must be non-empty and <= 15 MB.",
            status_code=status.HTTP_400_BAD_REQUEST,
        )

    gee_telemetry = get_gee_client().get_climate_suitability(lat=lat, lng=lng)
    ward_bi = _get_ward_breteau_index(db, ward_lgd)
    scan_result = get_vision_client().analyze_breeding_site(
        raw_image_bytes=raw_bytes,
        lat=lat,
        lng=lng,
        ward_lgd=ward_lgd,
        gee_telemetry=gee_telemetry,
        ward_breteau_index=ward_bi,
    )

    # If RiskScore >= 0.70, automatically log to 5_Alert_Logs and notify the health officer via email
    if scan_result.composite_risk_score >= 0.70:
        try:
            sheets = get_sheets_client()
            contact = sheets.lookup_authorized_staff(
                ward_village=ward_lgd, district_lgd=ward_lgd
            )
            notes = (
                f"Auto-escalated AI Vector Scan ({scan_result.scan_id}): "
                f"{scan_result.primary_classification} detected with {int(scan_result.vision_confidence * 100)}% confidence."
            )
            receipt = get_email_alert_client().send_emergency_alert(
                to_email=contact.village_officer_email,
                cc_email=contact.district_rep_email,
                ward_village=contact.ward_or_village,
                lat=lat,
                lng=lng,
                notes=notes,
                severity=scan_result.risk_tier,
                breteau_index=ward_bi,
                gee_risk_score=gee_telemetry.environmental_suitability_score,
                lst_celsius=gee_telemetry.lst_celsius,
                rain_14d_mm=gee_telemetry.rain_14d_mm,
                district_rep_phone=contact.district_rep_phone,
            )
            sheets.log_alert_dispatch(
                alert_id=scan_result.scan_id,
                ward_village=contact.ward_or_village,
                severity=scan_result.risk_tier,
                breteau_index=ward_bi,
                gee_risk_score=gee_telemetry.environmental_suitability_score,
                emailed_to=contact.village_officer_email,
                district_rep_notified=f"{contact.district_rep_name} ({contact.district_rep_phone})",
                action_notes=notes,
            )
            scan_result.auto_escalation_triggered = True
            scan_result.alert_message_id = receipt.message_id
        except Exception as exc:
            logger.warning("Auto-escalation alert note for %s: %s", scan_result.scan_id, exc)

    # Persist scan record in Firestore ai_scans collection
    try:
        db.collection("ai_scans").document(scan_result.scan_id).set(
            {
                **scan_result.model_dump(),
                "location": firestore.GeoPoint(lat, lng),
                "created_at": datetime.now(UTC),
            }
        )
    except Exception as exc:
        logger.warning("Firestore ai_scans write note: %s", exc)

    return scan_result


# ---------------------------------------------------------------------------
# Endpoint 4: Live Health Centers Directory (`GET /api/v1/centers`)
# ---------------------------------------------------------------------------


@app.get("/api/v1/centers", tags=["Directory"])
def list_health_centers(
    lat: float = Query(default=30.7333, ge=-90.0, le=90.0),
    lng: float = Query(default=76.7794, ge=-180.0, le=180.0),
    radius_km: float = Query(default=25.0, ge=1.0, le=500.0),
    facility_type: str | None = Query(default=None),
) -> dict[str, Any]:
    """Merge 2_Health_Centers Google Sheet with data.gov.in OGD Health Facility Registry."""
    centers = get_sheets_client().get_health_centers(
        lat=lat, lng=lng, radius_km=radius_km
    )
    if facility_type and facility_type.strip().lower() != "all":
        ft_norm = facility_type.strip().lower()
        centers = [
            c for c in centers if ft_norm in c.facility_type.lower() or ft_norm in c.name.lower()
        ]
    return {
        "count": len(centers),
        "observer_coordinates": {"latitude": lat, "longitude": lng},
        "radius_km": radius_km,
        "centers": [c.model_dump() for c in centers],
    }


# ---------------------------------------------------------------------------
# Endpoint 5: Live Fogging Vans Telemetry (`GET /api/v1/vans`)
# ---------------------------------------------------------------------------


@app.get("/api/v1/vans", tags=["Fleet"])
def list_fogging_vans(
    lat: float = Query(default=30.7333, ge=-90.0, le=90.0),
    lng: float = Query(default=76.7794, ge=-180.0, le=180.0),
    ward_or_district: str | None = Query(default=None),
) -> dict[str, Any]:
    """Return active fogging vans from 1_Vans_Fleet with live traffic ETAs and route polylines."""
    vans = get_sheets_client().get_vans_fleet(ward_or_district=ward_or_district)
    routing_client = get_maps_routing_client()
    enriched: list[dict[str, Any]] = []

    for van in vans:
        try:
            route = routing_client.compute_route(
                origin_lat=van.base_lat,
                origin_lng=van.base_lng,
                target_lat=lat,
                target_lng=lng,
            )
        except Exception:
            route = routing_client._compute_road_adjusted_fallback(
                origin_lat=van.base_lat,
                origin_lng=van.base_lng,
                target_lat=lat,
                target_lng=lng,
            )
        enriched.append(
            {
                **van.model_dump(),
                "eta_minutes": route["eta_minutes"],
                "distance_km": route["distance_km"],
                "encoded_polyline": route.get("encoded_polyline")
                or encode_polyline([(van.base_lat, van.base_lng), (lat, lng)]),
                "routing_source": route["routing_source"],
            }
        )

    enriched.sort(key=lambda item: int(item["eta_minutes"]))
    return {
        "count": len(enriched),
        "target_coordinates": {"latitude": lat, "longitude": lng},
        "vans": enriched,
    }


# ---------------------------------------------------------------------------
# Endpoint 6: Authorized Staff & District Representative Contacts (`GET /api/v1/contacts`)
# ---------------------------------------------------------------------------


@app.get("/api/v1/contacts", tags=["Directory"])
def list_authorized_contacts(
    district_lgd: str | None = Query(default=None),
) -> dict[str, Any]:
    """Fetch Village Officers and District Nodal Officers from 3_Staff_Directory + OGD."""
    contacts = get_sheets_client().list_all_staff_contacts(
        district_lgd=district_lgd
    )
    return {
        "count": len(contacts),
        "emergency_helplines": [
            {
                "name": "NCDC Vector Control Room",
                "number": "1800-11-4377",
                "display_code": "1800-11-VECTOR",
                "type": "NATIONAL_SOS",
            },
            {
                "name": "National Health Helpline",
                "number": "104",
                "display_code": "104",
                "type": "MEDICAL_ADVICE",
            },
            {
                "name": "Emergency Ambulance & Outbreak Response",
                "number": "108",
                "display_code": "108",
                "type": "EMERGENCY_AMBULANCE",
            },
        ],
        "contacts": [c.model_dump() for c in contacts],
    }


# ---------------------------------------------------------------------------
# Endpoint 7: Multilingual Gemma 4 / Gemini Agent Skill Copilot (`POST /api/v1/agent/chat`)
# ---------------------------------------------------------------------------


class AgentChatRequest(BaseModel):
    uid: str = Field(default="officer_kunal_04055001")
    message: str = Field(..., min_length=1, max_length=2000)
    ward_village: str = Field(default="Sector 22-B")
    lgd_code: str = Field(default="04055001")
    latitude: float = Field(default=30.7333, ge=-90.0, le=90.0)
    longitude: float = Field(default=76.7794, ge=-180.0, le=180.0)
    stream: bool = Field(default=False)


@app.post("/api/v1/agent/chat", tags=["Agent Skill Copilot"])
async def agent_chat_endpoint(
    payload: AgentChatRequest,
    db: firestore.Client = Depends(get_firestore_db),
) -> Any:
    """Execute the standardized Vector Surveillance Agent Skill via Gemma 4 / Gemini 3.8 Flash."""
    harness = GemmaAgentHarness()
    turn_result = harness.run_chat_turn(
        user_message=scrub_pii_text(payload.message),
        ward_village=payload.ward_village,
        lgd_code=payload.lgd_code,
        lat=payload.latitude,
        lng=payload.longitude,
    )

    # Persist conversation turn in Firestore chat_sessions/{uid}/messages
    try:
        session_ref = (
            db.collection("chat_sessions")
            .document(payload.uid)
            .collection("messages")
        )
        now = datetime.now(UTC)
        session_ref.add(
            {
                "role": "user",
                "text": scrub_pii_text(payload.message),
                "ward_village": payload.ward_village,
                "lgd_code": payload.lgd_code,
                "timestamp": now,
            }
        )
        session_ref.add(
            {
                "role": "assistant",
                "text": turn_result.reply_text,
                "model_used": turn_result.model_used,
                "tool_cards": [c.model_dump() for c in turn_result.tool_cards],
                "timestamp": now,
            }
        )
    except Exception as exc:
        logger.warning("Firestore chat_sessions persistence note: %s", exc)

    if payload.stream:
        async def _sse_stream() -> AsyncGenerator[str, None]:
            for card in turn_result.tool_cards:
                yield f"event: tool_card\ndata: {json.dumps(card.model_dump())}\n\n"
            for chunk in turn_result.reply_text.split(" "):
                yield f"event: delta\ndata: {json.dumps({'text': chunk + ' '})}\n\n"
            yield f"event: completed\ndata: {json.dumps(turn_result.model_dump())}\n\n"

        return StreamingResponse(_sse_stream(), media_type="text/event-stream")

    return turn_result.model_dump()


# ---------------------------------------------------------------------------
# Endpoint 8: Public DPI Geospatial Risk Index (`GET /api/v1/risk-index`)
# ---------------------------------------------------------------------------


@app.get("/api/v1/risk-index", tags=["Public DPI API"])
@limiter.limit(settings.public_api_rate_limit)
def get_public_vector_risk(
    request: Request,
    lat: float = Query(..., ge=-90.0, le=90.0, description="WGS84 latitude"),
    lng: float = Query(..., ge=-180.0, le=180.0, description="WGS84 longitude"),
    lgd_code: str = Query(default="04055001", description="Optional LGD ward code"),
    db: firestore.Client = Depends(get_firestore_db),
) -> dict[str, Any]:
    """Public DPI endpoint combining live GEE satellite bands with Firestore ground entomological indices."""
    gee = get_gee_client().get_climate_suitability(lat=lat, lng=lng)

    # Aggregate ward field logs
    docs = list(
        db.collection("field_logs")
        .where(filter=firestore.FieldFilter("lgd_code", "==", lgd_code))
        .limit(20)
        .stream()
    )
    if not docs:
        docs = list(db.collection("field_logs").limit(10).stream())

    h_insp = sum(int((d.to_dict() or {}).get("houses_inspected") or 0) for d in docs)
    h_pos = sum(int((d.to_dict() or {}).get("houses_positive") or 0) for d in docs)
    c_chk = sum(int((d.to_dict() or {}).get("containers_checked") or 0) for d in docs)
    c_pos = sum(int((d.to_dict() or {}).get("containers_positive") or 0) for d in docs)

    hi = round((h_pos / h_insp) * 100.0, 2) if h_insp > 0 else 0.0
    ci = round((c_pos / c_chk) * 100.0, 2) if c_chk > 0 else 0.0
    bi = round((c_pos / h_insp) * 100.0, 2) if h_insp > 0 else 0.0

    # Latest vision confidence in ward if scanned recently
    latest_scans = list(
        db.collection("ai_scans")
        .where(filter=firestore.FieldFilter("ward_lgd", "==", lgd_code))
        .limit(1)
        .stream()
    )
    i_vision = (
        float((latest_scans[0].to_dict() or {}).get("vision_confidence") or 0.85)
        if latest_scans
        else 0.85
    )

    v_field, composite_risk, risk_tier = compute_composite_risk_score(
        e_gee=gee.environmental_suitability_score,
        ward_breteau_index=bi,
        i_vision=i_vision,
    )
    intervention, dosage = get_ncvbdc_dosage_protocol(
        "Uncovered Overhead Tank / Stagnant Drain", risk_tier
    )

    return {
        "dpi_standard": "Government of India IHIP / NCVBDC Open Risk Index v1.0",
        "coordinates": {"latitude": lat, "longitude": lng},
        "lgd_code": lgd_code,
        "risk_tier": risk_tier,
        "composite_risk_score": composite_risk,
        "formula": "0.35 * E_GEE + 0.40 * V_Field + 0.25 * I_Vision",
        "components": {
            "e_gee": gee.environmental_suitability_score,
            "v_field": v_field,
            "i_vision": i_vision,
        },
        "entomological_indices": {
            "house_index_pct": hi,
            "container_index_pct": ci,
            "breteau_index": bi,
            "who_critical_breteau_threshold": 20.0,
        },
        "satellite_telemetry_gee": {
            "land_surface_temp_celsius": gee.lst_celsius,
            "stagnant_water_ndwi": gee.ndwi,
            "canopy_ndvi": gee.ndvi,
            "rainfall_14d_mm": gee.rain_14d_mm,
            "water_detection_mode": gee.water_detection_mode,
            "optimal_breeding_window": gee.aedes_optimal_thermal_window,
            "observation_window_end_utc": gee.observation_window_end_utc,
        },
        "recommended_intervention": intervention,
        "ncvbdc_larvicide_dosage": dosage,
    }


# ---------------------------------------------------------------------------
# Endpoint 9: Epidemiological Stats & IHIP FHIR/CSV Export (`GET /api/v1/stats`)
# ---------------------------------------------------------------------------


@app.get("/api/v1/stats", tags=["Epidemiology & IHIP"])
def get_ward_epidemiology_stats(
    lgd_code: str = Query(default="04055001"),
    weeks: int = Query(default=8, ge=1, le=52),
    db: firestore.Client = Depends(get_firestore_db),
) -> dict[str, Any]:
    """Compute live HI, CI, BI, 8-week trend series, and IHIP Form VC-1/VC-2 FHIR export."""
    docs = list(
        db.collection("field_logs")
        .where(filter=firestore.FieldFilter("lgd_code", "==", lgd_code))
        .stream()
    )
    if not docs:
        docs = list(db.collection("field_logs").limit(16).stream())

    records = [d.to_dict() or {} for d in docs]
    records.sort(key=lambda r: str(r.get("timestamp") or ""))
    recent = records[-weeks:] if len(records) >= weeks else records

    h_insp = sum(int(r.get("houses_inspected") or 0) for r in recent)
    h_pos = sum(int(r.get("houses_positive") or 0) for r in recent)
    c_chk = sum(int(r.get("containers_checked") or 0) for r in recent)
    c_pos = sum(int(r.get("containers_positive") or 0) for r in recent)

    hi = round((h_pos / h_insp) * 100.0, 1) if h_insp > 0 else 0.0
    ci = round((c_pos / c_chk) * 100.0, 1) if c_chk > 0 else 0.0
    bi = round((c_pos / h_insp) * 100.0, 1) if h_insp > 0 else 0.0

    weekly_series: list[dict[str, Any]] = []
    for idx, rec in enumerate(recent, start=1):
        weekly_series.append(
            {
                "week_label": f"W{idx}",
                "hi": float(rec.get("computed_hi") or 0.0),
                "ci": float(rec.get("computed_ci") or 0.0),
                "bi": float(rec.get("computed_bi") or 0.0),
                "rainfall_mm": float(rec.get("rainfall_14d_mm") or 0.0),
                "houses_inspected": int(rec.get("houses_inspected") or 0),
                "houses_positive": int(rec.get("houses_positive") or 0),
                "containers_checked": int(rec.get("containers_checked") or 0),
                "containers_positive": int(rec.get("containers_positive") or 0),
                "larvicidal_treatment": str(rec.get("larvicidal_treatment") or "None"),
            }
        )

    return {
        "lgd_code": lgd_code,
        "ward_name": str((recent[-1] if recent else {}).get("ward_village") or "Sector 22-B"),
        "house_index_pct": hi,
        "container_index_pct": ci,
        "breteau_index": bi,
        "alert_level": "HIGH RISK" if bi > 20.0 else ("MODERATE" if bi >= 5.0 else "SAFE"),
        "weekly_trends": weekly_series,
        "ihip_fhir_observation_bundle": {
            "resourceType": "Bundle",
            "type": "collection",
            "timestamp": datetime.now(UTC).isoformat(),
            "identifier": {
                "system": "https://ihip.nhp.gov.in/ncvbdc/vc-report",
                "value": f"IHIP-VC-{lgd_code}",
            },
            "entry": [
                {"code": "HOUSE_INDEX_PCT", "value": hi, "unit": "%", "whoThreshold": 1.0},
                {"code": "CONTAINER_INDEX_PCT", "value": ci, "unit": "%", "whoThreshold": 5.0},
                {"code": "BRETEAU_INDEX", "value": bi, "unit": "index", "whoThreshold": 20.0},
            ],
        },
    }


# ---------------------------------------------------------------------------
# Endpoint 10: Field Inspection Log Creation & Support Escalation Tickets
# ---------------------------------------------------------------------------


class FieldInspectionPayload(BaseModel):
    officer_uid: str = Field(default="officer_kunal_04055001")
    officer_name: str = Field(default="Kunal Yadav")
    lgd_code: str = Field(default="04055001")
    ward_village: str = Field(..., min_length=1)
    larvicidal_treatment: str = Field(default="Temephos 50% EC Applied")
    houses_inspected: int = Field(..., ge=1)
    houses_positive: int = Field(..., ge=0)
    containers_checked: int = Field(..., ge=1)
    containers_positive: int = Field(..., ge=0)
    latitude: float = Field(default=30.7333, ge=-90.0, le=90.0)
    longitude: float = Field(default=76.7794, ge=-180.0, le=180.0)


@app.post("/api/v1/field-logs", tags=["Epidemiology & IHIP"])
def create_field_inspection_log(
    payload: FieldInspectionPayload,
    db: firestore.Client = Depends(get_firestore_db),
) -> dict[str, Any]:
    """Compute HI, CI, BI mathematically and persist field inspection log to Cloud Firestore."""
    hi = round((payload.houses_positive / payload.houses_inspected) * 100.0, 2)
    ci = round((payload.containers_positive / payload.containers_checked) * 100.0, 2)
    bi = round((payload.containers_positive / payload.houses_inspected) * 100.0, 2)

    log_id = f"LOG-{uuid.uuid4().hex[:8].upper()}"
    now_utc = datetime.now(UTC)
    record = {
        "log_id": log_id,
        "officer_uid": payload.officer_uid,
        "officer_name": payload.officer_name,
        "lgd_code": payload.lgd_code,
        "ward_village": payload.ward_village,
        "larvicidal_treatment": payload.larvicidal_treatment,
        "houses_inspected": payload.houses_inspected,
        "houses_positive": payload.houses_positive,
        "containers_checked": payload.containers_checked,
        "containers_positive": payload.containers_positive,
        "computed_hi": hi,
        "computed_ci": ci,
        "computed_bi": bi,
        "location": firestore.GeoPoint(payload.latitude, payload.longitude),
        "latitude": payload.latitude,
        "longitude": payload.longitude,
        "geohash": "ttnfv8",
        "timestamp": now_utc,
    }
    db.collection("field_logs").document(log_id).set(record)
    return {
        "status": "FIELD_LOG_SAVED",
        "log_id": log_id,
        "computed_indices": {"hi": hi, "ci": ci, "bi": bi},
    }


class SupportTicketPayload(BaseModel):
    officer_uid: str = Field(default="officer_kunal_04055001")
    category: str = Field(default="Outbreak Cluster Flare-up (High Larval Index)")
    severity_sla: str = Field(default="Critical (2h SLA)")
    ward_village: str = Field(default="Sector 22-B")
    lgd_code: str = Field(default="04055001")
    observation_notes: str = Field(..., min_length=3)


@app.post("/api/v1/support/tickets", tags=["Support & Escalation"])
def create_support_ticket(
    payload: SupportTicketPayload,
    db: firestore.Client = Depends(get_firestore_db),
) -> dict[str, Any]:
    """Create an escalation ticket in Firestore and mirror into 5_Alert_Logs in Google Sheets."""
    ticket_id = f"ESC-2026-{uuid.uuid4().hex[:4].upper()}"
    now_utc = datetime.now(UTC)
    sheets = get_sheets_client()
    contacts = sheets.lookup_authorized_staff(
        ward_village=payload.ward_village, district_lgd=payload.lgd_code
    )
    ward_bi = _get_ward_breteau_index(db, payload.lgd_code)

    sheets.log_alert_dispatch(
        alert_id=ticket_id,
        ward_village=payload.ward_village,
        severity=payload.severity_sla,
        breteau_index=ward_bi,
        gee_risk_score=0.86,
        emailed_to=contacts.village_officer_email,
        district_rep_notified=f"{contacts.district_rep_name} ({contacts.district_rep_phone})",
        action_notes=f"[{payload.category}] {payload.observation_notes}",
    )

    ticket_doc = {
        "ticket_id": ticket_id,
        "officer_uid": payload.officer_uid,
        "category": payload.category,
        "severity_sla": payload.severity_sla,
        "ward_village": payload.ward_village,
        "lgd_code": payload.lgd_code,
        "observation_notes": scrub_pii_text(payload.observation_notes),
        "status": "DISPATCH SENT",
        "assigned_nodal_officer": contacts.district_rep_name,
        "created_at": now_utc,
        "created_at_utc": now_utc.isoformat(),
    }
    db.collection("support_tickets").document(ticket_id).set(ticket_doc)
    return {"status": "TICKET_SUBMITTED", "ticket": ticket_doc}


@app.get("/api/v1/support/tickets", tags=["Support & Escalation"])
def list_support_tickets(
    db: firestore.Client = Depends(get_firestore_db),
) -> dict[str, Any]:
    """Return live escalation tickets from Firestore."""
    docs = list(db.collection("support_tickets").limit(25).stream())
    tickets: list[dict[str, Any]] = []
    for d in docs:
        rec = d.to_dict() or {}
        rec.pop("created_at", None)
        tickets.append(rec)
    tickets.sort(key=lambda t: str(t.get("created_at_utc") or ""), reverse=True)
    return {"count": len(tickets), "tickets": tickets}
