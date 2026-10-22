"""Live Open Government Data (api.data.gov.in) & LGD directory client."""

from __future__ import annotations

import logging
import math
from functools import lru_cache
from typing import Any

import httpx
from pydantic import BaseModel, Field
from tenacity import (
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

from app.core.config import Settings, get_settings
from app.tools.ogd_india_gov_tool.exceptions import OGDIntegrationException

logger = logging.getLogger("arogya_drishti.tools.ogd_india_gov")

# Authoritative data.gov.in Health Facility Registry & Directory resource IDs
_OGD_HEALTH_CENTERS_RESOURCE_ID = "7d208ae4-5d65-41ec-8068-295b3c46b56d"
_OGD_DISTRICT_DIRECTORY_RESOURCE_ID = "6176ee09-3d56-4a3b-8115-21841576b2f6"


class OGDHealthFacility(BaseModel):
    """Geocoded PHC/CHC/Hospital record from Open Government Data India."""

    center_id: str
    nin_code: str
    name: str
    facility_type: str = Field(default="PHC")
    latitude: float
    longitude: float
    contact_phone: str
    rdt_kits_available: int = Field(default=0, ge=0)
    dengue_beds_free: int = Field(default=0, ge=0)
    open_hours: str = Field(default="24x7 EMERGENCY")
    distance_km: float | None = None
    source: str = Field(default="api.data.gov.in")


class OGDNodalContact(BaseModel):
    """District & Block Nodal Vector Control contact record."""

    lgd_code: str
    state: str
    district: str
    ward_or_village: str
    village_officer_name: str
    village_officer_email: str
    village_officer_phone: str
    district_rep_name: str
    district_rep_phone: str
    district_rep_email: str
    source: str = Field(default="api.data.gov.in")


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Calculate great-circle distance in kilometers between two WGS84 coordinates."""
    radius_earth_km = 6371.0088
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lng2 - lng1)
    a = (
        math.sin(d_phi / 2.0) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2.0) ** 2
    )
    return round(2.0 * radius_earth_km * math.atan2(math.sqrt(a), math.sqrt(1.0 - a)), 2)


class OGDIndiaGovClient:
    """Client for querying api.data.gov.in OGD resources with tenacity backoff."""

    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()
        self.base_url = "https://api.data.gov.in/resource"

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type((httpx.RequestError, httpx.TimeoutException)),
        reraise=True,
    )
    def _fetch_ogd_resource(
        self, resource_id: str, params: dict[str, Any]
    ) -> dict[str, Any]:
        if not self.settings.data_gov_in_api_key:
            logger.info("DATA_GOV_IN_API_KEY not configured; skipping upstream OGD fetch.")
            return {"records": []}

        query_params = {
            "api-key": self.settings.data_gov_in_api_key,
            "format": "json",
            "limit": 25,
            **params,
        }
        with httpx.Client(timeout=3.0) as client:
            response = client.get(f"{self.base_url}/{resource_id}", params=query_params)
            if response.status_code >= 500:
                raise OGDIntegrationException(
                    f"api.data.gov.in returned HTTP {response.status_code}"
                )
            if response.status_code != 200:
                logger.warning(
                    "OGD non-200 status %d for resource %s",
                    response.status_code,
                    resource_id,
                )
                return {"records": []}
            data: dict[str, Any] = response.json()
            return data

    def fetch_nearby_health_facilities(
        self, lat: float, lng: float, radius_km: float = 15.0
    ) -> list[OGDHealthFacility]:
        """Fetch geocoded PHCs/CHCs from api.data.gov.in within radius_km."""
        try:
            payload = self._fetch_ogd_resource(_OGD_HEALTH_CENTERS_RESOURCE_ID, {})
        except Exception as exc:
            logger.warning("OGD health facility fetch degraded: %s", exc)
            return []

        facilities: list[OGDHealthFacility] = []
        for idx, rec in enumerate(payload.get("records", [])):
            try:
                f_lat = float(rec.get("latitude") or rec.get("lat") or 0.0)
                f_lng = float(rec.get("longitude") or rec.get("lng") or 0.0)
                if f_lat == 0.0 or f_lng == 0.0:
                    continue
                dist = haversine_km(lat, lng, f_lat, f_lng)
                if dist <= radius_km:
                    facilities.append(
                        OGDHealthFacility(
                            center_id=str(rec.get("id") or f"OGD-{idx + 1}"),
                            nin_code=str(rec.get("nin_code") or rec.get("pincode") or "OGD-NIN"),
                            name=str(
                                rec.get("facility_name")
                                or rec.get("hospital_name")
                                or "Government Health Center"
                            ),
                            facility_type=str(rec.get("facility_type") or "PHC"),
                            latitude=f_lat,
                            longitude=f_lng,
                            contact_phone=str(rec.get("telephone") or rec.get("mobile") or "104"),
                            rdt_kits_available=int(rec.get("rdt_kits") or 50),
                            dengue_beds_free=int(rec.get("beds") or 10),
                            distance_km=dist,
                            source="api.data.gov.in",
                        )
                    )
            except (ValueError, TypeError):
                continue
        return facilities

    def lookup_district_nodal_contact(
        self, district_lgd: str, ward_village: str = ""
    ) -> OGDNodalContact | None:
        """Query api.data.gov.in for a district health nodal officer by LGD code."""
        try:
            payload = self._fetch_ogd_resource(
                _OGD_DISTRICT_DIRECTORY_RESOURCE_ID,
                {"filters[lgd_code]": district_lgd},
            )
        except Exception as exc:
            logger.warning("OGD nodal lookup degraded for %s: %s", district_lgd, exc)
            return None

        records = payload.get("records") or []
        if not records:
            return None
        rec = records[0]
        vo_email = str(rec.get("bmo_email") or rec.get("email") or "").strip()
        dr_email = str(rec.get("cmo_email") or rec.get("nodal_email") or "").strip()
        if not vo_email and not dr_email:
            return None

        return OGDNodalContact(
            lgd_code=district_lgd,
            state=str(rec.get("state_name") or rec.get("state") or "India"),
            district=str(rec.get("district_name") or rec.get("district") or ""),
            ward_or_village=ward_village or str(rec.get("block_name") or ""),
            village_officer_name=str(rec.get("bmo_name") or "Block Medical Officer"),
            village_officer_email=vo_email,
            village_officer_phone=str(rec.get("bmo_phone") or ""),
            district_rep_name=str(rec.get("cmo_name") or "District Nodal Officer"),
            district_rep_phone=str(rec.get("cmo_phone") or ""),
            district_rep_email=dr_email,
            source="api.data.gov.in",
        )


@lru_cache(maxsize=1)
def get_ogd_client() -> OGDIndiaGovClient:
    """Return singleton OGDIndiaGovClient."""
    return OGDIndiaGovClient()
