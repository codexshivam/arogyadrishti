"""Statutory WHO / EDCD Nepal Epidemiological Math, Dual-Vector Thermal Curve, NASADEM Terrain Viability, and 5-Pillar Fusion."""

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Literal

RiskTierLiteral = Literal["SAFE", "MODERATE", "HIGH", "CRITICAL_TIER_1"]


@dataclass(frozen=True)
class EntomologicalIndicesResult:
    """Statutory WHO / EDCD Nepal entomological indices."""

    house_index_hi: float
    container_index_ci: float
    breteau_index_bi: float
    pupae_per_person_ppi: float
    edcd_priority_alert: bool
    critical_tier_1_outbreak_risk: bool


def compute_house_index_hi(houses_infested: int, houses_inspected: int) -> float:
    """House Index (HI) = (Infested Houses / Inspected Houses) * 100."""
    if houses_inspected <= 0:
        return 0.0
    if houses_infested < 0:
        raise ValueError("houses_infested cannot be negative.")
    return round(min(100.0, (houses_infested / houses_inspected) * 100.0), 2)


def compute_container_index_ci(
    positive_containers: int, wet_containers_inspected: int
) -> float:
    """Container Index (CI) = (Positive Containers / Inspected Wet Containers) * 100."""
    if wet_containers_inspected <= 0:
        return 0.0
    if positive_containers < 0:
        raise ValueError("positive_containers cannot be negative.")
    return round(
        min(100.0, (positive_containers / wet_containers_inspected) * 100.0), 2
    )


def compute_breteau_index_bi(
    positive_containers: int, houses_inspected: int
) -> float:
    """Breteau Index (BI) = (Positive Containers / Inspected Houses) * 100."""
    if houses_inspected <= 0:
        return 0.0
    if positive_containers < 0:
        raise ValueError("positive_containers cannot be negative.")
    return round((positive_containers / houses_inspected) * 100.0, 2)


def compute_pupae_per_person_ppi(
    total_pupae_counted: int, household_occupants_inspected: int
) -> float:
    """Pupae-per-Person Index (PPI) = Total Pupae Counted / Inspected Household Occupants Count."""
    if household_occupants_inspected <= 0:
        return 0.0
    if total_pupae_counted < 0:
        raise ValueError("total_pupae_counted cannot be negative.")
    return round(total_pupae_counted / household_occupants_inspected, 3)


def compute_all_entomological_indices(
    *,
    houses_inspected: int,
    houses_infested: int,
    wet_containers_inspected: int,
    positive_containers: int,
    total_pupae_counted: int,
    household_occupants_inspected: int,
    previous_2w_bi: float | None = None,
) -> EntomologicalIndicesResult:
    """Compute statutory HI, CI, BI, PPI and evaluate EDCD Priority Alert (BI>=20) and Critical Risk (BI>=30)."""
    hi = compute_house_index_hi(houses_infested, houses_inspected)
    ci = compute_container_index_ci(positive_containers, wet_containers_inspected)
    bi = compute_breteau_index_bi(positive_containers, houses_inspected)
    ppi = compute_pupae_per_person_ppi(
        total_pupae_counted, household_occupants_inspected
    )
    rapid_surge = (
        previous_2w_bi is not None
        and previous_2w_bi > 0
        and (bi - previous_2w_bi) >= 15.0
    )
    return EntomologicalIndicesResult(
        house_index_hi=hi,
        container_index_ci=ci,
        breteau_index_bi=bi,
        pupae_per_person_ppi=ppi,
        edcd_priority_alert=bi >= 20.0,
        critical_tier_1_outbreak_risk=(bi >= 30.0 or rapid_surge),
    )


def compute_altitude_viability_curve(elevation_m: float) -> float:
    """
    Altitude Biological Viability Curve (V_elev) for Aedes aegypti & Aedes albopictus in Nepal:
    - h <= 1500m: V_elev = 1.0 (Full viability: Terai, Chitwan, Pokhara, Kathmandu Valley floor ~1,300-1,400m)
    - 1500m < h < 2300m: V_elev = 1.0 - (h - 1500) / 800 (Mid-hill transition zone)
    - h >= 2300m: V_elev = 0.0 (High-alpine exclusion mask)
    """
    if elevation_m <= 1500.0:
        return 1.0
    if elevation_m >= 2300.0:
        return 0.0
    return round(1.0 - ((elevation_m - 1500.0) / 800.0), 4)


