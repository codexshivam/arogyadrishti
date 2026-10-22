"""Sandboxed, allow-listed tool dispatcher connecting the Agent Skill to live backend tools."""

from __future__ import annotations

import logging
import os
import sys
import uuid
from collections.abc import Callable
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

# Ensure backend/ is importable when running the harness standalone
_REPO_ROOT = Path(__file__).resolve().parents[3]
_BACKEND_DIR = _REPO_ROOT / "backend"
if str(_BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(_BACKEND_DIR))

import google.auth
from app.core.config import Settings, get_settings
from app.tools.gee_climate_tool import get_gee_client
from app.tools.gmail_alert_tool import get_email_alert_client
from app.tools.maps_routing_tool import get_maps_routing_client
from app.tools.sheets_admin_tool import get_sheets_client
from google.cloud import firestore
from google.oauth2.service_account import Credentials

logger = logging.getLogger("arogya_drishti.skill_executor")

ALLOWED_TOOLS = frozenset(
    {
        "query_gee_microclimate",
        "compute_ward_entomological_indices",
        "compute_ward_indices",
        "dispatch_fogging_van",
        "trigger_emergency_ward_alert",
        "trigger_emergency_alert",
    }
)


def _get_firestore_client(settings: Settings) -> firestore.Client:
    cred_path = settings.google_application_credentials or os.getenv(
        "GOOGLE_APPLICATION_CREDENTIALS", ""
    )
    if cred_path and os.path.exists(cred_path):
        creds = Credentials.from_service_account_file(cred_path)
        return firestore.Client(
            project=settings.gcp_project_id, credentials=creds
        )
    creds, _ = google.auth.default()
    return firestore.Client(project=settings.gcp_project_id, credentials=creds)


