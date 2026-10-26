"""Field SOS & Palika/EDCD SLA Escalation Ticket model (2h Critical / 6h High / 24h Routine)."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class EscalationTicket(Base):
    """SLA-tracked outbreak escalation ticket between Ward BHSC/UHPC, Palika Health Chief, and EDCD Teku."""

    __tablename__ = "escalation_tickets"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    ticket_code: Mapped[str] = mapped_column(
        String(32), unique=True, nullable=False, index=True
    )
    composite_ward_id: Mapped[str] = mapped_column(
        String(36), nullable=False, index=True
    )
    palika_code: Mapped[str] = mapped_column(String(16), nullable=False, index=True)
    reported_by_id: Mapped[str] = mapped_column(String(36), nullable=False)
    severity_tier: Mapped[str] = mapped_column(String(32), nullable=False)
    sla_hours: Mapped[int] = mapped_column(Integer, nullable=False)
    category: Mapped[str] = mapped_column(String(80), nullable=False)
    summary_sanitized: Mapped[str] = mapped_column(String(500), nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="OPEN")
    sla_due_at_utc: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    created_at_utc: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    created_at_bs: Mapped[str] = mapped_column(String(64), nullable=False)
