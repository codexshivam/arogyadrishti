"""Google Maps Routes API v2 client for traffic-aware fogging van assignment and polylines."""

from __future__ import annotations

import logging
from collections.abc import Sequence
from functools import lru_cache
from typing import Any

import httpx
from fastapi import status
from pydantic import BaseModel, Field
from tenacity import (
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

from app.core.config import Settings, get_settings
from app.tools.maps_routing_tool.exceptions import RoutingUnavailableException
from app.tools.ogd_india_gov_tool.client import haversine_km
from app.tools.sheets_admin_tool.client import VanFleetRecord

logger = logging.getLogger("arogya_drishti.tools.maps_routing")

_ROUTES_API_V2_URL = "https://routes.googleapis.com/directions/v2:computeRoutes"
_FIELD_MASK = "routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline"


class OptimalVanRoute(BaseModel):
    """Selected fogging van with live traffic ETA and encoded route polyline."""

    row_index: int
    van_id: str
    vehicle_no: str
    driver_name: str
    driver_phone: str
    origin_lat: float
    origin_lng: float
    target_lat: float
    target_lng: float
    eta_minutes: int = Field(..., ge=1)
    distance_km: float = Field(..., ge=0.0)
    encoded_polyline: str
    chemical_stock: str
    routing_source: str = Field(
        default="GOOGLE_MAPS_ROUTES_V2",
        description="GOOGLE_MAPS_ROUTES_V2",
    )


def _encode_signed_number(num: int) -> str:
    s_num = num << 1
    if num < 0:
        s_num = ~s_num
    out: list[str] = []
    while s_num >= 0x20:
        out.append(chr((0x20 | (s_num & 0x1F)) + 63))
        s_num >>= 5
    out.append(chr(s_num + 63))
    return "".join(out)


def encode_polyline(coordinates: Sequence[tuple[float, float]]) -> str:
    """Encode a sequence of (lat, lng) points using Google Encoded Polyline Algorithm."""
    result: list[str] = []
    prev_lat = 0
    prev_lng = 0
    for lat, lng in coordinates:
        lat_e5 = int(round(lat * 1e5))
        lng_e5 = int(round(lng * 1e5))
        d_lat = lat_e5 - prev_lat
        d_lng = lng_e5 - prev_lng
        prev_lat = lat_e5
        prev_lng = lng_e5
        result.append(_encode_signed_number(d_lat))
        result.append(_encode_signed_number(d_lng))
    return "".join(result)


class MapsRoutingClient:
    """Google Maps Routes API v2 client with tenacity retry."""

    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type((httpx.RequestError, httpx.TimeoutException)),
        reraise=True,
    )
    def compute_route(
        self,
        origin_lat: float,
        origin_lng: float,
        target_lat: float,
        target_lng: float,
    ) -> dict[str, Any]:
        """Call Google Maps Routes API v2 computeRoutes with TRAFFIC_AWARE_OPTIMAL."""
        if not self.settings.google_maps_api_key:
            raise RoutingUnavailableException(
                "GOOGLE_MAPS_API_KEY is not configured.",
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": self.settings.google_maps_api_key,
            "X-Goog-FieldMask": _FIELD_MASK,
        }
        body = {
            "origin": {
                "location": {
                    "latLng": {"latitude": origin_lat, "longitude": origin_lng}
                }
            },
            "destination": {
                "location": {
                    "latLng": {"latitude": target_lat, "longitude": target_lng}
                }
            },
            "travelMode": "DRIVE",
            "routingPreference": "TRAFFIC_AWARE_OPTIMAL",
            "computeAlternativeRoutes": False,
        }

        with httpx.Client(timeout=10.0) as client:
            resp = client.post(_ROUTES_API_V2_URL, json=body, headers=headers)
            if resp.status_code >= 500:
                raise RoutingUnavailableException(
                    f"Google Maps Routes API v2 returned HTTP {resp.status_code}"
                )
            if resp.status_code != 200:
                raise RoutingUnavailableException(
                    f"Google Maps Routes API v2 error ({resp.status_code}): {resp.text[:300]}"
                )
            data: dict[str, Any] = resp.json()

        routes = data.get("routes") or []
        if not routes:
            raise RoutingUnavailableException(
                "ZERO_RESULTS returned by Google Maps Routes API v2 for the specified coordinates.",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        route = routes[0]
        raw_duration = str(route.get("duration") or "0s").rstrip("s")
        duration_sec = max(1, int(float(raw_duration)))
        distance_m = int(route.get("distanceMeters") or 0)
        polyline = str((route.get("polyline") or {}).get("encodedPolyline") or "")
        if not polyline:
            raise RoutingUnavailableException(
                "Google Maps Routes API v2 response missing encodedPolyline."
            )
        return {
            "duration_sec": duration_sec,
            "eta_minutes": max(1, round(duration_sec / 60)),
            "distance_km": round(distance_m / 1000.0, 2),
            "encoded_polyline": polyline,
            "routing_source": "GOOGLE_MAPS_ROUTES_V2",
        }

    def select_fastest_van(
        self,
        target_lat: float,
        target_lng: float,
        vans: list[VanFleetRecord],
    ) -> OptimalVanRoute:
        """Rank all Available candidate vans by lowest live Google Maps traffic-adjusted duration."""
        if not (-90.0 <= target_lat <= 90.0 and -180.0 <= target_lng <= 180.0):
            raise RoutingUnavailableException(
                f"Invalid destination coordinates ({target_lat}, {target_lng}).",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        available_vans = [
            v for v in vans if v.status.strip().lower() == "available"
        ]
        if not available_vans:
            available_vans = list(vans)
        if not available_vans:
            raise RoutingUnavailableException(
                "No fogging vans found in 1_Vans_Fleet.",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        candidates = sorted(
            available_vans,
            key=lambda v: haversine_km(v.base_lat, v.base_lng, target_lat, target_lng),
        )[:3]

        best_route: OptimalVanRoute | None = None
        min_duration_sec = float("inf")

        for van in candidates:
            route_info = self.compute_route(
                origin_lat=van.base_lat,
                origin_lng=van.base_lng,
                target_lat=target_lat,
                target_lng=target_lng,
            )
            if route_info["duration_sec"] < min_duration_sec:
                min_duration_sec = route_info["duration_sec"]
                best_route = OptimalVanRoute(
                    row_index=van.row_index,
                    van_id=van.van_id,
                    vehicle_no=van.vehicle_no,
                    driver_name=van.driver_name,
                    driver_phone=van.driver_phone,
                    origin_lat=van.base_lat,
                    origin_lng=van.base_lng,
                    target_lat=target_lat,
                    target_lng=target_lng,
                    eta_minutes=route_info["eta_minutes"],
                    distance_km=route_info["distance_km"],
                    encoded_polyline=route_info["encoded_polyline"],
                    chemical_stock=van.chemical_stock,
                    routing_source=route_info["routing_source"],
                )

        if best_route is None:
            raise RoutingUnavailableException(
                "Unable to compute a route for any candidate fogging van."
            )
        return best_route


@lru_cache(maxsize=1)
def get_maps_routing_client() -> MapsRoutingClient:
    """Return cached singleton MapsRoutingClient."""
    return MapsRoutingClient()
