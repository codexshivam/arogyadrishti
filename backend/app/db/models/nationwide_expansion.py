"""SQLAlchemy 2.0 ORM Models for Nepal Nationwide Vector Surveillance Scale:
1. WHO/EDCD Malaria & Kala-azar 1-3-7 Statutory SLA Engine (`vector_137_cases`)
2. Cross-Border Point-of-Entry (PoE) Health Desk Surveillance (`poe_importation_logs`)
3. MoHP eLMIS & Provincial PHLMC Commodity Stock Registry (`elmis_commodity_stocks`)
4. NPHL Teku & VBDRTC Hetauda Serotype & Insecticide Resistance Registry (`lab_serotype_resistance_logs`)
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import Boolean, DateTime, Float, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class MalariaKalaazar137Case(Base):
    """
    Statutory WHO / EDCD Nepal 1-3-7 Malaria & Kala-azar Elimination SLA Tracker:
    - Day 1 (24h): Case Notification via RDT/Microscopy
    - Day 3 (72h): Case Investigation & Classification (Indigenous vs Imported)
    - Day 7 (168h): Foci Investigation & Vector Control Response (Pyrethroid IRS + LLIN distribution)
    """

    __tablename__ = "vector_137_cases"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    case_code: Mapped[str] = mapped_column(String(40), unique=True, index=True, nullable=False)
    disease: Mapped[str] = mapped_column(
        String(32), index=True, nullable=False
    )  # MALARIA_ANOPHELES | KALAAZAR_SANDFLY
    ecological_belt: Mapped[str] = mapped_column(
        String(24), nullable=False, default="TERAI"
    )  # TERAI | INNER_TERAI | PAHAD_VALLEY | HIMAL_CORRIDOR
    composite_ward_id: Mapped[str] = mapped_column(String(32), index=True, nullable=False)
    palika_code: Mapped[str] = mapped_column(String(16), index=True, nullable=False)
    province_code: Mapped[int] = mapped_column(Integer, index=True, nullable=False)
    reporting_facility_nhfr: Mapped[str] = mapped_column(String(32), nullable=False)

    day1_notified_at_utc: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC), nullable=False
    )
    day1_sla_due_utc: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    day3_investigated_at_utc: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    day3_sla_due_utc: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    case_classification: Mapped[str | None] = mapped_column(
        String(32), nullable=True
    )  # INDIGENOUS | IMPORTED | INTRODUCED | RELAPSE

    day7_foci_responded_at_utc: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    day7_sla_due_utc: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    foci_irs_llin_summary: Mapped[str | None] = mapped_column(Text, nullable=True)

    current_stage: Mapped[str] = mapped_column(
        String(32), default="DAY_1_NOTIFIED", nullable=False
    )  # DAY_1_NOTIFIED | DAY_3_INVESTIGATED | DAY_7_FOCI_COMPLETED | SLA_BREACHED_ESCALATED
    sla_breached: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    escalated_to_provincial_phd: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False
    )
    escalation_ticket_code: Mapped[str | None] = mapped_column(String(32), nullable=True)
    created_at_bs: Mapped[str] = mapped_column(String(64), nullable=False)


class PoeImportationLog(Base):
    """
    Zero-Citizen-PII Cross-Border Point-of-Entry (PoE Health Desk) Importation Surveillance Log.
    Covers Kakarbhitta, Rani, Birgunj, Belahiya, Jamunaha, Trinagar, Gaddachauki, and TIA.
    """

    __tablename__ = "poe_importation_logs"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    poe_desk_code: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    poe_name: Mapped[str] = mapped_column(String(96), nullable=False)
    disease: Mapped[str] = mapped_column(String(32), index=True, nullable=False)
    rdt_result: Mapped[str] = mapped_column(String(32), nullable=False)
    origin_zone: Mapped[str] = mapped_column(String(64), nullable=False)
    destination_province_code: Mapped[int] = mapped_column(Integer, index=True, nullable=False)
    destination_palika_code: Mapped[str] = mapped_column(String(16), index=True, nullable=False)
    destination_ward_no: Mapped[int] = mapped_column(Integer, nullable=False)
    destination_composite_ward_id: Mapped[str] = mapped_column(
        String(32), index=True, nullable=False
    )
    destination_alert_dispatched: Mapped[bool] = mapped_column(
        Boolean, default=True, nullable=False
    )
    alert_ticket_code: Mapped[str] = mapped_column(String(32), nullable=False)
    logged_by_id: Mapped[str] = mapped_column(String(36), nullable=False)
    logged_at_utc: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC), nullable=False
    )
    logged_at_bs: Mapped[str] = mapped_column(String(64), nullable=False)


class ElmisCommodityStock(Base):
    """
    MoHP eLMIS (Electronic Logistics Management Information System) & PHLMC Commodity Stock Registry.
    Tracks RDT kits, Bti larvicide, Temephos, LLIN bed-nets, Doxycycline, ORS, and Paracetamol.
    """

    __tablename__ = "elmis_commodity_stocks"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    palika_code: Mapped[str] = mapped_column(String(16), index=True, nullable=False)
    phlmc_province_code: Mapped[int] = mapped_column(Integer, index=True, nullable=False)
    store_tier: Mapped[str] = mapped_column(
        String(40), default="PALIKA_HEALTH_STORE", nullable=False
    )  # CENTRAL_TEKU_PATHLAIYA | PROVINCIAL_PHLMC | PALIKA_HEALTH_STORE | BASIC_HEALTH_SERVICE_CENTER
    commodity_code: Mapped[str] = mapped_column(String(32), index=True, nullable=False)
    commodity_name_ne: Mapped[str] = mapped_column(String(96), nullable=False)
    unit: Mapped[str] = mapped_column(String(24), nullable=False)
    current_stock: Mapped[float] = mapped_column(Float, nullable=False)
    daily_baseline_burn: Mapped[float] = mapped_column(Float, nullable=False)
    updated_at_utc: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC), nullable=False
    )
    updated_at_bs: Mapped[str] = mapped_column(String(64), nullable=False)


class LabSurveillanceRecord(Base):
    """
    NPHL Teku (Dengue Serotype DENV-1..4) & VBDRTC Hetauda (WHO Tube Bioassay Insecticide Resistance)
    Surveillance Registry.
    """

    __tablename__ = "lab_serotype_resistance_logs"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    lab_center: Mapped[str] = mapped_column(
        String(32), index=True, nullable=False
    )  # NPHL_TEKU | VBDRTC_HETAUDA
    province_code: Mapped[int] = mapped_column(Integer, index=True, nullable=False)
    district_code: Mapped[int] = mapped_column(Integer, index=True, nullable=False)
    record_type: Mapped[str] = mapped_column(
        String(32), index=True, nullable=False
    )  # DENGUE_SEROTYPE_SHIFT | INSECTICIDE_BIOASSAY
    dominant_serotype: Mapped[str | None] = mapped_column(String(16), nullable=True)
    previous_serotype: Mapped[str | None] = mapped_column(String(16), nullable=True)
    serotype_shift_detected: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    ade_surge_multiplier: Mapped[float] = mapped_column(Float, default=1.0, nullable=False)
    vector_species: Mapped[str] = mapped_column(
        String(48), default="Aedes aegypti", nullable=False
    )
    chemical_tested: Mapped[str | None] = mapped_column(String(32), nullable=True)
    bioassay_mortality_pct: Mapped[float | None] = mapped_column(Float, nullable=True)
    resistance_status: Mapped[str] = mapped_column(
        String(32), default="SUSCEPTIBLE", nullable=False
    )  # SUSCEPTIBLE | POSSIBLE_RESISTANCE | CONFIRMED_RESISTANCE
    recommended_substitute: Mapped[str] = mapped_column(
        String(64), default="Bti (Bacillus thuringiensis israelensis)", nullable=False
    )
    recorded_by_id: Mapped[str] = mapped_column(String(36), nullable=False)
    recorded_at_utc: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC), nullable=False
    )
    recorded_at_bs: Mapped[str] = mapped_column(String(64), nullable=False)


class ImagePerceptualHashLog(Base):
    """
    64-bit Perceptual Hash (dHash) registry for uploaded breeding-site photos.
    Prevents field spoofing (re-uploading old WhatsApp photos or re-photographing screens)
    under Mahalekha Parikshak (OAG Nepal) audit integrity standards.
    """

    __tablename__ = "image_perceptual_hashes"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    dhash_hex: Mapped[str] = mapped_column(String(16), index=True, nullable=False)
    dhash_int_str: Mapped[str] = mapped_column(String(32), nullable=False)
    composite_ward_id: Mapped[str] = mapped_column(String(32), index=True, nullable=False)
    palika_code: Mapped[str] = mapped_column(String(16), index=True, nullable=False)
    inspector_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    scan_id: Mapped[str] = mapped_column(String(36), nullable=False)
    device_key_id: Mapped[str | None] = mapped_column(
        String(64), default="NP-GOV-KEYSTORE-DEFAULT", nullable=True
    )
    cryptographic_signature: Mapped[str | None] = mapped_column(
        String(128), nullable=True
    )
    created_at_utc: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC), nullable=False
    )
    created_at_bs: Mapped[str] = mapped_column(String(64), nullable=False)


class SupervisorReviewItem(Base):
    """
    Supervisor Review Queue for field submissions flagged by:
    1. PostGIS 150m Ward Geofence Violation (`ST_Contains(ward_geom_buffered_150m, gps_point) == False`)
    2. Impossible-Velocity / Desk-Reporting Check (e.g., >=15 houses logged in <120s from identical GPS).
    Quarantined records do NOT alter official Breteau Index (BI) until supervisor-approved.
    """

    __tablename__ = "supervisor_review_queue"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    client_submission_uuid: Mapped[str] = mapped_column(
        String(64), unique=True, index=True, nullable=False
    )
    composite_ward_id: Mapped[str] = mapped_column(String(32), index=True, nullable=False)
    palika_code: Mapped[str] = mapped_column(String(16), index=True, nullable=False)
    inspector_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    spoof_flag_type: Mapped[str] = mapped_column(
        String(48), nullable=False
    )  # GEOFENCE_OUTSIDE_150M_BUFFER | IMPOSSIBLE_VELOCITY_DESK_REPORTING
    spoof_reason: Mapped[str] = mapped_column(Text, nullable=False)
    distance_from_ward_m: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    houses_inspected: Mapped[int] = mapped_column(Integer, nullable=False)
    positive_containers: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(
        String(32), default="QUARANTINED_PENDING_REVIEW", nullable=False
    )  # QUARANTINED_PENDING_REVIEW | APPROVED_BY_SUPERVISOR | REJECTED_SPOOF
    created_at_utc: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC), nullable=False
    )
    created_at_bs: Mapped[str] = mapped_column(String(64), nullable=False)


class WardInfrastructureProfile(Base):
    """
    Urban Utility Risk Modifiers (`ward_infrastructure_profiles`):
    Captures intermittent piped water rationing (`water_supply_interval_days`, e.g. KUKL 5-7 day cycle)
    and monsoon solid-waste collection lag (`waste_collection_lag_days`) that drive indoor drum/bucket
    Aedes breeding invisible to optical/SAR satellites.
    """

    __tablename__ = "ward_infrastructure_profiles"

    composite_ward_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    palika_code: Mapped[str] = mapped_column(String(16), index=True, nullable=False)
    water_supply_interval_days: Mapped[int] = mapped_column(
        Integer, default=5, nullable=False
    )
    waste_collection_lag_days: Mapped[int] = mapped_column(
        Integer, default=3, nullable=False
    )
    utility_provider: Mapped[str] = mapped_column(
        String(64), default="KUKL (Kathmandu Upatyaka Khanepani Limited)", nullable=False
    )
    utility_storage_multiplier: Mapped[float] = mapped_column(
        Float, default=1.18, nullable=False
    )
    updated_at_utc: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC), nullable=False
    )
    updated_at_bs: Mapped[str] = mapped_column(String(64), nullable=False)


class AsyncGpuVisionJob(Base):
    """
    Monsoon Surge Async GPU Task Queue & Circuit Breaker Job Record.
    Decouples PaliGemma 3B vision from synchronous HTTP workers when IDMC GPU VRAM >= 90% or offline.
    """

    __tablename__ = "async_gpu_vision_jobs"

    job_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    composite_ward_id: Mapped[str] = mapped_column(String(32), index=True, nullable=False)
    palika_code: Mapped[str] = mapped_column(String(16), index=True, nullable=False)
    inspector_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    dhash_hex: Mapped[str] = mapped_column(String(16), nullable=False)
    status: Mapped[str] = mapped_column(
        String(36), default="QUEUED_CIRCUIT_BREAKER_202", nullable=False
    )  # QUEUED_CIRCUIT_BREAKER_202 | COMPLETED
    circuit_state: Mapped[str] = mapped_column(String(24), default="OPEN", nullable=False)
    vram_utilization_pct: Mapped[float] = mapped_column(Float, default=92.5, nullable=False)
    recommended_larvicide: Mapped[str] = mapped_column(String(96), nullable=False)
    recommended_dosage_value: Mapped[float] = mapped_column(Float, nullable=False)
    recommended_dosage_unit: Mapped[str] = mapped_column(String(32), nullable=False)
    edcd_intervention_ne: Mapped[str] = mapped_column(Text, nullable=False)
    edcd_intervention_en: Mapped[str] = mapped_column(Text, nullable=False)
    created_at_utc: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC), nullable=False
    )
    created_at_bs: Mapped[str] = mapped_column(String(64), nullable=False)
