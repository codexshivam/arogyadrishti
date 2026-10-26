"""SLA Outbreak Escalation Tickets Router (2h Critical / 6h High / 24h Routine)."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.audit_worm import append_worm_audit_log
from app.core.bs_calendar import ad_to_bs_stamp
from app.core.rbac import (
    AuthenticatedStaffPrincipal,
    NepalStaffRole,
    enforce_ward_isolation,
    get_current_staff,
)
from app.core.security import scrub_citizen_pii_text
from app.db.models.escalation_ticket import EscalationTicket
from app.db.session import get_db_session
from app.schemas.dto import EscalationCreatePayload, EscalationTicketResponse

router = APIRouter(prefix="/api/v1/escalations", tags=["SLA Escalation Tickets"])

_SLA_HOURS_MAP: dict[str, int] = {
    "CRITICAL_2H": 2,
    "HIGH_6H": 6,
    "ROUTINE_24H": 24,
}


@router.post(
    "",
    response_model=EscalationTicketResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_escalation_ticket_endpoint(
    payload: EscalationCreatePayload,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> EscalationTicketResponse:
    """Create a 2h Critical, 6h High, or 24h Routine SLA escalation ticket for a Nepal Ward."""
    enforce_ward_isolation(
        principal, payload.composite_ward_id, allow_read_only_nodal=False
    )

    parts = payload.composite_ward_id.split("-")
    inferred_palika = parts[3] if len(parts) >= 4 else principal.palika_code
    sla_hours = _SLA_HOURS_MAP.get(payload.severity_tier, 24)
    now_utc = datetime.now(UTC)
    due_utc = now_utc + timedelta(hours=sla_hours)
    stamp = ad_to_bs_stamp(now_utc)

    t_id = str(uuid.uuid4())
    t_code = f"ESC-NP-{uuid.uuid4().hex[:8].upper()}"
    sanitized_summary = scrub_citizen_pii_text(payload.summary)

    ticket = EscalationTicket(
        id=t_id,
        ticket_code=t_code,
        composite_ward_id=payload.composite_ward_id,
        palika_code=inferred_palika,
        reported_by_id=principal.sub,
        severity_tier=payload.severity_tier,
        sla_hours=sla_hours,
        category=payload.category,
        summary_sanitized=sanitized_summary,
        status="OPEN",
        sla_due_at_utc=due_utc,
        created_at_utc=now_utc,
        created_at_bs=stamp.bs_combined_label,
    )
    session.add(ticket)
    await session.flush()

    await append_worm_audit_log(
        session,
        event_type="ESCALATION_TICKET_OPENED",
        actor_id=principal.sub,
        actor_role=principal.role.value,
        palika_code=inferred_palika,
        resource_id=f"escalations/{t_code}",
        payload={
            "ticket_code": t_code,
            "composite_ward_id": payload.composite_ward_id,
            "severity_tier": payload.severity_tier,
            "sla_hours": sla_hours,
        },
    )

    return EscalationTicketResponse(
        id=ticket.id,
        ticket_code=ticket.ticket_code,
        composite_ward_id=ticket.composite_ward_id,
        palika_code=ticket.palika_code,
        reported_by_id=ticket.reported_by_id,
        severity_tier=ticket.severity_tier,
        sla_hours=ticket.sla_hours,
        category=ticket.category,
        summary_sanitized=ticket.summary_sanitized,
        status=ticket.status,
        sla_due_at_utc=due_utc.isoformat(),
        created_at_bs=stamp.bs_combined_label,
    )


@router.get("")
async def list_escalation_tickets_endpoint(
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """List SLA escalation tickets scoped to the officer's Palika/Ward jurisdiction."""
    stmt = select(EscalationTicket)
    if principal.role != NepalStaffRole.EDCD_NODAL:
        stmt = stmt.where(EscalationTicket.palika_code == principal.palika_code)
    if principal.role in {NepalStaffRole.FCHV, NepalStaffRole.WARD_HEALTH_OFFICER}:
        stmt = stmt.where(
            EscalationTicket.composite_ward_id.in_(principal.assigned_wards)
        )

    rows = list((await session.execute(stmt)).scalars().all())
    stamp = ad_to_bs_stamp()
    return {
        "count": len(rows),
        "tickets": [
            {
                "id": r.id,
                "ticket_code": r.ticket_code,
                "composite_ward_id": r.composite_ward_id,
                "palika_code": r.palika_code,
                "severity_tier": r.severity_tier,
                "sla_hours": r.sla_hours,
                "category": r.category,
                "summary_sanitized": r.summary_sanitized,
                "status": r.status,
                "sla_due_at_utc": r.sla_due_at_utc.isoformat(),
                "created_at_bs": r.created_at_bs,
            }
            for r in rows
        ],
        "timestamp_utc": stamp.timestamp_utc,
        "bs_date": stamp.bs_combined_label,
    }
