"""Custom exceptions for Open Government Data (OGD) India integration."""

from __future__ import annotations

from fastapi import status

from app.core.exceptions import ArogyaException


class OGDIntegrationException(ArogyaException):
    """Raised when api.data.gov.in returns an error or no matching LGD records."""

    def __init__(
        self,
        detail: str,
        status_code: int = status.HTTP_502_BAD_GATEWAY,
    ) -> None:
        super().__init__(
            title="Open Government Data (data.gov.in) Integration Error",
            detail=detail,
            status_code=status_code,
            problem_type="https://arogyadrishti.gov.in/problems/ogd-integration-error",
        )
