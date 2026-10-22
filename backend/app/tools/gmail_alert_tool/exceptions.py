"""Custom exceptions for Gmail / SMTP TLS emergency alert dispatch."""

from __future__ import annotations

from fastapi import status

from app.core.exceptions import ArogyaException


class EmailDispatchException(ArogyaException):
    """Raised when recipient email fails DNS MX validation or SMTP delivery fails."""

    def __init__(
        self,
        detail: str,
        status_code: int = status.HTTP_502_BAD_GATEWAY,
    ) -> None:
        super().__init__(
            title="Emergency Alert Email Dispatch Error",
            detail=detail,
            status_code=status_code,
            problem_type="https://arogyadrishti.gov.in/problems/email-dispatch-error",
        )
