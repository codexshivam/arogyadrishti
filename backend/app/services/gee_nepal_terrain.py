"""Himalayan & Valley Terrain-Corrected Satellite Pipeline (NASADEM 30m Slope < 8° + Sentinel-1 SAR + MODIS LST + CHIRPS)."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Any

from app.core.bs_calendar import ad_to_bs_stamp
from app.services.epidemiology_math import (
    compute_altitude_viability_curve,
    compute_dual_vector_thermal_suitability,
    compute_sar_valley_pooling_score,
)

logger = logging.getLogger("nidaniq.gee_nepal_terrain")


@dataclass(frozen=True)
class NepalTerrainSatelliteTelemetry:
    """Terrain-corrected Earth observation signals for a Nepal Palika/Ward."""

    composite_ward_id: str
    elevation_m: float
    slope_deg: float
    slope_mask_valid: bool
    sar_vv_db: float
    sar_water_score: float
    modis_lst_celsius: float
    thermal_suitability: float
    chirps_14d_rain_mm: float
    chirps_72h_rain_mm: float
    sentinel2_ndwi: float
    altitude_viability_v_elev: float
    gee_climate_score: float
    source_mode: str
    timestamp_bs: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "composite_ward_id": self.composite_ward_id,
            "elevation_m": self.elevation_m,
            "slope_deg": self.slope_deg,
            "slope_mask_valid": self.slope_mask_valid,
            "sar_vv_db": self.sar_vv_db,
            "sar_water_score": self.sar_water_score,
            "modis_lst_celsius": self.modis_lst_celsius,
            "thermal_suitability": self.thermal_suitability,
            "chirps_14d_rain_mm": self.chirps_14d_rain_mm,
            "chirps_72h_rain_mm": self.chirps_72h_rain_mm,
            "sentinel2_ndwi": self.sentinel2_ndwi,
            "altitude_viability_v_elev": self.altitude_viability_v_elev,
            "gee_climate_score": self.gee_climate_score,
            "source_mode": self.source_mode,
            "timestamp_bs": self.timestamp_bs,
        }


class GeeNepalTerrainService:
    """
    Google Earth Engine (GEE) Himalayan & Valley Terrain-Corrected Pipeline:
    1. NASADEM 30m Topography (`NASA/NASADEM_HGT/001`): `slope = ee.Terrain.slope(dem)`
    2. Valley Pooling Mask: Restrict Sentinel-1 C-band SAR (`COPERNICUS/S1_GRD`, `VV < -16.5 dB`
       + focal median speckle filter) strictly to pixels where `slope < 8.0°`, isolating flat urban
       rooftops and river floodplains (Bagmati, Bishnumati, Dhobi Khola, Manohara, Seti) while
       eliminating steep Himalayan hill-shadow false positives.
    3. Altitude Biological Viability Curve (`V_elev`): 1.0 at <=1500m, linear decay 1500-2300m, 0.0 at >=2300m.
    4. Micro-Climate Signals: `MODIS/061/MOD11A2` LST (°C), `UCSB-CHG/CHIRPS/DAILY` 14d rainfall (mm),
       and `COPERNICUS/S2_SR_HARMONIZED` NDWI.
    """

    def build_gee_expression_spec(
        self, *, centroid_lat: float, centroid_lng: float
    ) -> dict[str, Any]:
        """Return the canonical Google Earth Engine dataset and mask specification for auditing/execution."""
        return {
            "dem_dataset": "NASA/NASADEM_HGT/001",
            "slope_operation": "ee.Terrain.slope(ee.Image('NASA/NASADEM_HGT/001').select('elevation'))",
            "valley_pooling_slope_threshold_deg": 8.0,
            "sar_dataset": "COPERNICUS/S1_GRD",
            "sar_filter": {
                "instrumentMode": "IW",
                "transmitterReceiverPolarisation": "VV",
                "speckle_filter": "focal_median(30, 'circle', 'meters')",
                "standing_water_threshold_vv_db": -16.5,
                "mask_expression": "vv_filtered.lt(-16.5).And(slope.lt(8.0))",
            },
            "lst_dataset": "MODIS/061/MOD11A2",
            "rainfall_dataset": "UCSB-CHG/CHIRPS/DAILY",
            "ndwi_dataset": "COPERNICUS/S2_SR_HARMONIZED",
            "target_point_wgs84": [centroid_lng, centroid_lat],
        }

    def evaluate_terrain_telemetry(
        self,
        *,
        composite_ward_id: str,
        elevation_m: float,
        slope_deg: float = 3.2,
        sar_vv_db: float = -19.8,
        lst_celsius: float = 27.3,
        chirps_14d_rain_mm: float = 135.0,
        chirps_72h_rain_mm: float = 42.0,
        sentinel2_ndwi: float = 0.28,
        water_fraction_pct: float = 85.0,
        source_mode: str = "SOVEREIGN_IDMC_GEE_CACHE",
    ) -> NepalTerrainSatelliteTelemetry:
        """
        Compute terrain-corrected SAR water pooling score, altitude biological viability (V_elev),
        dual-vector thermal suitability, and GEE climate pillar score.
        """
        v_elev = compute_altitude_viability_curve(elevation_m)
        slope_mask_valid = slope_deg < 8.0
        sar_water_score = compute_sar_valley_pooling_score(
            vv_db=sar_vv_db,
            slope_deg=slope_deg,
            water_fraction_pct=water_fraction_pct,
        )
        t_suit = compute_dual_vector_thermal_suitability(lst_celsius)

        # Combine thermal suitability (60%), monsoon rainfall saturation (25%), and Sentinel-2 NDWI (15%)
        rain_norm = min(1.0, max(0.0, chirps_14d_rain_mm / 180.0))
        ndwi_norm = min(1.0, max(0.0, (sentinel2_ndwi + 0.2) / 0.7))
        gee_climate_score = round(
            (0.60 * t_suit + 0.25 * rain_norm + 0.15 * ndwi_norm) * 100.0, 2
        )

        # If altitude >= 2300m, biological viability V_elev is 0.0
        if v_elev == 0.0:
            sar_water_score = 0.0
            gee_climate_score = 0.0

        stamp = ad_to_bs_stamp()
        return NepalTerrainSatelliteTelemetry(
            composite_ward_id=composite_ward_id,
            elevation_m=elevation_m,
            slope_deg=slope_deg,
            slope_mask_valid=slope_mask_valid,
            sar_vv_db=sar_vv_db,
            sar_water_score=sar_water_score,
            modis_lst_celsius=lst_celsius,
            thermal_suitability=t_suit,
            chirps_14d_rain_mm=chirps_14d_rain_mm,
            chirps_72h_rain_mm=chirps_72h_rain_mm,
            sentinel2_ndwi=sentinel2_ndwi,
            altitude_viability_v_elev=v_elev,
            gee_climate_score=gee_climate_score,
            source_mode=source_mode,
            timestamp_bs=stamp.bs_combined_label,
        )


_gee_terrain_service = GeeNepalTerrainService()


def get_gee_nepal_terrain_service() -> GeeNepalTerrainService:
    """Return singleton Himalayan & Valley Terrain-Corrected GEE service."""
    return _gee_terrain_service
