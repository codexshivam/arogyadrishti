"""Live Open Government Data (api.data.gov.in) Catalog Discovery, LGD, Health Directory & NVBDCP Client."""

from __future__ import annotations

import logging
import math
from functools import lru_cache
from typing import Any

import httpx
from fastapi import status
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

_OGD_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
    ),
    "Accept": "application/json",
}


class OGDHealthFacility(BaseModel):
    """Geocoded PHC/CHC/Hospital record from Open Government Data India & OSM."""

    center_id: str
    nin_code: str
    name: str
    facility_type: str
    latitude: float
    longitude: float
    contact_phone: str
    address: str = Field(default="")
    operator_type: str = Field(default="government")
    rdt_kits_available: int = Field(default=0, ge=0)
    dengue_beds_free: int = Field(default=0, ge=0)
    open_hours: str = Field(default="24x7")
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
    return round(
        2.0 * radius_earth_km * math.atan2(math.sqrt(a), math.sqrt(1.0 - a)), 2
    )


def _parse_float(val: Any) -> float | None:
    if val is None:
        return None
    s = str(val).strip()
    if not s or s.upper() in ("NA", "N/A", "NULL", "NONE"):
        return None
    try:
        num = float(s)
        if math.isnan(num) or math.isinf(num):
            return None
        return num
    except (ValueError, TypeError):
        return None


def _parse_int(val: Any) -> int:
    if val is None:
        return 0
    s = str(val).strip()
    if not s or s.upper() in ("NA", "N/A", "NULL", "NONE"):
        return 0
    try:
        return max(0, int(float(s)))
    except (ValueError, TypeError):
        return 0


