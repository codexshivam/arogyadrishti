"""Test Suite 6: Public DPI Geospatial Risk API integration tests.

Covers:
- Test Case 6.1: GET /api/v1/risk-index?lat=30.7333&lng=76.7794.
  Returns valid JSON containing risk_tier, composite_risk_score,
  and real satellite telemetry (lst_celsius, ndwi, rain_14d_mm).
"""

from __future__ import annotations

from fastapi.testclient import TestClient


def test_public_dpi_risk_index_endpoint(client: TestClient) -> None:
    """Test Case 6.1: GET /api/v1/risk-index with live GEE satellite telemetry."""
    params = {
        "lat": 30.7333,
        "lng": 76.7794,
        "lgd_code": "0404400017",
    }

    resp = client.get("/api/v1/risk-index", params=params)
    assert resp.status_code == 200, f"Expected 200 OK, got {resp.status_code}: {resp.text}"

    data = resp.json()

    # 1. Core Risk Assessment Properties
    assert "risk_tier" in data
    assert data["risk_tier"] in ("CRITICAL OUTBREAK", "HIGH RISK", "MODERATE RISK", "LOW / SAFE", "CRITICAL", "HIGH", "MODERATE", "LOW")
    assert "composite_risk_score" in data
    score = float(data["composite_risk_score"])
    assert score >= 0.0

    # 2. Satellite Telemetry Bands
    assert "satellite_telemetry_gee" in data
    sat = data["satellite_telemetry_gee"]

    lst = sat.get("lst_celsius") or sat.get("land_surface_temp_celsius") or data.get("lst_celsius")
    ndwi = sat.get("ndwi") or sat.get("stagnant_water_ndwi") or data.get("ndwi")
    rain = sat.get("rain_14d_mm") or sat.get("rainfall_14d_mm") or data.get("rain_14d_mm")

    assert lst is not None, "Missing Land Surface Temperature (LST)"
    assert ndwi is not None, "Missing NDWI surface water band"
    assert rain is not None, "Missing GPM 14-day cumulative rainfall"

    assert 10.0 <= float(lst) <= 50.0, f"LST out of plausible physical range: {lst}"
    assert -1.0 <= float(ndwi) <= 1.0, f"NDWI out of bounds: {ndwi}"
    assert float(rain) >= 0.0, f"Rainfall cannot be negative: {rain}"

    # 3. Entomological indices
    assert "entomological_indices" in data
    indices = data["entomological_indices"]
    assert "breteau_index" in indices
    assert "house_index_pct" in indices
    assert "container_index_pct" in indices
