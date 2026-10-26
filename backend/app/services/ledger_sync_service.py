"""Sovereign 7-Tab Municipal Command Ledger (PostgreSQL -> Signed Local XLSX + Optional Google Sheets Strategy)."""

from __future__ import annotations

import hashlib
import io
import os
from datetime import UTC, datetime
from typing import Any

from openpyxl import Workbook
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.bs_calendar import ad_to_bs_stamp
from app.core.config import get_settings
from app.db.models import (
    AdminBoundaryWard,
    EscalationTicket,
    FieldInspection,
    RrtDispatchLog,
    StaffUser,
    WardRiskDaily,
    WormAuditLog,
)

REQUIRED_SEVEN_TABS: tuple[str, ...] = (
    "1_Ward_Master_32",
    "2_Daily_6AM_Risk_Fusion",
    "3_Staff_FCHV_Directory",
    "4_RRT_Khoj_Ra_Nashta_Dispatch",
    "5_Field_Entomology_Logs",
    "6_DHIS2_EWARS_Sync_Log",
    "7_Escalation_SLA_Tickets",
)


class MunicipalLedgerSyncService:
    """
    Maintain and export the statutory 7-Tab Municipal Command Workbook:
    1. `1_Ward_Master_32`
    2. `2_Daily_6AM_Risk_Fusion`
    3. `3_Staff_FCHV_Directory`
    4. `4_RRT_Khoj_Ra_Nashta_Dispatch`
    5. `5_Field_Entomology_Logs`
    6. `6_DHIS2_EWARS_Sync_Log`
    7. `7_Escalation_SLA_Tickets`
    Every row carries Bikram Sambat (BS) timestamps and the exported `.xlsx` is SHA-256 signed.
    """

    async def generate_seven_tab_xlsx_bytes(
        self,
        session: AsyncSession,
        *,
        palika_code: str = "30608",
    ) -> tuple[bytes, dict[str, Any]]:
        wb = Workbook()
        # Remove default sheet
        default_sheet = wb.active
        if default_sheet is not None:
            wb.remove(default_sheet)

        stamp = ad_to_bs_stamp(datetime.now(UTC))

        # Tab 1: 1_Ward_Master_32
        ws1 = wb.create_sheet(title="1_Ward_Master_32")
        ws1.append(
            [
                "Composite_Ward_ID",
                "Province_Code",
                "District_Name",
                "Palika_Code",
                "Palika_Name",
                "Ward_Number",
                "Locality_EN",
                "Locality_NE",
                "Mean_Elevation_m",
                "DHIS2_OrgUnit_UID",
                "Updated_BS",
            ]
        )
        wards = list(
            (
                await session.execute(
                    select(AdminBoundaryWard)
                    .where(AdminBoundaryWard.palika_code == palika_code)
                    .order_by(AdminBoundaryWard.ward_number.asc())
                )
            )
            .scalars()
            .all()
        )
        for w in wards:
            ws1.append(
                [
                    w.composite_ward_id,
                    w.province_code,
                    w.district_name,
                    w.palika_code,
                    w.palika_name,
                    w.ward_number,
                    w.locality_name,
                    w.locality_name_ne,
                    w.mean_elevation_m,
                    w.dhis2_org_unit_uid,
                    w.updated_at_bs,
                ]
            )

        # Tab 2: 2_Daily_6AM_Risk_Fusion
        ws2 = wb.create_sheet(title="2_Daily_6AM_Risk_Fusion")
        ws2.append(
            [
                "Composite_Ward_ID",
                "Fusion_Date_AD",
                "Fusion_Date_BS",
                "HI_Pct",
                "CI_Pct",
                "BI_Score",
                "PPI_Index",
                "V_Elev",
                "Composite_Risk_Score",
                "Risk_Tier",
                "EWARS_Cases",
            ]
        )
        risks = list(
            (
                await session.execute(
                    select(WardRiskDaily).where(WardRiskDaily.palika_code == palika_code)
                )
            )
            .scalars()
            .all()
        )
        for r in risks:
            ws2.append(
                [
                    r.composite_ward_id,
                    r.fusion_date_ad,
                    r.fusion_date_bs,
                    r.house_index_hi,
                    r.container_index_ci,
                    r.breteau_index_bi,
                    r.pupae_per_person_ppi,
                    r.elevation_viability_factor,
                    r.composite_risk_score,
                    r.risk_tier,
                    r.ewars_confirmed_cases,
                ]
            )

        # Tab 3: 3_Staff_FCHV_Directory
        ws3 = wb.create_sheet(title="3_Staff_FCHV_Directory")
        ws3.append(
            [
                "Staff_ID",
                "Full_Name_EN",
                "Full_Name_NE",
                "Designation",
                "Role",
                "Palika_Code",
                "Assigned_Wards",
                "Is_Active",
                "Created_BS",
            ]
        )
        staff_rows = list(
            (
                await session.execute(
                    select(StaffUser).where(StaffUser.palika_code == palika_code)
                )
            )
            .scalars()
            .all()
        )
        for s in staff_rows:
            ws3.append(
                [
                    s.id,
                    s.full_name,
                    s.full_name_ne,
                    s.designation,
                    s.role,
                    s.palika_code,
                    ",".join(s.assigned_wards),
                    s.is_active,
                    s.created_at_bs,
                ]
            )

        # Tab 4: 4_RRT_Khoj_Ra_Nashta_Dispatch
        ws4 = wb.create_sheet(title="4_RRT_Khoj_Ra_Nashta_Dispatch")
        ws4.append(
            [
                "Dispatch_ID",
                "Vehicle_ID",
                "Plate_Number",
                "Composite_Ward_ID",
                "Dispatch_Type",
                "Campaign_Action_NE",
                "Distance_km",
                "ETA_Minutes",
                "Routing_Engine",
                "Dispatched_BS",
            ]
        )
        dispatches = list(
            (
                await session.execute(
                    select(RrtDispatchLog).where(
                        RrtDispatchLog.palika_code == palika_code
                    )
                )
            )
            .scalars()
            .all()
        )
        for d in dispatches:
            ws4.append(
                [
                    d.dispatch_id,
                    d.vehicle_id,
                    d.plate_number,
                    d.composite_ward_id,
                    d.dispatch_type,
                    d.campaign_action_ne,
                    d.route_distance_km,
                    d.route_eta_minutes,
                    d.routing_engine,
                    d.dispatched_at_bs,
                ]
            )

        # Tab 5: 5_Field_Entomology_Logs
        ws5 = wb.create_sheet(title="5_Field_Entomology_Logs")
        ws5.append(
            [
                "Inspection_ID",
                "Client_UUID",
                "Composite_Ward_ID",
                "Houses_Inspected",
                "Houses_Infested",
                "Wet_Containers",
                "Positive_Containers",
                "Pupae_Count",
                "Container_Type",
                "Larvicide_Applied",
                "Grid_250m_Lat",
                "Grid_250m_Lng",
                "Inspected_BS",
            ]
        )
        inspections = list(
            (
                await session.execute(
                    select(FieldInspection).where(
                        FieldInspection.palika_code == palika_code
                    )
                )
            )
            .scalars()
            .all()
        )
        for i in inspections:
            ws5.append(
                [
                    i.id,
                    i.client_submission_uuid,
                    i.composite_ward_id,
                    i.houses_inspected,
                    i.houses_infested,
                    i.wet_containers_inspected,
                    i.positive_containers,
                    i.pupae_count,
                    i.container_type,
                    i.larvicide_applied,
                    i.public_grid_lat,
                    i.public_grid_lng,
                    i.inspected_at_bs,
                ]
            )

        # Tab 6: 6_DHIS2_EWARS_Sync_Log
        ws6 = wb.create_sheet(title="6_DHIS2_EWARS_Sync_Log")
        ws6.append(
            [
                "Audit_Seq_ID",
                "Event_Type",
                "Actor_ID",
                "Palika_Code",
                "Resource_ID",
                "Timestamp_BS",
                "Entry_SHA256_Hash",
            ]
        )
        audits = list(
            (
                await session.execute(
                    select(WormAuditLog)
                    .order_by(WormAuditLog.seq_id.desc())
                    .limit(100)
                )
            )
            .scalars()
            .all()
        )
        for a in audits:
            ws6.append(
                [
                    a.seq_id,
                    a.event_type,
                    a.actor_id,
                    a.palika_code,
                    a.resource_id,
                    a.timestamp_bs,
                    a.entry_hash,
                ]
            )

        # Tab 7: 7_Escalation_SLA_Tickets
        ws7 = wb.create_sheet(title="7_Escalation_SLA_Tickets")
        ws7.append(
            [
                "Ticket_Code",
                "Composite_Ward_ID",
                "Severity_Tier",
                "SLA_Hours",
                "Category",
                "Summary_Sanitized",
                "Status",
                "Created_BS",
            ]
        )
        tickets = list(
            (
                await session.execute(
                    select(EscalationTicket).where(
                        EscalationTicket.palika_code == palika_code
                    )
                )
            )
            .scalars()
            .all()
        )
        for t in tickets:
            ws7.append(
                [
                    t.ticket_code,
                    t.composite_ward_id,
                    t.severity_tier,
                    t.sla_hours,
                    t.category,
                    t.summary_sanitized,
                    t.status,
                    t.created_at_bs,
                ]
            )

        buf = io.BytesIO()
        wb.save(buf)
        xlsx_bytes = buf.getvalue()
        sha256_sig = hashlib.sha256(xlsx_bytes).hexdigest()

        # Content-addressable audit storage keyed by SHA-256 signature (zero user-controlled data in path)
        settings = get_settings()
        safe_root_dir = os.path.abspath(settings.ledger_export_dir)
        os.makedirs(safe_root_dir, exist_ok=True)
        root_prefix = safe_root_dir if safe_root_dir.endswith(os.sep) else safe_root_dir + os.sep

        filename = f"nepal_municipal_ledger_{sha256_sig}.xlsx"
        resolved_path = os.path.normpath(os.path.join(safe_root_dir, filename))

        if not resolved_path.startswith(root_prefix):
            raise ValueError("Access denied: path traversal detected in export directory")

        with open(resolved_path, "wb") as f:
            f.write(xlsx_bytes)

        meta = {
            "palika_code": palika_code,
            "sheet_tabs": list(REQUIRED_SEVEN_TABS),
            "sha256_signature": sha256_sig,
            "file_size_bytes": len(xlsx_bytes),
            "local_export_path": resolved_path,
            "exported_at_utc": stamp.timestamp_utc,
            "exported_at_bs": stamp.bs_combined_label,
        }
        return xlsx_bytes, meta


_ledger_service = MunicipalLedgerSyncService()


def get_municipal_ledger_service() -> MunicipalLedgerSyncService:
    """Return singleton 7-Tab Municipal Command Ledger service."""
    return _ledger_service
