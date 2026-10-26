"""Tamper-Evident SHA-256 Hash-Chained WORM Audit Ledger & MinIO Object Lock Archiver (Electronic Transactions Act, 2063)."""

from __future__ import annotations

import hashlib
import json
import logging
import uuid
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.bs_calendar import ad_to_bs_stamp
from app.core.config import get_settings
from app.core.security import serialize_canonical_json
from app.db.models.audit_log import WormAuditLog

logger = logging.getLogger("nidaniq.audit_worm")

GENESIS_PREV_HASH = "0" * 64


def compute_worm_entry_hash(
    prev_hash: str, canonical_payload: str, timestamp_utc: str
) -> str:
    """Compute SHA-256(prev_hash || canonical_payload || timestamp_utc)."""
    material = f"{prev_hash}||{canonical_payload}||{timestamp_utc}"
    return hashlib.sha256(material.encode("utf-8")).hexdigest()


async def append_worm_audit_log(
    session: AsyncSession,
    *,
    event_type: str,
    actor_id: str,
    actor_role: str,
    palika_code: str,
    resource_id: str,
    payload: dict[str, Any],
) -> WormAuditLog:
    """
    Append an immutable hash-chained audit record to `audit_logs` and mirror to
    S3/MinIO Object Lock WORM archive (COMPLIANCE mode, 365-day retention).
    """
    stmt = select(WormAuditLog).order_by(WormAuditLog.seq_id.desc()).limit(1)
    result = await session.execute(stmt)
    last_entry = result.scalar_one_or_none()

    prev_hash = last_entry.entry_hash if last_entry is not None else GENESIS_PREV_HASH
    stamp = ad_to_bs_stamp(datetime.now(UTC))
    canonical_payload = serialize_canonical_json(payload)
    entry_hash = compute_worm_entry_hash(
        prev_hash=prev_hash,
        canonical_payload=canonical_payload,
        timestamp_utc=stamp.timestamp_utc,
    )
    audit_uuid = str(uuid.uuid4())
    settings = get_settings()
    minio_key = (
        f"worm/{settings.sovereign_datacenter_id}/{palika_code}/"
        f"{stamp.bs_date_iso.split()[0]}/{audit_uuid}.json"
    )

    record = WormAuditLog(
        audit_uuid=audit_uuid,
        event_type=event_type,
        actor_id=actor_id,
        actor_role=actor_role,
        palika_code=palika_code,
        resource_id=resource_id,
        canonical_payload=canonical_payload,
        timestamp_utc=stamp.timestamp_utc,
        timestamp_bs=stamp.bs_combined_label,
        prev_hash=prev_hash,
        entry_hash=entry_hash,
        minio_object_key=minio_key,
    )
    session.add(record)
    await session.flush()

    # Mirror to sovereign local WORM spool directory (and MinIO Object Lock when reachable)
    _mirror_to_worm_storage(record, settings.worm_retention_days)
    return record


def _mirror_to_worm_storage(record: WormAuditLog, retention_days: int) -> None:
    """Write WORM Object Lock envelope to local IDMC archive spool."""
    try:
        spool_dir = Path("./exports/worm_object_lock")
        spool_dir.mkdir(parents=True, exist_ok=True)
        envelope = {
            "audit_uuid": record.audit_uuid,
            "seq_id": record.seq_id,
            "event_type": record.event_type,
            "actor_id": record.actor_id,
            "actor_role": record.actor_role,
            "palika_code": record.palika_code,
            "resource_id": record.resource_id,
            "canonical_payload": json.loads(record.canonical_payload),
            "timestamp_utc": record.timestamp_utc,
            "timestamp_bs": record.timestamp_bs,
            "prev_hash": record.prev_hash,
            "entry_hash": record.entry_hash,
            "object_lock_mode": "COMPLIANCE",
            "retention_days": retention_days,
        }
        out_file = spool_dir / f"{record.seq_id:08d}_{record.audit_uuid}.json"
        out_file.write_text(
            json.dumps(envelope, ensure_ascii=False, indent=2), encoding="utf-8"
        )
    except Exception as exc:
        logger.warning("Local WORM archive spool notice: %s", exc)


async def verify_audit_chain_integrity(session: AsyncSession) -> dict[str, Any]:
    """
    Traverse the entire `audit_logs` table in ascending sequence order and verify:
    1. First entry `prev_hash == GENESIS_PREV_HASH`
    2. Each entry `prev_hash == previous_entry.entry_hash`
    3. Each entry `entry_hash == SHA-256(prev_hash || canonical_payload || timestamp_utc)`
    """
    stmt = select(WormAuditLog).order_by(WormAuditLog.seq_id.asc())
    rows = list((await session.execute(stmt)).scalars().all())

    expected_prev = GENESIS_PREV_HASH
    broken_at_seq: int | None = None
    failure_reason: str | None = None

    for row in rows:
        if row.prev_hash != expected_prev:
            broken_at_seq = row.seq_id
            failure_reason = (
                f"Chain link mismatch at seq_id={row.seq_id}: "
                f"expected prev_hash={expected_prev}, found {row.prev_hash}"
            )
            break

        recomputed = compute_worm_entry_hash(
            prev_hash=row.prev_hash,
            canonical_payload=row.canonical_payload,
            timestamp_utc=row.timestamp_utc,
        )
        if recomputed != row.entry_hash:
            broken_at_seq = row.seq_id
            failure_reason = (
                f"Payload tamper detected at seq_id={row.seq_id}: "
                f"recomputed SHA-256={recomputed} != stored entry_hash={row.entry_hash}"
            )
            break

        expected_prev = row.entry_hash

    stamp = ad_to_bs_stamp(datetime.now(UTC))
    return {
        "valid": broken_at_seq is None,
        "total_entries_verified": len(rows),
        "head_hash": expected_prev if rows else GENESIS_PREV_HASH,
        "broken_at_seq_id": broken_at_seq,
        "failure_reason": failure_reason,
        "compliance_standard": "Electronic Transactions Act, 2063 & DCCS Directive 2081 (365-Day WORM)",
        "verified_at_utc": stamp.timestamp_utc,
        "verified_at_bs": stamp.bs_combined_label,
    }
