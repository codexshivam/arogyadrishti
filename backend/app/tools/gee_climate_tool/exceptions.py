"""Custom exceptions for Google Earth Engine satellite bio-climate analysis."""

from __future__ import annotations

from fastapi import status

from app.core.exceptions import ArogyaException


class GEEClimateException(ArogyaException):
    """Raised when satellite climate telemetry cannot be retrieved or coordinates are outside India."""

    def __init__(
        self,
        detail: str,
        status_code: int = status.HTTP_502_BAD_GATEWAY,
    ) -> None:
        super().__init__(
            title="Satellite Bio-Climate Telemetry Error",
            detail=detail,
            status_code=status_code,
            problem_type="https://arogyadrishti.gov.in/problems/gee-climate-error",
        )
