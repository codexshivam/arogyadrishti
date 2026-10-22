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
    ward_or_village: str
    village_officer_name: str
    village_officer_email: str
    village_officer_phone: str
    district_rep_name: str
    district_rep_phone: str
    district_rep_email: str
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
            return sheet.worksheet(tab_name)
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
            results.append(
                VanFleetRecord(
                    row_index=idx,
                    van_id=str(row.get("Van_ID") or f"VAN-{idx}"),
                    vehicle_no=str(row.get("Vehicle_No") or ""),
                    driver_name=str(row.get("Driver_Name") or ""),
                    driver_phone=str(row.get("Driver_Phone") or ""),
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

        # Merge live OGD facilities within radius
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
        for row in rows:
            raw_lgd = str(row.get("LGD_Code") or "").strip()
            lgd = raw_lgd.zfill(8) if raw_lgd.isdigit() and len(raw_lgd) < 8 else raw_lgd
            dist = str(row.get("District") or "").strip()
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
                    state=str(row.get("State") or ""),
                    district=dist,
                    ward_or_village=ward,
                    village_officer_name=str(row.get("Village_Officer_Name") or ""),
                    village_officer_email=str(row.get("Village_Officer_Email") or ""),
                    village_officer_phone=str(row.get("Village_Officer_Phone") or ""),
                    district_rep_name=str(row.get("District_Rep_Name") or ""),
                    district_rep_phone=str(row.get("District_Rep_Phone") or ""),
                    district_rep_email=str(row.get("District_Rep_Email") or ""),
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
        record = VanRequestRecord(
            request_id=request_id,
            timestamp_utc=timestamp_utc,
            officer_uid=officer_uid,
            ward_village=ward_village,
            target_lat=target_lat,
            target_lng=target_lng,
            assigned_van_id=assigned_van_id,
            vehicle_no=vehicle_no,
            driver_phone=driver_phone,
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
            ws.append_row(row_values, value_input_option="USER_ENTERED")
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
            ws.append_row(row_values, value_input_option="USER_ENTERED")
            return record
        except gspread.exceptions.APIError as exc:
            raise SheetsIntegrationException(str(exc)) from exc


@lru_cache(maxsize=1)
def get_sheets_client() -> SheetsAdminClient:
    """Return cached singleton SheetsAdminClient."""
    return SheetsAdminClient()
