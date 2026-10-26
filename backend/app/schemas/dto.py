"""Strict Pydantic v2 Request/Response DTOs with mandatory Bikram Sambat (BS) dual-date timestamps and Zero-PII validators."""

from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.core.bs_calendar import ad_to_bs_stamp
from app.core.security import normalize_nepal_phone, validate_zero_citizen_pii

VectorProgramType = Literal[
    "DENGUE_AEDES",
    "MALARIA_ANOPHELES",
    "KALAAZAR_SANDFLY",
    "SCRUB_TYPHUS_MITE",
    "JE_CULEX",
]

EcologicalBeltType = Literal[
    "TERAI",
    "INNER_TERAI",
    "PAHAD_VALLEY",
    "HIMAL_CORRIDOR",
]

NepalLanguageCode = Literal["ne", "mai", "bho", "thr", "new", "en", "ne-roman"]


class DualCalendarMixin(BaseModel):
    """Mandatory dual-date (AD UTC+05:45 NPT + Bikram Sambat BS) metadata on API responses."""

    timestamp_utc: str = Field(
        default_factory=lambda: ad_to_bs_stamp().timestamp_utc,
        description="ISO-8601 UTC timestamp.",
    )
    timestamp_npt: str = Field(
        default_factory=lambda: ad_to_bs_stamp().timestamp_npt,
        description="Asia/Kathmandu (UTC+05:45) Nepal Standard Time timestamp.",
    )
    bs_date: str = Field(
        default_factory=lambda: ad_to_bs_stamp().bs_combined_label,
        description="Bikram Sambat (BS) dual-format string (e.g., '2083-07-09 BS | २०८३ कार्तिक ९').",
    )
    bs_ad_official_label: str = Field(
        default_factory=lambda: ad_to_bs_stamp().bs_ad_official_label,
        description="Official Bikram Sambat Devanagari + Gregorian AD label (e.g., '२०८३ कार्तिक ९ | 2026-10-26').",
    )


# ---------------------------------------------------------------------------
# 1. Authentication & RBAC DTOs (Pure +977 OTP & Asymmetric EdDSA JWT)
# ---------------------------------------------------------------------------


