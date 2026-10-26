"""Nationwide Operations Router:
- Module 1: EDCD 5-Vector Mandate & WHO/EDCD 1-3-7 Statutory SLA Engine (`/api/v1/multi-vector/*`)
- Module 3: NDRRMA BIPAD Portal & DHM AWS Ground Weather Fusion (`/api/v1/disaster-weather/*`)
- Module 5: MoHP eLMIS & Provincial PHLMC Stockout Predictor (`/api/v1/elmis/*`)
- Module 7: Singha Durbar GIOMS Official Tippani PDF & Shrawan–Ashadh SuTRA Fiscal Planner (`/api/v1/palika/*`)
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.audit_worm import append_worm_audit_log
from app.core.bs_calendar import ad_to_bs_stamp
from app.core.rbac import AuthenticatedStaffPrincipal, get_current_staff
from app.db.session import get_db_session
from app.schemas.dto import (
    DisasterWeatherFusionRequest,
    DisasterWeatherFusionResponse,
    ElmisPalikaForecastResponse,
    MalariaKalaazar137CaseResponse,
    MalariaKalaazar137CreateRequest,
    MalariaKalaazar137StageUpdateRequest,
    MultiVectorEvaluationRequest,
    MultiVectorEvaluationResponse,
    PalikaAnnualBudgetForecastResponse,
)
from app.services.bipad_dhm_connector import fuse_bipad_disaster_and_dhm_weather
from app.services.elmis_forecast import forecast_elmis_stockout_for_palika
from app.services.gioms_documents import (
    generate_gioms_tippani_pdf_bytes,
    generate_palika_fiscal_budget_plan,
)
from app.services.multi_vector_engine import (
    create_137_case,
    evaluate_multi_vector_risk,
    scan_and_escalate_all_137_breaches,
    update_137_case_stage,
)

router = APIRouter(tags=["Nationwide Multi-Vector, 1-3-7 SLA, BIPAD/DHM, eLMIS & GIOMS"])


# ---------------------------------------------------------------------------
# Module 1: EDCD 5-Vector Evaluation & WHO/EDCD 1-3-7 Statutory SLA Engine
# ---------------------------------------------------------------------------


@router.post("/api/v1/multi-vector/evaluate", response_model=MultiVectorEvaluationResponse)
async def evaluate_multi_vector_endpoint(
    payload: MultiVectorEvaluationRequest,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
) -> MultiVectorEvaluationResponse:
    """Evaluate habitat, climate, ecological belt, and case cluster risk across all 5 EDCD vector programs."""
    _ = principal
    return evaluate_multi_vector_risk(payload)


@router.post(
    "/api/v1/multi-vector/1-3-7-cases",
    response_model=MalariaKalaazar137CaseResponse,
)
async def create_137_case_endpoint(
    payload: MalariaKalaazar137CreateRequest,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> MalariaKalaazar137CaseResponse:
    """Register a Malaria or Kala-azar case in the statutory WHO/EDCD 1-3-7 Elimination SLA Engine."""
    res = await create_137_case(session, payload, reporter_id=principal.sub)
    await append_worm_audit_log(
        session,
        event_type="STATUTORY_137_CASE_REGISTERED",
        actor_id=principal.sub,
        actor_role=principal.role.value,
        palika_code=res.palika_code,
        resource_id=f"137/{res.id}",
        payload={
            "case_code": res.case_code,
            "disease": res.disease,
            "composite_ward_id": res.composite_ward_id,
            "sla_breached": res.sla_breached,
        },
    )
    return res


@router.patch(
    "/api/v1/multi-vector/1-3-7-cases/{case_id}",
    response_model=MalariaKalaazar137CaseResponse,
)
async def update_137_case_stage_endpoint(
    case_id: str,
    payload: MalariaKalaazar137StageUpdateRequest,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> MalariaKalaazar137CaseResponse:
    """Advance a 1-3-7 case to Day-3 Case Investigation or Day-7 Foci IRS + LLIN Response."""
    updated = await update_137_case_stage(session, case_id, payload)
    if updated is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"1-3-7 case {case_id} not found.",
        )
    await append_worm_audit_log(
        session,
        event_type=f"STATUTORY_137_{payload.stage}",
        actor_id=principal.sub,
        actor_role=principal.role.value,
        palika_code=updated.palika_code,
        resource_id=f"137/{updated.id}",
        payload={
            "case_code": updated.case_code,
            "current_stage": updated.current_stage,
            "case_classification": updated.case_classification,
        },
    )
    return updated


@router.post(
    "/api/v1/multi-vector/1-3-7-sla-check",
    response_model=list[MalariaKalaazar137CaseResponse],
)
async def trigger_137_sla_watchdog_endpoint(
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> list[MalariaKalaazar137CaseResponse]:
    """Scan all active 1-3-7 cases and automatically escalate Day-3 (72h) or Day-7 (168h) breaches to the Provincial Health Directorate."""
    _ = principal
    return await scan_and_escalate_all_137_breaches(session)


# ---------------------------------------------------------------------------
# Module 3: NDRRMA BIPAD Portal & DHM Ground Weather Station (AWS) Fusion
# ---------------------------------------------------------------------------


@router.post(
    "/api/v1/disaster-weather/fuse-ward",
    response_model=DisasterWeatherFusionResponse,
)
async def fuse_bipad_and_dhm_weather_endpoint(
    payload: DisasterWeatherFusionRequest,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> DisasterWeatherFusionResponse:
    """Fuse NDRRMA BIPAD flood/landslide alerts and DHM ground AWS telemetry to apply a 14-day Post-Disaster Outbreak Multiplier."""
    res = await fuse_bipad_disaster_and_dhm_weather(
        session, payload, actor_id=principal.sub
    )
    await append_worm_audit_log(
        session,
        event_type="BIPAD_DHM_DISASTER_WEATHER_FUSION",
        actor_id=principal.sub,
        actor_role=principal.role.value,
        palika_code=res.palika_code,
        resource_id=f"bipad-dhm/{res.composite_ward_id}",
        payload={
            "river_corridor": res.river_corridor,
            "post_disaster_multiplier": res.post_disaster_multiplier,
            "adjusted_dengue_risk": res.adjusted_dengue_risk,
            "adjusted_scrub_typhus_risk": res.adjusted_scrub_typhus_risk,
        },
    )
    return res


# ---------------------------------------------------------------------------
# Module 5: MoHP eLMIS Supply Chain & Provincial PHLMC Stockout Predictor
# ---------------------------------------------------------------------------


@router.get(
    "/api/v1/elmis/forecast/{palika_code}",
    response_model=ElmisPalikaForecastResponse,
)
async def get_elmis_palika_forecast_endpoint(
    palika_code: str,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> ElmisPalikaForecastResponse:
    """Predict 14-day commodity burn rates for a Palika and auto-emit Provincial PHLMC eLMIS requisitions when days_remaining < 10."""
    res = await forecast_elmis_stockout_for_palika(session, palika_code)
    await append_worm_audit_log(
        session,
        event_type="ELMIS_PHLMC_FORECAST_GENERATED",
        actor_id=principal.sub,
        actor_role=principal.role.value,
        palika_code=palika_code,
        resource_id=f"elmis/{palika_code}",
        payload={
            "phlmc_hub_name": res.phlmc_hub_name,
            "outbreak_surge_multiplier": res.outbreak_surge_multiplier,
            "auto_requisitions_count": len(res.auto_requisitions),
        },
    )
    return res


# ---------------------------------------------------------------------------
# Module 7: Singha Durbar GIOMS Official Tippani PDF & Shrawan–Ashadh SuTRA Budget
# ---------------------------------------------------------------------------


@router.get(
    "/api/v1/palika/{palika_code}/fiscal-budget-plan",
    response_model=PalikaAnnualBudgetForecastResponse,
)
async def get_palika_fiscal_budget_plan_endpoint(
    palika_code: str,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> PalikaAnnualBudgetForecastResponse:
    """Generate the Shrawan 1 – Ashadh End Bikram Sambat Fiscal Year Municipal Assembly Vector Budget Plan (`SuTRA` compatible)."""
    _ = principal
    return await generate_palika_fiscal_budget_plan(session, palika_code=palika_code)


@router.get(
    "/api/v1/palika/annual-budget-forecast",
    response_model=PalikaAnnualBudgetForecastResponse,
)
async def get_palika_annual_budget_forecast_alias(
    palika_code: str = Query(default="30608"),
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> PalikaAnnualBudgetForecastResponse:
    """Alias endpoint `/api/v1/palika/annual-budget-forecast` for Shrawan–Ashadh Municipal Assembly Fiscal Planning."""
    _ = principal
    return await generate_palika_fiscal_budget_plan(session, palika_code=palika_code)


@router.get("/api/v1/palika/{palika_code}/gioms-tippani-pdf")
async def download_gioms_tippani_pdf_endpoint(
    palika_code: str,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> Response:
    """Generate and stream a Singha Durbar GIOMS Official Nepali Tippani PDF for Chief Administrative Officer (CAO) sign-off."""
    budget = await generate_palika_fiscal_budget_plan(session, palika_code=palika_code)
    pdf_bytes = generate_gioms_tippani_pdf_bytes(
        budget,
        prepared_by=f"Officer {principal.sub} ({principal.role.value})",
    )
    stamp = ad_to_bs_stamp()
    await append_worm_audit_log(
        session,
        event_type="GIOMS_TIPPANI_PDF_EXPORTED",
        actor_id=principal.sub,
        actor_role=principal.role.value,
        palika_code=palika_code,
        resource_id=f"gioms-tippani/{palika_code}",
        payload={
            "cao_tippani_reference_no": budget.cao_tippani_reference_no,
            "total_estimated_budget_npr": budget.total_estimated_budget_npr,
        },
    )
    filename = f"GIOMS_Tippani_{palika_code}_{stamp.bs_year}.pdf"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "X-GIOMS-Reference": budget.cao_tippani_reference_no,
            "X-Bikram-Sambat-Date": stamp.bs_date_iso,
        },
    )
