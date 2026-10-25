"""Custom exceptions for Google Sheets API v4 integration."""

from __future__ import annotations

from fastapi import status

from app.core.exceptions import NidanIQException


class SheetsIntegrationException(NidanIQException):
    """Raised when Google Sheets v4 encounters quota (429), permission (403), or schema errors."""

    def __init__(
        self,
        detail: str,
        status_code: int = status.HTTP_502_BAD_GATEWAY,
        retry_after_seconds: int | None = None,
    ) -> None:
        headers: dict[str, str] = {}
        if retry_after_seconds is not None:
            headers["Retry-After"] = str(retry_after_seconds)
        super().__init__(
            title="Google Sheets Municipal Ledger Error",
            detail=detail,
            status_code=status_code,
            problem_type="https://NidanIQ.gov.in/problems/sheets-ledger-error",
            headers=headers,
        )


class StaffContactNotFoundException(NidanIQException):
    """Raised when neither 3_Staff_Directory nor OGD has a verified staff record."""

    def __init__(self, detail: str) -> None:
        super().__init__(
            title="Authorized Staff Contact Not Found",
            detail=detail,
            status_code=status.HTTP_404_NOT_FOUND,
            problem_type="https://NidanIQ.gov.in/problems/staff-contact-not-found",
        )
