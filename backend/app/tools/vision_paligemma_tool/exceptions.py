"""Custom exceptions for DPDP visual redaction and breeding site analysis."""

from __future__ import annotations

from fastapi import status

from app.core.exceptions import NidanIQException


class VisionScanException(NidanIQException):
    """Raised when an uploaded image fails validation, redaction, or vision inference."""

    def __init__(
        self,
        detail: str,
        status_code: int = status.HTTP_422_UNPROCESSABLE_ENTITY,
    ) -> None:
        super().__init__(
            title="AI Vector Breeding Site Scan Error",
            detail=detail,
            status_code=status_code,
            problem_type="https://NidanIQ.gov.in/problems/vision-scan-error",
        )
