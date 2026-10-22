"""Standardized RFC 7807 Problem Details exception handlers for Arogya Drishti."""

from __future__ import annotations

import logging
from typing import Any

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

logger = logging.getLogger("arogya_drishti.exceptions")


class ArogyaException(Exception):
    """Base RFC 7807 Problem Details exception."""

    def __init__(
        self,
        title: str,
        detail: str,
        status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR,
        problem_type: str = "about:blank",
        instance: str | None = None,
        extensions: dict[str, Any] | None = None,
        headers: dict[str, str] | None = None,
    ) -> None:
        super().__init__(detail)
        self.title = title
        self.detail = detail
        self.status_code = status_code
        self.problem_type = problem_type
        self.instance = instance
        self.extensions = extensions or {}
        self.headers = headers or {}

    def to_problem_details(self, request_path: str) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "type": self.problem_type,
            "title": self.title,
            "status": self.status_code,
            "detail": self.detail,
            "instance": self.instance or request_path,
        }
        payload.update(self.extensions)
        return payload


def register_exception_handlers(app: FastAPI) -> None:
    """Attach RFC 7807 Problem Details handlers to the FastAPI application."""

    @app.exception_handler(ArogyaException)
    async def handle_arogya_exception(
        request: Request, exc: ArogyaException
    ) -> JSONResponse:
        logger.warning(
            "Domain exception on %s: [%d] %s - %s",
            request.url.path,
            exc.status_code,
            exc.title,
            exc.detail,
        )
        return JSONResponse(
            status_code=exc.status_code,
            content=exc.to_problem_details(request.url.path),
            headers=exc.headers,
            media_type="application/problem+json",
        )

    @app.exception_handler(RequestValidationError)
    async def handle_validation_error(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            content={
                "type": "https://arogyadrishti.gov.in/problems/validation-error",
                "title": "Request Validation Failed",
                "status": status.HTTP_422_UNPROCESSABLE_ENTITY,
                "detail": "One or more request parameters failed schema validation.",
                "instance": request.url.path,
                "errors": exc.errors(),
            },
            media_type="application/problem+json",
        )

    @app.exception_handler(Exception)
    async def handle_unexpected_exception(
        request: Request, exc: Exception
    ) -> JSONResponse:
        logger.exception("Unhandled error on %s: %s", request.url.path, exc)
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={
                "type": "https://arogyadrishti.gov.in/problems/internal-error",
                "title": "Internal Server Error",
                "status": status.HTTP_500_INTERNAL_SERVER_ERROR,
                "detail": "An unexpected internal error occurred while processing the request.",
                "instance": request.url.path,
            },
            media_type="application/problem+json",
        )
