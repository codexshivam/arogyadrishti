"""Firebase Admin JWT verification, App Check validation, and DPDP Act 2023 PII scrubber."""

from __future__ import annotations

import logging
import os
import re
from typing import Any

import firebase_admin
from fastapi import Depends, Header, Request, status
from firebase_admin import app_check, auth, credentials

from app.core.config import Settings, get_settings
from app.core.exceptions import ArogyaException

logger = logging.getLogger("arogya_drishti.security")

# Regex patterns for DPDP Act 2023 PII scrubbing in logs and free-text prompts
_INDIAN_PHONE_RE = re.compile(r"(?:\+91[\-\s]?|0)?[6-9]\d{9}\b")
_EMAIL_RE = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")
_AADHAAR_RE = re.compile(r"\b\d{4}[\s-]?\d{4}[\s-]?\d{4}\b")


def scrub_pii_text(text: str) -> str:
    """Scrub phone numbers, email addresses, and Aadhaar-like numbers per DPDP Act 2023."""
    if not text:
        return text
    scrubbed = _AADHAAR_RE.sub("[REDACTED_ID]", text)
    scrubbed = _INDIAN_PHONE_RE.sub("[REDACTED_PHONE]", scrubbed)
    scrubbed = _EMAIL_RE.sub("[REDACTED_EMAIL]", scrubbed)
    return scrubbed


def init_firebase_admin(settings: Settings | None = None) -> firebase_admin.App:
    """Idempotently initialize Firebase Admin SDK using SA credentials or ADC."""
    try:
        return firebase_admin.get_app()
    except ValueError:
        cfg = settings or get_settings()
        cred_path = cfg.google_application_credentials or os.getenv(
            "GOOGLE_APPLICATION_CREDENTIALS", ""
        )
        if cred_path and os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            return firebase_admin.initialize_app(
                cred, {"projectId": cfg.gcp_project_id}
            )
        return firebase_admin.initialize_app(
            options={"projectId": cfg.gcp_project_id}
        )


class AuthenticatedOfficer( dict[str, Any]):
    """Represents a verified officer identity extracted from a Firebase ID Token."""


async def verify_firebase_jwt(
    request: Request,
    authorization: str | None = Header(default=None),
    x_firebase_appcheck: str | None = Header(default=None),
    settings: Settings = Depends(get_settings),
) -> dict[str, Any]:
    """Verify Firebase Bearer ID token and optional App Check token."""
    init_firebase_admin(settings)

    if settings.enforce_app_check:
        if not x_firebase_appcheck:
            raise ArogyaException(
                title="Missing App Check Token",
                detail="X-Firebase-AppCheck header is required by CERT-In/MASVS policy.",
                status_code=status.HTTP_401_UNAUTHORIZED,
                problem_type="https://arogyadrishti.gov.in/problems/app-check-missing",
            )
        try:
            app_check.verify_token(x_firebase_appcheck)
        except Exception as exc:
            raise ArogyaException(
                title="Invalid App Check Token",
                detail=f"App Check attestation failed: {exc}",
                status_code=status.HTTP_401_UNAUTHORIZED,
                problem_type="https://arogyadrishti.gov.in/problems/app-check-invalid",
            ) from exc

    if not authorization or not authorization.startswith("Bearer "):
        raise ArogyaException(
            title="Authentication Required",
            detail="Missing or malformed Authorization: Bearer <id_token> header.",
            status_code=status.HTTP_401_UNAUTHORIZED,
            problem_type="https://arogyadrishti.gov.in/problems/unauthorized",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = authorization.removeprefix("Bearer ").strip()
    try:
        decoded: dict[str, Any] = auth.verify_id_token(token, check_revoked=False)
        return decoded
    except Exception as exc:
        logger.warning("Firebase JWT verification failed: %s", scrub_pii_text(str(exc)))
        raise ArogyaException(
            title="Invalid Authentication Token",
            detail="Firebase ID token is expired, revoked, or invalid.",
            status_code=status.HTTP_401_UNAUTHORIZED,
            problem_type="https://arogyadrishti.gov.in/problems/invalid-token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc


async def optional_firebase_jwt(
    request: Request,
    authorization: str | None = Header(default=None),
    settings: Settings = Depends(get_settings),
) -> dict[str, Any] | None:
    """Verify Firebase JWT if provided, or return None for hybrid endpoints."""
    if not authorization or not authorization.startswith("Bearer "):
        return None
    init_firebase_admin(settings)
    token = authorization.removeprefix("Bearer ").strip()
    try:
        return auth.verify_id_token(token, check_revoked=False)
    except Exception:
        return None


def set_officer_custom_claims(
    uid: str,
    role: str,
    assigned_lgd_code: str,
    ward_village: str,
    settings: Settings | None = None,
) -> dict[str, Any]:
    """Assign RBAC custom JWT claims to a verified officer in Firebase Auth."""
    init_firebase_admin(settings)
    claims = {
        "role": role,
        "assigned_lgd_code": assigned_lgd_code,
        "ward_village": ward_village,
        "authorized_staff": True,
    }
    auth.set_custom_user_claims(uid, claims)
    return claims
