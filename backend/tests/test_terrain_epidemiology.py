"""Tests for NASADEM Slope (<8°) Masking, Altitude Viability (>2300m Zero-Risk), WHO/EDCD Math, and BS Calendar."""

from __future__ import annotations

from datetime import UTC, datetime

from app.core.bs_calendar import ad_to_bs_stamp, bs_to_ad_date
from app.services.epidemiology_math import (
    compute_all_entomological_indices,
    compute_altitude_viability_curve,
    compute_dual_vector_thermal_suitability,
    compute_edcd_larvicide_protocol,
    compute_five_pillar_composite_risk,
    compute_sar_valley_pooling_score,
)
from app.services.gee_nepal_terrain import get_gee_nepal_terrain_service


def test_statutory_who_edcd_entomological_indices() -> None:
    res = compute_all_entomological_indices(
        houses_inspected=100,
        houses_infested=18,
        wet_containers_inspected=200,
        positive_containers=34,
        total_pupae_counted=60,
        household_occupants_inspected=40,
    )
    assert res.house_index_hi == 18.0
    assert res.container_index_ci == 17.0
    assert res.breteau_index_bi == 34.0
    assert res.pupae_per_person_ppi == 1.5
    assert res.edcd_priority_alert is True
    assert res.critical_tier_1_outbreak_risk is True


def test_nasadem_slope_mask_eliminates_himalayan_hill_shadow_false_positives() -> None:
    # Steep hill shadow (slope = 14.5° >= 8.0°) with low backscatter VV = -21.0 dB MUST return 0.0
    steep_score = compute_sar_valley_pooling_score(
        vv_db=-21.0, slope_deg=14.5, water_fraction_pct=90.0
    )
    assert steep_score == 0.0

    # Flat Kathmandu valley rooftop / floodplain (slope = 3.2° < 8.0°) with VV = -20.5 dB returns > 0
    valley_score = compute_sar_valley_pooling_score(
        vv_db=-20.5, slope_deg=3.2, water_fraction_pct=90.0
    )
    assert valley_score == 45.0


def test_altitude_biological_viability_curve_and_five_pillar_zero_risk_above_2300m() -> None:
    # <= 1500m (Kathmandu 1304m, Bharatpur 208m): V_elev = 1.0
    assert compute_altitude_viability_curve(208.0) == 1.0
    assert compute_altitude_viability_curve(1304.0) == 1.0
    assert compute_altitude_viability_curve(1500.0) == 1.0

    # Mid-hill transition (1900m is halfway between 1500m and 2300m): V_elev = 0.5
    assert compute_altitude_viability_curve(1900.0) == 0.5

    # >= 2300m (High-alpine exclusion mask): V_elev = 0.0
    assert compute_altitude_viability_curve(2300.0) == 0.0
    assert compute_altitude_viability_curve(3400.0) == 0.0

    # 5-pillar composite risk at 2450m MUST be 0.0 (SAFE) even if all pillar inputs are 100.0
    comp_alpine, tier_alpine, v_alpine = compute_five_pillar_composite_risk(
        elevation_m=2450.0,
        sar_water_score=100.0,
        gee_climate_score=100.0,
        field_entomology_score=100.0,
        historical_zscore=100.0,
        nepali_civic_nlp_score=100.0,
    )
    assert v_alpine == 0.0
    assert comp_alpine == 0.0
    assert tier_alpine == "SAFE"

    # At Kathmandu Valley floor (1310m), optimal LST 27.5°C -> thermal suitability = 1.0
    assert compute_dual_vector_thermal_suitability(27.5) == 1.0

    comp_kmc, tier_kmc, v_kmc = compute_five_pillar_composite_risk(
        elevation_m=1310.0,
        sar_water_score=80.0,
        gee_climate_score=80.0,
        field_entomology_score=80.0,
        historical_zscore=70.0,
        nepali_civic_nlp_score=70.0,
    )
    assert v_kmc == 1.0
    assert comp_kmc == 78.0
    assert tier_kmc == "CRITICAL_TIER_1"


def test_gee_terrain_service_and_edcd_larvicide_dosage_calculator() -> None:
    gee = get_gee_nepal_terrain_service()
    sig = gee.evaluate_terrain_telemetry(
        composite_ward_id="NP-P3-D27-30608-W17",
        elevation_m=1304.0,
        slope_deg=3.4,
        sar_vv_db=-20.5,
    )
    assert sig.slope_mask_valid is True
    assert sig.altitude_viability_v_elev == 1.0
    assert sig.sar_water_score > 0.0

    temephos = compute_edcd_larvicide_protocol(
        container_type="uncovered_plastic_drum",
        water_matrix="clean_non_potable",
        water_volume_liters=500.0,
    )
    assert temephos["recommended_larvicide"] == "Temephos 50% EC @ 1 ppm"
    assert temephos["dosage_value"] == 1.0  # 1.0 mL of 50% EC for 500 L
    assert "खोज र नष्ट गर" in str(temephos["guidance_ne"])

    bti = compute_edcd_larvicide_protocol(
        container_type="discarded_vehicle_tire",
        water_matrix="stagnant_pool_or_tire",
        surface_area_sqm=10.0,
    )
    assert "Bti" in str(bti["recommended_larvicide"])
    assert bti["dosage_min_g"] == 5.0
    assert bti["dosage_max_g"] == 10.0


def test_bikram_sambat_calendar_conversion_and_devanagari_formatting() -> None:
    dt_utc = datetime(2026, 10, 26, 0, 15, 0, tzinfo=UTC)  # 06:00 AM NPT
    stamp = ad_to_bs_stamp(dt_utc)
    assert stamp.bs_date_iso.endswith("BS")
    assert "+05:45" in stamp.timestamp_npt
    assert "|" in stamp.bs_combined_label

    # Round-trip BS -> AD check
    ad_d = bs_to_ad_date(2083, 7, 9)
    assert ad_d.year == 2026
