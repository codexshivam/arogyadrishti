"""NHFR Accredited Hospitals & KMC Urban Health Promotion Centers (UHPCs) Spatial Proximity Router."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.bs_calendar import ad_to_bs_stamp
from app.db.session import get_db_session
from app.services.dhis2_ihmis_connector import get_dhis2_ihmis_connector

router = APIRouter(prefix="/api/v1/facilities", tags=["NHFR Health Facilities & UHPCs"])


@router.get("/nearby")
async def get_nearby_facilities_endpoint(
    lat: float = Query(default=27.7049, ge=26.0, le=30.5),
    lng: float = Query(default=85.3137, ge=80.0, le=88.5),
    radius_km: float = Query(default=10.0, ge=0.5, le=100.0),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """
    Return nearest accredited Government of Nepal hospitals (Teku Hospital, Bir Hospital,
    Patan Hospital, TU Teaching Hospital, Civil Service Hospital) and KMC Urban Health Promotion
    Centers (UHPCs / सहरी स्वास्थ्य प्रवर्द्धन केन्द्र) with 24x7 emergency fever clinic flags
    and EDCD hotline `1115` (Hello Swasthya).
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
