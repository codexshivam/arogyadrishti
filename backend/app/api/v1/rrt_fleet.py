"""EDCD 'Search & Destroy' (खोज र नष्ट गर) RRT Fleet Dispatch & Policy-Gated Focal ULV Space-Spraying Router."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
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
from app.db.models.rrt_dispatch import RrtDispatchLog, RrtVehicleUnit
from app.db.session import get_db_session
from app.schemas.dto import (
    RrtDispatchRequest,
    RrtDispatchResponse,
    RrtUlvOverrideRequest,
)
from app.services.notification_service import get_notification_service
from app.services.routing_adapter import select_nearest_available_rrt

router = APIRouter(prefix="/api/v1/rrt", tags=["EDCD RRT Fleet & Policy-Gated Spraying"])


@router.get("/units")
async def list_rrt_units_endpoint(
    palika_code: str | None = Query(default=None),
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """List Rapid Response Team (RRT — BA-2-JHA-... government plates) units and Bti/Temephos stocks."""
    target_palika = palika_code or principal.palika_code
    if not principal.can_access_palika(target_palika):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Palika isolation violation: cannot view RRT fleet for palika '{target_palika}'.",
        )

    units = list(
        (
            await session.execute(
                select(RrtVehicleUnit).where(
                    RrtVehicleUnit.palika_code == target_palika
                )
            )
        )
        .scalars()
        .all()
    )
    stamp = ad_to_bs_stamp()
    return {
        "palika_code": target_palika,
        "count": len(units),
        "units": [
            {
                "vehicle_id": u.vehicle_id,
                "plate_number": u.plate_number,
                "base_ward_id": u.base_ward_id,
                "team_lead_name": u.team_lead_name,
                "team_lead_name_ne": u.team_lead_name_ne,
                "driver_phone": u.driver_phone,
                "bti_stock_kg": u.bti_stock_kg,
                "temephos_stock_liters": u.temephos_stock_liters,
                "ulv_equipment_mounted": u.ulv_equipment_mounted,
                "status": u.status,
                "base_lat": u.base_lat,
                "base_lng": u.base_lng,
                "updated_at_bs": u.updated_at_bs,
            }
            for u in units
        ],
        "timestamp_utc": stamp.timestamp_utc,
        "bs_date": stamp.bs_combined_label,
    }


@router.post("/dispatch", response_model=RrtDispatchResponse)
async def dispatch_search_and_destroy_rrt_endpoint(
    payload: RrtDispatchRequest,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> RrtDispatchResponse:
    """
    Default EDCD Nepal Vector Control Dispatch:
    Assigns the nearest available Rapid Response Team (RRT) stocked with 'Khoj Ra Nashta Gar'
    physical source-reduction toolkits and Bacillus thuringiensis israelensis (Bti) larvicide
    using sovereign OSRM Nepal road routing.
    """
    enforce_ward_isolation(
        principal, payload.composite_ward_id, allow_read_only_nodal=False
    )

    parts = payload.composite_ward_id.split("-")
    inferred_palika = parts[3] if len(parts) >= 4 else principal.palika_code

    units = list(
        (
            await session.execute(
                select(RrtVehicleUnit).where(
                    RrtVehicleUnit.palika_code == inferred_palika,
                    RrtVehicleUnit.status == "AVAILABLE",
                )
            )
        )
        .scalars()
        .all()
    )
    if not units:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"All RRT units in Palika {inferred_palika} are currently dispatched.",
        )

    best_unit, route = select_nearest_available_rrt(
        units=units,
        target_lat=payload.target_lat,
        target_lng=payload.target_lng,
    )

    now_utc = datetime.now(UTC)
    stamp = ad_to_bs_stamp(now_utc)
    dispatch_id = f"RRT-DSP-{uuid.uuid4().hex[:10].upper()}"
    bti_grams = round(payload.water_surface_sqm * 1.0, 1)

    action_ne = (
        f"खोज र नष्ट गर अभियान (RRT परिचालन) + जैविक लार्भिसाइड Bti @ 0.5-1.0 g/m² ({bti_grams} ग्राम)"
    )
    action_en = (
        f"Khoj Ra Nashta Gar (Search & Destroy RRT) + Bti Biological Larviciding ({bti_grams} g)"
    )

    log_row = RrtDispatchLog(
        dispatch_id=dispatch_id,
        vehicle_id=best_unit.vehicle_id,
        plate_number=best_unit.plate_number,
        composite_ward_id=payload.composite_ward_id,
        palika_code=inferred_palika,
        dispatch_type="SEARCH_AND_DESTROY",
        requested_by_id=principal.sub,
        approved_by_chief_id=None,
        ewars_cases_verified=0,
        breteau_index_at_dispatch=22.0,
        campaign_action_ne=action_ne,
        campaign_action_en=action_en,
        route_distance_km=route.distance_km,
        route_eta_minutes=route.eta_minutes,
        routing_engine=route.routing_engine,
        statutory_justification="Standard EDCD Search & Destroy + Bti Larviciding Protocol",
        status="DISPATCHED",
        dispatched_at_utc=now_utc,
        dispatched_at_bs=stamp.bs_combined_label,
    )
    session.add(log_row)
    await session.flush()

    await append_worm_audit_log(
        session,
        event_type="RRT_SEARCH_AND_DESTROY_DISPATCH",
        actor_id=principal.sub,
        actor_role=principal.role.value,
        palika_code=inferred_palika,
        resource_id=f"rrt_dispatches/{dispatch_id}",
        payload={
            "vehicle_id": best_unit.vehicle_id,
            "plate_number": best_unit.plate_number,
            "composite_ward_id": payload.composite_ward_id,
            "route_distance_km": route.distance_km,
            "route_eta_minutes": route.eta_minutes,
        },
    )

    await get_notification_service().route_system_event(
        session,
        target_user_id=principal.sub,
        event_type="RRT_DISPATCHED",
        title_en=f"RRT Unit {best_unit.plate_number} Dispatched to {payload.composite_ward_id}",
        title_ne=f"वडा {payload.composite_ward_id} मा RRT भ्यान ({best_unit.plate_number}) परिचालन",
        summary_en=f"{action_en} • ETA: {route.eta_minutes} min ({route.distance_km} km).",
        summary_ne=f"{action_ne} • अनुमानित समय: {route.eta_minutes} मिनेट।",
        metadata={
            "dispatch_id": dispatch_id,
            "vehicle_id": best_unit.vehicle_id,
            "plate_number": best_unit.plate_number,
            "composite_ward_id": payload.composite_ward_id,
        },
    )

    return RrtDispatchResponse(
        dispatch_id=dispatch_id,
        dispatch_type="SEARCH_AND_DESTROY",
        composite_ward_id=payload.composite_ward_id,
        palika_code=inferred_palika,
        vehicle_id=best_unit.vehicle_id,
        plate_number=best_unit.plate_number,
        team_lead_name=best_unit.team_lead_name,
        team_lead_name_ne=best_unit.team_lead_name_ne,
        driver_phone=best_unit.driver_phone,
        bti_stock_kg=best_unit.bti_stock_kg,
        temephos_stock_liters=best_unit.temephos_stock_liters,
        campaign_action_ne=action_ne,
        campaign_action_en=action_en,
        route_distance_km=route.distance_km,
        route_eta_minutes=route.eta_minutes,
        routing_engine=route.routing_engine,
        status="DISPATCHED",
        timestamp_utc=stamp.timestamp_utc,
        timestamp_npt=stamp.timestamp_npt,
        bs_date=stamp.bs_combined_label,
    )


@router.post("/ulv-override", response_model=RrtDispatchResponse)
async def dispatch_focal_ulv_override_endpoint(
    payload: RrtUlvOverrideRequest,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> RrtDispatchResponse:
    """
    Policy-Gated Focal ULV Space-Spraying Endpoint (EDCD National Dengue Guidelines):
    STRICTLY REJECTS routine fogging requests unless ALL 3 statutory conditions hold:
    1. `current_user.role == NepalStaffRole.PALIKA_HEALTH_CHIEF` ("palika_health_chief")
    2. `payload.ewars_confirmed_cases > 0` (confirmed clinical virus transmission in ward)
    3. `payload.breteau_index >= 30.0` (Critical Tier-1 vector density threshold)
    Every rejection or approval is permanently recorded in the WORM audit ledger.
    """
    if principal.role != NepalStaffRole.PALIKA_HEALTH_CHIEF:
        await append_worm_audit_log(
            session,
            event_type="ULV_OVERRIDE_RBAC_REJECTED",
            actor_id=principal.sub,
            actor_role=principal.role.value,
            palika_code=principal.palika_code,
            resource_id=f"wards/{payload.composite_ward_id}/ulv",
            payload={
                "reason": "ROLE_NOT_PALIKA_HEALTH_CHIEF",
                "attempted_by_role": principal.role.value,
            },
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "EDCD Nepal Policy Gate Forbidden: Routine fogging is prohibited. "
                "Focal ULV space-spraying requires cryptographic sign-off by 'palika_health_chief'."
            ),
        )

    enforce_ward_isolation(
        principal, payload.composite_ward_id, allow_read_only_nodal=False
    )

    if payload.ewars_confirmed_cases <= 0 or payload.breteau_index < 30.0:
        await append_worm_audit_log(
            session,
            event_type="ULV_OVERRIDE_EPIDEMIOLOGICAL_GATE_REJECTED",
            actor_id=principal.sub,
            actor_role=principal.role.value,
            palika_code=principal.palika_code,
            resource_id=f"wards/{payload.composite_ward_id}/ulv",
            payload={
                "ewars_confirmed_cases": payload.ewars_confirmed_cases,
                "breteau_index": payload.breteau_index,
                "reason": "REQUIRES_EWARS_CASES_GT_0_AND_BI_GTE_30",
            },
        )
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=(
                "EDCD Nepal Epidemiological Gate Rejected: Focal ULV space-spraying is strictly prohibited "
                f"unless ewars_confirmed_cases > 0 (got {payload.ewars_confirmed_cases}) AND "
                f"breteau_index >= 30.0 (got {payload.breteau_index}). Prioritize 'Khoj Ra Nashta Gar' & Bti."
            ),
        )

    units = list(
        (
            await session.execute(
                select(RrtVehicleUnit).where(
                    RrtVehicleUnit.palika_code == principal.palika_code,
                    RrtVehicleUnit.ulv_equipment_mounted.is_(True),
                )
            )
        )
        .scalars()
        .all()
    )
    if not units:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="No ULV-equipped RRT vehicle available in Palika.",
        )

    best_unit, route = select_nearest_available_rrt(
        units=units,
        target_lat=payload.target_lat,
        target_lng=payload.target_lng,
    )

    now_utc = datetime.now(UTC)
    stamp = ad_to_bs_stamp(now_utc)
    dispatch_id = f"ULV-OVR-{uuid.uuid4().hex[:10].upper()}"
    action_ne = (
        f"फोकल ULV कोल्ड एरोसोल स्प्रे (पालिका स्वास्थ्य प्रमुख स्वीकृत | EWARS केस={payload.ewars_confirmed_cases}, BI={payload.breteau_index})"
    )
    action_en = (
        f"Approved Focal ULV Space-Spraying Override (EWARS Cases={payload.ewars_confirmed_cases}, BI={payload.breteau_index})"
    )

    log_row = RrtDispatchLog(
        dispatch_id=dispatch_id,
        vehicle_id=best_unit.vehicle_id,
        plate_number=best_unit.plate_number,
        composite_ward_id=payload.composite_ward_id,
        palika_code=principal.palika_code,
        dispatch_type="ULV_FOCAL_OVERRIDE",
        requested_by_id=principal.sub,
        approved_by_chief_id=principal.sub,
        ewars_cases_verified=payload.ewars_confirmed_cases,
        breteau_index_at_dispatch=payload.breteau_index,
        campaign_action_ne=action_ne,
        campaign_action_en=action_en,
        route_distance_km=route.distance_km,
        route_eta_minutes=route.eta_minutes,
        routing_engine=route.routing_engine,
        statutory_justification=payload.statutory_justification,
        status="DISPATCHED",
        dispatched_at_utc=now_utc,
        dispatched_at_bs=stamp.bs_combined_label,
    )
    session.add(log_row)
    await session.flush()

    await append_worm_audit_log(
        session,
        event_type="ULV_FOCAL_OVERRIDE_APPROVED",
        actor_id=principal.sub,
        actor_role=principal.role.value,
        palika_code=principal.palika_code,
        resource_id=f"rrt_dispatches/{dispatch_id}",
        payload={
            "composite_ward_id": payload.composite_ward_id,
            "ewars_confirmed_cases": payload.ewars_confirmed_cases,
            "breteau_index": payload.breteau_index,
            "statutory_justification": payload.statutory_justification,
            "vehicle_plate": best_unit.plate_number,
        },
    )

    return RrtDispatchResponse(
        dispatch_id=dispatch_id,
        dispatch_type="ULV_FOCAL_OVERRIDE",
        composite_ward_id=payload.composite_ward_id,
        palika_code=principal.palika_code,
        vehicle_id=best_unit.vehicle_id,
        plate_number=best_unit.plate_number,
        team_lead_name=best_unit.team_lead_name,
        team_lead_name_ne=best_unit.team_lead_name_ne,
        driver_phone=best_unit.driver_phone,
        bti_stock_kg=best_unit.bti_stock_kg,
        temephos_stock_liters=best_unit.temephos_stock_liters,
        campaign_action_ne=action_ne,
        campaign_action_en=action_en,
        route_distance_km=route.distance_km,
        route_eta_minutes=route.eta_minutes,
        routing_engine=route.routing_engine,
        status="DISPATCHED",
        timestamp_utc=stamp.timestamp_utc,
        timestamp_npt=stamp.timestamp_npt,
        bs_date=stamp.bs_combined_label,
    )
