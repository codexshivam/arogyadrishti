"""FastAPI Main Application for NidanIQ — Sovereign Vector Surveillance & Early Warning DPI for the Government of Nepal."""

from __future__ import annotations

import logging
import time
import uuid
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from typing import Any

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

from app.api.v1 import (
    auth,
    copilot,
    dashboards,
    escalations,
    facilities,
    inspections,
    integrations,
    lab_surveillance,
    nationwide_ops,
    poe_border,
    rrt_fleet,
    sms_gateway,
    sovereign_resilience,
    spatial,
    users,
    wards_gis,
)
from app.core.bs_calendar import ad_to_bs_stamp
from app.core.config import get_settings
from app.db.session import get_session_factory, init_db_schema_and_triggers
from app.services.wazuh_siem_soc import get_wazuh_soc_service
from seed_data.seed_nepal_dpi import seed_nepal_sovereign_data

logging.basicConfig(
    level=logging.INFO,
    format='{"severity": "%(levelname)s", "logger": "%(name)s", "message": "%(message)s"}',
)
logger = logging.getLogger("nidaniq.nepal.main")

settings = get_settings()
limiter = Limiter(key_func=get_remote_address)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Initialize PostGIS/SQLite schema, WORM immutability triggers, and seed Nepal 4-tier federal data."""
    await init_db_schema_and_triggers()
    factory = get_session_factory()
    async with factory() as session:
        summary = await seed_nepal_sovereign_data(session)
        await session.commit()
        logger.info("Nepal Sovereign DPI Startup Seed Complete: %s", summary)
    yield


app = FastAPI(
    title="NidanIQ — Government of Nepal Sovereign Vector Surveillance & Early Warning DPI",
    description=(
        "Standalone Sovereign Digital Public Infrastructure (DPI) backend for the Government of Nepal "
        "(Ministry of Health and Population — MoHP, Epidemiology and Disease Control Division — EDCD Teku, "
        "and 753 Local Levels / Palikas starting with Kathmandu Metropolitan City). "
        "Enforces Constitution of Nepal (2072) Schedule 8 Palika Isolation, Individual Privacy Act 2075 "
        "Zero-Citizen-PII, DCCS Directive 2081 IDMC Singha Durbar Sovereignty, and Electronic Transactions Act 2063 "
        "EdDSA JWTs & 365-Day WORM Hash-Chained Audit Ledger."
    ),
    version="2.0.0",
    lifespan=lifespan,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)  # type: ignore[arg-type]

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "OPTIONS"],
    allow_headers=["*"],
)


@app.middleware("http")
async def nepal_sovereign_security_headers(
    request: Request, call_next: Any
) -> Response:
    """Enforce NCSC 2080, DCCS Directive 2081, Wazuh SOC IP Blacklist, and Individual Privacy Act 2075 headers."""
    forwarded_for = request.headers.get("x-forwarded-for", "").split(",")[0].strip()
    client_ip = forwarded_for or (request.client.host if request.client else "")
    if client_ip and get_wazuh_soc_service().is_ip_blacklisted(client_ip):
        return Response(
            content=(
                '{"detail": "Wazuh 24/7 SOC Active Response: Source IP is blacklisted '
                'due to Impossible-Travel or 50x/min Brute-Force attack. DoIT SysAdmin alerted."}'
            ),
            status_code=403,
            media_type="application/json",
        )

    content_length = request.headers.get("content-length")
    if content_length and int(content_length) > settings.max_upload_bytes:
        return Response(
            content='{"detail": "Request payload exceeds 10 MB maximum upload limit."}',
            status_code=413,
            media_type="application/json",
        )

    start = time.perf_counter()
    trace_id = request.headers.get("X-Trace-Id", uuid.uuid4().hex)
    response: Response = await call_next(request)
    elapsed_ms = round((time.perf_counter() - start) * 1000.0, 2)
    stamp = ad_to_bs_stamp()

    response.headers["Strict-Transport-Security"] = (
        "max-age=63072000; includeSubDomains; preload"
    )
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; frame-ancestors 'none'; base-uri 'self'"
    )
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["X-Sovereign-DataCenter"] = settings.sovereign_datacenter_id
    response.headers["X-Privacy-Compliance"] = (
        "Nepal Individual Privacy Act 2075 (Zero Citizen PII)"
    )
    response.headers["X-Bikram-Sambat-Date"] = stamp.bs_date_iso
    response.headers["X-Trace-Id"] = trace_id
    response.headers["X-Response-Time-Ms"] = str(elapsed_ms)
    return response


# Register all 12 Sovereign v1 Routers
app.include_router(auth.router)
app.include_router(inspections.router)
app.include_router(wards_gis.router)
app.include_router(rrt_fleet.router)
app.include_router(facilities.router)
app.include_router(copilot.router)
app.include_router(escalations.router)
app.include_router(integrations.router)
app.include_router(sms_gateway.router)
app.include_router(poe_border.router)
app.include_router(lab_surveillance.router)
app.include_router(nationwide_ops.router)
app.include_router(sovereign_resilience.router)
app.include_router(users.router)
app.include_router(spatial.router)
app.include_router(dashboards.router)


@app.get("/healthz", tags=["System"])
async def healthz() -> dict[str, Any]:
    """Liveness probe for IDMC Singha Durbar container orchestrator."""
    stamp = ad_to_bs_stamp()
    return {
        "status": "ok",
        "service": "nidaniq-nepal-sovereign-dpi",
        "jurisdiction": "Government of Nepal (MoHP / EDCD Teku / 753 Palikas)",
        "datacenter": settings.sovereign_datacenter_id,
        "timezone": settings.timezone,
        "timestamp_utc": stamp.timestamp_utc,
        "timestamp_npt": stamp.timestamp_npt,
        "bs_date": stamp.bs_combined_label,
    }


@app.get("/readyz", tags=["System"])
async def readyz() -> dict[str, Any]:
    """Readiness probe reporting sovereign stack status."""
    stamp = ad_to_bs_stamp()
    return {
        "status": "ready",
        "datacenter_primary": settings.sovereign_datacenter_id,
        "datacenter_dr": settings.dr_datacenter_id,
        "jwt_algorithm": settings.jwt_algorithm,
        "gemma_model": settings.gemma_model_id,
        "paligemma_model": settings.paligemma_model_id,
        "routing_strategy": settings.routing_strategy,
        "hello_swasthya_hotline": "1115",
        "timestamp_utc": stamp.timestamp_utc,
        "bs_date": stamp.bs_combined_label,
    }