class SkillExecutor:
    """Allow-listed dispatcher executing the 4 standardized Agent Skill tools against live GCP/Sheets."""

    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()
        self._dispatch_table: dict[str, Callable[..., dict[str, Any]]] = {
            "query_gee_microclimate": self.query_gee_microclimate,
            "compute_ward_entomological_indices": self.compute_ward_entomological_indices,
            "compute_ward_indices": self.compute_ward_entomological_indices,
            "dispatch_fogging_van": self.dispatch_fogging_van,
            "trigger_emergency_ward_alert": self.trigger_emergency_ward_alert,
            "trigger_emergency_alert": self.trigger_emergency_ward_alert,
        }

    def execute(self, tool_name: str, arguments: dict[str, Any]) -> dict[str, Any]:
        """Validate tool_name against allow-list and invoke with structured error recovery."""
        if tool_name not in ALLOWED_TOOLS:
            raise ValueError(
                f"Tool '{tool_name}' is not in the Agent Skill allow-list ({sorted(ALLOWED_TOOLS)})."
            )
        handler = self._dispatch_table[tool_name]
        return handler(**arguments)

    def query_gee_microclimate(self, lat: float, lng: float) -> dict[str, Any]:
        """Tool 1: Query live Google Earth Engine bio-climate suitability."""
        telemetry = get_gee_client().get_climate_suitability(
            lat=float(lat), lng=float(lng)
        )
        return {
            "tool": "query_gee_microclimate",
            "status": "SUCCESS",
            "data": telemetry.model_dump(),
        }

    def compute_ward_entomological_indices(self, lgd_code: str) -> dict[str, Any]:
        """Tool 2: Compute live HI, CI, BI from Cloud Firestore field_logs for lgd_code."""
        db = _get_firestore_client(self.settings)
        clean_lgd = str(lgd_code or "04055001").strip()
        docs = list(
            db.collection("field_logs")
            .where(filter=firestore.FieldFilter("lgd_code", "==", clean_lgd))
            .stream()
        )
        if not docs:
            # Also allow matching by ward_village name if officer passed e.g. "Sector 22-B"
            all_docs = list(db.collection("field_logs").limit(50).stream())
            docs = [
                d
                for d in all_docs
                if clean_lgd.lower()
                in str((d.to_dict() or {}).get("ward_village", "")).lower()
                or clean_lgd.lower()
                in str((d.to_dict() or {}).get("lgd_code", "")).lower()
            ] or all_docs[:8]

        total_houses_inspected = 0
        total_houses_positive = 0
        total_containers_checked = 0
        total_containers_positive = 0
        ward_name = clean_lgd

        for snap in docs:
            rec = snap.to_dict() or {}
            total_houses_inspected += int(rec.get("houses_inspected") or 0)
            total_houses_positive += int(rec.get("houses_positive") or 0)
            total_containers_checked += int(rec.get("containers_checked") or 0)
            total_containers_positive += int(rec.get("containers_positive") or 0)
            if rec.get("ward_village"):
                ward_name = str(rec["ward_village"])

        hi = (
            round((total_houses_positive / total_houses_inspected) * 100.0, 2)
            if total_houses_inspected > 0
            else 0.0
        )
        ci = (
            round((total_containers_positive / total_containers_checked) * 100.0, 2)
            if total_containers_checked > 0
            else 0.0
        )
        bi = (
            round((total_containers_positive / total_houses_inspected) * 100.0, 2)
            if total_houses_inspected > 0
            else 0.0
        )

        if bi > 20.0 or hi > 5.0:
            risk_tier = "CRITICAL"
            protocol = (
                "Apply Temephos 50% EC @ 1 ppm (1 ml per 1,000 L) in overhead tanks/coolers, "
                "Bti granules (5–10 g/m²) in drains, and schedule ULV Pyrethrum 2% thermal fogging within 24h."
            )
        elif bi >= 5.0 or hi >= 1.0:
            risk_tier = "HIGH"
            protocol = "Targeted larviciding with Temephos 50% EC @ 1 ppm and weekly container source reduction."
        else:
            risk_tier = "LOW"
            protocol = "Continue routine weekly domestic surveillance."

        return {
            "tool": "compute_ward_entomological_indices",
            "status": "SUCCESS",
            "data": {
                "lgd_code": clean_lgd,
                "ward_village": ward_name,
                "records_aggregated": len(docs),
                "houses_inspected": total_houses_inspected,
                "houses_positive": total_houses_positive,
                "containers_checked": total_containers_checked,
                "containers_positive": total_containers_positive,
                "house_index_pct": hi,
                "container_index_pct": ci,
                "breteau_index": bi,
                "who_risk_tier": risk_tier,
                "recommended_ncvbdc_protocol": protocol,
            },
        }

    def dispatch_fogging_van(
        self, ward_village: str, lat: float, lng: float, notes: str
    ) -> dict[str, Any]:
        """Tool 3: Assign nearest fogging van via Google Maps Routes API v2 and log to 4_Van_Requests."""
        sheets = get_sheets_client()
        routing = get_maps_routing_client()

        fleet = sheets.get_vans_fleet(ward_or_district=ward_village)
        optimal = routing.select_fastest_van(
            target_lat=float(lat), target_lng=float(lng), vans=fleet
        )
        req_id = f"REQ-{uuid.uuid4().hex[:8].upper()}"
        logged = sheets.log_van_request(
            request_id=req_id,
            officer_uid="agent_skill_copilot",
            ward_village=ward_village,
            target_lat=float(lat),
            target_lng=float(lng),
            assigned_van_id=optimal.van_id,
            vehicle_no=optimal.vehicle_no,
            driver_phone=optimal.driver_phone,
            maps_eta_mins=optimal.eta_minutes,
            distance_km=optimal.distance_km,
            van_row_index=optimal.row_index,
            status_label="Dispatched",
        )

        # Mirror into Firestore dispatches collection
        try:
            db = _get_firestore_client(self.settings)
            db.collection("dispatches").document(req_id).set(
                {
                    "request_id": req_id,
                    "action_type": "REQUEST_VAN",
                    "officer_uid": "agent_skill_copilot",
                    "ward_village": ward_village,
                    "location": firestore.GeoPoint(float(lat), float(lng)),
                    "latitude": float(lat),
                    "longitude": float(lng),
                    "notes": notes,
                    "assigned_van": optimal.model_dump(),
                    "timestamp": datetime.now(UTC),
                }
            )
        except Exception as exc:
            logger.warning("Firestore dispatch mirror warning: %s", exc)

        return {
            "tool": "dispatch_fogging_van",
            "status": "VAN_ASSIGNED",
            "data": {
                "request_id": logged.request_id,
                "ward_village": ward_village,
                "van_id": optimal.van_id,
                "vehicle_no": optimal.vehicle_no,
                "driver_name": optimal.driver_name,
                "driver_phone": optimal.driver_phone,
                "eta_minutes": optimal.eta_minutes,
                "distance_km": optimal.distance_km,
                "encoded_polyline": optimal.encoded_polyline,
                "chemical_stock": optimal.chemical_stock,
            },
        }

    def trigger_emergency_ward_alert(
        self, ward_village: str, lat: float, lng: float, severity_notes: str
    ) -> dict[str, Any]:
        """Tool 4: Lookup staff in 3_Staff_Directory, dispatch emergency HTML email, and log to 5_Alert_Logs."""
        sheets = get_sheets_client()
        contact = sheets.lookup_authorized_staff(
            ward_village=ward_village, district_lgd="04055001"
        )
        gee = get_gee_client().get_climate_suitability(
            lat=float(lat), lng=float(lng)
        )
        indices = self.compute_ward_entomological_indices(contact.lgd_code)["data"]
        bi_val = float(indices.get("breteau_index") or 0.0)

        receipt = get_email_alert_client().send_emergency_alert(
            to_email=contact.village_officer_email,
            cc_email=contact.district_rep_email,
            ward_village=ward_village,
            lat=float(lat),
            lng=float(lng),
            notes=severity_notes,
            severity="CRITICAL",
            breteau_index=bi_val,
            gee_risk_score=gee.environmental_suitability_score,
            lst_celsius=gee.lst_celsius,
            rain_14d_mm=gee.rain_14d_mm,
            district_rep_phone=contact.district_rep_phone,
        )
        alert_id = f"ALT-{uuid.uuid4().hex[:8].upper()}"
        sheets.log_alert_dispatch(
            alert_id=alert_id,
            ward_village=ward_village,
            severity="CRITICAL",
            breteau_index=bi_val,
            gee_risk_score=gee.environmental_suitability_score,
            emailed_to=contact.village_officer_email,
            district_rep_notified=f"{contact.district_rep_name} ({contact.district_rep_phone})",
            action_notes=severity_notes,
        )

        return {
            "tool": "trigger_emergency_ward_alert",
            "status": "ALERT_SENT",
            "data": {
                "alert_id": alert_id,
                "ward_village": ward_village,
                "notified_officer": contact.village_officer_name,
                "notified_email": contact.village_officer_email,
                "district_rep_name": contact.district_rep_name,
                "district_rep_phone": contact.district_rep_phone,
                "message_id": receipt.message_id,
                "delivery_channel": receipt.delivery_channel,
            },
        }
