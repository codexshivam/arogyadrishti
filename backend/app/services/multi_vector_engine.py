"""EDCD Multi-Vector Surveillance Engine (5 Vector Programs across Terai, Inner Terai, Pahad, Himal)
& Statutory WHO/EDCD 1-3-7 Malaria / Kala-azar Elimination SLA Engine.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from typing import Literal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.bs_calendar import ad_to_bs_stamp
from app.db.models.escalation_ticket import EscalationTicket
from app.db.models.nationwide_expansion import MalariaKalaazar137Case
from app.schemas.dto import (
    MalariaKalaazar137CaseResponse,
    MalariaKalaazar137CreateRequest,
    MalariaKalaazar137StageUpdateRequest,
    MultiVectorEvaluationRequest,
    MultiVectorEvaluationResponse,
)


def parse_composite_ward_parts(composite_ward_id: str) -> tuple[int, int, str, int]:
    """
    Parse 'NP-P3-D27-30608-W17' -> (province_code=3, district_code=27, palika_code='30608', ward_no=17).
    """
    parts = composite_ward_id.split("-")
    if len(parts) >= 5 and parts[1].startswith("P") and parts[2].startswith("D") and parts[4].startswith("W"):
        prov = int(parts[1][1:])
        dist = int(parts[2][1:])
        palika = parts[3]
        ward = int(parts[4][1:])
        return prov, dist, palika, ward
    return 3, 27, "30608", 17


def evaluate_multi_vector_risk(
    req: MultiVectorEvaluationRequest,
) -> MultiVectorEvaluationResponse:
    """
    Evaluate habitat, climate, ecological belt, and case cluster risk across EDCD Nepal's
    5 priority vector-borne disease programs:
    1. DENGUE_AEDES (Dengue & Chikungunya - Aedes aegypti / albopictus)
    2. MALARIA_ANOPHELES (Plasmodium vivax / falciparum - Anopheles fluviatilis / annularis)
    3. KALAAZAR_SANDFLY (Visceral Leishmaniasis - Phlebotomus argentipes in mud/stone cracks)
    4. SCRUB_TYPHUS_MITE (Orientia tsutsugamushi - Chigger mites in post-monsoon bush/terraces)
    5. JE_CULEX (Japanese Encephalitis - Culex tritaeniorhynchus in Terai paddy fields)
    """
    belt_weights = {
        "TERAI": 1.20,
        "INNER_TERAI": 1.15,
        "PAHAD_VALLEY": 1.00,
        "HIMAL_CORRIDOR": 0.80,
    }
    belt_mult = belt_weights.get(req.ecological_belt, 1.0)
    case_boost = min(35.0, req.confirmed_rdt_cases_7d * 7.5)

    if req.vector_program == "DENGUE_AEDES":
        elev_factor = 1.0 if req.mean_elevation_m <= 1600 else max(0.35, 1.0 - (req.mean_elevation_m - 1600) / 2000.0)
        raw_score = (48.0 + case_boost + max(0.0, req.ndwi_paddy_inundation) * 20.0) * elev_factor
        protocol_code = "EDCD-DENGUE-SOP-2081-KHOJ-NASHTA"
        inter_ne = (
            "खोज र नष्ट गर अभियान: घर-छतका ड्रम, टायर र गमलाको पानी खन्याई ब्रसले रगड्ने; "
            "नबग्ने पानीमा Bti लार्भिसाइड (5 g / 10 m²) छर्कने।"
        )
        inter_en = (
            "Khoj Ra Nashta Gar (Search & Destroy): Empty and scrub rooftop drums, tires, and flower pots; "
            "apply biological Bti larvicide (5 g / 10 m²) in non-potable standing water."
        )
        agent = "Bti (Bacillus thuringiensis israelensis) WP / Temephos 50% EC"
        med_alert = "Ensure NS1/IgM RDT, ORS, and Paracetamol stock; strictly prohibit NSAIDs (Ibuprofen/Aspirin)."
        requires_137 = False

    elif req.vector_program == "MALARIA_ANOPHELES":
        raw_score = (52.0 * belt_mult) + case_boost + max(0.0, req.ndwi_paddy_inundation) * 22.0
        protocol_code = "EDCD-MALARIA-137-ELIMINATION-2026"
        inter_ne = (
            "१-३-७ औलो निवारण प्रोटोकल: २४ घण्टाभित्र RDT रिपोर्टिङ, ३ दिनभित्र केस अनुसन्धान र "
            "७ दिनभित्र प्रभावित टोलमा कीटनाशक छिटा (IRS) तथा झुल (LLIN) वितरण।"
        )
        inter_en = (
            "Statutory 1-3-7 Malaria Elimination Protocol: Day-1 RDT notification, Day-3 case classification "
            "(Indigenous vs Imported), and Day-7 Foci Response (Pyrethroid IRS + LLIN bed-net distribution)."
        )
        agent = "Deltamethrin 2.5% WP / Alphacypermethrin 5% WP (IRS) + Long-Lasting Insecticidal Nets (LLIN)"
        med_alert = "Verify ACT (Artemether-Lumefantrine), Primaquine, and G6PD testing availability at Health Post."
        requires_137 = True

    elif req.vector_program == "KALAAZAR_SANDFLY":
        # Kala-azar shifting into Karnali/Sudurpashchim/Pahad hill river valleys & mud/stone wall cracks
        wall_score = req.mud_stone_wall_crack_ratio * 42.0
        raw_score = 38.0 + wall_score + case_boost
        protocol_code = "EDCD-KALAAZAR-SANDFLY-IRS-137"
        inter_ne = (
            "कालाजार १-३-७ रेस्पोन्स: माटो/ढुङ्गाको भित्ताको चिरा र गोठमा भुसुना (Sandfly) नियन्त्रणका लागि "
            "५० मिटर परिधिमा पाइरेथ्रोइड IRS छर्कने र rK39 स्क्रिनिङ गर्ने।"
        )
        inter_en = (
            "Kala-azar 1-3-7 Elimination Response: Seal mud/stone wall cracks & livestock sheds; deploy focal "
            "synthetic pyrethroid IRS within 50m radius and conduct active rK39 rapid screening."
        )
        agent = "Alphacypermethrin 5% WP Focal IRS (Indoor + Cattle Sheds)"
        med_alert = "Verify rK39 RDT kits and Liposomal Amphotericin B (L-AmB) referral readiness at Provincial Hospital."
        requires_137 = True

    elif req.vector_program == "SCRUB_TYPHUS_MITE":
        # Post-monsoon bush/terrace vegetation (NDVI) + rodent/chigger mite exposure
        bush_score = max(0.0, req.ndvi_bush_index) * 45.0
        raw_score = 36.0 + bush_score + case_boost
        protocol_code = "EDCD-SCRUB-TYPHUS-CHIGGER-SOP"
        inter_ne = (
            "स्क्रब टाइफस (Scrub Typhus) रोकथाम: घर वरिपरिको झाडी फाँड्ने, मुसा नियन्त्रण गर्ने र "
            "खेतबारीमा काम गर्दा लामो बाहुला भएको कपडा तथा बुट प्रयोग गर्ने।"
        )
        inter_en = (
            "Scrub Typhus Control: Clear peridomestic bush/vegetation, control commensal rodents, enforce protective "
            "clothing on agricultural terraces, and pre-position Doxycycline/Azithromycin at Health Posts."
        )
        agent = "Peridomestic Bush Clearance + Rodent Harbourage Reduction"
        med_alert = "CRITICAL: Pre-position Doxycycline 100mg tablets & Azithromycin syrup at Basic Health Service Centers."
        requires_137 = False

    else:  # JE_CULEX
        # Terai irrigated paddy inundation (NDWI) + routine JE immunization coverage gap
        paddy_score = max(0.0, req.ndwi_paddy_inundation) * 40.0
        imm_gap_penalty = max(0.0, 95.0 - req.je_immunization_coverage_pct) * 0.9
        raw_score = (32.0 * belt_mult) + paddy_score + imm_gap_penalty + case_boost
        protocol_code = "EDCD-JE-CULEX-PADDY-IMMUNIZATION"
        inter_ne = (
            "जापानी इन्सेफलाइटिस (JE) नियन्त्रण: धानखेतमा वैकल्पिक भिजाइ र सुकाइ (AWD), सुँगुर/हाँसको खोर घरबाट टाढा राख्ने र "
            "छुटेका बालबालिकालाई तत्काल JE खोप लगाउने।"
        )
        inter_en = (
            "Japanese Encephalitis (Culex) Control: Alternate Wetting & Drying (AWD) in irrigated paddy belts, "
            "piggery mosquito screening, and immediate catch-up JE immunization campaign in low-coverage wards."
        )
        agent = "Bti Granules in Peridomestic Pools + Catch-Up JE Live Attenuated Vaccine Campaign"
        med_alert = f"Routine JE immunization coverage is {req.je_immunization_coverage_pct:.1f}%; trigger Family Welfare Division catch-up drive if <90%."
        requires_137 = False

    final_score = round(min(100.0, max(0.0, raw_score)), 2)
    tier: Literal["SAFE", "MODERATE", "HIGH", "CRITICAL_TIER_1"]
    if final_score >= 75.0:
        tier = "CRITICAL_TIER_1"
    elif final_score >= 55.0:
        tier = "HIGH"
    elif final_score >= 30.0:
        tier = "MODERATE"
    else:
        tier = "SAFE"

    return MultiVectorEvaluationResponse(
        composite_ward_id=req.composite_ward_id,
        vector_program=req.vector_program,
        ecological_belt=req.ecological_belt,
        risk_score=final_score,
        risk_tier=tier,
        statutory_protocol_code=protocol_code,
        primary_intervention_ne=inter_ne,
        primary_intervention_en=inter_en,
        chemical_or_biological_agent=agent,
        medical_prophylaxis_alert=med_alert,
        requires_137_sla_tracking=requires_137,
    )


def _case_to_response(case: MalariaKalaazar137Case) -> MalariaKalaazar137CaseResponse:
    return MalariaKalaazar137CaseResponse(
        id=case.id,
        case_code=case.case_code,
        disease=case.disease,
        ecological_belt=case.ecological_belt,
        composite_ward_id=case.composite_ward_id,
        palika_code=case.palika_code,
        province_code=case.province_code,
        reporting_facility_nhfr=case.reporting_facility_nhfr,
        day1_notified_at_utc=case.day1_notified_at_utc.isoformat(),
        day1_sla_due_utc=case.day1_sla_due_utc.isoformat(),
        day3_investigated_at_utc=(
            case.day3_investigated_at_utc.isoformat() if case.day3_investigated_at_utc else None
        ),
        day3_sla_due_utc=case.day3_sla_due_utc.isoformat(),
        case_classification=case.case_classification,
        day7_foci_responded_at_utc=(
            case.day7_foci_responded_at_utc.isoformat() if case.day7_foci_responded_at_utc else None
        ),
        day7_sla_due_utc=case.day7_sla_due_utc.isoformat(),
        foci_irs_llin_summary=case.foci_irs_llin_summary,
        current_stage=case.current_stage,
        sla_breached=case.sla_breached,
        escalated_to_provincial_phd=case.escalated_to_provincial_phd,
        escalation_ticket_code=case.escalation_ticket_code,
        created_at_bs=case.created_at_bs,
    )


async def create_137_case(
    db: AsyncSession,
    req: MalariaKalaazar137CreateRequest,
    reporter_id: str,
) -> MalariaKalaazar137CaseResponse:
    """
    Create a statutory WHO/EDCD 1-3-7 Malaria or Kala-azar elimination case tracker.
    Sets Day-1 (+24h), Day-3 (+72h), and Day-7 (+168h) deadlines.
    """
    prov, _dist, palika, _ward = parse_composite_ward_parts(req.composite_ward_id)
    now_utc = datetime.now(UTC) - timedelta(hours=req.backdate_hours_for_simulation)
    stamp = ad_to_bs_stamp(now_utc)

    short_uid = uuid.uuid4().hex[:6].upper()
    prefix = "MAL" if req.disease == "MALARIA_ANOPHELES" else "KAL"
    case_code = f"NP-137-{prefix}-{stamp.bs_year}-{short_uid}"

    case = MalariaKalaazar137Case(
        id=str(uuid.uuid4()),
        case_code=case_code,
        disease=req.disease,
        ecological_belt=req.ecological_belt,
        composite_ward_id=req.composite_ward_id,
        palika_code=palika,
        province_code=prov,
        reporting_facility_nhfr=req.reporting_facility_nhfr,
        day1_notified_at_utc=now_utc,
        day1_sla_due_utc=now_utc + timedelta(hours=24),
        day3_investigated_at_utc=None,
        day3_sla_due_utc=now_utc + timedelta(hours=72),
        case_classification=None,
        day7_foci_responded_at_utc=None,
        day7_sla_due_utc=now_utc + timedelta(hours=168),
        foci_irs_llin_summary=None,
        current_stage="DAY_1_NOTIFIED",
        sla_breached=False,
        escalated_to_provincial_phd=False,
        escalation_ticket_code=None,
        created_at_bs=stamp.bs_combined_label,
    )
    db.add(case)
    await db.flush()

    # Immediately evaluate if backdated simulation already breached Day-3 or Day-7 SLA
    await enforce_single_137_case_sla(db, case, reporter_id=reporter_id)
    await db.commit()
    await db.refresh(case)
    return _case_to_response(case)


async def enforce_single_137_case_sla(
    db: AsyncSession,
    case: MalariaKalaazar137Case,
    reporter_id: str = "system-137-watchdog",
) -> bool:
    """
    Check if a 1-3-7 case has exceeded its Day-3 (72h) or Day-7 (168h) statutory SLA.
    If breached, automatically escalate to the Provincial Health Directorate & VBDRTC Hetauda.
    """
    now_utc = datetime.now(UTC)
    day3_due = (
        case.day3_sla_due_utc
        if case.day3_sla_due_utc.tzinfo is not None
        else case.day3_sla_due_utc.replace(tzinfo=UTC)
    )
    day7_due = (
        case.day7_sla_due_utc
        if case.day7_sla_due_utc.tzinfo is not None
        else case.day7_sla_due_utc.replace(tzinfo=UTC)
    )

    breach_reason: str | None = None
    if case.day3_investigated_at_utc is None and now_utc > day3_due:
        breach_reason = (
            f"1-3-7 STATUTORY BREACH (Day-3 / 72h): {case.disease} case {case.case_code} "
            f"in {case.composite_ward_id} was not investigated/classified within 72 hours."
        )
    elif case.day7_foci_responded_at_utc is None and now_utc > day7_due:
        breach_reason = (
            f"1-3-7 STATUTORY BREACH (Day-7 / 168h): {case.disease} case {case.case_code} "
            f"in {case.composite_ward_id} lacks Day-7 Foci IRS + LLIN response within 168 hours."
        )

    if breach_reason and not case.escalated_to_provincial_phd:
        ticket_code = f"PHD-137-ESC-{uuid.uuid4().hex[:6].upper()}"
        stamp = ad_to_bs_stamp(now_utc)
        esc = EscalationTicket(
            id=str(uuid.uuid4()),
            ticket_code=ticket_code,
            composite_ward_id=case.composite_ward_id,
            palika_code=case.palika_code,
            reported_by_id=reporter_id,
            severity_tier="CRITICAL_2H",
            sla_hours=2,
            category="STATUTORY_1_3_7_SLA_BREACH_PROVINCIAL_ESCALATION",
            summary_sanitized=breach_reason,
            status="ESCALATED_TO_PROVINCIAL_PHD_AND_VBDRTC",
            sla_due_at_utc=now_utc + timedelta(hours=2),
            created_at_utc=now_utc,
            created_at_bs=stamp.bs_combined_label,
        )
        db.add(esc)
        case.sla_breached = True
        case.escalated_to_provincial_phd = True
        case.escalation_ticket_code = ticket_code
        case.current_stage = "SLA_BREACHED_ESCALATED"
        await db.flush()
        return True
    return False


async def update_137_case_stage(
    db: AsyncSession,
    case_id: str,
    req: MalariaKalaazar137StageUpdateRequest,
) -> MalariaKalaazar137CaseResponse | None:
    """Advance a 1-3-7 case to DAY_3_INVESTIGATED or DAY_7_FOCI_COMPLETED."""
    stmt = select(MalariaKalaazar137Case).where(MalariaKalaazar137Case.id == case_id)
    result = await db.execute(stmt)
    case = result.scalar_one_or_none()
    if case is None:
        return None

    now_utc = datetime.now(UTC)
    if req.stage == "DAY_3_INVESTIGATED":
        case.day3_investigated_at_utc = now_utc
        case.case_classification = req.case_classification
        if not case.sla_breached:
            case.current_stage = "DAY_3_INVESTIGATED"
    elif req.stage == "DAY_7_FOCI_COMPLETED":
        if case.day3_investigated_at_utc is None:
            case.day3_investigated_at_utc = now_utc
            case.case_classification = req.case_classification
        case.day7_foci_responded_at_utc = now_utc
        case.foci_irs_llin_summary = req.foci_irs_llin_summary
        case.current_stage = "DAY_7_FOCI_COMPLETED"

    await db.commit()
    await db.refresh(case)
    return _case_to_response(case)


async def scan_and_escalate_all_137_breaches(
    db: AsyncSession,
) -> list[MalariaKalaazar137CaseResponse]:
    """Scan all active 1-3-7 cases and escalate any Day-3 or Day-7 statutory SLA breaches."""
    stmt = select(MalariaKalaazar137Case).where(
        MalariaKalaazar137Case.current_stage != "DAY_7_FOCI_COMPLETED"
    )
    result = await db.execute(stmt)
    cases = list(result.scalars().all())
    for c in cases:
        await enforce_single_137_case_sla(db, c)
    await db.commit()
    return [_case_to_response(c) for c in cases]