class OGDIndiaGovClient:
    """Client for querying api.data.gov.in OGD resources and catalog discovery."""

    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()
        self.base_url = "https://api.data.gov.in/resource"
        self.catalog_url = "https://api.data.gov.in/lists"

    def _require_api_key(self) -> str:
        if not self.settings.data_gov_in_api_key:
            raise OGDIntegrationException(
                "DATA_GOV_IN_API_KEY is not configured in environment.",
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        return self.settings.data_gov_in_api_key

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type((httpx.RequestError, httpx.TimeoutException)),
        reraise=True,
    )
    def discover_catalog_resources(
        self, title_query: str, limit: int = 20
    ) -> list[dict[str, Any]]:
        """Query the live OGD India Catalog API (/lists) to discover dataset UUID resource_ids."""
        api_key = self._require_api_key()
        params = {
            "api-key": api_key,
            "format": "json",
            "limit": limit,
            "filters[title]": title_query,
        }
        with httpx.Client(timeout=15.0, headers=_OGD_HEADERS) as client:
            resp = client.get(self.catalog_url, params=params)
            if resp.status_code != 200:
                raise OGDIntegrationException(
                    f"OGD Catalog Discovery failed with HTTP {resp.status_code}: {resp.text}"
                )
            data = resp.json()
            records: list[dict[str, Any]] = data.get("records") or []
            return records

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type((httpx.RequestError, httpx.TimeoutException)),
        reraise=True,
    )
    def _fetch_ogd_resource(
        self,
        resource_id: str,
        params: dict[str, Any] | None = None,
        limit: int = 1000,
        offset: int = 0,
    ) -> dict[str, Any]:
        """Execute a live REST call against https://api.data.gov.in/resource/{resource_id}."""
        api_key = self._require_api_key()
        query_params: dict[str, Any] = {
            "api-key": api_key,
            "format": "json",
            "limit": limit,
            "offset": offset,
        }
        if params:
            query_params.update(params)

        with httpx.Client(timeout=20.0, headers=_OGD_HEADERS) as client:
            response = client.get(
                f"{self.base_url}/{resource_id}", params=query_params
            )
            if response.status_code != 200:
                raise OGDIntegrationException(
                    f"api.data.gov.in returned HTTP {response.status_code} for resource {resource_id}: {response.text}"
                )
            data: dict[str, Any] = response.json()
            if data.get("status") == "error":
                raise OGDIntegrationException(
                    f"api.data.gov.in error on resource {resource_id}: {data.get('message')}"
                )
            return data

    def fetch_all_paginated_records(
        self,
        resource_id: str,
        filters: dict[str, Any] | None = None,
        page_size: int = 500,
        max_records: int = 2500,
    ) -> list[dict[str, Any]]:
        """Paginate through an OGD resource using limit & offset until all records are fetched."""
        all_records: list[dict[str, Any]] = []
        offset = 0
        while offset < max_records:
            payload = self._fetch_ogd_resource(
                resource_id=resource_id,
                params=filters,
                limit=page_size,
                offset=offset,
            )
            batch = payload.get("records") or []
            if not isinstance(batch, list) or not batch:
                break
            all_records.extend(batch)
            total = _parse_int(payload.get("total"))
            offset += len(batch)
            if len(batch) < page_size or (total > 0 and offset >= total):
                break
        return all_records

    def fetch_state_localities_and_lgd(
        self, state_name: str, district_name: str | None = None
    ) -> list[dict[str, Any]]:
        """
        Fetch real villages, sectors, and localities along with official LGD metadata
        from api.data.gov.in (OGD_PINCODE_LGD_RESOURCE_ID + LGD Local Bodies / Sub-Districts).
        """
        state_clean = state_name.strip()
        # 1. Fetch official LGD Local Bodies & Sub-Districts for the state to anchor LGD prefix
        lgd_local_bodies = self.fetch_all_paginated_records(
            self.settings.ogd_lgd_local_bodies_resource_id,
            filters={"filters[stateNameEnglish]": state_clean},
            page_size=500,
        )
        base_lgd_code = "276386"
        if lgd_local_bodies:
            first_lb = lgd_local_bodies[0]
            raw_code = str(first_lb.get("localBodyCode") or "").strip()
            if raw_code:
                base_lgd_code = raw_code

        # 2. Fetch all locality/village/sector records from OGD All India Locality Directory
        pincode_records = self.fetch_all_paginated_records(
            self.settings.ogd_pincode_lgd_resource_id,
            filters={"filters[statename]": state_clean.upper()},
            page_size=500,
        )
        if not pincode_records:
            # Try title-case filter if uppercase returned empty
            pincode_records = self.fetch_all_paginated_records(
                self.settings.ogd_pincode_lgd_resource_id,
                filters={"filters[statename]": state_clean},
                page_size=500,
            )

        normalized: list[dict[str, Any]] = []
        seen_names: set[str] = set()
        dist_filter = (district_name or "").strip().lower()

        for idx, rec in enumerate(pincode_records, start=1):
            rec_dist = str(rec.get("district") or state_clean).strip()
            if (
                dist_filter
                and dist_filter not in rec_dist.lower()
                and rec_dist.lower() not in dist_filter
            ):
                continue

            raw_office = str(rec.get("officename") or "").strip()
            # Clean postal suffixes (" S.O", " B.O", " H.O", "(Chandigarh)") into canonical locality/ward/village name
            clean_name = (
                raw_office.replace(" S.O (Chandigarh)", "")
                .replace(" S.O", "")
                .replace(" B.O", "")
                .replace(" H.O", "")
                .replace("(Chandigarh)", "")
                .strip()
            )
            if not clean_name:
                continue
            name_key = clean_name.lower()
            if name_key in seen_names:
                continue
            seen_names.add(name_key)

            lat = _parse_float(rec.get("latitude"))
            lng = _parse_float(rec.get("longitude"))
            # Validate coordinates are plausible WGS84 in India (lat 6..38, lng 68..98)
            if lat is not None and not (6.0 <= lat <= 38.0):
                lat = None
            if lng is not None and not (68.0 <= lng <= 98.0):
                lng = None

            pincode = str(rec.get("pincode") or "").strip()
            division_name = str(rec.get("divisionname") or "").strip()
            region_name = str(rec.get("regionname") or "").strip()
            pin_part = pincode if pincode else f"{idx:03d}"
            lgd_code = f"LGD-{base_lgd_code}-{pin_part}-{idx:03d}"

            normalized.append(
                {
                    "lgd_code": lgd_code,
                    "local_body_code": base_lgd_code,
                    "name": clean_name,
                    "raw_officename": raw_office,
                    "pincode": pincode,
                    "district": rec_dist.title(),
                    "state": state_clean.title(),
                    "sub_district": division_name or region_name or rec_dist.title(),
                    "latitude": lat,
                    "longitude": lng,
                    "source": "api.data.gov.in",
                }
            )

        return normalized

    def fetch_state_health_facilities(
        self, state_name: str, district_name: str | None = None
    ) -> list[OGDHealthFacility]:
        """
        Query both NIN Health Centres Directory (OGD_HEALTH_DIRECTORY_RESOURCE_ID)
        and National Hospital Geo Directory (OGD_HOSPITAL_DIRECTORY_RESOURCE_ID)
        on api.data.gov.in for a given state and optional district.
        """
        state_clean = state_name.strip()
        dist_filter = (district_name or "").strip().lower()
        facilities: list[OGDHealthFacility] = []
        seen_keys: set[str] = set()

        # 1. NIN Health Centres Directory (PHCs, CHCs, Sub-Centres, District Hospitals)
        nin_records = self.fetch_all_paginated_records(
            self.settings.ogd_health_directory_resource_id,
            filters={"filters[state_name]": state_clean},
            page_size=500,
        )
        for idx, rec in enumerate(nin_records, start=1):
            rec_dist = str(rec.get("district_name") or state_clean).strip()
            if (
                dist_filter
                and dist_filter not in rec_dist.lower()
                and rec_dist.lower() not in dist_filter
            ):
                continue
            lat = _parse_float(rec.get("_latitude") or rec.get("latitude"))
            lng = _parse_float(rec.get("_longitude") or rec.get("longitude"))
            if lat is None or lng is None or not (6.0 <= lat <= 38.0 and 68.0 <= lng <= 98.0):
                continue

            nin_code = str(rec.get("nin_n") or rec.get("nin_code") or "").strip()
            name = str(rec.get("facility_name") or "").strip()
            if not name:
                continue
            dedup_key = nin_code or f"{name.lower()}_{round(lat, 4)}_{round(lng, 4)}"
            if dedup_key in seen_keys:
                continue
            seen_keys.add(dedup_key)

            raw_type = str(rec.get("facility_type") or "PHC").strip().upper()
            if raw_type == "DIS_H":
                fac_type = "District Hospital"
            elif raw_type in ("SUB_CEN", "SC"):
                fac_type = "Sub-Center"
            else:
                fac_type = raw_type

            address = str(
                rec.get("facility_address")
                or rec.get("Town")
                or rec.get("village_name")
                or rec_dist
            ).strip()
            op_type = str(rec.get("type_of_facility") or "Public").strip().lower()
            phone = str(rec.get("telephone") or rec.get("mobile") or "104").strip()
            if phone.upper() in ("NA", "N/A", "0", "NULL", "NONE", ""):
                phone = "104"

            facilities.append(
                OGDHealthFacility(
                    center_id=f"OGD-NIN-{nin_code or idx}",
                    nin_code=nin_code or f"OGD-{idx:04d}",
                    name=name,
                    facility_type=fac_type,
                    latitude=round(lat, 6),
                    longitude=round(lng, 6),
                    contact_phone=phone,
                    address=address,
                    operator_type="government" if "pub" in op_type or "gov" in op_type else op_type,
                    rdt_kits_available=_parse_int(rec.get("rdt_kits")),
                    dengue_beds_free=_parse_int(rec.get("beds")),
                    open_hours="24x7",
                    source="api.data.gov.in",
                )
            )

        # 2. National Hospital Directory with Geo Code (has phone numbers & exact coordinates)
        hosp_records = self.fetch_all_paginated_records(
            self.settings.ogd_hospital_directory_resource_id,
            filters={"filters[state]": state_clean},
            page_size=500,
        )
        for idx, rec in enumerate(hosp_records, start=1):
            rec_dist = str(rec.get("district") or state_clean).strip()
            if (
                dist_filter
                and dist_filter not in rec_dist.lower()
                and rec_dist.lower() not in dist_filter
            ):
                continue
            coords_raw = str(rec.get("_location_coordinates") or "").strip()
            lat: float | None = None
            lng: float | None = None
            if "," in coords_raw:
                parts = coords_raw.split(",")
                lat = _parse_float(parts[0])
                lng = _parse_float(parts[1])
            if lat is None or lng is None or not (6.0 <= lat <= 38.0 and 68.0 <= lng <= 98.0):
                continue

            name = str(rec.get("hospital_name") or "").strip()
            if not name:
                continue
            sr_no = str(rec.get("sr_no") or idx).strip()
            nin_code = f"NHP-{sr_no}"
            dedup_key = f"{name.lower()}_{round(lat, 3)}_{round(lng, 3)}"
            if dedup_key in seen_keys:
                continue
            seen_keys.add(dedup_key)

            phone_raw = str(
                rec.get("telephone")
                or rec.get("mobile_number")
                or rec.get("emergency_num")
                or "104"
            ).strip()
            if phone_raw.upper() in ("NA", "N/A", "0", "NULL", "NONE", ""):
                phone_raw = "104"
            else:
                phone_raw = phone_raw.split(",")[0].strip()

            cat_raw = str(rec.get("hospital_category") or "Public").strip()
            address = str(rec.get("address_original_first_line") or rec_dist).strip()
            total_beds = _parse_int(rec.get("total_num_beds"))

            facilities.append(
                OGDHealthFacility(
                    center_id=f"OGD-NHP-{sr_no}",
                    nin_code=nin_code,
                    name=name,
                    facility_type=cat_raw if cat_raw and cat_raw != "0" else "Government Hospital",
                    latitude=round(lat, 6),
                    longitude=round(lng, 6),
                    contact_phone=phone_raw,
                    address=address,
                    operator_type="government"
                    if any(k in cat_raw.lower() for k in ("pub", "gov", "dispensary", "phc", "chc"))
                    else "hospital",
                    rdt_kits_available=0,
                    dengue_beds_free=total_beds,
                    open_hours="24x7",
                    source="api.data.gov.in",
                )
            )

        return facilities

    def fetch_nvbdcp_surveillance_records(
        self, state_name: str | None = None
    ) -> list[dict[str, Any]]:
        """Fetch official NVBDCP vector-borne disease surveillance records from api.data.gov.in."""
        records = self.fetch_all_paginated_records(
            self.settings.ogd_nvbdcp_cases_resource_id,
            page_size=200,
        )
        if not state_name:
            return records
        target = state_name.strip().lower()
        return [
            r
            for r in records
            if target in str(r.get("states___uts") or r.get("state") or "").lower()
        ]

    def fetch_nearby_health_facilities(
        self,
        lat: float,
        lng: float,
        radius_km: float = 15.0,
        state_name: str = "Chandigarh",
    ) -> list[OGDHealthFacility]:
        """Fetch geocoded PHCs/CHCs/Hospitals from api.data.gov.in within radius_km."""
        all_state_facilities = self.fetch_state_health_facilities(state_name=state_name)
        nearby: list[OGDHealthFacility] = []
        for fac in all_state_facilities:
            dist = haversine_km(lat, lng, fac.latitude, fac.longitude)
            if dist <= radius_km:
                nearby.append(fac.model_copy(update={"distance_km": dist}))
        nearby.sort(key=lambda f: f.distance_km or 0.0)
        return nearby

    def lookup_district_nodal_contact(
        self, district_lgd: str, ward_village: str = ""
    ) -> OGDNodalContact | None:
        """Query api.data.gov.in LGD Local Bodies directory for a district/ward nodal record."""
        records = self.fetch_all_paginated_records(
            self.settings.ogd_lgd_local_bodies_resource_id,
            filters={"filters[localBodyCode]": district_lgd},
            page_size=50,
        )
        if not records:
            return None
        rec = records[0]
        vo_email = str(rec.get("bmo_email") or rec.get("email") or "").strip()
        dr_email = str(rec.get("cmo_email") or rec.get("nodal_email") or "").strip()
        if not vo_email and not dr_email:
            return None

        return OGDNodalContact(
            lgd_code=district_lgd,
            state=str(rec.get("stateNameEnglish") or ""),
            district=str(rec.get("localBodyNameEnglish") or ""),
            ward_or_village=ward_village or str(rec.get("localBodyNameEnglish") or ""),
            village_officer_name=str(rec.get("bmo_name") or ""),
            village_officer_email=vo_email,
            village_officer_phone=str(rec.get("bmo_phone") or ""),
            district_rep_name=str(rec.get("cmo_name") or ""),
            district_rep_phone=str(rec.get("cmo_phone") or ""),
            district_rep_email=dr_email,
            source="api.data.gov.in",
        )


@lru_cache(maxsize=1)
def get_ogd_client() -> OGDIndiaGovClient:
    """Return singleton OGDIndiaGovClient."""
    return OGDIndiaGovClient()
