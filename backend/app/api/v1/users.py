"""Staff Email Linking, 15-Minute Email OTP Verification, and Zero-Cost Notification Routing Router."""

import json
import uuid
from datetime import UTC, datetime
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.audit_worm import append_worm_audit_log
from app.core.bs_calendar import ad_to_bs_stamp
from app.core.rate_limit import get_otp_rate_limit_store
from app.core.rbac import AuthenticatedStaffPrincipal, NepalStaffRole, get_current_staff
from app.core.security import (
    encrypt_field_aes256gcm,
    generate_6digit_otp,
    hash_nepal_phone,
    hash_secret_argon2id,
    normalize_nepal_phone,
    verify_secret_argon2id,
)
from app.db.models.staff_user import StaffUser
from app.db.session import get_db_session
from app.schemas.dto import (
    StaffProfileResponse,
    StaffUserCreateRequest,
    StaffUserUpdateRequest,
    UserEmailLinkRequest,
    UserEmailVerifyRequest,
)
from app.services.notification_service import (
    SystemNotificationEventType,
    get_notification_service,
)

router = APIRouter(prefix="/api/v1/users", tags=["Users & Zero-Cost Email Notifications"])


def _standardize_role(input_role: str) -> str:
    r = input_role.strip().lower()
    if r in {"admin", "edcd_nodal"}:
        return NepalStaffRole.ADMIN.value
    if r in {"municipality_admin", "palika_health_chief"}:
        return NepalStaffRole.MUNICIPALITY_ADMIN.value
    if r in {"field_visitor", "ward_health_officer", "fchv"}:
        return NepalStaffRole.FIELD_VISITOR.value
    return r


@router.get("", response_model=dict[str, Any])
async def list_staff_users_endpoint(
    palika_code: str | None = Query(default=None),
    role: str | None = Query(default=None),
    search: str | None = Query(default=None),
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """
    List staff users according to RBAC:
    - Admin: can see all users, or filter by palika, role, and search.
    - Municipality Admin: strictly sees users in their own Palika.
    - Field Visitor: sees only their own profile.
    """
    stmt = select(StaffUser)

    if principal.is_admin:
        if palika_code:
            stmt = stmt.where(StaffUser.palika_code == palika_code)
    elif principal.is_municipality_admin:
        stmt = stmt.where(StaffUser.palika_code == principal.palika_code)
    else:
        stmt = stmt.where(StaffUser.id == principal.sub)

    if role:
        std_role = _standardize_role(role)
        stmt = stmt.where(StaffUser.role == std_role)

    if search:
        term = f"%{search.strip()}%"
        stmt = stmt.where(
            or_(
                StaffUser.full_name.ilike(term),
                StaffUser.designation.ilike(term),
                StaffUser.email.ilike(term),
            )
        )

    stmt = stmt.order_by(StaffUser.created_at_utc.desc())
    users = list((await session.execute(stmt)).scalars().all())
    stamp = ad_to_bs_stamp()

    return {
        "count": len(users),
        "users": [
            {
                "id": u.id,
                "full_name": u.full_name,
                "full_name_ne": u.full_name_ne,
                "designation": u.designation,
                "role": u.role,
                "province_code": u.province_code,
                "district_code": u.district_code,
                "palika_code": u.palika_code,
                "assigned_wards": u.assigned_wards,
                "email": u.email,
                "is_email_verified": u.is_email_verified,
                "is_active": u.is_active,
                "created_at_bs": u.created_at_bs,
            }
            for u in users
        ],
        "timestamp_utc": stamp.timestamp_utc,
        "bs_date": stamp.bs_combined_label,
    }


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_staff_user_endpoint(
    payload: StaffUserCreateRequest,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """
    Create a new staff user:
    - Admin: can add Admin, Municipality Admin, or Field Visitor for any Palika/Ward.
    - Municipality Admin: can ONLY add Field Visitors within their own assigned Palika.
    """
    if not (principal.is_admin or principal.is_municipality_admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Forbidden: Only System Administrators and Municipality Administrators can create users.",
        )

    target_role = _standardize_role(payload.role)

    # Municipality admin restriction: can only add field visitors for their own palika
    if principal.is_municipality_admin:
        if target_role not in {NepalStaffRole.FIELD_VISITOR.value, NepalStaffRole.FCHV.value, NepalStaffRole.WARD_HEALTH_OFFICER.value}:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Forbidden: Municipality Administrators can only add Field Visitors.",
            )
        target_palika = principal.palika_code
    else:
        target_palika = payload.palika_code

    try:
        norm_phone = normalize_nepal_phone(payload.phone)
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve)) from ve

    phone_h = hash_nepal_phone(norm_phone)
    existing = (
        await session.execute(select(StaffUser).where(StaffUser.phone_hash == phone_h))
    ).scalar_one_or_none()
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Conflict: A staff user with mobile number {payload.phone} already exists in the directory.",
        )

    now_utc = datetime.now(UTC)
    stamp = ad_to_bs_stamp(now_utc)
    user_id = f"staff-{target_role[:5]}-{uuid.uuid4().hex[:8]}"

    # Pin hash if provided
    pin_h = hash_secret_argon2id(payload.pin) if payload.pin else None

    new_user = StaffUser(
        id=user_id,
        phone_hash=phone_h,
        phone_encrypted=encrypt_field_aes256gcm(norm_phone),
        full_name=payload.full_name,
        full_name_ne=payload.full_name_ne or payload.full_name,
        designation=payload.designation or "Public Health Field Staff",
        role=target_role,
        province_code=payload.province_code,
        district_code=payload.district_code,
        palika_code=target_palika,
        assigned_wards_json=json.dumps(payload.assigned_wards or ["*"]),
        pin_hash=pin_h,
        email=payload.email,
        is_email_verified=False,
        is_active=True,
        created_at_utc=now_utc,
        created_at_bs=stamp.bs_combined_label,
    )
    session.add(new_user)
    await session.flush()

    await append_worm_audit_log(
        session,
        event_type="STAFF_USER_CREATED",
        actor_id=principal.sub,
        actor_role=principal.role.value,
        palika_code=target_palika,
        resource_id=f"staff_users/{user_id}",
        payload={
            "created_user_id": user_id,
            "role": target_role,
            "palika_code": target_palika,
            "assigned_wards": payload.assigned_wards,
        },
    )

    return {
        "status": "CREATED",
        "user_id": user_id,
        "full_name": new_user.full_name,
        "role": new_user.role,
        "palika_code": new_user.palika_code,
        "assigned_wards": new_user.assigned_wards,
        "created_at_bs": new_user.created_at_bs,
    }


