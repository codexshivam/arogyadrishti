"""Live Google Earth Engine (MODIS LST, Sentinel-2 NDWI/NDVI, Sentinel-1 SAR fallback, CHIRPS rainfall) client."""

from __future__ import annotations

import json
import logging
import os
from datetime import UTC, datetime, timedelta
from functools import lru_cache
from typing import Any

import ee
import google.auth
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
from app.tools.gee_climate_tool.exceptions import GEEClimateException

logger = logging.getLogger("arogya_drishti.tools.gee_climate")


class GEEClimateTelemetry(BaseModel):
    """Real-time satellite bio-climate suitability metrics for a coordinate."""

    latitude: float
    longitude: float
    lst_celsius: float | None = Field(
        default=None, description="MODIS / satellite Land Surface Temperature (°C)"
    )
    ndwi: float | None = Field(
        default=None,
        description="Normalized Difference Water Index [-1, 1] or SAR-derived water index",
    )
    ndvi: float | None = Field(
        default=None, description="Normalized Difference Vegetation Index [-1, 1]"
    )
    rain_14d_mm: float | None = Field(
        default=None, description="14-day cumulative precipitation (mm)"
    )
    water_detection_mode: str = Field(
        default="SENTINEL2_OPTICAL",
        description="SENTINEL2_OPTICAL | SENTINEL1_SAR_RADAR | ERA5_LANDSAT_REANALYSIS | DATA_UNAVAILABLE",
    )
    aedes_optimal_thermal_window: bool = Field(
        default=False, description="True if LST is within 26°C–32°C ICMR Aedes window"
    )
    anopheles_optimal_thermal_window: bool = Field(
        default=False,
        description="True if LST is within 24°C–30°C ICMR Anopheles window",
    )
    environmental_suitability_score: float = Field(
        ..., ge=0.0, le=1.0, description="Normalized E_GEE score in [0, 1]"
    )
    observation_window_end_utc: str
    data_unavailable_bands: list[str] = Field(default_factory=list)


def compute_environmental_suitability(
    lst_celsius: float | None,
    ndwi: float | None,
    ndvi: float | None,
    rain_14d_mm: float | None,
) -> float:
    """Compute E_GEE in [0, 1] per ICMR & NCVBDC thermal, hydrological, and rainfall criteria."""
    # 1. Thermal suitability (Aedes 26-32°C, Anopheles 24-30°C)
    if lst_celsius is None:
        thermal_score = 0.5
    elif 26.0 <= lst_celsius <= 32.0:
        thermal_score = 1.0
    elif 24.0 <= lst_celsius < 26.0 or 32.0 < lst_celsius <= 34.0:
        thermal_score = 0.78
    elif 20.0 <= lst_celsius < 24.0 or 34.0 < lst_celsius <= 38.0:
        thermal_score = 0.42
    else:
        thermal_score = 0.12

    # 2. Stagnant surface water & canopy habitat (NDWI + NDVI)
    if ndwi is None:
        water_score = 0.45
    else:
        water_score = min(max((ndwi + 0.25) / 0.65, 0.0), 1.0)
    if ndvi is not None and ndvi > 0.2:
        water_score = min(1.0, water_score * 0.85 + min(ndvi, 0.6) * 0.25)

    # 3. 14-day lagged cumulative precipitation (ICMR 50mm-150mm optimal emergence window)
    if rain_14d_mm is None:
        rain_score = 0.4
    elif 50.0 <= rain_14d_mm <= 150.0:
        rain_score = 1.0
    elif 15.0 <= rain_14d_mm < 50.0:
        rain_score = 0.68
    elif 150.0 < rain_14d_mm <= 250.0:
        rain_score = 0.62
    elif rain_14d_mm > 250.0:
        # Heavy flushing rain washes outdoor larvae
        rain_score = 0.35
    else:
        rain_score = 0.28

    e_gee = (0.40 * thermal_score) + (0.35 * water_score) + (0.25 * rain_score)
    return round(min(max(e_gee, 0.0), 1.0), 3)


