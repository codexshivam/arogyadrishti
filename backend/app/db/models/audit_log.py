"""Append-only PostgreSQL WORM Audit Ledger model (UPDATE/DELETE blocked via DB trigger & ORM events)."""

from __future__ import annotations

from typing import Any

from sqlalchemy import Integer, String, Text, event
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class WormAuditLog(Base):
    """
    Tamper-evident hash-chained WORM audit table per Electronic Transactions Act, 2063 (2008).
    Any UPDATE or DELETE is blocked by database triggers and SQLAlchemy ORM guards.
    """

    __tablename__ = "audit_logs"

    seq_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, autoincrement=True
    )
    audit_uuid: Mapped[str] = mapped_column(
        String(36), unique=True, nullable=False, index=True
    )
    event_type: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    actor_id: Mapped[str] = mapped_column(String(64), nullable=False)
    actor_role: Mapped[str] = mapped_column(String(32), nullable=False)
    palika_code: Mapped[str] = mapped_column(String(16), nullable=False, index=True)
    resource_id: Mapped[str] = mapped_column(String(128), nullable=False)
    canonical_payload: Mapped[str] = mapped_column(Text, nullable=False)
    timestamp_utc: Mapped[str] = mapped_column(String(64), nullable=False)
    timestamp_bs: Mapped[str] = mapped_column(String(64), nullable=False)
    prev_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    entry_hash: Mapped[str] = mapped_column(
        String(64), unique=True, nullable=False, index=True
    )
    minio_object_key: Mapped[str | None] = mapped_column(String(160), nullable=True)


@event.listens_for(WormAuditLog, "before_update")
def _block_orm_update(mapper: Any, connection: Any, target: Any) -> None:
    raise RuntimeError(
        "WORM Audit Violation (Electronic Transactions Act 2063): audit_logs table is append-only; UPDATE is prohibited."
    )


@event.listens_for(WormAuditLog, "before_delete")
def _block_orm_delete(mapper: Any, connection: Any, target: Any) -> None:
    raise RuntimeError(
        "WORM Audit Violation (Electronic Transactions Act 2063): audit_logs table is append-only; DELETE is prohibited."
    )