def compute_dual_vector_thermal_suitability(lst_celsius: float) -> float:
    """
    Dual-Vector Thermal Suitability (Ae. aegypti + cooler-tolerant Ae. albopictus):
    T_suit = exp(-((LST - 27.5)^2) / (2 * 4.2^2))
    """
    exponent = -((lst_celsius - 27.5) ** 2) / (2.0 * (4.2**2))
    return round(math.exp(exponent), 4)


def compute_sar_valley_pooling_score(
    *,
    vv_db: float,
    slope_deg: float,
    water_fraction_pct: float = 100.0,
) -> float:
    """
    NASADEM Slope (<8.0°) Masked Sentinel-1 C-band SAR (VV < -16.5 dB) Valley Pooling Score [0, 100].
    Steep hill shadows (slope >= 8.0°) produce low backscatter identical to water and MUST be masked to 0.0.
    """
    if slope_deg >= 8.0:
        return 0.0
    if vv_db >= -16.5:
        return 0.0
    # Scale backscatter depth below -16.5 dB (e.g. -16.5 to -24.5 dB) weighted by pooled pixel fraction
    intensity = min(1.0, abs(vv_db - (-16.5)) / 8.0)
    frac = max(0.1, min(1.0, water_fraction_pct / 100.0))
    return round(min(100.0, intensity * frac * 100.0), 2)


def classify_ward_risk_tier(composite_risk_score: float) -> RiskTierLiteral:
    """Classify R in [0, 100] into SAFE (<25), MODERATE (25-49.9), HIGH (50-74.9), CRITICAL_TIER_1 (>=75)."""
    if composite_risk_score < 25.0:
        return "SAFE"
    if composite_risk_score < 50.0:
        return "MODERATE"
    if composite_risk_score < 75.0:
        return "HIGH"
    return "CRITICAL_TIER_1"


def compute_urban_utility_risk_multiplier(
    *,
    water_supply_interval_days: int = 1,
    waste_collection_lag_days: int = 1,
) -> float:
    """
    Urban Utility Container-Storage Risk Multiplier (M_utility in [1.0, 1.35]):
    Captures Kathmandu Valley (KUKL) and hill-town intermittent piped water supply
    (households storing water for 5-7+ days in open plastic drums/buckets/sumps)
    plus delayed monsoon solid-waste pickup (`waste_collection_lag_days`).
    """
    water_penalty = max(0, water_supply_interval_days - 2) * 0.035
    waste_penalty = max(0, waste_collection_lag_days - 1) * 0.025
    multiplier = 1.0 + min(0.22, water_penalty) + min(0.13, waste_penalty)
    return round(min(1.35, max(1.0, multiplier)), 4)


def compute_five_pillar_composite_risk(
    *,
    elevation_m: float,
    sar_water_score: float,
    gee_climate_score: float,
    field_entomology_score: float,
    historical_zscore: float,
    nepali_civic_nlp_score: float,
    water_supply_interval_days: int = 1,
    waste_collection_lag_days: int = 1,
) -> tuple[float, RiskTierLiteral, float]:
    """
    5-Pillar Composite Ward Risk (R in [0, 100]) with Urban Utility Rationing & Waste Lag Modifier:
    R = clip(
        V_elev * M_utility * (
            0.30 * S_SAR_Water
            + 0.25 * S_GEE_Climate
            + 0.25 * S_Field_Entomology
            + 0.10 * S_Historical_ZScore
            + 0.10 * S_Nepali_Civic_NLP
        ),
        0, 100
    )
    Returns (composite_risk_score, risk_tier, v_elev).
    """
    v_elev = compute_altitude_viability_curve(elevation_m)
    m_utility = compute_urban_utility_risk_multiplier(
        water_supply_interval_days=water_supply_interval_days,
        waste_collection_lag_days=waste_collection_lag_days,
    )
    weighted_sum = (
        0.30 * max(0.0, min(100.0, sar_water_score))
        + 0.25 * max(0.0, min(100.0, gee_climate_score))
        + 0.25 * max(0.0, min(100.0, field_entomology_score))
        + 0.10 * max(0.0, min(100.0, historical_zscore))
        + 0.10 * max(0.0, min(100.0, nepali_civic_nlp_score))
    )
    raw_score = v_elev * m_utility * weighted_sum
    clipped_score = round(max(0.0, min(100.0, raw_score)), 2)
    tier = classify_ward_risk_tier(clipped_score)
    return clipped_score, tier, v_elev


