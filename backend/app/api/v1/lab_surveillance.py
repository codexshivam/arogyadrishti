"""NPHL Teku (Dengue Serotype DENV-1..4) & VBDRTC Hetauda (WHO Tube Bioassay Insecticide Resistance) Router.

1. Serotype Shift Tracker (`POST /api/v1/lab/serotype-shift`):
   Detects regional serotype shifts (e.g., DENV-1/DENV-3 -> DENV-2) and elevates Antibody-Dependent
   Enhancement (ADE) hospital-surge multipliers (`1.45x`).
2. Insecticide Resistance Gate (`POST /api/v1/lab/insecticide-resistance`):
   Evaluates WHO tube-bioassay mortality (< 90% = CONFIRMED_RESISTANCE) and automatically switches
   Gemma Copilot & RRT chemical recommendations away from resisted chemicals to biological `Bti`.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.audit_worm import append_worm_audit_log
from app.core.bs_calendar import ad_to_bs_stamp
from app.core.rbac import AuthenticatedStaffPrincipal, get_current_staff
from app.db.models import LabSurveillanceRecord
from app.db.session import get_db_session
from app.schemas.dto import (
    LabInsecticideBioassayRequest,
    LabSerotypeShiftRequest,
    LabSurveillanceResponse,
)

router = APIRouter(
    prefix="/api/v1/lab",
    tags=["NPHL Teku & VBDRTC Hetauda Lab Serotype & Resistance Registry"],
)


def _record_to_response(
    rec: LabSurveillanceRecord, directive_ne: str, directive_en: str
) -> LabSurveillanceResponse:
    return LabSurveillanceResponse(
        id=rec.id,
        lab_center=rec.lab_center,
        province_code=rec.province_code,
        district_code=rec.district_code,
        record_type=rec.record_type,
        dominant_serotype=rec.dominant_serotype,
        previous_serotype=rec.previous_serotype,
        serotype_shift_detected=rec.serotype_shift_detected,
        ade_surge_multiplier=rec.ade_surge_multiplier,
        vector_species=rec.vector_species,
        chemical_tested=rec.chemical_tested,
        bioassay_mortality_pct=rec.bioassay_mortality_pct,
        resistance_status=rec.resistance_status,
        recommended_substitute=rec.recommended_substitute,
        directive_ne=directive_ne,
        directive_en=directive_en,
        recorded_at_bs=rec.recorded_at_bs,
    )


@router.post("/serotype-shift", response_model=LabSurveillanceResponse)
async def register_dengue_serotype_surveillance(
    payload: LabSerotypeShiftRequest,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> LabSurveillanceResponse:
    """Log NPHL Teku / VBDRTC Hetauda RT-PCR Dengue serotype surveillance and evaluate ADE surge risk."""
    now_utc = datetime.now(UTC)
    stamp = ad_to_bs_stamp(now_utc)
    shift_detected = payload.dominant_serotype != payload.previous_serotype
    ade_mult = 1.45 if shift_detected else 1.0
    rec_id = str(uuid.uuid4())

    rec = LabSurveillanceRecord(
        id=rec_id,
        lab_center=payload.lab_center,
        province_code=payload.province_code,
        district_code=payload.district_code,
        record_type="DENGUE_SEROTYPE_SHIFT",
        dominant_serotype=payload.dominant_serotype,
        previous_serotype=payload.previous_serotype,
        serotype_shift_detected=shift_detected,
        ade_surge_multiplier=ade_mult,
        vector_species="Aedes aegypti",
        chemical_tested=None,
        bioassay_mortality_pct=None,
        resistance_status="NOT_APPLICABLE",
        recommended_substitute="Bti (Bacillus thuringiensis israelensis) WP + Hospital ICU/Platelet Readiness",
        recorded_by_id=principal.sub,
        recorded_at_utc=now_utc,
        recorded_at_bs=stamp.bs_combined_label,
    )
    session.add(rec)
    await session.flush()

    await append_worm_audit_log(
        session,
        event_type="LAB_SEROTYPE_SHIFT_LOGGED",
        actor_id=principal.sub,
        actor_role=principal.role.value,
        palika_code=principal.palika_code,
        resource_id=f"lab/serotype/{rec_id}",
        payload={
            "lab_center": payload.lab_center,
            "province_code": payload.province_code,
            "previous_serotype": payload.previous_serotype,
            "dominant_serotype": payload.dominant_serotype,
            "serotype_shift_detected": shift_detected,
            "ade_surge_multiplier": ade_mult,
        },
    )

    if shift_detected:
        dir_ne = (
            f"【NPHL टेकु सेरोटाइप परिवर्तन चेतावनी】 प्रदेश नं. {payload.province_code} मा डेंगु सेरोटाइप "
            f"{payload.previous_serotype} बाट {payload.dominant_serotype} मा परिवर्तन पुष्टि। "
            f"ADE (गम्भीर डेंगु) जोखिमका कारण अस्पताल र eLMIS माग प्रक्षेपण {ade_mult}x ले वृद्धि गरिएको छ।"
        )
        dir_en = (
            f"[NPHL Teku Serotype Shift Alert] Province {payload.province_code} shifted from "
            f"{payload.previous_serotype} to {payload.dominant_serotype}. Secondary-infection ADE severe dengue "
            f"hospitalization & eLMIS burn-rate multiplier elevated to {ade_mult}x."
        )
    else:
        dir_ne = (
            f"प्रदेश नं. {payload.province_code} मा {payload.dominant_serotype} यथावत् छ (सेरोटाइप परिवर्तन देखिएको छैन)।"
        )
        dir_en = (
            f"Province {payload.province_code} remains dominant {payload.dominant_serotype} (no serotype switch)."
        )

    return _record_to_response(rec, dir_ne, dir_en)


@router.post("/insecticide-resistance", response_model=LabSurveillanceResponse)
async def register_insecticide_bioassay(
    payload: LabInsecticideBioassayRequest,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> LabSurveillanceResponse:
    """
    Log VBDRTC Hetauda WHO tube-bioassay mortality score.
    If mortality < 90.0%, flags CONFIRMED_RESISTANCE and automatically gates Copilot/RRT chemical
    recommendations to switch to biological `Bti` or alternate WHO-approved classes.
    """
    now_utc = datetime.now(UTC)
    stamp = ad_to_bs_stamp(now_utc)
    rec_id = str(uuid.uuid4())

    if payload.bioassay_mortality_pct < 90.0:
        res_status = "CONFIRMED_RESISTANCE"
        substitute = "Bti (Bacillus thuringiensis israelensis) WP — 5 g / 10 m² (Biological Override)"
    elif payload.bioassay_mortality_pct < 98.0:
        res_status = "POSSIBLE_RESISTANCE"
        substitute = "Rotate with Bti WP (5 g / 10 m²) + Repeat WHO Tube Bioassay in 14 Days"
    else:
        res_status = "SUSCEPTIBLE"
        substitute = f"Continue {payload.chemical_tested} per EDCD statutory dosage"

    rec = LabSurveillanceRecord(
        id=rec_id,
        lab_center=payload.lab_center,
        province_code=payload.province_code,
        district_code=payload.district_code,
        record_type="INSECTICIDE_BIOASSAY",
        dominant_serotype=None,
        previous_serotype=None,
        serotype_shift_detected=False,
        ade_surge_multiplier=1.0,
        vector_species=payload.vector_species,
        chemical_tested=payload.chemical_tested,
        bioassay_mortality_pct=payload.bioassay_mortality_pct,
        resistance_status=res_status,
        recommended_substitute=substitute,
        recorded_by_id=principal.sub,
        recorded_at_utc=now_utc,
        recorded_at_bs=stamp.bs_combined_label,
    )
    session.add(rec)
    await session.flush()

    await append_worm_audit_log(
        session,
        event_type="LAB_INSECTICIDE_BIOASSAY_LOGGED",
        actor_id=principal.sub,
        actor_role=principal.role.value,
        palika_code=principal.palika_code,
        resource_id=f"lab/bioassay/{rec_id}",
        payload={
            "lab_center": payload.lab_center,
            "province_code": payload.province_code,
            "vector_species": payload.vector_species,
            "chemical_tested": payload.chemical_tested,
            "bioassay_mortality_pct": payload.bioassay_mortality_pct,
            "resistance_status": res_status,
        },
    )

    dir_ne = (
        f"【VBDRTC हेटौंडा कीटनाशक परीक्षण】 {payload.vector_species} मा {payload.chemical_tested} को मृत्युदर "
        f"{payload.bioassay_mortality_pct}% ({res_status})। सिफारिस: {substitute}।"
    )
    dir_en = (
        f"[VBDRTC Hetauda WHO Tube Bioassay] {payload.vector_species} exposed to {payload.chemical_tested}: "
        f"mortality = {payload.bioassay_mortality_pct}% ({res_status}). Action: {substitute}."
    )
    return _record_to_response(rec, dir_ne, dir_en)


@router.get("/status/{province_code}", response_model=list[LabSurveillanceResponse])
async def get_provincial_lab_surveillance_status(
    province_code: int,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> list[LabSurveillanceResponse]:
    """List recent NPHL Teku & VBDRTC Hetauda lab surveillance records for a province."""
    _ = principal
    stmt = (
        select(LabSurveillanceRecord)
        .where(LabSurveillanceRecord.province_code == province_code)
        .order_by(LabSurveillanceRecord.recorded_at_utc.desc())
        .limit(25)
    )
    rows = list((await session.execute(stmt)).scalars().all())
    return [
        _record_to_response(
            r,
            directive_ne=f"प्रयोगशाला अभिलेख ({r.lab_center}): {r.record_type} — {r.recommended_substitute}",
            directive_en=f"Lab Record ({r.lab_center}): {r.record_type} — {r.recommended_substitute}",
        )
        for r in rows
    ]
