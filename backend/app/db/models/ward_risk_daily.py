"""06:00 AM NPT 5-pillar fused ward risk model (HI, CI, BI, PPI, V_elev, Z-score, Composite Risk)."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, Float, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class WardRiskDaily(Base):
    """Daily 06:00 AM NPT (00:15 UTC) 5-pillar epidemiological risk fusion snapshot per Ward."""

    __tablename__ = "ward_risk_daily"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    composite_ward_id: Mapped[str] = mapped_column(
        String(36), nullable=False, index=True
    )
    palika_code: Mapped[str] = mapped_column(String(16), nullable=False, index=True)
    fusion_date_ad: Mapped[str] = mapped_column(String(16), nullable=False, index=True)
    fusion_date_bs: Mapped[str] = mapped_column(String(64), nullable=False)
    house_index_hi: Mapped[float] = mapped_column(Float, nullable=False)
    container_index_ci: Mapped[float] = mapped_column(Float, nullable=False)
    breteau_index_bi: Mapped[float] = mapped_column(Float, nullable=False)
    pupae_per_person_ppi: Mapped[float] = mapped_column(Float, nullable=False)
    sar_water_score: Mapped[float] = mapped_column(Float, nullable=False)
    gee_climate_score: Mapped[float] = mapped_column(Float, nullable=False)
    field_entomology_score: Mapped[float] = mapped_column(Float, nullable=False)
    historical_zscore: Mapped[float] = mapped_column(Float, nullable=False)
    nepali_news_nlp_score: Mapped[float] = mapped_column(Float, nullable=False)
    elevation_viability_factor: Mapped[float] = mapped_column(Float, nullable=False)
    composite_risk_score: Mapped[float] = mapped_column(Float, nullable=False)
    risk_tier: Mapped[str] = mapped_column(String(32), nullable=False)
    ewars_confirmed_cases: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0
    )
    lst_celsius: Mapped[float] = mapped_column(Float, nullable=False)
    rainfall_14d_mm: Mapped[float] = mapped_column(Float, nullable=False)
    ndwi: Mapped[float] = mapped_column(Float, nullable=False)
    slope_deg: Mapped[float] = mapped_column(Float, nullable=False)
    computed_at_utc: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    computed_at_bs: Mapped[str] = mapped_column(String(64), nullable=False)
