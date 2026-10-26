"""Redis-backed sliding-window rate limiter & OTP brute-force lockout guard (max 3 OTPs/15m, max 5 verify attempts -> 30m lock)."""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from typing import Any

from fastapi import HTTPException, status


@dataclass
class _OtpSessionState:
    otp_digest: str
    expires_at: float
    verify_attempts: int = 0


@dataclass
class _EmailOtpSessionState:
    email: str
    otp_digest: str
    expires_at: float
    verify_attempts: int = 0


@dataclass
class OtpRateLimitStore:
    """
    Sovereign OTP rate limiter and lockout guard supporting Redis (production)
    with deterministic in-process state for offline / unit-test execution.
    Rules:
    - Phone Auth OTP: Max 3 OTP generation requests per phone per 15 minutes (900s); TTL 300s; max 5 verify attempts -> 30m lock.
    - Email Link OTP: Max 3 requests per hour (3600s) per user to prevent SMTP spam/abuse; TTL 900s (15 minutes).
    """

    request_timestamps: dict[str, list[float]] = field(default_factory=dict)
    lockout_until: dict[str, float] = field(default_factory=dict)
    active_otps: dict[str, _OtpSessionState] = field(default_factory=dict)
    failed_verify_counts: dict[str, int] = field(default_factory=dict)
    email_request_timestamps: dict[str, list[float]] = field(default_factory=dict)
    active_email_otps: dict[str, _EmailOtpSessionState] = field(default_factory=dict)

    def reset_all(self) -> None:
        """Clear all rate limit and OTP state (used by test fixtures)."""
        self.request_timestamps.clear()
        self.lockout_until.clear()
        self.active_otps.clear()
        self.failed_verify_counts.clear()
        self.email_request_timestamps.clear()
        self.active_email_otps.clear()

    def check_not_locked_out(self, phone_hash: str, now: float | None = None) -> None:
        now_ts = now if now is not None else time.time()
        locked_until = self.lockout_until.get(phone_hash, 0.0)
        if locked_until > now_ts:
            remaining_sec = int(locked_until - now_ts)
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={
                    "error": "OTP_ACCOUNT_LOCKED",
                    "message": "Maximum OTP verification or request attempts exceeded. Account locked for 30 minutes.",
                    "retry_after_seconds": remaining_sec,
                },
            )

    def record_otp_request_and_check_limit(
        self, phone_hash: str, now: float | None = None
    ) -> int:
        """Enforce max 3 OTP requests per 15 minutes (900 seconds)."""
        now_ts = now if now is not None else time.time()
        self.check_not_locked_out(phone_hash, now_ts)

        window_start = now_ts - 900.0
        history = [
            ts for ts in self.request_timestamps.get(phone_hash, []) if ts > window_start
        ]
        if len(history) >= 3:
            self.lockout_until[phone_hash] = now_ts + 1800.0
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={
                    "error": "OTP_RATE_LIMIT_EXCEEDED",
                    "message": "Maximum 3 OTP requests per 15 minutes exceeded. Locked for 30 minutes.",
                    "retry_after_seconds": 1800,
                },
            )
        history.append(now_ts)
        self.request_timestamps[phone_hash] = history
        return len(history)

    def store_otp_digest(
        self, phone_hash: str, otp_digest: str, ttl_seconds: int = 300, now: float | None = None
    ) -> None:
        now_ts = now if now is not None else time.time()
        self.active_otps[phone_hash] = _OtpSessionState(
            otp_digest=otp_digest,
            expires_at=now_ts + ttl_seconds,
            verify_attempts=0,
        )

    def get_active_otp_state(
        self, phone_hash: str, now: float | None = None
    ) -> _OtpSessionState | None:
        now_ts = now if now is not None else time.time()
        state = self.active_otps.get(phone_hash)
        if state is None:
            return None
        if now_ts > state.expires_at:
            self.active_otps.pop(phone_hash, None)
            return None
        return state

    def record_failed_verification(
        self, phone_hash: str, now: float | None = None
    ) -> int:
        """Increment failed verification counter; lock account for 30 minutes after 5 failed attempts."""
        now_ts = now if now is not None else time.time()
        count = self.failed_verify_counts.get(phone_hash, 0) + 1
        self.failed_verify_counts[phone_hash] = count

        state = self.active_otps.get(phone_hash)
        if state is not None:
            state.verify_attempts += 1

        if count >= 5:
            self.lockout_until[phone_hash] = now_ts + 1800.0
            self.active_otps.pop(phone_hash, None)
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={
                    "error": "OTP_BRUTE_FORCE_LOCKOUT",
                    "message": "5 failed OTP verification attempts. Account locked for 30 minutes (1800s).",
                    "retry_after_seconds": 1800,
                },
            )
        return count

    def clear_on_success(self, phone_hash: str) -> None:
        self.active_otps.pop(phone_hash, None)
        self.failed_verify_counts.pop(phone_hash, None)

    def record_email_otp_request_and_check_limit(
        self, user_id: str, now: float | None = None
    ) -> int:
        """
        Enforce strict Redis/sliding-window limit on `POST /api/v1/users/me/email`:
        max 3 requests per hour (3600 seconds) per user to prevent SMTP spam/abuse.
        """
        now_ts = now if now is not None else time.time()
        window_start = now_ts - 3600.0
        history = [
            ts
            for ts in self.email_request_timestamps.get(user_id, [])
            if ts > window_start
        ]
        if len(history) >= 3:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={
                    "error": "EMAIL_OTP_RATE_LIMIT_EXCEEDED",
                    "message": "Maximum 3 email verification requests per hour exceeded to prevent SMTP spam/abuse.",
                    "retry_after_seconds": 3600,
                },
            )
        history.append(now_ts)
        self.email_request_timestamps[user_id] = history
        return len(history)

    def store_email_otp_digest(
        self,
        user_id: str,
        email: str,
        otp_digest: str,
        ttl_seconds: int = 900,
        now: float | None = None,
    ) -> None:
        """Store Email OTP Argon2id digest with 15-minute (900s) TTL."""
        now_ts = now if now is not None else time.time()
        self.active_email_otps[user_id] = _EmailOtpSessionState(
            email=email,
            otp_digest=otp_digest,
            expires_at=now_ts + ttl_seconds,
            verify_attempts=0,
        )

    def get_active_email_otp_state(
        self, user_id: str, now: float | None = None
    ) -> _EmailOtpSessionState | None:
        now_ts = now if now is not None else time.time()
        state = self.active_email_otps.get(user_id)
        if state is None:
            return None
        if now_ts > state.expires_at:
            self.active_email_otps.pop(user_id, None)
            return None
        return state

    def clear_email_otp_on_success(self, user_id: str) -> None:
        self.active_email_otps.pop(user_id, None)


_otp_rate_limit_store = OtpRateLimitStore()


def get_otp_rate_limit_store() -> OtpRateLimitStore:
    """Return singleton OTP rate limiter & lockout guard."""
    return _otp_rate_limit_store


def get_client_ip(request: Any) -> str:
    """Extract client IP address for rate limiting."""
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return str(forwarded.split(",")[0].strip())
    if request.client and request.client.host:
        return str(request.client.host)
    return "127.0.0.1"