@router.put("/{user_id}")
async def update_staff_user_endpoint(
    user_id: str,
    payload: StaffUserUpdateRequest,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """Update staff user details with jurisdiction check."""
    user = (
        await session.execute(select(StaffUser).where(StaffUser.id == user_id))
    ).scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Staff user not found.")

    if not principal.is_admin:
        if not principal.is_municipality_admin or user.palika_code != principal.palika_code:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Forbidden: Cannot update staff user outside your assigned municipality.",
            )
        if payload.role and _standardize_role(payload.role) != user.role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Forbidden: Municipality Admins cannot alter user roles.",
            )

    if payload.full_name is not None:
        user.full_name = payload.full_name
    if payload.full_name_ne is not None:
        user.full_name_ne = payload.full_name_ne
    if payload.designation is not None:
        user.designation = payload.designation
    if payload.role is not None and principal.is_admin:
        user.role = _standardize_role(payload.role)
    if payload.assigned_wards is not None:
        user.assigned_wards_json = json.dumps(payload.assigned_wards)
    if payload.email is not None:
        user.email = payload.email
    if payload.is_active is not None:
        user.is_active = payload.is_active
    if payload.palika_code is not None and principal.is_admin:
        user.palika_code = payload.palika_code

    await session.flush()
    return {
        "status": "UPDATED",
        "user_id": user.id,
        "full_name": user.full_name,
        "role": user.role,
        "is_active": user.is_active,
        "palika_code": user.palika_code,
        "assigned_wards": user.assigned_wards,
    }


@router.delete("/{user_id}")
async def delete_staff_user_endpoint(
    user_id: str,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """Deactivate or remove staff user with jurisdiction check."""
    user = (
        await session.execute(select(StaffUser).where(StaffUser.id == user_id))
    ).scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Staff user not found.")

    if not principal.is_admin:
        if not principal.is_municipality_admin or user.palika_code != principal.palika_code:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Forbidden: Cannot delete staff user outside your assigned municipality.",
            )
        if user.role in {NepalStaffRole.ADMIN.value, NepalStaffRole.EDCD_NODAL.value, NepalStaffRole.MUNICIPALITY_ADMIN.value}:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Forbidden: Municipality Admins cannot delete administrative accounts.",
            )

    user.is_active = False
    await session.flush()
    return {"status": "DEACTIVATED", "user_id": user.id}


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
