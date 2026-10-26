"""MoHP IHMIS / DHIS2 Push, Sovereign 7-Tab Municipal Command Ledger Export, and WORM Audit Chain Verifier Router."""

from __future__ import annotations

import io
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.audit_worm import append_worm_audit_log, verify_audit_chain_integrity
from app.core.rbac import (
    AuthenticatedStaffPrincipal,
    NepalStaffRole,
    get_current_staff,
    require_roles,
)
from app.db.session import get_db_session
from app.schemas.dto import Dhis2PushRequest
from app.services.dhis2_ihmis_connector import get_dhis2_ihmis_connector
from app.services.ledger_sync_service import get_municipal_ledger_service

router = APIRouter(
    prefix="/api/v1",
    tags=["MoHP DHIS2 Interoperability, 7-Tab Ledger & WORM Audit"],
)


@router.post("/dhis2/push")
async def push_dhis2_ihmis_endpoint(
    payload: Dhis2PushRequest,
    principal: AuthenticatedStaffPrincipal = Depends(
        require_roles(NepalStaffRole.PALIKA_HEALTH_CHIEF, NepalStaffRole.EDCD_NODAL)
    ),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """
    Push weekly/daily ward indices (HI, CI, BI, PPI, Composite Risk, Houses Searched & Destroyed)
    to MoHP `hmis.gov.np` `/api/dataValueSets` keyed by `dhis2_org_unit_uid` and ISO/BS period.
    """
    if not principal.can_access_palika(payload.palika_code):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Cannot push DHIS2 data for unauthorized palika '{payload.palika_code}'.",
        )

    connector = get_dhis2_ihmis_connector()
    result = await connector.push_ward_metrics_to_ihmis(
        session,
        composite_ward_ids=payload.composite_ward_ids,
        period_iso=payload.period_iso,
    )

    await append_worm_audit_log(
        session,
        event_type="MOHP_DHIS2_IHMIS_PUSH",
        actor_id=principal.sub,
        actor_role=principal.role.value,
        palika_code=payload.palika_code,
        resource_id=f"dhis2/{result['sync_id']}",
        payload={
            "sync_id": result["sync_id"],
            "period_iso": payload.period_iso,
            "wards_synced": payload.composite_ward_ids,
            "data_values_count": result["data_values_count"],
        },
    )
    return result


@router.get("/ledger/export")
async def export_municipal_ledger_endpoint(
    palika_code: str = Query(default="30608"),
    format_type: str = Query(default="xlsx", alias="format"),
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> Any:
    """
    Export the Sovereign 7-Tab Municipal Command Workbook (`1_Ward_Master_32` through `7_Escalation_SLA_Tickets`)
    from PostgreSQL as a cryptographically SHA-256 signed `.xlsx` file or JSON metadata summary.
    """
    if not principal.can_access_palika(palika_code):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Palika isolation violation: cannot export ledger for palika '{palika_code}'.",
        )

    ledger_svc = get_municipal_ledger_service()
    xlsx_bytes, meta = await ledger_svc.generate_seven_tab_xlsx_bytes(
        session, palika_code=palika_code
    )

    await append_worm_audit_log(
        session,
        event_type="MUNICIPAL_7TAB_LEDGER_EXPORTED",
        actor_id=principal.sub,
        actor_role=principal.role.value,
        palika_code=palika_code,
        resource_id=f"ledger/{palika_code}",
        payload={
            "sha256_signature": meta["sha256_signature"],
            "sheet_tabs": meta["sheet_tabs"],
            "file_size_bytes": meta["file_size_bytes"],
        },
    )

    if format_type.lower() == "json":
        return meta

    headers = {
        "Content-Disposition": f'attachment; filename="nepal_palika_{palika_code}_7tab_ledger.xlsx"',
        "X-Ledger-SHA256": str(meta["sha256_signature"]),
        "X-Bikram-Sambat-Date": str(meta["exported_at_bs"]).split("|")[0].strip(),
    }
    return StreamingResponse(
        io.BytesIO(xlsx_bytes),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers=headers,
    )


@router.get("/admin/audit-verify")
async def verify_worm_audit_chain_endpoint(
    principal: AuthenticatedStaffPrincipal = Depends(
        require_roles(NepalStaffRole.PALIKA_HEALTH_CHIEF, NepalStaffRole.EDCD_NODAL)
    ),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """
    Mathematically verify the entire SHA-256 hash-chained WORM audit ledger
    (`prev_hash` and `SHA-256(prev_hash || canonical_payload || timestamp_utc)`).
    """
    return await verify_audit_chain_integrity(session)
