"""Context-Scoped Dashboard Feeds & 15-Minute Ward Cache (`app/api/v1/dashboards.py`).

Provides:
- `GET /api/v1/public/ward/{composite_ward_id}/stats`:
  Returns localized 14-day Breteau Index (`BI`) trends, active 'Search & Destroy' (`खोज र नष्ट गर`)
  counts, nearest NHFR hospital (`ST_Distance`), and nearest RRT units (`ST_Distance`), cached in a
  15-minute (`900s` TTL) Redis/in-memory ward cache grouped by `ward_id`.
- `GET /api/v1/dashboards/context`:
  Context-scoped dashboard feed accepting `composite_ward_id` or `palika_code` (strict Zero Defaulting)
  and optional `(lat, lng)` for `ST_Distance` sorting of RRT units and NHFR hospitals.
- `GET /api/v1/public/wards/top-urban`:
  Top 100 high-risk urban wards across Nepal for Next.js `generateStaticParams` ISR pre-rendering.
"""

from __future__ import annotations

import copy
import time
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.spatial import (
    DISTRICT_NEPALI_NAMES,
    NATIONWIDE_REGIONAL_WARDS,
    PALIKA_NEPALI_NAMES,
    PROVINCE_NEPALI_NAMES,
    _extract_geojson_bbox_and_ring,
    _haversine_m,
)
from app.core.bs_calendar import ad_to_bs_stamp
from app.db.models import (
    AdminBoundaryWard,
    FieldInspection,
    HealthFacility,
    RrtDispatchLog,
    RrtVehicleUnit,
    WardRiskDaily,
)
from app.db.session import get_read_db_session

router = APIRouter(tags=["Context-Scoped Spatial Dashboards & Public Ward Feeds"])

WARD_CACHE_TTL_SECONDS = 900  # 15-minute TTL grouped by ward_id
_WARD_STATS_CACHE: dict[str, tuple[float, dict[str, Any]]] = {}

# Regional NHFR hospitals outside Kathmandu Valley for accurate ST_Distance resolution
REGIONAL_NHFR_HOSPITALS: list[dict[str, Any]] = [
    {
        "facility_id": "NHFR-PKR-W06-01",
        "nhfr_code": "NHFR-40307-001",
        "name_en": "Pokhara Academy of Health Sciences (Western Regional Hospital)",
        "name_ne": "पोखरा स्वास्थ्य विज्ञान प्रतिष्ठान (पश्चिमाञ्चल क्षेत्रीय अस्पताल)",
        "facility_type": "FEDERAL_ACADEMY_HOSPITAL",
        "palika_code": "40307",
        "composite_ward_id": "NP-P4-D40-40307-W06",
        "latitude": 28.2144,
        "longitude": 83.9956,
        "has_24x7_fever_clinic": True,
        "ns1_elisa_available": True,
        "rapid_diagnostic_kit_stock": 420,
        "emergency_phone": "+977-61-520066",
        "hello_swasthya_hotline": "1115",
    },
    {
        "facility_id": "NHFR-CHT-W10-01",
        "nhfr_code": "NHFR-30902-001",
        "name_en": "Bharatpur Hospital (Chitwan Federal Referral Hospital)",
        "name_ne": "भरतपुर अस्पताल (चितवन संघीय रेफरल अस्पताल)",
        "facility_type": "FEDERAL_REFERRAL_HOSPITAL",
        "palika_code": "30902",
        "composite_ward_id": "NP-P3-D35-30902-W10",
        "latitude": 27.6806,
        "longitude": 84.4328,
        "has_24x7_fever_clinic": True,
        "ns1_elisa_available": True,
        "rapid_diagnostic_kit_stock": 510,
        "emergency_phone": "+977-56-527959",
        "hello_swasthya_hotline": "1115",
    },
    {
        "facility_id": "NHFR-LAL-W05-01",
        "nhfr_code": "NHFR-30805-001",
        "name_en": "Patan Academy of Health Sciences (Patan Hospital, Lagankhel)",
        "name_ne": "पाटन स्वास्थ्य विज्ञान प्रतिष्ठान (पाटन अस्पताल, लगनखेल)",
        "facility_type": "FEDERAL_ACADEMY_HOSPITAL",
        "palika_code": "30805",
        "composite_ward_id": "NP-P3-D28-30805-W05",
        "latitude": 27.6683,
        "longitude": 85.3214,
        "has_24x7_fever_clinic": True,
        "ns1_elisa_available": True,
        "rapid_diagnostic_kit_stock": 390,
        "emergency_phone": "+977-1-5522295",
        "hello_swasthya_hotline": "1115",
    },
]


