"""Monsoon Surge Async GPU Task Queue & Circuit Breaker Service.

Decouples PaliGemma 3B vision and Gemma 4 reports from synchronous HTTP workers during
peak monsoon hours (Shrawan–Kartik, 10:00 AM – 2:00 PM NPT).
If the IDMC Singha Durbar GPU node hits >= 90% VRAM or goes offline, trips the circuit breaker:
accepts the inspection immediately (`HTTP 202 Accepted`), returns deterministic EDCD dosage rules
instantly, and enqueues the vision scan into the background queue.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from typing import Any, Literal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.bs_calendar import ad_to_bs_stamp
from app.core.config import get_settings
from app.db.models import AsyncGpuVisionJob
from app.services.epidemiology_math import compute_edcd_larvicide_protocol

CircuitStateLiteral = Literal["CLOSED", "OPEN", "HALF_OPEN"]


class GpuCircuitBreaker:
    """In-memory + DB-backed GPU Circuit Breaker for IDMC Singha Durbar vLLM / PaliGemma cluster."""

    def __init__(self) -> None:
        self.vram_utilization_pct: float = 42.0
        self.gpu_node_online: bool = True
        self.consecutive_failures: int = 0

    @property
    def state(self) -> CircuitStateLiteral:
        threshold = get_settings().gpu_vram_circuit_threshold_pct
        if not self.gpu_node_online or self.vram_utilization_pct >= threshold or self.consecutive_failures >= 3:
            return "OPEN"
        if self.vram_utilization_pct >= (threshold - 5.0):
            return "HALF_OPEN"
        return "CLOSED"

    def set_telemetry(
        self,
        *,
        vram_utilization_pct: float,
        gpu_node_online: bool = True,
        consecutive_failures: int = 0,
    ) -> dict[str, Any]:
        self.vram_utilization_pct = round(max(0.0, min(100.0, vram_utilization_pct)), 2)
        self.gpu_node_online = gpu_node_online
        self.consecutive_failures = max(0, consecutive_failures)
        return self.status_dict()

    def status_dict(self) -> dict[str, Any]:
        stamp = ad_to_bs_stamp()
        return {
            "circuit_state": self.state,
            "vram_utilization_pct": self.vram_utilization_pct,
            "vram_threshold_pct": get_settings().gpu_vram_circuit_threshold_pct,
            "gpu_node_online": self.gpu_node_online,
            "consecutive_failures": self.consecutive_failures,
            "timestamp_utc": stamp.timestamp_utc,
            "bs_date": stamp.bs_combined_label,
        }


_gpu_circuit_breaker = GpuCircuitBreaker()


def get_gpu_circuit_breaker() -> GpuCircuitBreaker:
    """Return singleton IDMC GPU Circuit Breaker."""
    return _gpu_circuit_breaker


async def enqueue_monsoon_surge_vision_job(
    session: AsyncSession,
    *,
    composite_ward_id: str,
    palika_code: str,
    inspector_id: str,
    dhash_hex: str,
    water_volume_liters: float = 200.0,
    surface_area_sqm: float = 8.0,
) -> dict[str, Any]:
    """
    When the GPU circuit breaker is OPEN (VRAM >= 90% or node offline), immediately return
    deterministic EDCD dosage rules and queue the PaliGemma vision scan asynchronously (HTTP 202).
    """
    cb = get_gpu_circuit_breaker()
    protocol = compute_edcd_larvicide_protocol(
        container_type="discarded_vehicle_tire",
        water_matrix="stagnant_pool_or_tire",
        water_volume_liters=water_volume_liters,
        surface_area_sqm=surface_area_sqm,
    )
    now_utc = datetime.now(UTC)
    stamp = ad_to_bs_stamp(now_utc)
    job_id = f"GPU-JOB-{uuid.uuid4().hex[:10].upper()}"

    job = AsyncGpuVisionJob(
        job_id=job_id,
        composite_ward_id=composite_ward_id,
        palika_code=palika_code,
        inspector_id=inspector_id,
        dhash_hex=dhash_hex,
        status="QUEUED_CIRCUIT_BREAKER_202",
        circuit_state=cb.state,
        vram_utilization_pct=cb.vram_utilization_pct,
        recommended_larvicide=str(protocol["recommended_larvicide"]),
        recommended_dosage_value=float(protocol["dosage_value"]),
        recommended_dosage_unit=str(protocol["dosage_unit"]),
        edcd_intervention_ne=str(protocol["guidance_ne"]),
        edcd_intervention_en=str(protocol["guidance_en"]),
        created_at_utc=now_utc,
        created_at_bs=stamp.bs_combined_label,
    )
    session.add(job)
    await session.flush()

    return {
        "job_id": job_id,
        "status": "QUEUED_CIRCUIT_BREAKER_202",
        "http_status_code": 202,
        "circuit_state": cb.state,
        "vram_utilization_pct": cb.vram_utilization_pct,
        "composite_ward_id": composite_ward_id,
        "dhash_hex": dhash_hex,
        "recommended_larvicide": job.recommended_larvicide,
        "recommended_dosage_value": job.recommended_dosage_value,
        "recommended_dosage_unit": job.recommended_dosage_unit,
        "edcd_intervention_ne": job.edcd_intervention_ne,
        "edcd_intervention_en": job.edcd_intervention_en,
        "exif_stripped": True,
        "timestamp_utc": stamp.timestamp_utc,
        "timestamp_npt": stamp.timestamp_npt,
        "bs_date": stamp.bs_combined_label,
    }


async def get_vision_job_status(
    session: AsyncSession, job_id: str
) -> dict[str, Any] | None:
    """Retrieve status of an asynchronous GPU vision job."""
    job = (
        await session.execute(
            select(AsyncGpuVisionJob).where(AsyncGpuVisionJob.job_id == job_id)
        )
    ).scalar_one_or_none()
    if job is None:
        return None
    return {
        "job_id": job.job_id,
        "composite_ward_id": job.composite_ward_id,
        "status": job.status,
        "circuit_state": job.circuit_state,
        "vram_utilization_pct": job.vram_utilization_pct,
        "dhash_hex": job.dhash_hex,
        "recommended_larvicide": job.recommended_larvicide,
        "recommended_dosage_value": job.recommended_dosage_value,
        "recommended_dosage_unit": job.recommended_dosage_unit,
        "edcd_intervention_ne": job.edcd_intervention_ne,
        "edcd_intervention_en": job.edcd_intervention_en,
        "created_at_bs": job.created_at_bs,
    }
