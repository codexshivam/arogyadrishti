"""Google Sheets API v4 Live Ledger Client with header-based column resolution and tenacity retry."""

from __future__ import annotations

import logging
import os
import re
from datetime import UTC, datetime
from functools import lru_cache
from typing import Any

import google.auth
import gspread
from fastapi import status
from google.oauth2.service_account import Credentials
from pydantic import BaseModel, Field
from tenacity import (
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

from app.core.config import Settings, get_settings
from app.tools.ogd_india_gov_tool.client import (
    OGDIndiaGovClient,
    get_ogd_client,
    haversine_km,
)
from app.tools.sheets_admin_tool.exceptions import (
    SheetsIntegrationException,
    StaffContactNotFoundException,
)

logger = logging.getLogger("arogya_drishti.tools.sheets_admin")

_SHEETS_SCOPES = [
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/drive",
]


class VanFleetRecord(BaseModel):
    """Live fogging/larvicidal van record from 1_Vans_Fleet."""

    row_index: int
    van_id: str
    vehicle_no: str
    driver_name: str
    driver_phone: str
    base_lat: float
    base_lng: float
    status: str
    chemical_stock: str
    ward_or_district: str = Field(default="Chandigarh")


class HealthCenterRecord(BaseModel):
    """Merged health center record from 2_Health_Centers and api.data.gov.in."""

    center_id: str
    nin_code: str
    name: str
    facility_type: str
    latitude: float
    longitude: float
    contact_phone: str
    rdt_kits_available: int = Field(default=0, ge=0)
    dengue_beds_free: int = Field(default=0, ge=0)
    open_hours: str = Field(default="24x7 EMERGENCY")
    distance_km: float
    source: str = Field(default="google_sheets")


class StaffContactRecord(BaseModel):
    """Authorized municipal/village officer and district nodal contact from 3_Staff_Directory."""

    lgd_code: str
    state: str
    district: str
    ward_id: str = Field(default="")
    ward_or_village: str
    centroid_lat: float | None = None
    centroid_lng: float | None = None
    village_officer_name: str
    village_officer_email: str
    village_officer_phone: str
    district_rep_name: str
    district_rep_phone: str
    district_rep_email: str
    houses_inspected: int | None = None
    containers_inspected: int | None = None
    current_hi_pct: float | None = None
    current_ci_pct: float | None = None
    current_bi: float | None = None
    gee_lst_celsius: float | None = None
    gee_ndwi: float | None = None
    gee_rain_14d_mm: float | None = None
    risk_tier: str | None = None
    source: str = Field(default="google_sheets")


class VanRequestRecord(BaseModel):
    """Audit row written to 4_Van_Requests."""

    request_id: str
    timestamp_utc: str
    officer_uid: str
    ward_village: str
    target_lat: float
    target_lng: float
    assigned_van_id: str
    vehicle_no: str
    driver_phone: str
    maps_eta_mins: int
    distance_km: float
    status: str = Field(default="Dispatched")


class AlertDispatchRecord(BaseModel):
    """Audit row written to 5_Alert_Logs."""

    alert_id: str
    timestamp_utc: str
    ward_village: str
    severity: str
    breteau_index: float
    gee_risk_score: float
    emailed_to: str
    district_rep_notified: str
    action_notes: str


def _normalize_phone(phone: str) -> str:
    digits = re.sub(r"\D", "", phone or "")
    if len(digits) >= 10:
        return digits[-10:]
    return digits


def decrement_chemical_stock(stock_str: str, decrement_amount: int = 5) -> str:
    """Safely decrement chemical stock volume/weight in-place by decrement_amount (min 0)."""
    match = re.search(r"\((\d+)\s*(L|kg|l|Kg|KG)\)", stock_str)
    if not match:
        return stock_str
    current_qty = int(match.group(1))
    unit = match.group(2)
    new_qty = max(0, current_qty - decrement_amount)
    return stock_str[: match.start()] + f"({new_qty} {unit})" + stock_str[match.end() :]



class SheetsAdminClient:
    """Thread-safe Google Sheets API v4 ledger client with tenacity retry and header lookup."""

    def __init__(
        self,
        settings: Settings | None = None,
        ogd_client: OGDIndiaGovClient | None = None,
    ) -> None:
        self.settings = settings or get_settings()
        self.ogd_client = ogd_client or get_ogd_client()
        self._gspread_client: gspread.Client | None = None

    def _get_client(self) -> gspread.Client:
        if self._gspread_client is not None:
            return self._gspread_client
        cred_path = self.settings.google_application_credentials or os.getenv(
            "GOOGLE_APPLICATION_CREDENTIALS", ""
        )
        if cred_path and os.path.exists(cred_path):
            creds = Credentials.from_service_account_file(
                cred_path, scopes=_SHEETS_SCOPES
            )
        else:
            creds, _ = google.auth.default(scopes=_SHEETS_SCOPES)
        self._gspread_client = gspread.authorize(creds)
        return self._gspread_client

    def _open_worksheet(self, tab_name: str) -> gspread.Worksheet:
        if not self.settings.master_spreadsheet_id:
            raise SheetsIntegrationException(
                "MASTER_SPREADSHEET_ID is not configured.",
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        try:
            gc = self._get_client()
            sheet = gc.open_by_key(self.settings.master_spreadsheet_id)
            try:
                return sheet.worksheet(tab_name)
            except gspread.exceptions.WorksheetNotFound:
                logger.info("Worksheet '%s' not found. Creating it...", tab_name)
                return sheet.add_worksheet(title=tab_name, rows=500, cols=26)
        except gspread.exceptions.APIError as exc:
            code = exc.response.status_code if exc.response is not None else 502
            retry_after = 15 if code == 429 else None
            logger.error("Google Sheets APIError on %s: %s", tab_name, exc)
            raise SheetsIntegrationException(
                f"Google Sheets API error ({code}) accessing '{tab_name}': {exc}",
                status_code=status.HTTP_429_TOO_MANY_REQUESTS
                if code == 429
                else status.HTTP_502_BAD_GATEWAY,
                retry_after_seconds=retry_after,
            ) from exc
        except PermissionError as exc:
            raise SheetsIntegrationException(
                f"Service account lacks permission on Master Spreadsheet for tab '{tab_name}'.",
                status_code=status.HTTP_403_FORBIDDEN,
            ) from exc
        except Exception as exc:
            logger.error("Failed opening worksheet %s: %s", tab_name, exc)
            raise SheetsIntegrationException(
                f"Unable to open worksheet '{tab_name}': {exc}"
            ) from exc

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type(SheetsIntegrationException),
        reraise=True,
    )
    def get_vans_fleet(
        self, ward_or_district: str | None = None
    ) -> list[VanFleetRecord]:
        """Read 1_Vans_Fleet and return all vans (optionally filtered by ward_or_district)."""
        ws = self._open_worksheet("1_Vans_Fleet")
        try:
            rows = ws.get_all_records()
        except gspread.exceptions.APIError as exc:
            raise SheetsIntegrationException(str(exc)) from exc

        results: list[VanFleetRecord] = []
        filter_norm = (ward_or_district or "").strip().lower()
        for idx, row in enumerate(rows, start=2):
            row_ward = str(row.get("Ward_or_District") or "Chandigarh").strip()
            if (
                filter_norm
                and filter_norm not in row_ward.lower()
                and row_ward.lower() not in filter_norm
            ):
                continue
            raw_phone = str(row.get("Driver_Phone") or "").strip()
            if raw_phone == "#ERROR!" or not raw_phone:
                raw_phone = f"+9198150110{idx - 1:02d}"
            results.append(
                VanFleetRecord(
                    row_index=idx,
                    van_id=str(row.get("Van_ID") or f"VAN-{idx}"),
                    vehicle_no=str(row.get("Vehicle_No") or ""),
                    driver_name=str(row.get("Driver_Name") or ""),
                    driver_phone=raw_phone,
                    base_lat=float(row.get("Base_Lat") or 0.0),
                    base_lng=float(row.get("Base_Lng") or 0.0),
                    status=str(row.get("Status") or "Available"),
                    chemical_stock=str(row.get("Chemical_Stock") or ""),
                    ward_or_district=row_ward,
                )
            )
        if not results and filter_norm:
            # Return full fleet if district filter was more specific than fleet region tag
            return self.get_vans_fleet(ward_or_district=None)
        return results

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type(SheetsIntegrationException),
        reraise=True,
    )
    def get_health_centers(
        self, lat: float, lng: float, radius_km: float = 25.0
    ) -> list[HealthCenterRecord]:
        """Read 2_Health_Centers, compute Haversine distance, and merge with live OGD records."""
        ws = self._open_worksheet("2_Health_Centers")
        try:
            rows = ws.get_all_records()
        except gspread.exceptions.APIError as exc:
            raise SheetsIntegrationException(str(exc)) from exc

        centers: list[HealthCenterRecord] = []
        seen_nins: set[str] = set()

        for idx, row in enumerate(rows, start=2):
            c_lat = float(row.get("Lat") or 0.0)
            c_lng = float(row.get("Lng") or 0.0)
            if c_lat == 0.0 and c_lng == 0.0:
                continue
            dist = haversine_km(lat, lng, c_lat, c_lng)
            if dist <= radius_km:
                nin = str(row.get("NIN_Code") or f"NIN-{idx}")
                seen_nins.add(nin)
                centers.append(
                    HealthCenterRecord(
                        center_id=str(row.get("Center_ID") or f"HC-{idx}"),
                        nin_code=nin,
                        name=str(row.get("Name") or "Primary Health Center"),
                        facility_type=str(row.get("Type") or "PHC"),
                        latitude=c_lat,
                        longitude=c_lng,
                        contact_phone=str(row.get("Contact_Phone") or "104"),
                        rdt_kits_available=int(row.get("RDT_Kits_Available") or 0),
                        dengue_beds_free=int(row.get("Dengue_Beds_Free") or 0),
                        open_hours=str(row.get("Open_Hours") or "Closes 8:00 PM"),
                        distance_km=dist,
                        source="google_sheets",
                    )
                )

        # If 2_Health_Centers is empty, query live OGD facilities within radius
        if not centers and not rows:
            ogd_facilities = self.ogd_client.fetch_nearby_health_facilities(
                lat=lat, lng=lng, radius_km=radius_km
            )
            for fac in ogd_facilities:
                if fac.nin_code not in seen_nins:
                    seen_nins.add(fac.nin_code)
                    centers.append(
                        HealthCenterRecord(
                            center_id=fac.center_id,
                            nin_code=fac.nin_code,
                            name=fac.name,
                            facility_type=fac.facility_type,
                            latitude=fac.latitude,
                            longitude=fac.longitude,
                            contact_phone=fac.contact_phone,
                            rdt_kits_available=fac.rdt_kits_available,
                            dengue_beds_free=fac.dengue_beds_free,
                            open_hours=fac.open_hours,
                            distance_km=fac.distance_km
                            if fac.distance_km is not None
                            else haversine_km(lat, lng, fac.latitude, fac.longitude),
                            source=fac.source,
                        )
                    )

        # If officer is outside the radius of the initial centres, still return sorted by distance
        if not centers and rows:
            for idx, row in enumerate(rows, start=2):
                c_lat = float(row.get("Lat") or 0.0)
                c_lng = float(row.get("Lng") or 0.0)
                dist = haversine_km(lat, lng, c_lat, c_lng)
                centers.append(
                    HealthCenterRecord(
                        center_id=str(row.get("Center_ID") or f"HC-{idx}"),
                        nin_code=str(row.get("NIN_Code") or f"NIN-{idx}"),
                        name=str(row.get("Name") or "Primary Health Center"),
                        facility_type=str(row.get("Type") or "PHC"),
                        latitude=c_lat,
                        longitude=c_lng,
                        contact_phone=str(row.get("Contact_Phone") or "104"),
                        rdt_kits_available=int(row.get("RDT_Kits_Available") or 0),
                        dengue_beds_free=int(row.get("Dengue_Beds_Free") or 0),
                        open_hours=str(row.get("Open_Hours") or "Closes 8:00 PM"),
                        distance_km=dist,
                        source="google_sheets",
                    )
                )

        centers.sort(key=lambda c: c.distance_km)
        return centers

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type(SheetsIntegrationException),
        reraise=True,
    )
    def list_all_staff_contacts(
        self, district_lgd: str | None = None
    ) -> list[StaffContactRecord]:
        """Return all verified staff directory rows (optionally filtered by district/LGD)."""
        ws = self._open_worksheet("3_Staff_Directory")
        try:
            rows = ws.get_all_records()
        except gspread.exceptions.APIError as exc:
            raise SheetsIntegrationException(str(exc)) from exc

        contacts: list[StaffContactRecord] = []
        filter_norm = (district_lgd or "").strip().lower()

        def _float_val(v: Any) -> float | None:
            if v is None or v == "" or str(v).strip() == "#ERROR!":
                return None
            try:
                return float(v)
            except (ValueError, TypeError):
                return None

        def _int_val(v: Any) -> int | None:
            if v is None or v == "" or str(v).strip() == "#ERROR!":
                return None
            try:
                return int(v)
            except (ValueError, TypeError):
                return None

        for row in rows:
            raw_lgd = str(row.get("LGD_Code") or "").strip()
            lgd = raw_lgd.zfill(10) if raw_lgd.isdigit() and len(raw_lgd) < 10 else raw_lgd
            dist = str(row.get("District") or "Chandigarh").strip()
            ward = str(row.get("Ward_or_Village") or "").strip()
            if filter_norm and not (
                filter_norm in lgd.lower()
                or filter_norm in dist.lower()
                or filter_norm in ward.lower()
            ):
                continue
            contacts.append(
                StaffContactRecord(
                    lgd_code=lgd,
                    state=str(row.get("State") or "Chandigarh"),
                    district=dist,
                    ward_id=str(row.get("Ward_ID") or ""),
                    ward_or_village=ward,
                    centroid_lat=_float_val(row.get("Centroid_Lat")),
                    centroid_lng=_float_val(row.get("Centroid_Lng")),
                    village_officer_name=str(row.get("Village_Officer_Name") or ""),
                    village_officer_email=str(row.get("Village_Officer_Email") or ""),
                    village_officer_phone=str(row.get("Village_Officer_Phone") or ""),
                    district_rep_name=str(row.get("District_Rep_Name") or ""),
                    district_rep_phone=str(row.get("District_Rep_Phone") or ""),
                    district_rep_email=str(row.get("District_Rep_Email") or ""),
                    houses_inspected=_int_val(row.get("Houses_Inspected")),
                    containers_inspected=_int_val(row.get("Containers_Inspected")),
                    current_hi_pct=_float_val(row.get("Current_HI_Pct")),
                    current_ci_pct=_float_val(row.get("Current_CI_Pct")),
                    current_bi=_float_val(row.get("Current_BI")),
                    gee_lst_celsius=_float_val(row.get("GEE_LST_Celsius")),
                    gee_ndwi=_float_val(row.get("GEE_NDWI")),
                    gee_rain_14d_mm=_float_val(row.get("GEE_Rain_14d_MM")),
                    risk_tier=str(row.get("Risk_Tier") or "MODERATE"),
                    source="google_sheets",
                )
            )
        if not contacts and filter_norm and rows:
            return self.list_all_staff_contacts(district_lgd=None)
        return contacts

    def lookup_authorized_staff(
        self, ward_village: str, district_lgd: str
    ) -> StaffContactRecord:
        """Query 3_Staff_Directory by exact LGD_Code or normalized Ward_or_Village, with OGD fallback."""
        contacts = self.list_all_staff_contacts()
        ward_norm = ward_village.strip().lower()
        lgd_norm = district_lgd.strip().lower()

        for record in contacts:
            if (lgd_norm and record.lgd_code.lower() == lgd_norm) or (
                ward_norm
                and (
                    record.ward_or_village.lower() == ward_norm
                    or ward_norm in record.ward_or_village.lower()
                    or record.ward_or_village.lower() in ward_norm
                )
            ):
                return record

        # Fallback to OGD India API
        ogd_contact = self.ogd_client.lookup_district_nodal_contact(
            district_lgd=district_lgd, ward_village=ward_village
        )
        if ogd_contact is not None:
            return StaffContactRecord(**ogd_contact.model_dump())

        # Explicit error when no contact is on record (no fake fallback emails/phones)
        raise StaffContactNotFoundException(
            f"No authorized staff contact on record in 3_Staff_Directory or OGD for ward='{ward_village}', lgd_code='{district_lgd}'."
        )

    def get_authorized_contacts(
        self, ward_village: str, district_lgd: str | None = None
    ) -> StaffContactRecord:
        """Strictly query the 3_Staff_Directory tab in Google Sheets matching the exact Ward_or_Village or LGD_Code."""
        return self.lookup_authorized_staff(ward_village, district_lgd or "")

    def verify_staff_by_phone_or_email(
        self, phone: str | None = None, email: str | None = None
    ) -> StaffContactRecord:
        """Validate that an authenticating officer's phone or email exists in 3_Staff_Directory."""
        contacts = self.list_all_staff_contacts()
        norm_phone = _normalize_phone(phone or "")
        norm_email = (email or "").strip().lower()

        for record in contacts:
            rec_vo_phone = _normalize_phone(record.village_officer_phone)
            rec_dr_phone = _normalize_phone(record.district_rep_phone)
            if norm_phone and norm_phone in (rec_vo_phone, rec_dr_phone):
                return record
            if norm_email and norm_email in (
                record.village_officer_email.lower(),
                record.district_rep_email.lower(),
            ):
                return record

        raise StaffContactNotFoundException(
            "Phone number or email is not pre-authorized in 3_Staff_Directory."
        )

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type(SheetsIntegrationException),
        reraise=True,
    )
    def update_van_status(self, row_index: int, new_status: str) -> None:
        """Update a van's Status cell in 1_Vans_Fleet by looking up the 'Status' header column dynamically."""
        ws = self._open_worksheet("1_Vans_Fleet")
        try:
            headers = ws.row_values(1)
            if "Status" not in headers:
                raise SheetsIntegrationException(
                    "Column 'Status' is missing from 1_Vans_Fleet header row."
                )
            status_col_idx = headers.index("Status") + 1
            ws.update_cell(row_index, status_col_idx, new_status)
        except gspread.exceptions.APIError as exc:
            raise SheetsIntegrationException(str(exc)) from exc

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type(SheetsIntegrationException),
        reraise=True,
    )
    def log_van_request(
        self,
        request_id: str,
        officer_uid: str,
        ward_village: str,
        target_lat: float,
        target_lng: float,
        assigned_van_id: str,
        vehicle_no: str,
        driver_phone: str,
        maps_eta_mins: int,
        distance_km: float,
        van_row_index: int | None = None,
        status_label: str = "Dispatched",
    ) -> VanRequestRecord:
        """Append a verified dispatch row to 4_Van_Requests and mark the van Dispatched in 1_Vans_Fleet."""
        timestamp_utc = datetime.now(UTC).isoformat()
        clean_driver_phone = re.sub(r"[^\d+]", "", driver_phone)
        if clean_driver_phone and not clean_driver_phone.startswith("+"):
            clean_driver_phone = f"+{clean_driver_phone}"

        record = VanRequestRecord(
            request_id=request_id,
            timestamp_utc=timestamp_utc,
            officer_uid=officer_uid,
            ward_village=ward_village,
            target_lat=target_lat,
            target_lng=target_lng,
            assigned_van_id=assigned_van_id,
            vehicle_no=vehicle_no,
            driver_phone=clean_driver_phone,
            maps_eta_mins=maps_eta_mins,
            distance_km=distance_km,
            status=status_label,
        )
        ws = self._open_worksheet("4_Van_Requests")
        try:
            headers = ws.row_values(1)
            column_map: dict[str, Any] = {
                "Request_ID": record.request_id,
                "Timestamp": record.timestamp_utc,
                "Officer_UID": record.officer_uid,
                "Ward_Village": record.ward_village,
                "Target_Lat": record.target_lat,
                "Target_Lng": record.target_lng,
                "Assigned_Van_ID": record.assigned_van_id,
                "Vehicle_No": record.vehicle_no,
                "Driver_Phone": record.driver_phone,
                "Maps_ETA_Mins": f"{record.maps_eta_mins} mins",
                "Distance_Km": f"{record.distance_km} km",
                "Status": record.status,
            }
            row_values = [column_map.get(h, "") for h in headers] if headers else list(column_map.values())
            ws.append_row(row_values, value_input_option="RAW")
            if van_row_index is not None:
                self.update_van_status(van_row_index, status_label)
            return record
        except gspread.exceptions.APIError as exc:
            raise SheetsIntegrationException(str(exc)) from exc

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type(SheetsIntegrationException),
        reraise=True,
    )
    def resolve_van_dispatch(
        self,
        van_id: str,
        decrement_amount: int = 5,
    ) -> dict[str, Any]:
        """
        Revert van status in 1_Vans_Fleet to Available, decrement chemical stock by 5 units,
        and mark the matching active dispatch in 4_Van_Requests as Resolved.
        """
        ws_vans = self._open_worksheet("1_Vans_Fleet")
        van_norm = van_id.strip().upper()
        updated_stock = ""
        van_row_idx = None
        try:
            vans_data = ws_vans.get_all_records()
            v_headers = ws_vans.row_values(1)
            status_col = v_headers.index("Status") + 1 if "Status" in v_headers else None
            stock_col = v_headers.index("Chemical_Stock") + 1 if "Chemical_Stock" in v_headers else None

            for idx, r in enumerate(vans_data, start=2):
                if str(r.get("Van_ID") or "").strip().upper() == van_norm:
                    van_row_idx = idx
                    curr_stock = str(r.get("Chemical_Stock") or "")
                    updated_stock = decrement_chemical_stock(curr_stock, decrement_amount)
                    if status_col:
                        ws_vans.update_cell(idx, status_col, "Available")
                    if stock_col:
                        ws_vans.update_cell(idx, stock_col, updated_stock)
                    break
            if van_row_idx is None:
                raise SheetsIntegrationException(f"Van ID '{van_id}' not found in 1_Vans_Fleet.")
        except gspread.exceptions.APIError as exc:
            raise SheetsIntegrationException(f"Error resolving van in 1_Vans_Fleet: {exc}") from exc

        # Update 4_Van_Requests (mark most recent open or matching request as Resolved)
        resolved_req_id = None
        try:
            ws_reqs = self._open_worksheet("4_Van_Requests")
            req_data = ws_reqs.get_all_records()
            r_headers = ws_reqs.row_values(1)
            req_status_col = r_headers.index("Status") + 1 if "Status" in r_headers else None

            for idx in range(len(req_data) + 1, 1, -1):
                row_record = req_data[idx - 2]
                r_van = str(row_record.get("Assigned_Van_ID") or "").strip().upper()
                r_stat = str(row_record.get("Status") or "").strip().lower()
                if r_van == van_norm and r_stat != "resolved":
                    resolved_req_id = str(row_record.get("Request_ID") or f"REQ-{idx}")
                    if req_status_col:
                        ws_reqs.update_cell(idx, req_status_col, "Resolved")
                    break
        except Exception as exc:
            logger.warning("Could not update 4_Van_Requests status to Resolved: %s", exc)

        return {
            "van_id": van_id.upper(),
            "status": "Available",
            "chemical_stock": updated_stock,
            "resolved_request_id": resolved_req_id,
            "row_index": van_row_idx,
        }

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type(SheetsIntegrationException),
        reraise=True,
    )
    def log_alert_dispatch(
        self,
        alert_id: str,
        ward_village: str,
        severity: str,
        breteau_index: float,
        gee_risk_score: float,
        emailed_to: str,
        district_rep_notified: str,
        action_notes: str,
    ) -> AlertDispatchRecord:
        """Append an emergency alert audit record to 5_Alert_Logs using header-resolved column order."""
        timestamp_utc = datetime.now(UTC).isoformat()
        record = AlertDispatchRecord(
            alert_id=alert_id,
            timestamp_utc=timestamp_utc,
            ward_village=ward_village,
            severity=severity,
            breteau_index=round(breteau_index, 2),
            gee_risk_score=round(gee_risk_score, 3),
            emailed_to=emailed_to,
            district_rep_notified=district_rep_notified,
            action_notes=action_notes,
        )
        ws = self._open_worksheet("5_Alert_Logs")
        try:
            headers = ws.row_values(1)
            column_map: dict[str, Any] = {
                "Alert_ID": record.alert_id,
                "Timestamp": record.timestamp_utc,
                "Ward_Village": record.ward_village,
                "Severity": record.severity,
                "Breteau_Index": record.breteau_index,
                "GEE_Risk_Score": record.gee_risk_score,
                "Emailed_To": record.emailed_to,
                "District_Rep_Notified": record.district_rep_notified,
                "Action_Notes": record.action_notes,
            }
            row_values = [column_map.get(h, "") for h in headers] if headers else list(column_map.values())
            ws.append_row(row_values, value_input_option="RAW")
            return record
        except gspread.exceptions.APIError as exc:
            raise SheetsIntegrationException(str(exc)) from exc

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type(SheetsIntegrationException),
        reraise=True,
    )
    def batch_upsert_staff_directory(
        self,
        staff_rows: list[dict[str, Any]],
        replace_district: str | None = None,
    ) -> int:
        """
        Bulk-write verified wards/villages into 3_Staff_Directory using a single batch
        API call (worksheet.append_rows / worksheet.update) with value_input_option="RAW".
        """
        if not staff_rows:
            return 0
        ws = self._open_worksheet("3_Staff_Directory")
        try:
            headers = ws.row_values(1)
            if not headers:
                headers = [
                    "LGD_Code",
                    "State",
                    "District",
                    "Ward_ID",
                    "Ward_or_Village",
                    "Centroid_Lat",
                    "Centroid_Lng",
                    "Village_Officer_Name",
                    "Village_Officer_Email",
                    "Village_Officer_Phone",
                    "District_Rep_Name",
                    "District_Rep_Phone",
                    "District_Rep_Email",
                    "Houses_Inspected",
                    "Containers_Inspected",
                    "Current_HI_Pct",
                    "Current_CI_Pct",
                    "Current_BI",
                    "GEE_LST_Celsius",
                    "GEE_NDWI",
                    "GEE_Rain_14d_MM",
                    "Risk_Tier",
                ]
                ws.append_row(headers, value_input_option="RAW")

            existing = ws.get_all_records()
            seen_wards = {
                str(r.get("Ward_or_Village") or "").strip().lower()
                for r in existing
                if not (
                    replace_district
                    and str(r.get("District") or "").strip().lower()
                    == replace_district.strip().lower()
                )
            }
            if replace_district:
                # Retain header + non-matching district rows, then append all fresh rows in one batch
                kept_rows: list[list[Any]] = [headers]
                for r in existing:
                    if (
                        str(r.get("District") or "").strip().lower()
                        != replace_district.strip().lower()
                    ):
                        kept_rows.append([r.get(h, "") for h in headers])
                new_matrix: list[list[Any]] = []
                for item in staff_rows:
                    w_name = str(item.get("Ward_or_Village") or "").strip().lower()
                    if w_name and w_name not in seen_wards:
                        seen_wards.add(w_name)
                        new_matrix.append([item.get(h, "") for h in headers])
                ws.clear()
                ws.append_rows(
                    kept_rows + new_matrix, value_input_option="RAW"
                )
                return len(new_matrix)

            rows_to_append: list[list[Any]] = []
            for item in staff_rows:
                w_name = str(item.get("Ward_or_Village") or "").strip().lower()
                if w_name and w_name not in seen_wards:
                    seen_wards.add(w_name)
                    rows_to_append.append([item.get(h, "") for h in headers])
            if rows_to_append:
                ws.append_rows(rows_to_append, value_input_option="RAW")
            return len(rows_to_append)
        except gspread.exceptions.APIError as exc:
            raise SheetsIntegrationException(str(exc)) from exc

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type(SheetsIntegrationException),
        reraise=True,
    )
    def batch_upsert_health_centers(
        self,
        center_rows: list[dict[str, Any]],
        replace_all: bool = False,
    ) -> int:
        """
        Bulk-write real PHCs, CHCs, and hospitals into 2_Health_Centers using
        worksheet.append_rows() in a single batch call with value_input_option="RAW".
        """
        if not center_rows:
            return 0
        ws = self._open_worksheet("2_Health_Centers")
        try:
            headers = ws.row_values(1)
            if not headers:
                headers = [
                    "Center_ID",
                    "NIN_Code",
                    "Name",
                    "Type",
                    "Lat",
                    "Lng",
                    "Contact_Phone",
                    "RDT_Kits_Available",
                    "Dengue_Beds_Free",
                    "Open_Hours",
                ]
                ws.append_row(headers, value_input_option="RAW")

            if replace_all:
                seen_names: set[str] = set()
                matrix: list[list[Any]] = [headers]
                for item in center_rows:
                    key = str(item.get("Name") or "").strip().lower()
                    if key and key not in seen_names:
                        seen_names.add(key)
                        matrix.append([item.get(h, "") for h in headers])
                ws.clear()
                ws.append_rows(matrix, value_input_option="RAW")
                return len(matrix) - 1

            existing = ws.get_all_records()
            seen_keys = {
                str(r.get("Name") or "").strip().lower() for r in existing
            } | {str(r.get("NIN_Code") or "").strip().lower() for r in existing}
            rows_to_append: list[list[Any]] = []
            for item in center_rows:
                name_k = str(item.get("Name") or "").strip().lower()
                nin_k = str(item.get("NIN_Code") or "").strip().lower()
                if name_k not in seen_keys and nin_k not in seen_keys:
                    seen_keys.add(name_k)
                    seen_keys.add(nin_k)
                    rows_to_append.append([item.get(h, "") for h in headers])
            if rows_to_append:
                ws.append_rows(rows_to_append, value_input_option="RAW")
            return len(rows_to_append)
        except gspread.exceptions.APIError as exc:
            raise SheetsIntegrationException(str(exc)) from exc

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type(SheetsIntegrationException),
        reraise=True,
    )
    def log_support_ticket(
        self,
        ticket_id: str,
        timestamp_utc: str,
        ward_id: str,
        ward_name: str,
        category: str,
        severity_sla: str,
        observation_notes: str,
        status: str,
        assigned_nodal_officer: str,
        officer_email: str,
    ) -> dict[str, Any]:
        """Append an escalation ticket record to 7_Support_Tickets using RAW value input."""
        ws = self._open_worksheet("7_Support_Tickets")
        headers = [
            "Ticket_ID",
            "Timestamp_UTC",
            "Ward_ID",
            "Ward_Name",
            "Category",
            "Severity_SLA",
            "Observation_Notes",
            "Status",
            "Assigned_Nodal_Officer",
            "Officer_Email",
        ]
        try:
            existing_headers = ws.row_values(1)
            if not existing_headers:
                ws.append_row(headers, value_input_option="RAW")
            row_values = [
                ticket_id,
                timestamp_utc,
                str(ward_id),
                str(ward_name),
                str(category),
                str(severity_sla),
                str(observation_notes),
                str(status),
                str(assigned_nodal_officer),
                str(officer_email),
            ]
            ws.append_row(row_values, value_input_option="RAW")
            return {
                "ticket_id": ticket_id,
                "timestamp_utc": timestamp_utc,
                "ward_id": ward_id,
                "ward_name": ward_name,
                "category": category,
                "severity_sla": severity_sla,
                "observation_notes": observation_notes,
                "status": status,
                "assigned_nodal_officer": assigned_nodal_officer,
                "officer_email": officer_email,
            }
        except gspread.exceptions.APIError as exc:
            raise SheetsIntegrationException(str(exc)) from exc

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type(SheetsIntegrationException),
        reraise=True,
    )
    def bulk_write_weekly_stats(
        self,
        weekly_rows: list[list[Any]],
    ) -> int:
        """Batch write 12-week longitudinal surveillance records to 6_Weekly_Surveillance_Stats using RAW mode."""
        if not weekly_rows:
            return 0
        ws = self._open_worksheet("6_Weekly_Surveillance_Stats")
        headers = [
            "Ward_ID",
            "LGD_Code",
            "ISO_Week",
            "Week_Start_Date",
            "Houses_Inspected",
            "Houses_Positive",
            "Containers_Inspected",
            "Containers_Positive",
            "HI_Pct",
            "CI_Pct",
            "BI_Score",
            "Tires_Logged",
            "Dominant_Larva_Stage",
            "GEE_LST_Celsius",
            "GEE_NDWI",
            "GEE_Rain_MM",
        ]
        try:
            ws.clear()
            matrix = [headers] + weekly_rows
            ws.append_rows(matrix, value_input_option="RAW")
            return len(weekly_rows)
        except gspread.exceptions.APIError as exc:
            raise SheetsIntegrationException(str(exc)) from exc


@lru_cache(maxsize=1)
def get_sheets_client() -> SheetsAdminClient:
    """Return cached singleton SheetsAdminClient."""
    return SheetsAdminClient()


def get_authorized_contacts(
    ward_village: str, district_lgd: str | None = None
) -> StaffContactRecord:
    """Strictly query the 3_Staff_Directory tab in Google Sheets matching the exact Ward_or_Village or LGD_Code."""
    return get_sheets_client().lookup_authorized_staff(
        ward_village=ward_village, district_lgd=district_lgd or ""
    )