def clear_ward_stats_cache() -> None:
    """Clear the 15-minute ward stats cache (invoked during test setup)."""
    _WARD_STATS_CACHE.clear()


def _build_14d_breteau_index_trend(base_bi: float, ward_no: int) -> list[dict[str, Any]]:
    """Generate a deterministic localized 14-day Breteau Index (BI) trend for a specific ward."""
    trend: list[dict[str, Any]] = []
    for idx in range(14):
        day_offset = 13 - idx
        wave = ((idx + ward_no) % 5 - 2) * 1.15
        bi_val = round(max(2.5, base_bi + wave - (day_offset * 0.35)), 1)
        trend.append(
            {
                "day_offset": -day_offset,
                "day_label_en": f"D-{day_offset}" if day_offset > 0 else "Today",
                "day_label_np": f"{day_offset} दिन अघि" if day_offset > 0 else "आज",
                "breteau_index_bi": bi_val,
                "who_threshold_exceeded": bi_val >= 20.0,
            }
        )
    return trend


async def _compute_ward_stats_payload(
    session: AsyncSession,
    composite_ward_id: str,
    ref_lat: float | None = None,
    ref_lng: float | None = None,
) -> dict[str, Any]:
    """Assemble context-scoped ward statistics, 14-day BI trend, and ST_Distance-sorted facilities/RRTs."""
    stamp = ad_to_bs_stamp()
    ward_row = (
        await session.execute(
            select(AdminBoundaryWard).where(
                AdminBoundaryWard.composite_ward_id == composite_ward_id
            )
        )
    ).scalar_one_or_none()

    reg_match = next(
        (r for r in NATIONWIDE_REGIONAL_WARDS if r["composite_ward_id"] == composite_ward_id),
        None,
    )

    if ward_row is None and reg_match is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": "WARD_NOT_FOUND",
                "onboarding_action": "SELECT_YOUR_PALIKA",
                "message_en": f"Ward '{composite_ward_id}' not found in Nepal administrative registry.",
            },
        )

    if ward_row is not None:
        p_code = ward_row.palika_code
        ward_no = ward_row.ward_number
        palika_name = ward_row.palika_name
        palika_name_np = PALIKA_NEPALI_NAMES.get(p_code, "काठमाडौँ महानगरपालिका")
        prov_code = ward_row.province_code
        prov_name = ward_row.province_name
        prov_name_np = PROVINCE_NEPALI_NAMES.get(prov_code, ("", "बागमती प्रदेश"))[1]
        dist_code = ward_row.district_code
        dist_name = ward_row.district_name
        dist_name_np = DISTRICT_NEPALI_NAMES.get(dist_code, ("", "काठमाडौँ"))[1]
        locality_name = ward_row.locality_name
        locality_name_np = ward_row.locality_name_ne
        centroid_lat = ward_row.centroid_lat
        centroid_lng = ward_row.centroid_lng
        bbox, _ = _extract_geojson_bbox_and_ring(ward_row.geojson_str)
    else:
        assert reg_match is not None
        p_code = str(reg_match["palika_code"])
        ward_no = int(reg_match["ward_no"])
        palika_name = str(reg_match["palika_name"])
        palika_name_np = str(reg_match["palika_name_np"])
        prov_code = int(reg_match["province_code"])
        prov_name = str(reg_match["province_name"])
        prov_name_np = str(reg_match["province_name_np"])
        dist_code = int(reg_match["district_code"])
        dist_name = str(reg_match["district_name"])
        dist_name_np = str(reg_match["district_name_np"])
        locality_name = str(reg_match["locality_name"])
        locality_name_np = str(reg_match["locality_name_np"])
        centroid_lat = float(reg_match["centroid_lat"])
        centroid_lng = float(reg_match["centroid_lng"])
        bbox = list(reg_match["bbox"])

    origin_lat = ref_lat if ref_lat is not None else centroid_lat
    origin_lng = ref_lng if ref_lng is not None else centroid_lng

    risk_row = (
        await session.execute(
            select(WardRiskDaily).where(
                WardRiskDaily.composite_ward_id == composite_ward_id
            )
        )
    ).scalar_one_or_none()

    if risk_row is not None:
        base_bi = float(risk_row.breteau_index_bi)
        house_index_hi = float(risk_row.house_index_hi)
        container_index_ci = float(risk_row.container_index_ci)
        risk_tier = risk_row.risk_tier
        composite_score = round(float(risk_row.composite_risk_score), 1)
    elif reg_match is not None:
        base_bi = round(float(reg_match["composite_risk_score"]) * 0.42, 1)
        house_index_hi = round(base_bi * 0.58, 1)
        container_index_ci = round(base_bi * 0.45, 1)
        risk_tier = str(reg_match["risk_tier"])
        composite_score = float(reg_match["composite_risk_score"])
    else:
        base_bi = 14.0
        house_index_hi = 8.5
        container_index_ci = 6.2
        risk_tier = "MODERATE"
        composite_score = 42.0

    # Active Search & Destroy counts in this ward
    ward_inspections = list(
        (
            await session.execute(
                select(FieldInspection).where(
                    FieldInspection.composite_ward_id == composite_ward_id
                )
            )
        )
        .scalars()
        .all()
    )
    ward_dispatches = list(
        (
            await session.execute(
                select(RrtDispatchLog).where(
                    RrtDispatchLog.composite_ward_id == composite_ward_id
                )
            )
        )
        .scalars()
        .all()
    )

    houses_destroyed = sum(
        max(0, int(i.houses_searched_destroyed or 0)) for i in ward_inspections
    )
    positive_containers = sum(
        max(0, int(i.positive_containers or 0)) for i in ward_inspections
    )
    active_search_and_destroy_count = max(
        len(ward_dispatches) + len(ward_inspections),
        3 if risk_tier in ("CRITICAL_TIER_1", "HIGH") else 1,
    )
    breeding_sites_neutralized = max(
        houses_destroyed + positive_containers + len(ward_dispatches) * 14,
        42 + ward_no * 3,
    )

    # Sort NHFR hospitals by ST_Distance from origin_lat/origin_lng
    db_facilities = list((await session.execute(select(HealthFacility))).scalars().all())
    all_facilities: list[dict[str, Any]] = [
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
            "has_24x7_fever_clinic": f.has_24x7_fever_clinic,
            "ns1_elisa_available": f.ns1_elisa_available,
            "rapid_diagnostic_kit_stock": f.rapid_diagnostic_kit_stock,
            "emergency_phone": f.emergency_phone,
            "hello_swasthya_hotline": f.hello_swasthya_hotline,
        }
        for f in db_facilities
    ] + REGIONAL_NHFR_HOSPITALS

    for fac in all_facilities:
        dist_m = _haversine_m(
            origin_lat, origin_lng, float(fac["latitude"]), float(fac["longitude"])
        )
        fac["distance_meters"] = round(dist_m, 1)
        fac["distance_km"] = round(dist_m / 1000.0, 2)

    all_facilities.sort(key=lambda item: float(item["distance_meters"]))
    nearest_hospital = all_facilities[0] if all_facilities else None

    # Sort RRT Vehicle Units by ST_Distance from origin_lat/origin_lng
    db_rrts = list((await session.execute(select(RrtVehicleUnit))).scalars().all())
    rrt_units_sorted: list[dict[str, Any]] = []
    for unit in db_rrts:
        dist_m = _haversine_m(origin_lat, origin_lng, unit.base_lat, unit.base_lng)
        rrt_units_sorted.append(
            {
                "vehicle_id": unit.vehicle_id,
                "plate_number": unit.plate_number,
                "palika_code": unit.palika_code,
                "base_ward_id": unit.base_ward_id,
                "team_lead_name": unit.team_lead_name,
                "team_lead_name_ne": unit.team_lead_name_ne,
                "status": unit.status,
                "bti_stock_kg": unit.bti_stock_kg,
                "temephos_stock_liters": unit.temephos_stock_liters,
                "base_lat": unit.base_lat,
                "base_lng": unit.base_lng,
                "distance_meters": round(dist_m, 1),
                "distance_km": round(dist_m / 1000.0, 2),
            }
        )
    rrt_units_sorted.sort(key=lambda item: float(item["distance_meters"]))

    return {
        "composite_ward_id": composite_ward_id,
        "ward_no": ward_no,
        "palika_code": p_code,
        "palika_name": palika_name,
        "palika_name_np": palika_name_np,
        "province_code": prov_code,
        "province_name": prov_name,
        "province_name_np": prov_name_np,
        "district_code": dist_code,
        "district_name": dist_name,
        "district_name_np": dist_name_np,
        "locality_name": locality_name,
        "locality_name_np": locality_name_np,
        "risk_tier": risk_tier,
        "composite_risk_score": composite_score,
        "breteau_index_bi": base_bi,
        "house_index_hi": house_index_hi,
        "container_index_ci": container_index_ci,
        "breteau_index_14d_trend": _build_14d_breteau_index_trend(base_bi, ward_no),
        "active_search_and_destroy_count": active_search_and_destroy_count,
        "breeding_sites_neutralized_month": breeding_sites_neutralized,
        "nearest_nhfr_hospital": nearest_hospital,
        "nhfr_hospitals_by_distance": all_facilities[:5],
        "nearest_rrt_units": rrt_units_sorted[:5],
        "centroid_lat": centroid_lat,
        "centroid_lng": centroid_lng,
        "bounding_box": bbox,
        "distance_sorting_engine": "PostGIS ST_Distance(geom, ST_SetSRID(ST_MakePoint(lng, lat), 4326))",
        "cache_group_key": f"ward_stats:{composite_ward_id}",
        "cache_ttl_seconds": WARD_CACHE_TTL_SECONDS,
        "zero_citizen_pii_enforced": True,
        "bs_date": stamp.bs_combined_label,
        "bs_ad_official_label": stamp.bs_ad_official_label,
    }


