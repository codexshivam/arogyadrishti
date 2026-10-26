"""Staff Email Linking, 15-Minute Email OTP Verification, and Zero-Cost Notification Routing Router."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.audit_worm import append_worm_audit_log
from app.core.bs_calendar import ad_to_bs_stamp
from app.core.rate_limit import get_otp_rate_limit_store
from app.core.rbac import AuthenticatedStaffPrincipal, get_current_staff
from app.core.security import (
    generate_6digit_otp,
    hash_secret_argon2id,
    verify_secret_argon2id,
)
from app.db.models.staff_user import StaffUser
from app.db.session import get_db_session
from app.schemas.dto import UserEmailLinkRequest, UserEmailVerifyRequest
from app.services.notification_service import (
    SystemNotificationEventType,
    get_notification_service,
)

router = APIRouter(prefix="/api/v1/users", tags=["Users & Zero-Cost Email Notifications"])


class SystemAlertDispatchRequest(BaseModel):
    event_type: SystemNotificationEventType = "RRT_DISPATCHED"
    title_en: str = Field(
        default="RRT Van BA-2-JHA-4101 Dispatched to Ward 17 Chhetrapati",
        max_length=160,
    )
    title_ne: str = Field(
        default="वडा १७ क्षेत्रपाटीमा RRT भ्यान (BA-2-JHA-4101) परिचालन गरियो",
        max_length=160,
    )
    summary_en: str = Field(
        default="Biological Bti larviciding and Search & Destroy campaign initiated for Tier-1 hotspot.",
        max_length=500,
    )
    summary_ne: str = Field(
        default="उच्च जोखिम वडा १७ मा जैविक Bti तथा खोज र नष्ट अभियान सुरु गरिएको छ।",
        max_length=500,
    )
    metadata: dict[str, Any] = Field(default_factory=dict)


@router.post("/me/email")
async def link_official_staff_email_endpoint(
    payload: UserEmailLinkRequest,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """
    Link an official or personal email address to the authenticated staff member's profile
    for zero-cost notifications (`SLA_BREACH`, `RRT_DISPATCHED`, `DAILY_RISK_REPORT`):
    - Enforces max 3 requests per hour per user (`HTTP 429` anti-spam guard).
    - Sets `email = payload.email` and `is_email_verified = False`.
    - Dispatches a 6-digit Email OTP via SMTP (15-minute / 900s TTL).
    - Appends a hash-chained WORM audit log entry (`EMAIL_LINK_REQUESTED`).
    """
    rate_store = get_otp_rate_limit_store()
    req_count_1h = rate_store.record_email_otp_request_and_check_limit(principal.sub)

    staff = (
        await session.execute(
            select(StaffUser).where(StaffUser.id == principal.sub)
        )
    ).scalar_one_or_none()
    if staff is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Authenticated staff record not found.",
        )

    conflict = (
        await session.execute(
            select(StaffUser).where(
                StaffUser.email == payload.email,
                StaffUser.id != staff.id,
            )
        )
    ).scalar_one_or_none()
    if conflict is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This email address is already linked to another accredited staff account.",
        )

    staff.email = payload.email
    staff.is_email_verified = False
    await session.flush()

    otp_code = generate_6digit_otp()
    otp_digest = hash_secret_argon2id(otp_code)
    rate_store.store_email_otp_digest(
        staff.id, payload.email, otp_digest, ttl_seconds=900
    )

    notif_res = await get_notification_service().send_email_verification_otp(
        user=staff,
        target_email=payload.email,
        otp_code=otp_code,
    )

    worm_row = await append_worm_audit_log(
        session,
        event_type="EMAIL_LINK_REQUESTED",
        actor_id=staff.id,
        actor_role=staff.role,
        palika_code=staff.palika_code,
        resource_id=f"staff_users/{staff.id}/email",
        payload={
            "ACTION": "EMAIL_LINK_REQUESTED",
            "ACTOR": staff.id,
            "NEW_VALUE": payload.email,
            "requests_in_last_hour": req_count_1h,
            "ttl_seconds": 900,
        },
    )

    stamp = ad_to_bs_stamp()
    return {
        "status": "EMAIL_VERIFICATION_OTP_SENT",
        "email": staff.email,
        "is_email_verified": staff.is_email_verified,
        "ttl_seconds": 900,
        "requests_in_last_hour": req_count_1h,
        "max_requests_per_hour": 3,
        "smtp_delivery": notif_res,
        "worm_audit_hash": worm_row.entry_hash,
        "timestamp_utc": stamp.timestamp_utc,
        "bs_date": stamp.bs_combined_label,
        "bs_ad_official_label": stamp.bs_ad_official_label,
    }


@router.post("/me/email/verify")
async def verify_official_staff_email_otp_endpoint(
    payload: UserEmailVerifyRequest,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """
    Validate the 6-digit Email OTP (15-minute TTL), mark `is_email_verified = True`,
    and record an immutable WORM audit entry (`"ACTION": "EMAIL_VERIFIED"`).
    """
    rate_store = get_otp_rate_limit_store()
    staff = (
        await session.execute(
            select(StaffUser).where(StaffUser.id == principal.sub)
        )
    ).scalar_one_or_none()
    if staff is None or not staff.email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No pending email address found on this profile. Call POST /api/v1/users/me/email first.",
        )

    state = rate_store.get_active_email_otp_state(staff.id)
    if state is None or state.email != staff.email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email verification OTP has expired (15-minute TTL) or was not requested.",
        )

    if not verify_secret_argon2id(state.otp_digest, payload.email_otp):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid 6-digit Email verification OTP.",
        )

    staff.is_email_verified = True
    rate_store.clear_email_otp_on_success(staff.id)
    await session.flush()

    worm_row = await append_worm_audit_log(
        session,
        event_type="EMAIL_VERIFIED",
        actor_id=staff.id,
        actor_role=staff.role,
        palika_code=staff.palika_code,
        resource_id=f"staff_users/{staff.id}/email",
        payload={
            "ACTION": "EMAIL_VERIFIED",
            "ACTOR": staff.id,
            "NEW_VALUE": staff.email,
        },
    )

    stamp = ad_to_bs_stamp()
    return {
        "status": "EMAIL_VERIFIED",
        "email": staff.email,
        "is_email_verified": True,
        "notification_routing": "ZERO_COST_EMAIL_AND_IN_APP_PUSH_ACTIVE",
        "worm_audit_hash": worm_row.entry_hash,
        "timestamp_utc": stamp.timestamp_utc,
        "bs_date": stamp.bs_combined_label,
        "bs_ad_official_label": stamp.bs_ad_official_label,
    }


@router.post("/me/notifications/route-event")
async def route_system_event_notification_endpoint(
    payload: SystemAlertDispatchRequest,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """
    Route a system event (`SLA_BREACH`, `RRT_DISPATCHED`, `DAILY_RISK_REPORT`) for the current user
    via `NotificationService` (Email if `is_email_verified == True`, else In-App Push only; ZERO SMS).
    """
    return await get_notification_service().route_system_event(
        session,
        target_user_id=principal.sub,
        event_type=payload.event_type,
        title_en=payload.title_en,
        title_ne=payload.title_ne,
        summary_en=payload.summary_en,
        summary_ne=payload.summary_ne,
        metadata=payload.metadata,
    )
