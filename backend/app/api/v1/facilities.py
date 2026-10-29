"""NHFR Accredited Hospitals & KMC Urban Health Promotion Centers (UHPCs) Spatial Proximity and CRUD Router."""

from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.audit_worm import append_worm_audit_log
from app.core.bs_calendar import ad_to_bs_stamp
from app.core.rbac import AuthenticatedStaffPrincipal, get_current_staff
from app.db.models.admin_boundary import HealthFacility
from app.db.session import get_db_session
from app.schemas.dto import HealthFacilityCreateRequest, HealthFacilityUpdateRequest
from app.services.dhis2_ihmis_connector import get_dhis2_ihmis_connector

router = APIRouter(prefix="/api/v1/facilities", tags=["NHFR Health Facilities & UHPCs"])


@router.get("")
async def list_health_facilities_endpoint(
    palika_code: str | None = Query(default=None),
    composite_ward_id: str | None = Query(default=None),
    search: str | None = Query(default=None),
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """List health facilities filtered by Palika/Ward according to user role."""
    stmt = select(HealthFacility)

    if principal.is_admin:
        if palika_code:
            stmt = stmt.where(HealthFacility.palika_code == palika_code)
    elif principal.is_municipality_admin:
        stmt = stmt.where(HealthFacility.palika_code == principal.palika_code)
    else:
        stmt = stmt.where(HealthFacility.composite_ward_id.in_(principal.assigned_wards))

    if composite_ward_id:
        stmt = stmt.where(HealthFacility.composite_ward_id == composite_ward_id)

    if search:
        term = f"%{search.strip()}%"
        stmt = stmt.where(
            or_(
                HealthFacility.name_en.ilike(term),
                HealthFacility.name_ne.ilike(term),
                HealthFacility.facility_type.ilike(term),
            )
        )

    stmt = stmt.order_by(HealthFacility.name_en.asc())
    facilities = list((await session.execute(stmt)).scalars().all())
    stamp = ad_to_bs_stamp()

    return {
        "count": len(facilities),
        "facilities": [
            {
                "facility_id": f.facility_id,
                "nhfr_code": f.nhfr_code,
                "name_en": f.name_en,
                "name_ne": f.name_ne,
                "facility_type": f.facility_type,
                "palika_code": f.palika_code,
                "composite_ward_id": f.composite_ward_id,
                "latitude": f.latitude,
                "longitude": f.longitude,
                "elevation_m": f.elevation_m,
                "has_24x7_fever_clinic": f.has_24x7_fever_clinic,
                "ns1_elisa_available": f.ns1_elisa_available,
                "rapid_diagnostic_kit_stock": f.rapid_diagnostic_kit_stock,
                "emergency_phone": f.emergency_phone,
                "hello_swasthya_hotline": f.hello_swasthya_hotline,
            }
            for f in facilities
        ],
        "timestamp_utc": stamp.timestamp_utc,
        "bs_date": stamp.bs_combined_label,
    }


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_health_facility_endpoint(
    payload: HealthFacilityCreateRequest,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """
    Create a new health facility:
    - Admin: can create in any Palika.
    - Municipality Admin: can only create for their assigned Palika.
    """
    if not (principal.is_admin or principal.is_municipality_admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Forbidden: Only Administrators and Municipality Administrators can add health centers.",
        )

    target_palika = principal.palika_code if principal.is_municipality_admin else payload.palika_code

    existing = (
        await session.execute(
            select(HealthFacility).where(HealthFacility.nhfr_code == payload.nhfr_code)
        )
    ).scalar_one_or_none()
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Conflict: Health facility with NHFR code '{payload.nhfr_code}' already exists.",
        )

    f_id = f"fac-{uuid.uuid4().hex[:8]}"
    facility = HealthFacility(
        facility_id=f_id,
        nhfr_code=payload.nhfr_code,
        name_en=payload.name_en,
        name_ne=payload.name_ne or payload.name_en,
        facility_type=payload.facility_type,
        palika_code=target_palika,
        composite_ward_id=payload.composite_ward_id,
        latitude=payload.latitude,
        longitude=payload.longitude,
        elevation_m=payload.elevation_m,
        has_24x7_fever_clinic=payload.has_24x7_fever_clinic,
        ns1_elisa_available=payload.ns1_elisa_available,
        rapid_diagnostic_kit_stock=payload.rapid_diagnostic_kit_stock,
        emergency_phone=payload.emergency_phone,
        hello_swasthya_hotline=payload.hello_swasthya_hotline,
        geom=None,
    )
    session.add(facility)
    await session.flush()

    await append_worm_audit_log(
        session,
        event_type="HEALTH_FACILITY_CREATED",
        actor_id=principal.sub,
        actor_role=principal.role.value,
        palika_code=target_palika,
        resource_id=f"facilities/{f_id}",
        payload={"nhfr_code": payload.nhfr_code, "name_en": payload.name_en},
    )

    return {"status": "CREATED", "facility_id": f_id, "name_en": facility.name_en}


@router.put("/{facility_id}")
async def update_health_facility_endpoint(
    facility_id: str,
    payload: HealthFacilityUpdateRequest,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """Update health facility with jurisdiction verification."""
    facility = (
        await session.execute(
            select(HealthFacility).where(HealthFacility.facility_id == facility_id)
        )
    ).scalar_one_or_none()
    if facility is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Facility not found.")

    if not principal.is_admin:
        if not principal.is_municipality_admin or facility.palika_code != principal.palika_code:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Forbidden: Cannot modify health centers outside your assigned municipality.",
            )

    if payload.name_en is not None:
        facility.name_en = payload.name_en
    if payload.name_ne is not None:
        facility.name_ne = payload.name_ne
    if payload.facility_type is not None:
        facility.facility_type = payload.facility_type
    if payload.composite_ward_id is not None:
        facility.composite_ward_id = payload.composite_ward_id
    if payload.latitude is not None:
        facility.latitude = payload.latitude
    if payload.longitude is not None:
        facility.longitude = payload.longitude
    if payload.elevation_m is not None:
        facility.elevation_m = payload.elevation_m
    if payload.has_24x7_fever_clinic is not None:
        facility.has_24x7_fever_clinic = payload.has_24x7_fever_clinic
    if payload.ns1_elisa_available is not None:
        facility.ns1_elisa_available = payload.ns1_elisa_available
    if payload.rapid_diagnostic_kit_stock is not None:
        facility.rapid_diagnostic_kit_stock = payload.rapid_diagnostic_kit_stock
    if payload.emergency_phone is not None:
        facility.emergency_phone = payload.emergency_phone
    if payload.hello_swasthya_hotline is not None:
        facility.hello_swasthya_hotline = payload.hello_swasthya_hotline

    await session.flush()
    return {"status": "UPDATED", "facility_id": facility.facility_id, "name_en": facility.name_en}


@router.delete("/{facility_id}")
async def delete_health_facility_endpoint(
    facility_id: str,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """Delete health facility with jurisdiction verification."""
    facility = (
        await session.execute(
            select(HealthFacility).where(HealthFacility.facility_id == facility_id)
        )
    ).scalar_one_or_none()
    if facility is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Facility not found.")

    if not principal.is_admin:
        if not principal.is_municipality_admin or facility.palika_code != principal.palika_code:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Forbidden: Cannot delete health centers outside your assigned municipality.",
            )

    await session.delete(facility)
    await session.flush()
    return {"status": "DELETED", "facility_id": facility_id}


@router.get("/nearby")
async def get_nearby_facilities_endpoint(
    lat: float = Query(default=27.7049, ge=26.0, le=30.5),
    lng: float = Query(default=85.3137, ge=80.0, le=88.5),
    radius_km: float = Query(default=10.0, ge=0.5, le=100.0),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """
    Return nearest accredited Government of Nepal hospitals and Urban Health Promotion
    Centers (UHPCs) with 24x7 emergency fever clinic flags and EDCD hotline 1115.
    """
    connector = get_dhis2_ihmis_connector()
    facilities = await connector.find_nearby_nhfr_facilities(
        session, latitude=lat, longitude=lng, radius_km=radius_km
    )
    stamp = ad_to_bs_stamp()
    return {
        "query_lat": lat,
        "query_lng": lng,
        "radius_km": radius_km,
        "hello_swasthya_hotline": "1115",
        "edcd_teku_control_room": "+977-1-4255796",
        "count": len(facilities),
        "facilities": facilities,
        "timestamp_utc": stamp.timestamp_utc,
        "bs_date": stamp.bs_combined_label,
    }
