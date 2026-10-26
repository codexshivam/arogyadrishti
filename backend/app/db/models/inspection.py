"""Zero-Citizen-PII field entomology inspection model with offline client_submission_uuid idempotency."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class FieldInspection(Base):
    """
    Zero-PII household & courtyard (bahal) entomological inspection log.
    Exact coordinates are encrypted at rest via AES-256-GCM; public endpoints expose only `public_grid_lat/lng`.
    """

    __tablename__ = "field_inspections"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    client_submission_uuid: Mapped[str] = mapped_column(
        String(64), unique=True, nullable=False, index=True
    )
    composite_ward_id: Mapped[str] = mapped_column(
        String(36), nullable=False, index=True
    )
    palika_code: Mapped[str] = mapped_column(String(16), nullable=False, index=True)
    inspector_id: Mapped[str] = mapped_column(String(36), nullable=False, index=True)
    houses_inspected: Mapped[int] = mapped_column(Integer, nullable=False)
    houses_infested: Mapped[int] = mapped_column(Integer, nullable=False)
    wet_containers_inspected: Mapped[int] = mapped_column(Integer, nullable=False)
    positive_containers: Mapped[int] = mapped_column(Integer, nullable=False)
    pupae_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    household_occupants_inspected: Mapped[int] = mapped_column(
        Integer, nullable=False, default=1
    )
    houses_searched_destroyed: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0
    )
    container_type: Mapped[str] = mapped_column(String(64), nullable=False)
    water_matrix: Mapped[str] = mapped_column(String(64), nullable=False)
    larvae_detected: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
    )
    instar_stage: Mapped[str | None] = mapped_column(String(32), nullable=True)
    larvicide_applied: Mapped[str] = mapped_column(String(64), nullable=False)
    larvicide_dosage_mg: Mapped[float] = mapped_column(
        Float, nullable=False, default=0.0
    )
    encrypted_gps_coords: Mapped[str] = mapped_column(Text, nullable=False)
    public_grid_lat: Mapped[float] = mapped_column(Float, nullable=False)
    public_grid_lng: Mapped[float] = mapped_column(Float, nullable=False)
    vision_confidence: Mapped[float | None] = mapped_column(Float, nullable=True)
    notes_sanitized: Mapped[str] = mapped_column(
        String(500), nullable=False, default=""
    )
    inspected_at_utc: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    inspected_at_bs: Mapped[str] = mapped_column(String(64), nullable=False)