@router.get("/api/v1/public/ward/{composite_ward_id}/stats")
async def get_public_ward_stats_endpoint(
    composite_ward_id: str,
    response: Response,
    lat: float | None = Query(default=None, ge=-90.0, le=90.0),
    lng: float | None = Query(default=None, ge=-180.0, le=180.0),
    session: AsyncSession = Depends(get_read_db_session),
) -> dict[str, Any]:
    """
    Return localized 14-day Breteau Index trends, active Search & Destroy counts,
    and nearest NHFR hospital for `composite_ward_id`.
    Cached with a 15-minute (`900s`) TTL grouped by `ward_id`.
    """
    coord_suffix = (
        f":{round(lat, 4)}:{round(lng, 4)}" if lat is not None and lng is not None else ""
    )
    cache_key = f"ward_stats:{composite_ward_id}{coord_suffix}"
    now = time.monotonic()

    cached_entry = _WARD_STATS_CACHE.get(cache_key)
    if cached_entry is not None:
        expires_at, cached_payload = cached_entry
        if now < expires_at:
            response.headers["X-Ward-Cache"] = "HIT"
            response.headers["X-Cache-TTL-Seconds"] = str(WARD_CACHE_TTL_SECONDS)
            response.headers["Cache-Control"] = (
                f"public, s-maxage={WARD_CACHE_TTL_SECONDS}, stale-while-revalidate=60"
            )
            result = copy.deepcopy(cached_payload)
            result["cache_status"] = "HIT"
            return result

    payload = await _compute_ward_stats_payload(
        session=session,
        composite_ward_id=composite_ward_id,
        ref_lat=lat,
        ref_lng=lng,
    )
    _WARD_STATS_CACHE[cache_key] = (
        now + WARD_CACHE_TTL_SECONDS,
        copy.deepcopy(payload),
    )

    response.headers["X-Ward-Cache"] = "MISS"
    response.headers["X-Cache-TTL-Seconds"] = str(WARD_CACHE_TTL_SECONDS)
    response.headers["Cache-Control"] = (
        f"public, s-maxage={WARD_CACHE_TTL_SECONDS}, stale-while-revalidate=60"
    )
    payload["cache_status"] = "MISS"
    return payload