class OtpRequestPayload(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    phone: str = Field(
        ...,
        validation_alias="phone",
        description="Nepali mobile number (+97798XXXXXXXX, +97797XXXXXXXX, or +97796XXXXXXXX). Email login is strictly prohibited.",
        examples=["+9779851000017"],
    )

    @model_validator(mode="before")
    @classmethod
    def _enforce_phone_only_no_email_login(cls, data: Any) -> Any:
        if isinstance(data, dict):
            if "email" in data:
                raise ValueError(
                    "Hybrid Auth Policy: Login via email is strictly prohibited. Provide +977 phone number only."
                )
            if "phone_number" in data and "phone" not in data:
                data = {**data, "phone": data["phone_number"]}
        return data

    @field_validator("phone")
    @classmethod
    def _validate_phone(cls, v: str) -> str:
        if "@" in str(v):
            raise ValueError(
                "Hybrid Auth Policy: Email addresses are not accepted for authentication. Use +977 mobile number."
            )
        return normalize_nepal_phone(v)


class OtpVerifyPayload(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    phone: str = Field(..., examples=["+9779851000017"])
    otp: str = Field(..., min_length=6, max_length=6, pattern=r"^\d{6}$")
    device_fingerprint: str = Field(
        default="nepal-mohp-field-android",
        min_length=3,
        max_length=128,
    )

    @model_validator(mode="before")
    @classmethod
    def _enforce_phone_only_verify(cls, data: Any) -> Any:
        if isinstance(data, dict):
            if "email" in data:
                raise ValueError(
                    "Hybrid Auth Policy: OTP verification via email is prohibited on /auth/verify-otp. Use +977 phone number."
                )
            if "phone_number" in data and "phone" not in data:
                data = {**data, "phone": data["phone_number"]}
            if "otp_code" in data and "otp" not in data:
                data = {**data, "otp": data["otp_code"]}
        return data

    @field_validator("phone")
    @classmethod
    def _validate_phone(cls, v: str) -> str:
        if "@" in str(v):
            raise ValueError(
                "Hybrid Auth Policy: Email addresses are not accepted for authentication. Use +977 mobile number."
            )
        return normalize_nepal_phone(v)


class RefreshTokenPayload(BaseModel):
    refresh_token: str = Field(..., min_length=16)
    device_fingerprint: str = Field(default="nepal-mohp-field-android")


class UserEmailLinkRequest(BaseModel):
    email: str = Field(
        ...,
        min_length=5,
        max_length=160,
        description="Official or personal email address for zero-cost MoHP/Palika alerts.",
        examples=["doc@kmc.gov.np"],
    )

    @field_validator("email")
    @classmethod
    def _validate_email_syntax(cls, v: str) -> str:
        cleaned = str(v or "").strip().lower()
        if (
            "@" not in cleaned
            or cleaned.startswith("@")
            or cleaned.endswith("@")
            or "." not in cleaned.split("@", 1)[1]
            or " " in cleaned
        ):
            raise ValueError("Invalid email address format.")
        return cleaned


class UserEmailVerifyRequest(BaseModel):
    email_otp: str = Field(
        ...,
        min_length=6,
        max_length=6,
        pattern=r"^\d{6}$",
        description="6-digit Email verification OTP (TTL 15 minutes).",
    )


class StaffProfileResponse(DualCalendarMixin):
    id: str
    full_name: str
    full_name_ne: str
    designation: str
    role: str
    province_code: int
    district_code: int
    palika_code: str
    assigned_wards: list[str]
    email: str | None = None
    is_email_verified: bool = False
    is_active: bool


class TokenPairResponse(DualCalendarMixin):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    algorithm: str = "EdDSA"
    expires_in_seconds: int = 900
    jti: str
    staff_profile: StaffProfileResponse


# ---------------------------------------------------------------------------
# 2. Field Inspections, Offline Batch Sync & PaliGemma Vision DTOs
# ---------------------------------------------------------------------------


class InspectionCreateItem(BaseModel):
    """
    Zero-Citizen-PII field entomology inspection record.
    Any citizen PII (citizen_name, nagarikta_no, nid_number, household_phone) is strictly rejected
    under Nepal's Individual Privacy Act, 2075 (2018).
    """

    model_config = ConfigDict(extra="allow")

    client_submission_uuid: str = Field(..., min_length=8, max_length=64)
    composite_ward_id: str = Field(
        ...,
        pattern=r"^NP-P[1-7]-D\d{1,2}-\d{5}-W\d{1,2}$",
        examples=["NP-P3-D27-30608-W17"],
    )
    houses_inspected: int = Field(..., ge=1, le=10000)
    houses_infested: int = Field(..., ge=0, le=10000)
    wet_containers_inspected: int = Field(..., ge=1, le=50000)
    positive_containers: int = Field(..., ge=0, le=50000)
    pupae_count: int = Field(default=0, ge=0, le=100000)
    household_occupants_inspected: int = Field(default=10, ge=1, le=50000)
    houses_searched_destroyed: int = Field(default=1, ge=0, le=10000)
    container_type: Literal[
        "uncovered_plastic_drum",
        "discarded_vehicle_tire",
        "rooftop_tank",
        "flower_pot",
        "construction_pit",
        "solid_waste",
    ] = "uncovered_plastic_drum"
    water_matrix: Literal[
        "clean_non_potable",
        "stagnant_pool_or_tire",
        "potable_drinking_water",
    ] = "clean_non_potable"
    larvae_detected: bool = False
    instar_stage: Literal["I-II", "III-IV", "Pupae", "NONE"] | None = None
    larvicide_applied: str = Field(default="Khoj Ra Nashta Gar Physical Scrubbing", max_length=64)
    larvicide_dosage_mg: float = Field(default=0.0, ge=0.0)
    latitude: float = Field(..., ge=26.0, le=30.5)
    longitude: float = Field(..., ge=80.0, le=88.5)
    target_household_lat: float | None = Field(default=None, ge=26.0, le=30.5)
    target_household_lng: float | None = Field(default=None, ge=80.0, le=88.5)
    is_mock_location_detected: bool = Field(
        default=False,
        description="True if fake GPS / Android mock location provider is detected.",
    )
    is_device_time_tampered: bool = Field(
        default=False,
        description="True if manual device clock modification / NTP time tampering is detected.",
    )
    device_clock_drift_seconds: float = Field(
        default=0.0,
        description="Measured device clock drift in seconds relative to NTP/monotonic anchor.",
    )
    cryptographic_exif_signature: str | None = Field(default=None, max_length=128)
    device_key_id: str | None = Field(default=None, max_length=64)
    image_dhash_hex: str | None = Field(default=None, max_length=32)
    notes: str = Field(default="", max_length=500)

    @model_validator(mode="before")
    @classmethod
    def _reject_citizen_pii_before(cls, values: Any) -> Any:
        if isinstance(values, dict):
            validate_zero_citizen_pii(values)
        return values

    @model_validator(mode="after")
    def _validate_counts(self) -> InspectionCreateItem:
        if self.houses_infested > self.houses_inspected:
            raise ValueError("houses_infested cannot exceed houses_inspected.")
        if self.positive_containers > self.wet_containers_inspected:
            raise ValueError("positive_containers cannot exceed wet_containers_inspected.")
        return self


class InspectionBatchPayload(BaseModel):
    inspections: list[InspectionCreateItem] = Field(..., min_length=1, max_length=100)


class InspectionSyncReceipt(DualCalendarMixin):
    client_submission_uuid: str
    inspection_id: str
    composite_ward_id: str
    status: Literal["CREATED", "DUPLICATE_IGNORED", "QUARANTINED_SUPERVISOR_REVIEW"]
    house_index_hi: float
    container_index_ci: float
    breteau_index_bi: float
    pupae_per_person_ppi: float
    public_grid_lat: float
    public_grid_lng: float
    spoof_quarantine_reason: str | None = None


class InspectionBatchResponse(DualCalendarMixin):
    total_received: int
    created_count: int
    duplicate_ignored_count: int
    receipts: list[InspectionSyncReceipt]


class BoundingBoxDTO(BaseModel):
    ymin: float = Field(..., ge=0.0, le=1.0)
    xmin: float = Field(..., ge=0.0, le=1.0)
    ymax: float = Field(..., ge=0.0, le=1.0)
    xmax: float = Field(..., ge=0.0, le=1.0)
    label: str
    confidence: float = Field(..., ge=0.0, le=1.0)


class BreedingSiteVisionResponse(DualCalendarMixin):
    scan_id: str
    composite_ward_id: str
    ward_elevation_m: float
    chirps_72h_rain_mm: float
    modis_lst_celsius: float
    container_type: Literal[
        "uncovered_plastic_drum",
        "discarded_vehicle_tire",
        "rooftop_tank",
        "flower_pot",
        "construction_pit",
        "solid_waste",
    ]
    water_matrix: Literal[
        "clean_non_potable",
        "stagnant_pool_or_tire",
        "potable_drinking_water",
    ]
    larvae_detected: bool
    instar_stage: Literal["I-II", "III-IV", "Pupae", "NONE"]
    confidence: float = Field(..., ge=0.0, le=1.0)
    bounding_boxes: list[BoundingBoxDTO]
    edcd_intervention_ne: str
    edcd_intervention_en: str
    recommended_larvicide: str
    recommended_dosage_value: float
    recommended_dosage_unit: str
    exif_stripped: bool = True
    dhash_hex: str = "0000000000000000"
    device_key_id: str = "NP-GOV-KEYSTORE-DEFAULT"
    cryptographic_exif_signature: str = ""
    privacy_compliance: str = "Individual Privacy Act, 2075 (EXIF Stripped, Zero Citizen PII)"


# ---------------------------------------------------------------------------
# 3. Ward GIS & 5-Pillar Risk DTOs
# ---------------------------------------------------------------------------


class WardRiskResponse(DualCalendarMixin):
    composite_ward_id: str
    palika_code: str
    palika_name: str
    ward_number: int
    locality_name: str
    locality_name_ne: str
    mean_elevation_m: float
    fusion_date_ad: str
    fusion_date_bs: str
    house_index_hi: float
    container_index_ci: float
    breteau_index_bi: float
    pupae_per_person_ppi: float
    sar_water_score: float
    gee_climate_score: float
    field_entomology_score: float
    historical_zscore: float
    nepali_news_nlp_score: float
    elevation_viability_factor: float
    composite_risk_score: float
    risk_tier: Literal["SAFE", "MODERATE", "HIGH", "CRITICAL_TIER_1"]
    ewars_confirmed_cases: int
    lst_celsius: float
    rainfall_14d_mm: float
    ndwi: float
    slope_deg: float


# ---------------------------------------------------------------------------
# 4. RRT Dispatch & Policy-Gated Focal ULV Override DTOs
# ---------------------------------------------------------------------------


class RrtDispatchRequest(BaseModel):
    composite_ward_id: str = Field(..., examples=["NP-P3-D27-30608-W17"])
    target_lat: float = Field(..., ge=26.0, le=30.5)
    target_lng: float = Field(..., ge=80.0, le=88.5)
    water_surface_sqm: float = Field(default=50.0, ge=1.0, le=10000.0)
    notes: str = Field(
        default="Immediate Khoj Ra Nashta Gar RRT & Bti larviciding requested.",
        max_length=400,
    )

    @model_validator(mode="before")
    @classmethod
    def _check_pii(cls, values: Any) -> Any:
        if isinstance(values, dict):
            validate_zero_citizen_pii(values)
        return values


class RrtUlvOverrideRequest(BaseModel):
    composite_ward_id: str = Field(..., examples=["NP-P3-D27-30608-W17"])
    target_lat: float = Field(..., ge=26.0, le=30.5)
    target_lng: float = Field(..., ge=80.0, le=88.5)
    ewars_confirmed_cases: int = Field(
        ...,
        ge=0,
        description="Confirmed EWARS hospital dengue cases in the ward cluster.",
    )
    breteau_index: float = Field(
        ...,
        ge=0.0,
        description="Current ward Breteau Index (must be >= 30.0 for ULV override).",
    )
    statutory_justification: str = Field(
        ...,
        min_length=15,
        max_length=600,
        description="Palika Health Chief statutory justification for focal ULV space-spraying.",
    )


class RrtDispatchResponse(DualCalendarMixin):
    dispatch_id: str
    dispatch_type: Literal["SEARCH_AND_DESTROY", "ULV_FOCAL_OVERRIDE"]
    composite_ward_id: str
    palika_code: str
    vehicle_id: str
    plate_number: str
    team_lead_name: str
    team_lead_name_ne: str
    driver_phone: str
    bti_stock_kg: float
    temephos_stock_liters: float
    campaign_action_ne: str
    campaign_action_en: str
    route_distance_km: float
    route_eta_minutes: float
    routing_engine: str
    status: str


# ---------------------------------------------------------------------------
# 5. Copilot (Regional Linguistic Equity across 7 Provinces), Escalations & DHIS2
# ---------------------------------------------------------------------------


class CopilotChatRequest(BaseModel):
    query: str = Field(..., min_length=2, max_length=1000)
    composite_ward_id: str = Field(default="NP-P3-D27-30608-W17")
    language: NepalLanguageCode = "ne"
    preferred_language: NepalLanguageCode | None = None


class ToolExecutionTraceDTO(BaseModel):
    tool_name: str
    arguments: dict[str, Any]
    output: dict[str, Any]


class CopilotChatResponse(DualCalendarMixin):
    model_id: str
    sovereign_endpoint: str
    composite_ward_id: str
    language_resolved: NepalLanguageCode = "ne"
    answer_ne: str
    answer_en: str
    answer_regional: str = ""
    tool_traces: list[ToolExecutionTraceDTO]


class EscalationCreatePayload(BaseModel):
    composite_ward_id: str = Field(..., examples=["NP-P3-D27-30608-W17"])
    severity_tier: Literal["CRITICAL_2H", "HIGH_6H", "ROUTINE_24H"] = "CRITICAL_2H"
    category: str = Field(
        default="UNCONTROLLED_TIRE_DUMP_LARVAE_CLUSTER", max_length=80
    )
    summary: str = Field(..., min_length=5, max_length=500)

    @model_validator(mode="before")
    @classmethod
    def _check_pii(cls, values: Any) -> Any:
        if isinstance(values, dict):
            validate_zero_citizen_pii(values)
        return values


class EscalationTicketResponse(DualCalendarMixin):
    id: str
    ticket_code: str
    composite_ward_id: str
    palika_code: str
    reported_by_id: str
    severity_tier: str
    sla_hours: int
    category: str
    summary_sanitized: str
    status: str
    sla_due_at_utc: str
    created_at_bs: str


class Dhis2PushRequest(BaseModel):
    palika_code: str = Field(default="30608")
    composite_ward_ids: list[str] = Field(
        default_factory=lambda: ["NP-P3-D27-30608-W17", "NP-P3-D27-30608-W12"]
    )
    period_iso: str = Field(default="2026W43")


# ---------------------------------------------------------------------------
# 6. Nationwide Module 1: Multi-Vector Engine & WHO/EDCD 1-3-7 SLA Engine DTOs
# ---------------------------------------------------------------------------


class MultiVectorEvaluationRequest(BaseModel):
    composite_ward_id: str = Field(..., examples=["NP-P7-D71-70105-W04"])
    vector_program: VectorProgramType = "MALARIA_ANOPHELES"
    ecological_belt: EcologicalBeltType = "TERAI"
    mean_elevation_m: float = Field(default=185.0, ge=50.0, le=8848.86)
    ndvi_bush_index: float = Field(default=0.45, ge=-1.0, le=1.0)
    ndwi_paddy_inundation: float = Field(default=0.38, ge=-1.0, le=1.0)
    mud_stone_wall_crack_ratio: float = Field(default=0.35, ge=0.0, le=1.0)
    je_immunization_coverage_pct: float = Field(default=82.0, ge=0.0, le=100.0)
    confirmed_rdt_cases_7d: int = Field(default=2, ge=0, le=5000)


class MultiVectorEvaluationResponse(DualCalendarMixin):
    composite_ward_id: str
    vector_program: VectorProgramType
    ecological_belt: EcologicalBeltType
    risk_score: float
    risk_tier: Literal["SAFE", "MODERATE", "HIGH", "CRITICAL_TIER_1"]
    statutory_protocol_code: str
    primary_intervention_ne: str
    primary_intervention_en: str
    chemical_or_biological_agent: str
    medical_prophylaxis_alert: str
    requires_137_sla_tracking: bool


class MalariaKalaazar137CreateRequest(BaseModel):
    disease: Literal["MALARIA_ANOPHELES", "KALAAZAR_SANDFLY"] = "MALARIA_ANOPHELES"
    ecological_belt: EcologicalBeltType = "TERAI"
    composite_ward_id: str = Field(..., examples=["NP-P7-D71-70105-W04"])
    reporting_facility_nhfr: str = Field(default="NHFR-70105-SETI-PH")
    backdate_hours_for_simulation: float = Field(
        default=0.0,
        ge=0.0,
        le=500.0,
        description="Optional simulation offset to test Day-1/Day-3/Day-7 SLA breach escalation.",
    )

    @model_validator(mode="before")
    @classmethod
    def _reject_pii(cls, values: Any) -> Any:
        if isinstance(values, dict):
            validate_zero_citizen_pii(values)
        return values


class MalariaKalaazar137StageUpdateRequest(BaseModel):
    stage: Literal["DAY_3_INVESTIGATED", "DAY_7_FOCI_COMPLETED"]
    case_classification: Literal["INDIGENOUS", "IMPORTED", "INTRODUCED", "RELAPSE"] = (
        "INDIGENOUS"
    )
    foci_irs_llin_summary: str = Field(
        default="Pyrethroid IRS applied in 50m household ring + 40 LLIN bed-nets distributed.",
        max_length=500,
    )


class MalariaKalaazar137CaseResponse(DualCalendarMixin):
    id: str
    case_code: str
    disease: str
    ecological_belt: str
    composite_ward_id: str
    palika_code: str
    province_code: int
    reporting_facility_nhfr: str
    day1_notified_at_utc: str
    day1_sla_due_utc: str
    day3_investigated_at_utc: str | None
    day3_sla_due_utc: str
    case_classification: str | None
    day7_foci_responded_at_utc: str | None
    day7_sla_due_utc: str
    foci_irs_llin_summary: str | None
    current_stage: str
    sla_breached: bool
    escalated_to_provincial_phd: bool
    escalation_ticket_code: str | None
    created_at_bs: str


# ---------------------------------------------------------------------------
# 7. Nationwide Module 2: 2G GSM SMS Shortcode Gateway DTOs
# ---------------------------------------------------------------------------


class SmsWebhookIngestPayload(BaseModel):
    sender_phone: str = Field(
        ...,
        description="Whitelisted +977 FCHV or Ward Health Officer mobile number.",
        examples=["+9779841000017"],
    )
    shortcode: str = Field(default="31115", examples=["31115"])
    sms_text: str = Field(
        ...,
        min_length=4,
        max_length=600,
        description="Compact 2G SMS syntax (e.g., 'VEC W17 H25 P7 RDT2') or 'B64:<compressed>'.",
        examples=["VEC W17 H25 P7 RDT2"],
    )
    telecom_provider: Literal["SPARROW_SMS", "AAKASH_SMS"] = "SPARROW_SMS"
    sim_slot_carrier: Literal["NTC_SIM1", "NCELL_SIM2", "USSD_31115"] = "NTC_SIM1"

    @field_validator("sender_phone")
    @classmethod
    def _validate_sender_phone(cls, v: str) -> str:
        return normalize_nepal_phone(v)


class SmsWebhookIngestResponse(DualCalendarMixin):
    status: Literal["INGESTED", "DUPLICATE_IGNORED"]
    shortcode: str
    sender_phone: str
    composite_ward_id: str
    inspection_id: str
    parsed_houses_inspected: int
    parsed_positive_containers: int
    parsed_rdt_positive: int
    disease_flag: str
    breteau_index_bi: float
    reply_sms_unicode_ne: str


# ---------------------------------------------------------------------------
# 8. Nationwide Module 3: NDRRMA BIPAD Portal & DHM Ground Weather Fusion DTOs
# ---------------------------------------------------------------------------


class DisasterWeatherFusionRequest(BaseModel):
    composite_ward_id: str = Field(..., examples=["NP-P3-D27-30608-W17"])
    river_corridor: Literal[
        "BHOTEKOSHI",
        "TRISHULI",
        "ROSHI",
        "KOSHI",
        "NARAYANI",
        "KARNALI",
        "MAHAKALI",
        "BAGMATI",
    ] = "BAGMATI"
    bipad_flood_inundation_alert: bool = True
    bipad_landslide_alert: bool = False
    dhm_aws_station_id: str = Field(default="DHM-AWS-KTM-1030")
    dhm_ground_rainfall_24h_mm: float = Field(default=142.5, ge=0.0, le=1000.0)
    dhm_ground_temp_celsius: float = Field(default=27.4, ge=-20.0, le=50.0)
    satellite_chirps_rainfall_mm: float = Field(default=68.0, ge=0.0, le=1000.0)
    satellite_modis_lst_celsius: float = Field(default=22.0, ge=-20.0, le=50.0)
    baseline_composite_risk: float = Field(default=58.0, ge=0.0, le=100.0)


class DisasterWeatherFusionResponse(DualCalendarMixin):
    composite_ward_id: str
    palika_code: str
    river_corridor: str
    dhm_aws_station_id: str
    cloud_shadow_bias_corrected: bool
    fused_rainfall_mm: float
    fused_temperature_celsius: float
    post_disaster_multiplier: float
    outbreak_window_days: int
    adjusted_dengue_risk: float
    adjusted_malaria_risk: float
    adjusted_scrub_typhus_risk: float
    palika_chief_pre_alert_dispatched: bool
    pre_alert_directive_ne: str
    pre_alert_directive_en: str


# ---------------------------------------------------------------------------
# 9. Nationwide Module 4: Cross-Border PoE Health Desk Surveillance DTOs
# ---------------------------------------------------------------------------


class PoeSurveillanceCreateRequest(BaseModel):
    """
    Zero-Citizen-PII Cross-Border Point-of-Entry (PoE Health Desk) Surveillance Payload.
    Logs ONLY disease, RDT result, border transit zone, and destination Palika/Ward.
    Rejects any traveler name, passport/citizenship number, or phone number.
    """

    model_config = ConfigDict(extra="allow")

    poe_desk_code: Literal[
        "KAKARBHITTA",
        "RANI_BIRATNAGAR",
        "BIRGUNJ",
        "BELAHIYA_BHAIRAHAWA",
        "JAMUNAHA_NEPALGUNJ",
        "TRINAGAR_DHANGADHI",
        "GADDACHAUKI_MAHENDRANAGAR",
        "TIA_KATHMANDU",
    ] = "GADDACHAUKI_MAHENDRANAGAR"
    disease: VectorProgramType = "MALARIA_ANOPHELES"
    rdt_result: str = Field(default="POSITIVE_PF_RDT", max_length=32)
    origin_zone: str = Field(
        default="Cross-Border Western Transit Corridor", max_length=64
    )
    destination_province_code: int = Field(default=7, ge=1, le=7)
    destination_district_code: int = Field(default=69, ge=1, le=77)
    destination_palika_code: str = Field(default="70701", min_length=3, max_length=16)
    destination_ward_no: int = Field(default=4, ge=1, le=35)

    @model_validator(mode="before")
    @classmethod
    def _reject_pii_before(cls, values: Any) -> Any:
        if isinstance(values, dict):
            validate_zero_citizen_pii(values)
        return values


class PoeSurveillanceResponse(DualCalendarMixin):
    id: str
    poe_desk_code: str
    poe_name: str
    disease: VectorProgramType
    rdt_result: str
    origin_zone: str
    destination_province_code: int
    destination_palika_code: str
    destination_ward_no: int
    destination_composite_ward_id: str
    destination_alert_dispatched: bool
    alert_ticket_code: str
    focal_response_directive_ne: str
    focal_response_directive_en: str
    logged_at_bs: str


# ---------------------------------------------------------------------------
# 10. Nationwide Module 5: MoHP eLMIS & PHLMC Stockout Predictor DTOs
# ---------------------------------------------------------------------------


class ElmisCommodityItemForecast(BaseModel):
    commodity_code: str
    commodity_name_ne: str
    unit: str
    current_stock: float
    daily_baseline_burn: float
    projected_daily_outbreak_burn: float
    days_remaining: float
    stockout_imminent: bool
    recommended_reorder_qty: float


class ElmisRequisitionOrderDTO(BaseModel):
    requisition_id: str
    palika_code: str
    phlmc_province_code: int
    source_depot: str
    destination_store: str
    priority: Literal["EMERGENCY_AIR_OR_CONVOY", "URGENT_PHLMC_DISPATCH", "ROUTINE"]
    commodity_code: str
    quantity_requested: float
    unit: str
    justification_ne: str


class ElmisPalikaForecastResponse(DualCalendarMixin):
    palika_code: str
    phlmc_province_code: int
    phlmc_hub_name: str
    outbreak_surge_multiplier: float
    commodities: list[ElmisCommodityItemForecast]
    auto_requisitions: list[ElmisRequisitionOrderDTO]


# ---------------------------------------------------------------------------
# 11. Nationwide Module 6: NPHL Teku & VBDRTC Hetauda Lab Surveillance DTOs
# ---------------------------------------------------------------------------


class LabSerotypeShiftRequest(BaseModel):
    lab_center: Literal["NPHL_TEKU", "VBDRTC_HETAUDA"] = "NPHL_TEKU"
    province_code: int = Field(default=3, ge=1, le=7)
    district_code: int = Field(default=27, ge=1, le=77)
    previous_serotype: Literal["DENV-1", "DENV-2", "DENV-3", "DENV-4"] = "DENV-1"
    dominant_serotype: Literal["DENV-1", "DENV-2", "DENV-3", "DENV-4"] = "DENV-2"


class LabInsecticideBioassayRequest(BaseModel):
    lab_center: Literal["VBDRTC_HETAUDA", "NPHL_TEKU"] = "VBDRTC_HETAUDA"
    province_code: int = Field(default=3, ge=1, le=7)
    district_code: int = Field(default=27, ge=1, le=77)
    vector_species: Literal[
        "Aedes aegypti", "Anopheles fluviatilis", "Phlebotomus argentipes"
    ] = "Aedes aegypti"
    chemical_tested: Literal[
        "TEMEPHOS_50_EC",
        "DELTAMETHRIN_IRS",
        "ALPHACYPERMETHRIN_IRS",
        "MALATHION_ULV",
        "BTI_WP",
    ] = "TEMEPHOS_50_EC"
    bioassay_mortality_pct: float = Field(..., ge=0.0, le=100.0)


class LabSurveillanceResponse(DualCalendarMixin):
    id: str
    lab_center: str
    province_code: int
    district_code: int
    record_type: str
    dominant_serotype: str | None
    previous_serotype: str | None
    serotype_shift_detected: bool
    ade_surge_multiplier: float
    vector_species: str
    chemical_tested: str | None
    bioassay_mortality_pct: float | None
    resistance_status: str
    recommended_substitute: str
    directive_ne: str
    directive_en: str
    recorded_at_bs: str


# ---------------------------------------------------------------------------
# 12. Nationwide Module 7: GIOMS Tippani & Shrawan–Ashadh SuTRA Fiscal Budget DTOs
# ---------------------------------------------------------------------------


class WardFiscalAllocationItem(BaseModel):
    composite_ward_id: str
    ward_number: int
    locality_name: str
    locality_name_ne: str
    historical_risk_score: float
    bti_kilograms_required: float
    ns1_rdt_kits_required: int
    llin_bednets_required: int
    fchv_search_destroy_campaigns: int
    estimated_budget_npr: float


class PalikaAnnualBudgetForecastResponse(DualCalendarMixin):
    palika_code: str
    palika_name: str
    fiscal_year_bs: str
    budget_cycle_window_bs: str
    sutra_budget_head_code: str
    total_bti_kilograms: float
    total_ns1_rdt_kits: int
    total_llin_bednets: int
    total_doxycycline_courses: int
    total_estimated_budget_npr: float
    cao_tippani_reference_no: str
    ward_allocations: list[WardFiscalAllocationItem]
