"""Nepal +977 OTP, Refresh Rotation, and Staff Profile Router."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.audit_worm import append_worm_audit_log
from app.core.bs_calendar import ad_to_bs_stamp
from app.core.rbac import AuthenticatedStaffPrincipal, get_current_staff
from app.core.security import revoke_jti
from app.db.models.staff_user import StaffUser
from app.db.session import get_db_session
from app.schemas.dto import (
    OtpRequestPayload,
    OtpVerifyPayload,
    RefreshTokenPayload,
    StaffProfileResponse,
    TokenPairResponse,
)
from app.services.auth_service import get_nepal_auth_service

router = APIRouter(prefix="/api/v1/auth", tags=["Authentication & RBAC"])


@router.post("/request-otp")
async def request_otp_endpoint(
    payload: OtpRequestPayload,
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """
    Validate +977 Nepali mobile number against the MoHP/Palika Staff Whitelist (`is_active == True`)
    BEFORE dispatching a 6-digit OTP via Sparrow SMS / Aakash SMS.
    Enforces max 3 OTPs per 15 minutes.
    """
    auth_svc = get_nepal_auth_service()
    return await auth_svc.request_staff_otp(session, payload.phone)


@router.post("/verify-otp", response_model=TokenPairResponse)
async def verify_otp_endpoint(
    payload: OtpVerifyPayload,
    session: AsyncSession = Depends(get_db_session),
) -> TokenPairResponse:
    """
    Verify 6-digit OTP (max 5 attempts before 30m lockout) and issue asymmetric EdDSA
    Access (15m) + Refresh (7d) JWTs containing Nepal 4-tier ABAC claims.
    """
    auth_svc = get_nepal_auth_service()
    return await auth_svc.verify_staff_otp(
        session,
        raw_phone=payload.phone,
        otp_code=payload.otp,
        device_fingerprint=payload.device_fingerprint,
    )


@router.post("/refresh", response_model=TokenPairResponse)
async def refresh_token_endpoint(
    payload: RefreshTokenPayload,
    session: AsyncSession = Depends(get_db_session),
) -> TokenPairResponse:
    """Rotate refresh token (revoking previous JTI) and issue new EdDSA token pair."""
    auth_svc = get_nepal_auth_service()
    return await auth_svc.rotate_refresh_token(
        session,
        refresh_token=payload.refresh_token,
        device_fingerprint=payload.device_fingerprint,
    )


@router.post("/logout")
async def logout_endpoint(
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """Revoke current access token JTI and record logout in WORM audit ledger."""
    revoke_jti(principal.jti)
    await append_worm_audit_log(
        session,
        event_type="AUTH_LOGOUT_JTI_REVOKED",
        actor_id=principal.sub,
        actor_role=principal.role.value,
        palika_code=principal.palika_code,
        resource_id=f"jti/{principal.jti}",
        payload={"revoked_jti": principal.jti},
    )
    stamp = ad_to_bs_stamp()
    return {
        "status": "LOGGED_OUT",
        "revoked_jti": principal.jti,
        "timestamp_utc": stamp.timestamp_utc,
        "bs_date": stamp.bs_combined_label,
    }


@router.get("/me", response_model=StaffProfileResponse)
async def get_me_endpoint(
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> StaffProfileResponse:
    """Return authenticated staff member's profile and Nepal 4-tier jurisdiction claims."""
    staff = (
        await session.execute(
            select(StaffUser).where(StaffUser.id == principal.sub)
        )
    ).scalar_one_or_none()
    if staff is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Staff user record not found.",
        )
    return StaffProfileResponse(
        id=staff.id,
        full_name=staff.full_name,
        full_name_ne=staff.full_name_ne,
        designation=staff.designation,
        role=staff.role,
        province_code=staff.province_code,
        district_code=staff.district_code,
        palika_code=staff.palika_code,
        assigned_wards=staff.assigned_wards,
        email=staff.email,
        is_email_verified=staff.is_email_verified,
        is_active=staff.is_active,
    )
