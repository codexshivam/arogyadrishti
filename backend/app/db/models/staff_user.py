"""Whitelisted Staff Directory model (FCHVs, Ward Health Officers, Palika Health Chiefs, EDCD Nodals)."""

from __future__ import annotations

import json
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class StaffUser(Base):
    """
    Government of Nepal Accredited Public Health Personnel Directory.
    Pre-OTP Whitelist Gate verifies `phone_hash` and `is_active == True` before dispatching SMS.
    """

    __tablename__ = "staff_users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    phone_hash: Mapped[str] = mapped_column(
        String(64), unique=True, nullable=False, index=True
    )
    phone_encrypted: Mapped[str] = mapped_column(Text, nullable=False)
    full_name: Mapped[str] = mapped_column(String(120), nullable=False)
    full_name_ne: Mapped[str] = mapped_column(String(120), nullable=False)
    designation: Mapped[str] = mapped_column(String(120), nullable=False)
    role: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    province_code: Mapped[int] = mapped_column(Integer, nullable=False)
    district_code: Mapped[int] = mapped_column(Integer, nullable=False)
    palika_code: Mapped[str] = mapped_column(String(16), nullable=False, index=True)
    assigned_wards_json: Mapped[str] = mapped_column(Text, nullable=False, default="[]")
    pin_hash: Mapped[str | None] = mapped_column(String(256), nullable=True)
    email: Mapped[str | None] = mapped_column(
        String(160), unique=True, nullable=True, index=True
    )
    is_email_verified: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at_utc: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    created_at_bs: Mapped[str] = mapped_column(String(64), nullable=False)

    @property
    def assigned_wards(self) -> list[str]:
        try:
            parsed = json.loads(self.assigned_wards_json or "[]")
            return [str(w) for w in parsed]
        except Exception:
            return []
