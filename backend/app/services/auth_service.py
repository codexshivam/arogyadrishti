"""Nepal +977 OTP Authentication (Sparrow/Aakash SMS), Staff Whitelist Gate, and EdDSA JWT Issuance."""

from __future__ import annotations

import logging
from typing import Any

import httpx
from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.audit_worm import append_worm_audit_log
from app.core.bs_calendar import ad_to_bs_stamp
from app.core.config import get_settings
from app.core.rate_limit import get_otp_rate_limit_store
from app.core.security import (
    create_asymmetric_jwt,
    generate_6digit_otp,
    hash_nepal_phone,
    hash_secret_argon2id,
    normalize_nepal_phone,
    revoke_jti,
    validate_outbound_ssrf_url,
    verify_asymmetric_jwt,
    verify_secret_argon2id,
)
from app.db.models.staff_user import StaffUser
from app.schemas.dto import StaffProfileResponse, TokenPairResponse

logger = logging.getLogger("nidaniq.auth_service")

# Deterministic dev/test outbox for inspecting dispatched OTPs in automated test suites
_DEV_OTP_OUTBOX: dict[str, str] = {}


def get_dev_last_otp(phone: str) -> str | None:
    """Retrieve the last generated OTP for a normalized +977 phone in dev/test mode."""
    norm = normalize_nepal_phone(phone)
    return _DEV_OTP_OUTBOX.get(norm)


