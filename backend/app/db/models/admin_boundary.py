"""SQLAlchemy 2.0 + GeoAlchemy2 PostGIS models for Nepal 4-Tier Administrative Hierarchy and NHFR Health Facilities."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from geoalchemy2 import Geometry
from sqlalchemy import Boolean, DateTime, Float, Integer, String, Text
from sqlalchemy.engine import Dialect
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import TypeDecorator, TypeEngine

from app.db.session import Base


class SovereignPostGISGeometry(TypeDecorator[str]):
    """
    Uses native GeoAlchemy2 PostGIS `Geometry(geometry_type, srid=4326)` on PostgreSQL
    and falls back to WKT/GeoJSON `Text` on SQLite (avoiding SpatiaLite `RecoverGeometryColumn`).
    """

    impl = Text
    cache_ok = True

    def __init__(self, geometry_type: str = "MULTIPOLYGON", srid: int = 4326) -> None:
        super().__init__()
        self.geometry_type = geometry_type
        self.srid = srid

    def load_dialect_impl(self, dialect: Dialect) -> TypeEngine[Any]:
        if dialect.name == "postgresql":
            return dialect.type_descriptor(
                Geometry(
                    geometry_type=self.geometry_type,
                    srid=self.srid,
                    spatial_index=True,
                )
            )
        return dialect.type_descriptor(Text())


class AdminBoundaryWard(Base):
    """
    MoFAGA / National Statistics Office (NSO) 4-tier federal administrative boundary:
    Province (1-7) -> District (77) -> Palika / Local Level (753) -> Ward (6,743).
    """

    __tablename__ = "admin_boundary_wards"

    composite_ward_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    province_code: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    province_name: Mapped[str] = mapped_column(String(80), nullable=False)
    district_code: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    district_name: Mapped[str] = mapped_column(String(80), nullable=False)
    palika_code: Mapped[str] = mapped_column(String(16), nullable=False, index=True)
    palika_name: Mapped[str] = mapped_column(String(120), nullable=False)
    palika_type: Mapped[str] = mapped_column(String(40), nullable=False)
    ward_number: Mapped[int] = mapped_column(Integer, nullable=False)
    locality_name: Mapped[str] = mapped_column(String(120), nullable=False)
    locality_name_ne: Mapped[str] = mapped_column(String(120), nullable=False)
    mean_elevation_m: Mapped[float] = mapped_column(Float, nullable=False)
    centroid_lat: Mapped[float] = mapped_column(Float, nullable=False)
    centroid_lng: Mapped[float] = mapped_column(Float, nullable=False)
    dhis2_org_unit_uid: Mapped[str] = mapped_column(String(32), nullable=False)
    geojson_str: Mapped[str] = mapped_column(Text, nullable=False)
    geom: Mapped[str | None] = mapped_column(
        SovereignPostGISGeometry(geometry_type="MULTIPOLYGON", srid=4326),
        nullable=True,
    )
    updated_at_utc: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    updated_at_bs: Mapped[str] = mapped_column(String(64), nullable=False)


class HealthFacility(Base):
    """
    Nepal Health Facility Registry (NHFR — nhfr.mohp.gov.np) Accredited Hospitals
    and Municipal Urban Health Promotion Centers (UHPCs / सहरी स्वास्थ्य प्रवर्द्धन केन्द्र).
    """

    __tablename__ = "nhfr_health_facilities"

    facility_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    nhfr_code: Mapped[str] = mapped_column(String(32), unique=True, nullable=False)
    name_en: Mapped[str] = mapped_column(String(160), nullable=False)
    name_ne: Mapped[str] = mapped_column(String(160), nullable=False)
    facility_type: Mapped[str] = mapped_column(String(64), nullable=False)
    palika_code: Mapped[str] = mapped_column(String(16), nullable=False, index=True)
    composite_ward_id: Mapped[str] = mapped_column(String(36), nullable=False, index=True)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    elevation_m: Mapped[float] = mapped_column(Float, nullable=False)
    has_24x7_fever_clinic: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True
    )
    ns1_elisa_available: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True
    )
    rapid_diagnostic_kit_stock: Mapped[int] = mapped_column(
        Integer, nullable=False, default=100
    )
    emergency_phone: Mapped[str] = mapped_column(String(32), nullable=False)
    hello_swasthya_hotline: Mapped[str] = mapped_column(
        String(16), nullable=False, default="1115"
    )
    geom: Mapped[str | None] = mapped_column(
        SovereignPostGISGeometry(geometry_type="POINT", srid=4326),
        nullable=True,
    )
