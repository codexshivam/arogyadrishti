"""Rapid Response Team ('Khoj Ra Nashta Gar' / खोज र नष्ट गर) vehicle units & policy-gated dispatch logs."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class RrtVehicleUnit(Base):
    """Municipal Rapid Response Team (RRT) vehicle unit with government BA-2-JHA-... plate and Bti/Temephos stock."""

    __tablename__ = "rrt_vehicle_units"

    vehicle_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    plate_number: Mapped[str] = mapped_column(String(32), unique=True, nullable=False)
    palika_code: Mapped[str] = mapped_column(String(16), nullable=False, index=True)
    base_ward_id: Mapped[str] = mapped_column(String(36), nullable=False)
    team_lead_name: Mapped[str] = mapped_column(String(120), nullable=False)
    team_lead_name_ne: Mapped[str] = mapped_column(String(120), nullable=False)
    driver_phone: Mapped[str] = mapped_column(String(24), nullable=False)
    bti_stock_kg: Mapped[float] = mapped_column(Float, nullable=False)
    temephos_stock_liters: Mapped[float] = mapped_column(Float, nullable=False)
    ulv_equipment_mounted: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
    )
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="AVAILABLE")
    base_lat: Mapped[float] = mapped_column(Float, nullable=False)
    base_lng: Mapped[float] = mapped_column(Float, nullable=False)
    updated_at_bs: Mapped[str] = mapped_column(String(64), nullable=False)


class RrtDispatchLog(Base):
    """Audit-backed log of 'Search & Destroy' RRT dispatches and restricted focal ULV space-spraying overrides."""

    __tablename__ = "rrt_dispatch_logs"

    dispatch_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    vehicle_id: Mapped[str] = mapped_column(String(36), nullable=False, index=True)
    plate_number: Mapped[str] = mapped_column(String(32), nullable=False)
    composite_ward_id: Mapped[str] = mapped_column(
        String(36), nullable=False, index=True
    )
    palika_code: Mapped[str] = mapped_column(String(16), nullable=False, index=True)
    dispatch_type: Mapped[str] = mapped_column(String(32), nullable=False)
    requested_by_id: Mapped[str] = mapped_column(String(36), nullable=False)
    approved_by_chief_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    ewars_cases_verified: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0
    )
    breteau_index_at_dispatch: Mapped[float] = mapped_column(
        Float, nullable=False, default=0.0
    )
    campaign_action_ne: Mapped[str] = mapped_column(String(200), nullable=False)
    campaign_action_en: Mapped[str] = mapped_column(String(200), nullable=False)
    route_distance_km: Mapped[float] = mapped_column(Float, nullable=False)
    route_eta_minutes: Mapped[float] = mapped_column(Float, nullable=False)
    routing_engine: Mapped[str] = mapped_column(String(32), nullable=False)
    statutory_justification: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(
        String(32), nullable=False, default="DISPATCHED"
    )
    dispatched_at_utc: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    dispatched_at_bs: Mapped[str] = mapped_column(String(64), nullable=False)
