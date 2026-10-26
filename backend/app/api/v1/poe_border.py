"""Cross-Border Point-of-Entry (PoE Health Desk) Importation Surveillance Router.

Covers Nepal's 8 major terrestrial & aviation border Health Desks:
- Kakarbhitta (Jhapa, Koshi)
- Rani / Biratnagar (Morang, Koshi)
- Birgunj / Inarwa (Parsa, Madhesh)
- Belahiya / Bhairahawa (Rupandehi, Lumbini)
- Jamunaha / Nepalgunj (Banke, Lumbini)
- Trinagar / Dhangadhi (Kailali, Sudurpashchim)
- Gaddachauki / Mahendranagar (Kanchanpur, Sudurpashchim)
- Tribhuvan International Airport (TIA Health Desk, Kathmandu)

Strictly Zero-Citizen-PII under Individual Privacy Act, 2075: logs ONLY disease, RDT result,
border transit zone, and destination Palika/Ward, immediately alerting the destination Ward Health Post.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.audit_worm import append_worm_audit_log
from app.core.bs_calendar import ad_to_bs_stamp
from app.core.rbac import AuthenticatedStaffPrincipal, get_current_staff
from app.db.models import EscalationTicket, PoeImportationLog
from app.db.session import get_db_session
from app.schemas.dto import PoeSurveillanceCreateRequest, PoeSurveillanceResponse

router = APIRouter(tags=["Cross-Border Point-of-Entry (PoE) Health Desk Surveillance"])

POE_DESK_NAMES: dict[str, str] = {
    "KAKARBHITTA": "Kakarbhitta Border Health Desk (Jhapa, Koshi Province)",
    "RANI_BIRATNAGAR": "Rani Border Health Desk (Biratnagar, Koshi Province)",
    "BIRGUNJ": "Birgunj / Inarwa ICP Health Desk (Parsa, Madhesh Province)",
    "BELAHIYA_BHAIRAHAWA": "Belahiya Border Health Desk (Rupandehi, Lumbini Province)",
    "JAMUNAHA_NEPALGUNJ": "Jamunaha Border Health Desk (Nepalgunj, Lumbini Province)",
    "TRINAGAR_DHANGADHI": "Trinagar Border Health Desk (Dhangadhi, Sudurpashchim Province)",
    "GADDACHAUKI_MAHENDRANAGAR": "Gaddachauki Border Health Desk (Kanchanpur, Sudurpashchim Province)",
    "TIA_KATHMANDU": "Tribhuvan International Airport (TIA) Health Desk (Kathmandu)",
}


async def _handle_poe_surveillance_submission(
    payload: PoeSurveillanceCreateRequest,
    principal: AuthenticatedStaffPrincipal,
    session: AsyncSession,
) -> PoeSurveillanceResponse:
    now_utc = datetime.now(UTC)
    stamp = ad_to_bs_stamp(now_utc)
    poe_name = POE_DESK_NAMES.get(payload.poe_desk_code, payload.poe_desk_code)
    dest_comp_ward = (
        f"NP-P{payload.destination_province_code}-D{payload.destination_district_code:02d}-"
        f"{payload.destination_palika_code}-W{payload.destination_ward_no:02d}"
    )
    ticket_code = f"POE-ALERT-{uuid.uuid4().hex[:6].upper()}"
    log_id = str(uuid.uuid4())

    row = PoeImportationLog(
        id=log_id,
        poe_desk_code=payload.poe_desk_code,
        poe_name=poe_name,
        disease=payload.disease,
        rdt_result=payload.rdt_result,
        origin_zone=payload.origin_zone,
        destination_province_code=payload.destination_province_code,
        destination_palika_code=payload.destination_palika_code,
        destination_ward_no=payload.destination_ward_no,
        destination_composite_ward_id=dest_comp_ward,
        destination_alert_dispatched=True,
        alert_ticket_code=ticket_code,
        logged_by_id=principal.sub,
        logged_at_utc=now_utc,
        logged_at_bs=stamp.bs_combined_label,
    )
    session.add(row)

    # Immediately dispatch pre-emptive focal surveillance alert to destination Ward Health Post
    esc = EscalationTicket(
        id=str(uuid.uuid4()),
        ticket_code=ticket_code,
        composite_ward_id=dest_comp_ward,
        palika_code=payload.destination_palika_code,
        reported_by_id=principal.sub,
        severity_tier="CRITICAL_2H",
        sla_hours=2,
        category=f"POE_CROSS_BORDER_IMPORTATION_{payload.disease}",
        summary_sanitized=(
            f"Zero-PII PoE Health Desk Alert from {poe_name}: Traveler RDT-positive ({payload.rdt_result} / {payload.disease}) "
            f"routing to {dest_comp_ward}. Execute immediate focal vector control & 1-3-7 ring surveillance."
        ),
        status="DISPATCHED_TO_DESTINATION_WARD_HEALTH_POST",
        sla_due_at_utc=now_utc + timedelta(hours=2),
        created_at_utc=now_utc,
        created_at_bs=stamp.bs_combined_label,
    )
    session.add(esc)
    await session.flush()

    await append_worm_audit_log(
        session,
        event_type="POE_BORDER_SURVEILLANCE_LOGGED",
        actor_id=principal.sub,
        actor_role=principal.role.value,
        palika_code=payload.destination_palika_code,
        resource_id=f"poe/{log_id}",
        payload={
            "poe_desk_code": payload.poe_desk_code,
            "disease": payload.disease,
            "destination_composite_ward_id": dest_comp_ward,
            "alert_ticket_code": ticket_code,
        },
    )

    directive_ne = (
        f"【सीमा नाका (PoE) पूर्व-सतर्कता — {poe_name}】 गन्तव्य वडा {dest_comp_ward} मा {payload.disease} ({payload.rdt_result}) "
        f"आयातित केस संकेत। स्थानीय लामखुट्टे/भुसुनाबाट सर्न नदिन वडा स्वास्थ्य चौकीले २४ घण्टाभित्र फोकल भेक्टर कन्ट्रोल, "
        f"खोज र नष्ट गर वा १-३-७ IRS/LLIN अभियान सञ्चालन गर्नुहोस्।"
    )
    directive_en = (
        f"[PoE Health Desk Pre-Emptive Alert — {poe_name}] Imported {payload.disease} ({payload.rdt_result}) routing to "
        f"destination ward {dest_comp_ward}. Destination Ward Health Post notified (Ticket {ticket_code}) to execute "
        f"focal vector control within 24h before indigenous transmission establishes."
    )

    return PoeSurveillanceResponse(
        id=log_id,
        poe_desk_code=payload.poe_desk_code,
        poe_name=poe_name,
        disease=payload.disease,
        rdt_result=payload.rdt_result,
        origin_zone=payload.origin_zone,
        destination_province_code=payload.destination_province_code,
        destination_palika_code=payload.destination_palika_code,
        destination_ward_no=payload.destination_ward_no,
        destination_composite_ward_id=dest_comp_ward,
        destination_alert_dispatched=True,
        alert_ticket_code=ticket_code,
        focal_response_directive_ne=directive_ne,
        focal_response_directive_en=directive_en,
        logged_at_bs=stamp.bs_combined_label,
    )


@router.post("/api/v1/poe/surveillance", response_model=PoeSurveillanceResponse)
async def create_poe_surveillance_alert(
    payload: PoeSurveillanceCreateRequest,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> PoeSurveillanceResponse:
    """Log a Zero-Citizen-PII border Health Desk RDT-positive importation and alert the destination Ward Health Post."""
    return await _handle_poe_surveillance_submission(payload, principal, session)


@router.post("/api/v1/poe_surveillance", response_model=PoeSurveillanceResponse)
async def create_poe_surveillance_alert_alias(
    payload: PoeSurveillanceCreateRequest,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> PoeSurveillanceResponse:
    """Alias endpoint `/api/v1/poe_surveillance` for border Health Desk surveillance."""
    return await _handle_poe_surveillance_submission(payload, principal, session)


@router.get("/api/v1/poe/surveillance", response_model=list[PoeSurveillanceResponse])
async def list_poe_surveillance_alerts(
    destination_palika_code: str | None = Query(default=None),
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> list[PoeSurveillanceResponse]:
    """List recent Zero-PII Cross-Border Point-of-Entry importation logs."""
    _ = principal
    stmt = select(PoeImportationLog).order_by(PoeImportationLog.logged_at_utc.desc()).limit(50)
    if destination_palika_code:
        stmt = stmt.where(PoeImportationLog.destination_palika_code == destination_palika_code)
    rows = list((await session.execute(stmt)).scalars().all())
    out: list[PoeSurveillanceResponse] = []
    for r in rows:
        out.append(
            PoeSurveillanceResponse(
                id=r.id,
                poe_desk_code=r.poe_desk_code,
                poe_name=r.poe_name,
                disease=r.disease,  # type: ignore[arg-type]
                rdt_result=r.rdt_result,
                origin_zone=r.origin_zone,
                destination_province_code=r.destination_province_code,
                destination_palika_code=r.destination_palika_code,
                destination_ward_no=r.destination_ward_no,
                destination_composite_ward_id=r.destination_composite_ward_id,
                destination_alert_dispatched=r.destination_alert_dispatched,
                alert_ticket_code=r.alert_ticket_code,
                focal_response_directive_ne=f"गन्तव्य वडा {r.destination_composite_ward_id} फोकल भेक्टर कन्ट्रोल निर्देशित।",
                focal_response_directive_en=f"Destination ward {r.destination_composite_ward_id} alerted for focal response.",
                logged_at_bs=r.logged_at_bs,
            )
        )
    return out
