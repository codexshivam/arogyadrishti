"""Custom exceptions for Google Maps Routes API v2."""

from __future__ import annotations

from fastapi import status

from app.core.exceptions import ArogyaException


class RoutingUnavailableException(ArogyaException):
    """Raised when Google Maps Routes API v2 returns ZERO_RESULTS or no vans are available."""

    def __init__(
        self,
        detail: str,
        status_code: int = status.HTTP_503_SERVICE_UNAVAILABLE,
    ) -> None:
        super().__init__(
            title="Fogging Van Routing Unavailable",
            detail=detail,
            status_code=status_code,
            problem_type="https://arogyadrishti.gov.in/problems/routing-unavailable",
        )