class NepalAuthService:
    """
    Sovereign Authentication Service for the Government of Nepal:
    - Enforces +977 (Nepal Telecom / Ncell) mobile normalization.
    - Enforces Pre-OTP Whitelist Gate against `staff_users` (`is_active == True`) BEFORE sending SMS.
    - Enforces sliding-window rate limits (max 3 OTPs / 15m; max 5 verify attempts -> 30m lock).
    - Dispatches SMS via Sparrow SMS (`api.sparrowsms.com/v2/sms/`) or Aakash SMS.
    - Mints asymmetric `EdDSA` Access (15m) & Refresh (7d) JWTs with 4-tier Palika/Ward ABAC claims.
    """

    async def request_staff_otp(
        self, session: AsyncSession, raw_phone: str
    ) -> dict[str, Any]:
        norm_phone = normalize_nepal_phone(raw_phone)
        phone_hash = hash_nepal_phone(norm_phone)
        rate_store = get_otp_rate_limit_store()

        # 1. Check lockout state first
        rate_store.check_not_locked_out(phone_hash)

        # 2. Pre-OTP Staff Whitelist Gate (Zero SMS Waste)
        stmt = select(StaffUser).where(
            StaffUser.phone_hash == phone_hash,
            StaffUser.is_active.is_(True),
        )
        staff = (await session.execute(stmt)).scalar_one_or_none()

        if staff is None:
            # Uniform timing defense: compute dummy Argon2id digest before rejecting
            _ = hash_secret_argon2id("000000")
            await append_worm_audit_log(
                session,
                event_type="AUTH_OTP_WHITELIST_REJECTED",
                actor_id="unregistered_phone",
                actor_role="anonymous",
                palika_code="00000",
                resource_id=f"staff_whitelist/{phone_hash[:16]}",
                payload={"phone_hash_prefix": phone_hash[:16], "reason": "NOT_IN_STAFF_DIRECTORY"},
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Forbidden: Nepali mobile number is not registered in the accredited MoHP/Palika Staff Whitelist.",
            )

        # 3. Enforce max 3 OTP generation requests per 15m
        req_count = rate_store.record_otp_request_and_check_limit(phone_hash)

        # 4. Generate 6-digit cryptographic OTP & store Argon2id digest with 300s TTL
        otp_code = generate_6digit_otp()
        otp_digest = hash_secret_argon2id(otp_code)
        rate_store.store_otp_digest(phone_hash, otp_digest, ttl_seconds=300)

        settings = get_settings()
        if settings.env in {"development", "test"}:
            _DEV_OTP_OUTBOX[norm_phone] = otp_code

        gateway_used = await self._dispatch_sms_nepal(norm_phone, otp_code)

        await append_worm_audit_log(
            session,
            event_type="AUTH_OTP_DISPATCHED",
            actor_id=staff.id,
            actor_role=staff.role,
            palika_code=staff.palika_code,
            resource_id=f"staff_users/{staff.id}",
            payload={
                "gateway": gateway_used,
                "request_count_15m": req_count,
                "ttl_seconds": 300,
            },
        )

        stamp = ad_to_bs_stamp()
        return {
            "status": "OTP_SENT",
            "gateway": gateway_used,
            "ttl_seconds": 300,
            "message_ne": "तपाईंको दर्ता भएको मोबाइल नम्बरमा ६ अंकको ओटिपी (OTP) पठाइएको छ।",
            "message_en": "A 6-digit OTP has been dispatched to your whitelisted +977 mobile number.",
            "timestamp_utc": stamp.timestamp_utc,
            "timestamp_npt": stamp.timestamp_npt,
            "bs_date": stamp.bs_combined_label,
        }

    async def verify_staff_otp(
        self,
        session: AsyncSession,
        *,
        raw_phone: str,
        otp_code: str,
        device_fingerprint: str = "nepal-mohp-field-android",
    ) -> TokenPairResponse:
        norm_phone = normalize_nepal_phone(raw_phone)
        phone_hash = hash_nepal_phone(norm_phone)
        rate_store = get_otp_rate_limit_store()

        rate_store.check_not_locked_out(phone_hash)

        stmt = select(StaffUser).where(
            StaffUser.phone_hash == phone_hash,
            StaffUser.is_active.is_(True),
        )
        staff = (await session.execute(stmt)).scalar_one_or_none()
        if staff is None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Forbidden: Phone number is not registered in the MoHP/Palika Staff Whitelist.",
            )

        otp_state = rate_store.get_active_otp_state(phone_hash)
        if otp_state is None:
            rate_store.record_failed_verification(phone_hash)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="OTP has expired or was not requested.",
            )

        if not verify_secret_argon2id(otp_state.otp_digest, otp_code):
            try:
                attempts = rate_store.record_failed_verification(phone_hash)
            except HTTPException:
                await append_worm_audit_log(
                    session,
                    event_type="AUTH_OTP_LOCKOUT",
                    actor_id=staff.id,
                    actor_role=staff.role,
                    palika_code=staff.palika_code,
                    resource_id=f"staff_users/{staff.id}",
                    payload={"reason": "MAX_5_FAILED_VERIFY_ATTEMPTS", "lockout_seconds": 1800},
                )
                raise
            await append_worm_audit_log(
                session,
                event_type="AUTH_OTP_VERIFY_FAILED",
                actor_id=staff.id,
                actor_role=staff.role,
                palika_code=staff.palika_code,
                resource_id=f"staff_users/{staff.id}",
                payload={"failed_attempts": attempts},
            )
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid OTP code ({attempts}/5 attempts used).",
            )

        rate_store.clear_on_success(phone_hash)
        return await self._issue_tokens_for_staff(
            session, staff=staff, device_fingerprint=device_fingerprint, auth_method="SPARROW_OTP"
        )

    async def rotate_refresh_token(
        self,
        session: AsyncSession,
        *,
        refresh_token: str,
        device_fingerprint: str = "nepal-mohp-field-android",
    ) -> TokenPairResponse:
        """Verify rotating refresh token, revoke old JTI, and issue a fresh EdDSA token pair."""
        try:
            claims = verify_asymmetric_jwt(refresh_token, expected_type="refresh")
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid or revoked refresh token: {exc}",
            ) from exc

        old_jti = str(claims["jti"])
        revoke_jti(old_jti)

        staff_id = str(claims["sub"])
        staff = (
            await session.execute(
                select(StaffUser).where(
                    StaffUser.id == staff_id, StaffUser.is_active.is_(True)
                )
            )
        ).scalar_one_or_none()
        if staff is None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Staff account is no longer active.",
            )

        return await self._issue_tokens_for_staff(
            session, staff=staff, device_fingerprint=device_fingerprint, auth_method="REFRESH_ROTATION"
        )

    async def _issue_tokens_for_staff(
        self,
        session: AsyncSession,
        *,
        staff: StaffUser,
        device_fingerprint: str,
        auth_method: str,
    ) -> TokenPairResponse:
        access_token, access_jti, _ = create_asymmetric_jwt(
            subject_id=staff.id,
            role=staff.role,
            province_code=staff.province_code,
            district_code=staff.district_code,
            palika_code=staff.palika_code,
            assigned_wards=staff.assigned_wards,
            token_type="access",
            device_fingerprint=device_fingerprint,
        )
        refresh_token, _, _ = create_asymmetric_jwt(
            subject_id=staff.id,
            role=staff.role,
            province_code=staff.province_code,
            district_code=staff.district_code,
            palika_code=staff.palika_code,
            assigned_wards=staff.assigned_wards,
            token_type="refresh",
            device_fingerprint=device_fingerprint,
        )

        await append_worm_audit_log(
            session,
            event_type="AUTH_JWT_ISSUED",
            actor_id=staff.id,
            actor_role=staff.role,
            palika_code=staff.palika_code,
            resource_id=f"staff_users/{staff.id}",
            payload={
                "auth_method": auth_method,
                "jti": access_jti,
                "palika_code": staff.palika_code,
                "assigned_wards": staff.assigned_wards,
            },
        )

        profile = StaffProfileResponse(
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
        return TokenPairResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="Bearer",
            algorithm="EdDSA",
            expires_in_seconds=get_settings().access_token_expire_minutes * 60,
            jti=access_jti,
            staff_profile=profile,
        )

    async def _dispatch_sms_nepal(self, phone: str, otp_code: str) -> str:
        """Dispatch SMS via Sparrow SMS or Aakash SMS (or deterministic console mock in dev)."""
        settings = get_settings()
        msg_text = (
            f"MoHP/EDCD Nepal Vector DPI: Your login OTP is {otp_code} (valid 5 mins). "
            f"Do not share. ओटिपी: {otp_code}"
        )
        if settings.env in {"development", "test"} or not (
            settings.sparrow_sms_token or settings.aakash_sms_token
        ):
            logger.info("[DEV SMS MOCK -> %s] %s", phone, msg_text)
            return f"{settings.sms_provider}_dev_mock"

        if settings.sms_provider.lower() == "aakash" and settings.aakash_sms_token:
            url = validate_outbound_ssrf_url(settings.aakash_sms_api_url)
            async with httpx.AsyncClient(timeout=8.0) as client:
                await client.post(
                    url,
                    data={
                        "auth_token": settings.aakash_sms_token,
                        "to": phone.replace("+977", ""),
                        "text": msg_text,
                    },
                )
            return "aakash_sms_live"

        url = validate_outbound_ssrf_url(settings.sparrow_sms_api_url)
        async with httpx.AsyncClient(timeout=8.0) as client:
            await client.post(
                url,
                data={
                    "token": settings.sparrow_sms_token,
                    "from": settings.sparrow_sms_identity,
                    "to": phone.replace("+977", ""),
                    "text": msg_text,
                },
            )
        return "sparrow_sms_live"


_auth_service = NepalAuthService()


def get_nepal_auth_service() -> NepalAuthService:
    """Return singleton NepalAuthService."""
    return _auth_service