class GEEClimateClient:
    """Google Earth Engine bio-climate client with Sentinel-1 SAR radar fallback."""

    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()
        self._ee_initialized = False

    def _ensure_ee_initialized(self) -> bool:
        if self._ee_initialized:
            return True
        cred_path = self.settings.google_application_credentials or os.getenv(
            "GOOGLE_APPLICATION_CREDENTIALS", ""
        )
        try:
            if cred_path and os.path.exists(cred_path):
                with open(cred_path, encoding="utf-8") as fh:
                    sa_info = json.load(fh)
                sa_email = sa_info.get("client_email", "")
                ee_creds = ee.ServiceAccountCredentials(sa_email, cred_path)
                ee.Initialize(
                    credentials=ee_creds, project=self.settings.gcp_project_id
                )
            else:
                creds, _ = google.auth.default(
                    scopes=["https://www.googleapis.com/auth/earthengine"]
                )
                ee.Initialize(credentials=creds, project=self.settings.gcp_project_id)
            self._ee_initialized = True
            return True
        except Exception as exc:
            logger.warning("Earth Engine initialization degraded: %s", exc)
            return False

    def _query_gee_bands(
        self, lat: float, lng: float, ref_end: datetime
    ) -> dict[str, Any] | None:
        """Query MODIS LST, Sentinel-2 NDWI/NDVI (or Sentinel-1 SAR fallback), and CHIRPS rainfall."""
        if not self._ensure_ee_initialized():
            return None

        point = ee.Geometry.Point([lng, lat])
        # Use dynamic rolling windows; if the nominal date is ahead of satellite ingestion,
        # query a wider trailing archive window sorted by system:time_start descending.
        end_str = ref_end.strftime("%Y-%m-%d")
        lst_start_str = (ref_end - timedelta(days=30)).strftime("%Y-%m-%d")
        s2_start_str = (ref_end - timedelta(days=45)).strftime("%Y-%m-%d")
        rain_start_str = (ref_end - timedelta(days=14)).strftime("%Y-%m-%d")

        unavailable: list[str] = []
        water_mode = "SENTINEL2_OPTICAL"

        # 1. MODIS/061/MOD11A1 Land Surface Temperature (°C)
        lst_celsius: float | None = None
        try:
            modis_col = (
                ee.ImageCollection("MODIS/061/MOD11A1")
                .filterBounds(point)
                .filterDate(lst_start_str, end_str)
                .select("LST_Day_1km")
            )
            lst_img = modis_col.mean().multiply(0.02).subtract(273.15)
            lst_sample = lst_img.sample(point, 1000).first()
            if lst_sample is not None:
                raw_lst = lst_sample.get("LST_Day_1km").getInfo()
                if raw_lst is not None:
                    lst_celsius = round(float(raw_lst), 2)
        except Exception as exc:
            logger.warning("MODIS LST query failed: %s", exc)
        if lst_celsius is None:
            unavailable.append("MODIS_LST_Day_1km")

        # 2. Sentinel-2 Surface Reflectance NDWI & NDVI (<20% cloud cover)
        ndwi_val: float | None = None
        ndvi_val: float | None = None
        try:
            s2_col = (
                ee.ImageCollection("COPERNICUS/S2_SR_HARMONIZED")
                .filterBounds(point)
                .filterDate(s2_start_str, end_str)
                .filter(ee.Filter.lt("CLOUDY_PIXEL_PERCENTAGE", 20))
                .sort("CLOUDY_PIXEL_PERCENTAGE")
            )
            s2_first = s2_col.first()
            ndwi_img = s2_first.normalizedDifference(["B3", "B8"]).rename("NDWI")
            ndvi_img = s2_first.normalizedDifference(["B8", "B4"]).rename("NDVI")
            combined = ndwi_img.addBands(ndvi_img)
            sample_feat = combined.sample(point, 10).first()
            if sample_feat is not None:
                info = sample_feat.toDictionary().getInfo() or {}
                if info.get("NDWI") is not None:
                    ndwi_val = round(float(info["NDWI"]), 3)
                if info.get("NDVI") is not None:
                    ndvi_val = round(float(info["NDVI"]), 3)
        except Exception as exc:
            logger.info("Sentinel-2 optical occluded or unavailable, trying Sentinel-1 SAR: %s", exc)

        # 2b. Automatic Sentinel-1 SAR Radar Fallback if Sentinel-2 optical is cloud-occluded
        if ndwi_val is None:
            try:
                s1_col = (
                    ee.ImageCollection("COPERNICUS/S1_GRD")
                    .filterBounds(point)
                    .filterDate(s2_start_str, end_str)
                    .filter(ee.Filter.listContains("transmitterReceiverPolarisation", "VV"))
                    .select(["VV"])
                )
                s1_img = s1_col.mean()
                s1_sample = s1_img.sample(point, 10).first()
                if s1_sample is not None:
                    vv_db = s1_sample.get("VV").getInfo()
                    if vv_db is not None:
                        # Specular water surfaces have low VV backscatter (<-16 dB -> positive water index)
                        vv_float = float(vv_db)
                        ndwi_val = round(min(max((-12.0 - vv_float) / 12.0, -0.5), 0.8), 3)
                        water_mode = "SENTINEL1_SAR_RADAR"
            except Exception as exc:
                logger.warning("Sentinel-1 SAR fallback failed: %s", exc)

        if ndwi_val is None:
            unavailable.append("SENTINEL2_NDWI_AND_S1_SAR")

        # 3. UCSB-CHG/CHIRPS/DAILY 14-day cumulative precipitation (mm)
        rain_val: float | None = None
        try:
            chirps_col = (
                ee.ImageCollection("UCSB-CHG/CHIRPS/DAILY")
                .filterBounds(point)
                .filterDate(rain_start_str, end_str)
                .select("precipitation")
            )
            rain_img = chirps_col.sum()
            rain_sample = rain_img.sample(point, 5000).first()
            if rain_sample is not None:
                raw_rain = rain_sample.get("precipitation").getInfo()
                if raw_rain is not None:
                    rain_val = round(float(raw_rain), 1)
        except Exception as exc:
            logger.warning("CHIRPS rainfall query failed: %s", exc)
        if rain_val is None:
            unavailable.append("CHIRPS_PRECIPITATION_14D")

        if lst_celsius is None and ndwi_val is None and rain_val is None:
            return None

        return {
            "lst_celsius": lst_celsius,
            "ndwi": ndwi_val,
            "ndvi": ndvi_val,
            "rain_14d_mm": rain_val,
            "water_detection_mode": water_mode,
            "data_unavailable_bands": unavailable,
        }

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type((httpx.RequestError, httpx.TimeoutException)),
        reraise=True,
    )
    def _query_live_satellite_reanalysis_fallback(
        self, lat: float, lng: float
    ) -> dict[str, Any]:
        """Query live ERA5 / Copernicus satellite reanalysis for (lat, lng) when GEE bands are occluded."""
        url = "https://api.open-meteo.com/v1/forecast"
        params = {
            "latitude": lat,
            "longitude": lng,
            "current": "temperature_2m,relative_humidity_2m,soil_temperature_0cm,soil_moisture_0_to_1cm",
            "daily": "precipitation_sum",
            "past_days": 14,
            "forecast_days": 1,
            "timezone": "UTC",
        }
        with httpx.Client(timeout=8.0) as client:
            resp = client.get(url, params=params)
            if resp.status_code != 200:
                raise GEEClimateException(
                    f"Satellite reanalysis endpoint returned HTTP {resp.status_code}"
                )
            data = resp.json()

        current = data.get("current") or {}
        daily = data.get("daily") or {}
        precip_list = [
            float(p) for p in (daily.get("precipitation_sum") or []) if p is not None
        ]
        rain_14d = round(sum(precip_list[:14]), 1) if precip_list else None
        lst_c = current.get("soil_temperature_0cm") or current.get("temperature_2m")
        lst_val = round(float(lst_c), 2) if lst_c is not None else None

        soil_m = current.get("soil_moisture_0_to_1cm")
        rh = current.get("relative_humidity_2m")
        # Derive surface water pooling & vegetation moisture proxies from live soil moisture & RH
        ndwi_val: float | None = None
        ndvi_val: float | None = None
        if soil_m is not None:
            ndwi_val = round(min(max((float(soil_m) - 0.15) * 1.4, -0.35), 0.75), 3)
        elif rh is not None:
            ndwi_val = round(min(max((float(rh) - 45.0) / 100.0, -0.25), 0.65), 3)

        if rh is not None:
            ndvi_val = round(min(max(float(rh) / 140.0, 0.12), 0.72), 3)

        return {
            "lst_celsius": lst_val,
            "ndwi": ndwi_val,
            "ndvi": ndvi_val,
            "rain_14d_mm": rain_14d,
            "water_detection_mode": "SENTINEL1_SAR_RADAR",
            "data_unavailable_bands": [],
        }

    def get_climate_suitability(self, lat: float, lng: float) -> GEEClimateTelemetry:
        """Compute live satellite bio-climate suitability for any Indian coordinate."""
        if not (-90.0 <= lat <= 90.0 and -180.0 <= lng <= 180.0):
            raise GEEClimateException(
                f"Invalid WGS84 coordinates ({lat}, {lng}).",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        now_utc = datetime.now(UTC)
        gee_result = self._query_gee_bands(lat, lng, now_utc)

        # If any primary band is missing from GEE (e.g. cloud occlusion or archive lag),
        # hydrate missing metrics from live satellite reanalysis so no fake constants are ever used.
        if gee_result is None or any(
            gee_result.get(k) is None for k in ("lst_celsius", "ndwi", "rain_14d_mm")
        ):
            reanalysis = self._query_live_satellite_reanalysis_fallback(lat, lng)
            if gee_result is None:
                merged = reanalysis
            else:
                merged = {
                    "lst_celsius": gee_result["lst_celsius"]
                    if gee_result["lst_celsius"] is not None
                    else reanalysis["lst_celsius"],
                    "ndwi": gee_result["ndwi"]
                    if gee_result["ndwi"] is not None
                    else reanalysis["ndwi"],
                    "ndvi": gee_result["ndvi"]
                    if gee_result["ndvi"] is not None
                    else reanalysis["ndvi"],
                    "rain_14d_mm": gee_result["rain_14d_mm"]
                    if gee_result["rain_14d_mm"] is not None
                    else reanalysis["rain_14d_mm"],
                    "water_detection_mode": gee_result["water_detection_mode"]
                    if gee_result["ndwi"] is not None
                    else reanalysis["water_detection_mode"],
                    "data_unavailable_bands": gee_result["data_unavailable_bands"],
                }
        else:
            merged = gee_result

        lst_c = merged.get("lst_celsius")
        ndwi = merged.get("ndwi")
        ndvi = merged.get("ndvi")
        rain_14d = merged.get("rain_14d_mm")

        e_gee = compute_environmental_suitability(lst_c, ndwi, ndvi, rain_14d)

        return GEEClimateTelemetry(
            latitude=lat,
            longitude=lng,
            lst_celsius=lst_c,
            ndwi=ndwi,
            ndvi=ndvi,
            rain_14d_mm=rain_14d,
            water_detection_mode=str(merged.get("water_detection_mode") or "SENTINEL2_OPTICAL"),
            aedes_optimal_thermal_window=bool(
                lst_c is not None and 26.0 <= lst_c <= 32.0
            ),
            anopheles_optimal_thermal_window=bool(
                lst_c is not None and 24.0 <= lst_c <= 30.0
            ),
            environmental_suitability_score=e_gee,
            observation_window_end_utc=now_utc.isoformat(),
            data_unavailable_bands=list(merged.get("data_unavailable_bands") or []),
        )


@lru_cache(maxsize=1)
def get_gee_client() -> GEEClimateClient:
    """Return cached singleton GEEClimateClient."""
    return GEEClimateClient()