def compute_edcd_larvicide_protocol(
    *,
    container_type: str,
    water_matrix: str,
    water_volume_liters: float = 200.0,
    surface_area_sqm: float = 10.0,
) -> dict[str, str | float]:
    """
    Deterministic EDCD Nepal Larvicide & Source Reduction Calculator:
    - Potable drinking water: Physical emptying & scrubbing ('खोज र नष्ट गर') — 0 chemical.
    - Clean non-potable water: Physical emptying/scrubbing ('खोज र नष्ट गर') or Temephos 50% EC @ 1 ppm
      (1 mg active ingredient / L = 2 mL of 50% EC per 1,000 L).
    - Stagnant non-drainable pools/tires: Bti (Bacillus thuringiensis israelensis) WP/granules @ 0.5-1.0 g/m².
    """
    if water_matrix == "potable_drinking_water":
        return {
            "container_type": container_type,
            "water_matrix": water_matrix,
            "recommended_larvicide": "Khoj Ra Nashta Gar (Physical Emptying & Scrubbing Only)",
            "dosage_value": 0.0,
            "dosage_unit": "g",
            "guidance_ne": (
                "खोज र नष्ट गर अभियान: पिउने पानीमा कुनै रसायन नराख्ने। भाँडोको पानी खन्याउने, "
                "भित्री भित्तामा टाँसिएका एडिज लामखुट्टेका अण्डा नष्ट गर्न ब्रसले माझ्ने र बिर्को लगाउने।"
            ),
            "guidance_en": (
                "Khoj Ra Nashta Gar (Search & Destroy): Do not apply chemical larvicide to potable water. "
                "Decant water, scrub inner walls to remove desiccated Aedes eggs, dry, and cover tightly."
            ),
        }

    if water_matrix == "clean_non_potable":
        active_mg = round(max(1.0, water_volume_liters) * 1.0, 2)  # 1 ppm = 1 mg/L
        formulation_ml = round((max(1.0, water_volume_liters) / 1000.0) * 2.0, 3)
        return {
            "container_type": container_type,
            "water_matrix": water_matrix,
            "recommended_larvicide": "Temephos 50% EC @ 1 ppm",
            "dosage_value": formulation_ml,
            "dosage_unit": "mL (50% EC)",
            "active_ingredient_mg": active_mg,
            "guidance_ne": (
                f"खोज र नष्ट गर अभियान: सर्वप्रथम भाँडो खन्याई ब्रसले माझ्ने। खन्याउन नमिल्ने सफा तर नपिउने "
                f"पानी ({water_volume_liters:.0f} लिटर) मा टेमेफोस ५०% ई.सी. (Temephos 50% EC @ 1 ppm) "
                f"{formulation_ml} मि.लि. ({active_mg} मि.ग्रा. सक्रिय तत्व) प्रयोग गर्ने।"
            ),
            "guidance_en": (
                f"Khoj Ra Nashta Gar (Search & Destroy): First attempt physical emptying and scrubbing. "
                f"For non-drainable clean non-potable water ({water_volume_liters:.0f} L), apply Temephos 50% EC "
                f"@ 1 ppm ({formulation_ml} mL formulation = {active_mg} mg active ingredient)."
            ),
        }

    # Default: stagnant_pool_or_tire -> Bti WP/granules @ 0.5 - 1.0 g/m²
    area = max(1.0, surface_area_sqm)
    bti_min_g = round(area * 0.5, 2)
    bti_max_g = round(area * 1.0, 2)
    return {
        "container_type": container_type,
        "water_matrix": water_matrix,
        "recommended_larvicide": "Bacillus thuringiensis israelensis (Bti) WP/Granules @ 0.5-1.0 g/m²",
        "dosage_value": bti_max_g,
        "dosage_min_g": bti_min_g,
        "dosage_max_g": bti_max_g,
        "dosage_unit": "g (Bti WP/Granules)",
        "guidance_ne": (
            f"खोज र नष्ट गर अभियान: जमेको पानी, निर्माण खाल्डो वा टायर ({area:.1f} वर्गमिटर) मा "
            f"जैविक लार्भिसाइड बिएटिआई (Bti WP/granules @ 0.5–1.0 g/m²) {bti_min_g} देखि {bti_max_g} ग्राम छर्ने।"
        ),
        "guidance_en": (
            f"Khoj Ra Nashta Gar (Search & Destroy): Apply biological larvicide Bacillus thuringiensis "
            f"israelensis (Bti) WP/granules @ 0.5–1.0 g/m² ({bti_min_g}–{bti_max_g} g for {area:.1f} m² surface area)."
        ),
    }