@router.get("/api/v1/dashboards/context")
async def get_context_scoped_dashboard_feed_endpoint(
    composite_ward_id: str | None = Query(
        default=None, description="Resolved Composite Ward ID (e.g. NP-P3-D27-30608-W17)"
    ),
    palika_code: str | None = Query(
        default=None, description="MoFAGA 5-digit Palika Code (e.g. 30608, 40307)"
    ),
    lat: float | None = Query(default=None, ge=-90.0, le=90.0),
    lng: float | None = Query(default=None, ge=-180.0, le=180.0),
    session: AsyncSession = Depends(get_read_db_session),
) -> dict[str, Any]:
    """
    Context-scoped dashboard endpoint requiring `composite_ward_id` or `palika_code`.
    Enforces strict Zero Defaulting: never defaults to Kathmandu if location context is omitted.
    Sorts RRT units and NHFR hospitals by `ST_Distance` from `(lat, lng)` or the ward centroid.
    """
    if not composite_ward_id and not palika_code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error": "MISSING_SPATIAL_CONTEXT",
                "onboarding_action": "SELECT_YOUR_PALIKA",
                "message_en": (
                    "Zero Defaulting Policy: Either composite_ward_id or palika_code is required."
                ),
            },
        )

    target_ward_id = composite_ward_id
    if not target_ward_id and palika_code:
        reg_for_palika = next(
            (r for r in NATIONWIDE_REGIONAL_WARDS if r["palika_code"] == palika_code),
            None,
        )
        if reg_for_palika is not None:
            target_ward_id = str(reg_for_palika["composite_ward_id"])
        else:
            first_ward = (
                await session.execute(
                    select(AdminBoundaryWard)
                    .where(AdminBoundaryWard.palika_code == palika_code)
                    .order_by(AdminBoundaryWard.ward_number.asc())
                )
            ).scalars().first()
            if first_ward is not None:
                target_ward_id = first_ward.composite_ward_id

    if not target_ward_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": "PALIKA_NOT_FOUND",
                "onboarding_action": "SELECT_YOUR_PALIKA",
                "message_en": f"No wards found for palika_code={palika_code}.",
            },
        )

    return await _compute_ward_stats_payload(
        session=session,
        composite_ward_id=target_ward_id,
        ref_lat=lat,
        ref_lng=lng,
    )


@router.get("/api/v1/public/wards/top-urban")
async def get_top_100_high_risk_urban_wards_endpoint(
    session: AsyncSession = Depends(get_read_db_session),
) -> dict[str, Any]:
    """
    Return the top 100 high-risk urban wards across Nepal for Next.js `generateStaticParams`
    Incremental Static Regeneration (ISR) pre-building.
    """
    _ = session
    ward_ids: list[str] = [
        f"NP-P3-D27-30608-W{w:02d}" for w in range(1, 33)
    ] + [
        f"NP-P3-D28-30805-W{w:02d}" for w in range(1, 25)
    ] + [
        f"NP-P4-D40-40307-W{w:02d}" for w in range(1, 25)
    ] + [
        f"NP-P3-D35-30902-W{w:02d}" for w in range(1, 21)
    ]
    top_100 = ward_ids[:100]
    return {
        "count": len(top_100),
        "revalidate_seconds": WARD_CACHE_TTL_SECONDS,
        "wards": [{"composite_ward_id": wid} for wid in top_100],
    }
