"""Tests for SHA-256 Hash-Chained WORM Audit Ledger Integrity & Database Immutability Triggers."""

from __future__ import annotations

import pytest
from httpx import AsyncClient
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.audit_worm import append_worm_audit_log, verify_audit_chain_integrity
from app.services.auth_service import get_dev_last_otp


@pytest.mark.asyncio
async def test_worm_audit_hash_chain_verification_and_immutability_trigger(
    db_session: AsyncSession,
    client: AsyncClient,
) -> None:
    # Append multiple audit events
    e1 = await append_worm_audit_log(
        db_session,
        event_type="TEST_AUDIT_EVENT_1",
        actor_id="staff-who-kmc-w17",
        actor_role="ward_health_officer",
        palika_code="30608",
        resource_id="wards/NP-P3-D27-30608-W17",
        payload={"action": "initial_inspection", "count": 10},
    )
    e2 = await append_worm_audit_log(
        db_session,
        event_type="TEST_AUDIT_EVENT_2",
        actor_id="staff-chief-kmc-30608",
        actor_role="palika_health_chief",
        palika_code="30608",
        resource_id="palika/30608",
        payload={"action": "dhis2_sync", "wards": 32},
    )
    await db_session.commit()

    assert e1.prev_hash == "0" * 64
    assert e2.prev_hash == e1.entry_hash
    assert len(e2.entry_hash) == 64

    # Verify chain integrity via service
    report = await verify_audit_chain_integrity(db_session)
    assert report["valid"] is True
    assert report["total_entries_verified"] >= 2
    assert report["head_hash"] == e2.entry_hash

    # Verify chain via /api/v1/admin/audit-verify endpoint as EDCD Nodal Officer
    nodal_phone = "+9779851201115"
    await client.post("/api/v1/auth/request-otp", json={"phone": nodal_phone})
    nodal_otp = get_dev_last_otp(nodal_phone)
    assert nodal_otp is not None
    ver = await client.post(
        "/api/v1/auth/verify-otp", json={"phone": nodal_phone, "otp": nodal_otp}
    )
    nodal_headers = {"Authorization": f"Bearer {ver.json()['access_token']}"}

    api_verify = await client.get("/api/v1/admin/audit-verify", headers=nodal_headers)
    assert api_verify.status_code == 200
    assert api_verify.json()["valid"] is True

    target_seq_id = int(e1.seq_id)

    # Attempt raw SQL UPDATE on audit_logs -> MUST be blocked by DB trigger
    with pytest.raises(DBAPIError, match="WORM Audit Violation"):
        await db_session.execute(
            text("UPDATE audit_logs SET actor_id = 'tampered' WHERE seq_id = :seq"),
            {"seq": target_seq_id},
        )
    await db_session.rollback()

    # Attempt raw SQL DELETE on audit_logs -> MUST be blocked by DB trigger
    with pytest.raises(DBAPIError, match="WORM Audit Violation"):
        await db_session.execute(
            text("DELETE FROM audit_logs WHERE seq_id = :seq"),
            {"seq": target_seq_id},
        )
    await db_session.rollback()
