"""Zero-PII Field Entomological Inspections, Offline Idempotent Batch Sync, and PaliGemma Vision Router."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from typing import Any

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status
from fastapi.responses import JSONResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.audit_worm import append_worm_audit_log
from app.core.bs_calendar import ad_to_bs_stamp
from app.core.rbac import (
    AuthenticatedStaffPrincipal,
    NepalStaffRole,
    enforce_ward_isolation,
    get_current_staff,
)
from app.core.security import (
    decrypt_gps_point,
    encrypt_gps_point,
    round_to_250m_grid,
    scrub_citizen_pii_text,
    strip_exif_and_validate_image,
)
from app.db.models.admin_boundary import AdminBoundaryWard
from app.db.models.inspection import FieldInspection
from app.db.session import get_db_session, set_rls_palika_context
from app.schemas.dto import (
    BreedingSiteVisionResponse,
    InspectionBatchPayload,
    InspectionBatchResponse,
    InspectionCreateItem,
    InspectionSyncReceipt,
)
from app.services.anti_spoof_oag_service import (
    evaluate_geofence_and_velocity_anti_spoof,
    verify_and_record_image_phash,
)
from app.services.epidemiology_math import compute_all_entomological_indices
from app.services.gpu_circuit_breaker import (
    enqueue_monsoon_surge_vision_job,
    get_gpu_circuit_breaker,
)
from app.services.paligemma_vision import get_paligemma_vision_service

router = APIRouter(prefix="/api/v1", tags=["Field Entomology & PaliGemma Vision"])


async def _upsert_single_inspection(
    session: AsyncSession,
    *,
    item: InspectionCreateItem,
    principal: AuthenticatedStaffPrincipal,
) -> tuple[InspectionSyncReceipt, bool]:
    """
    Validate Ward/Palika ABAC isolation, deduplicate by `client_submission_uuid`,
    encrypt exact GPS coordinates at rest (AES-256-GCM), and compute WHO/EDCD indices.
    """
    enforce_ward_isolation(
        principal, item.composite_ward_id, allow_read_only_nodal=False
    )

    parts = item.composite_ward_id.split("-")
    inferred_palika = parts[3] if len(parts) >= 4 else principal.palika_code

    await set_rls_palika_context(
        session,
        palika_code=principal.palika_code,
        role=principal.role.value,
        assigned_wards=principal.assigned_wards,
    )

    existing = (
        await session.execute(
            select(FieldInspection).where(
                FieldInspection.client_submission_uuid == item.client_submission_uuid
            )
        )
    ).scalar_one_or_none()

    indices = compute_all_entomological_indices(
        houses_inspected=item.houses_inspected,
        houses_infested=item.houses_infested,
        wet_containers_inspected=item.wet_containers_inspected,
        positive_containers=item.positive_containers,
        total_pupae_counted=item.pupae_count,
        household_occupants_inspected=item.household_occupants_inspected,
    )

    if existing is not None:
        return (
            InspectionSyncReceipt(
                client_submission_uuid=existing.client_submission_uuid,
                inspection_id=existing.id,
                composite_ward_id=existing.composite_ward_id,
                status="DUPLICATE_IGNORED",
                house_index_hi=indices.house_index_hi,
                container_index_ci=indices.container_index_ci,
                breteau_index_bi=indices.breteau_index_bi,
                pupae_per_person_ppi=indices.pupae_per_person_ppi,
                public_grid_lat=existing.public_grid_lat,
                public_grid_lng=existing.public_grid_lng,
                bs_date=existing.inspected_at_bs,
            ),
            False,
        )

    now_utc = datetime.now(UTC)
    stamp = ad_to_bs_stamp(now_utc)
    enc_gps = encrypt_gps_point(item.latitude, item.longitude)
    grid_lat, grid_lng = round_to_250m_grid(item.latitude, item.longitude)

    # OAG Anti-Spoofing Gate: Mock GPS/Time Anchor Block, PostGIS ST_DWithin 100m, 150m Buffered Ward Geofence & Velocity Check
    try:
        quarantined = await evaluate_geofence_and_velocity_anti_spoof(
            session,
            client_submission_uuid=item.client_submission_uuid,
            composite_ward_id=item.composite_ward_id,
            palika_code=inferred_palika,
            inspector_id=principal.sub,
            latitude=item.latitude,
            longitude=item.longitude,
            houses_inspected=item.houses_inspected,
            positive_containers=item.positive_containers,
            target_household_lat=item.target_household_lat,
            target_household_lng=item.target_household_lng,
            is_mock_location_detected=item.is_mock_location_detected,
            is_device_time_tampered=item.is_device_time_tampered,
            device_clock_drift_seconds=item.device_clock_drift_seconds,
        )
    except ValueError as exc:
        await append_worm_audit_log(
            session,
            event_type="OAG_ANTI_FRAUD_MOCK_GPS_OR_TIME_TAMPER_BLOCKED",
            actor_id=principal.sub,
            actor_role=principal.role.value,
            palika_code=inferred_palika,
            resource_id=f"spoof-blocked/{item.client_submission_uuid}",
            payload={
                "composite_ward_id": item.composite_ward_id,
                "is_mock_location_detected": item.is_mock_location_detected,
                "is_device_time_tampered": item.is_device_time_tampered,
                "device_clock_drift_seconds": item.device_clock_drift_seconds,
                "reason": str(exc),
            },
        )
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    if quarantined is not None:
        return (
            InspectionSyncReceipt(
                client_submission_uuid=item.client_submission_uuid,
                inspection_id=quarantined.id,
                composite_ward_id=item.composite_ward_id,
                status="QUARANTINED_SUPERVISOR_REVIEW",
                house_index_hi=indices.house_index_hi,
                container_index_ci=indices.container_index_ci,
                breteau_index_bi=indices.breteau_index_bi,
                pupae_per_person_ppi=indices.pupae_per_person_ppi,
                public_grid_lat=grid_lat,
                public_grid_lng=grid_lng,
                spoof_quarantine_reason=quarantined.spoof_reason,
                timestamp_utc=stamp.timestamp_utc,
                timestamp_npt=stamp.timestamp_npt,
                bs_date=stamp.bs_combined_label,
            ),
            False,
        )

    insp_id = f"INSP-NP-{uuid.uuid4().hex[:12].upper()}"

    record = FieldInspection(
        id=insp_id,
        client_submission_uuid=item.client_submission_uuid,
        composite_ward_id=item.composite_ward_id,
        palika_code=inferred_palika,
        inspector_id=principal.sub,
        houses_inspected=item.houses_inspected,
        houses_infested=item.houses_infested,
        wet_containers_inspected=item.wet_containers_inspected,
        positive_containers=item.positive_containers,
        pupae_count=item.pupae_count,
        household_occupants_inspected=item.household_occupants_inspected,
        houses_searched_destroyed=item.houses_searched_destroyed,
        container_type=item.container_type,
        water_matrix=item.water_matrix,
        larvae_detected=item.larvae_detected,
        instar_stage=item.instar_stage,
        larvicide_applied=item.larvicide_applied,
        larvicide_dosage_mg=item.larvicide_dosage_mg,
        encrypted_gps_coords=enc_gps,
        public_grid_lat=grid_lat,
        public_grid_lng=grid_lng,
        vision_confidence=None,
        notes_sanitized=scrub_citizen_pii_text(item.notes),
        inspected_at_utc=now_utc,
        inspected_at_bs=stamp.bs_combined_label,
    )
    session.add(record)
    await session.flush()

    return (
        InspectionSyncReceipt(
            client_submission_uuid=record.client_submission_uuid,
            inspection_id=record.id,
            composite_ward_id=record.composite_ward_id,
            status="CREATED",
            house_index_hi=indices.house_index_hi,
            container_index_ci=indices.container_index_ci,
            breteau_index_bi=indices.breteau_index_bi,
            pupae_per_person_ppi=indices.pupae_per_person_ppi,
            public_grid_lat=grid_lat,
            public_grid_lng=grid_lng,
            timestamp_utc=stamp.timestamp_utc,
            timestamp_npt=stamp.timestamp_npt,
            bs_date=stamp.bs_combined_label,
        ),
        True,
    )


@router.post(
    "/inspections",
    response_model=InspectionSyncReceipt,
    status_code=status.HTTP_201_CREATED,
)
async def create_inspection_endpoint(
    payload: InspectionCreateItem,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> InspectionSyncReceipt:
    """Submit a single Zero-Citizen-PII field entomological inspection with idempotency."""
    receipt, created = await _upsert_single_inspection(
        session, item=payload, principal=principal
    )
    await append_worm_audit_log(
        session,
        event_type="FIELD_INSPECTION_RECORDED" if created else "FIELD_INSPECTION_IDEMPOTENT_REPLAY",
        actor_id=principal.sub,
        actor_role=principal.role.value,
        palika_code=principal.palika_code,
        resource_id=f"inspections/{receipt.inspection_id}",
        payload={
            "client_submission_uuid": payload.client_submission_uuid,
            "composite_ward_id": payload.composite_ward_id,
            "breteau_index_bi": receipt.breteau_index_bi,
        },
    )
    return receipt


@router.post("/inspections/batch", response_model=InspectionBatchResponse)
async def batch_sync_inspections_endpoint(
    payload: InspectionBatchPayload,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> InspectionBatchResponse:
    """
    Idempotent Offline Batch Sync (up to 100 inspections queued in bahals/courtyards without data).
    Deduplicates cleanly via `client_submission_uuid` (`ON CONFLICT DO NOTHING` semantics) and
    returns per-record sync receipts with Bikram Sambat timestamps.
    """
    receipts: list[InspectionSyncReceipt] = []
    created_count = 0
    dup_count = 0

    for item in payload.inspections:
        receipt, created = await _upsert_single_inspection(
            session, item=item, principal=principal
        )
        receipts.append(receipt)
        if created:
            created_count += 1
        else:
            dup_count += 1

    await append_worm_audit_log(
        session,
        event_type="FIELD_INSPECTION_BATCH_SYNC",
        actor_id=principal.sub,
        actor_role=principal.role.value,
        palika_code=principal.palika_code,
        resource_id=f"palika/{principal.palika_code}/batch",
        payload={
            "total_received": len(payload.inspections),
            "created_count": created_count,
            "duplicate_ignored_count": dup_count,
        },
    )

    return InspectionBatchResponse(
        total_received=len(payload.inspections),
        created_count=created_count,
        duplicate_ignored_count=dup_count,
        receipts=receipts,
    )


@router.get("/inspections")
async def list_inspections_endpoint(
    composite_ward_id: str | None = Query(default=None),
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """
    List field inspections isolated by Palika/Ward ABAC and PostgreSQL Row-Level Security.
    Authenticated RRT / Health Officers can decrypt exact GPS coordinates for operational response within their jurisdiction.
    """
    if composite_ward_id:
        enforce_ward_isolation(
            principal, composite_ward_id, allow_read_only_nodal=True
        )

    await set_rls_palika_context(
        session,
        palika_code=principal.palika_code,
        role=principal.role.value,
        assigned_wards=principal.assigned_wards,
    )

    stmt = select(FieldInspection)
    if principal.role != NepalStaffRole.EDCD_NODAL:
        stmt = stmt.where(FieldInspection.palika_code == principal.palika_code)
    if composite_ward_id:
        stmt = stmt.where(FieldInspection.composite_ward_id == composite_ward_id)
    elif principal.role in {NepalStaffRole.FCHV, NepalStaffRole.WARD_HEALTH_OFFICER}:
        stmt = stmt.where(FieldInspection.composite_ward_id.in_(principal.assigned_wards))

    rows = list((await session.execute(stmt)).scalars().all())
    items: list[dict[str, Any]] = []
    for r in rows:
        lat, lng = decrypt_gps_point(r.encrypted_gps_coords)
        items.append(
            {
                "id": r.id,
                "client_submission_uuid": r.client_submission_uuid,
                "composite_ward_id": r.composite_ward_id,
                "palika_code": r.palika_code,
                "inspector_id": r.inspector_id,
                "houses_inspected": r.houses_inspected,
                "houses_infested": r.houses_infested,
                "wet_containers_inspected": r.wet_containers_inspected,
                "positive_containers": r.positive_containers,
                "pupae_count": r.pupae_count,
                "container_type": r.container_type,
                "larvicide_applied": r.larvicide_applied,
                "exact_latitude": lat,
                "exact_longitude": lng,
                "public_grid_lat": r.public_grid_lat,
                "public_grid_lng": r.public_grid_lng,
                "inspected_at_bs": r.inspected_at_bs,
            }
        )

    stamp = ad_to_bs_stamp()
    return {
        "count": len(items),
        "items": items,
        "timestamp_utc": stamp.timestamp_utc,
        "bs_date": stamp.bs_combined_label,
    }


@router.post("/inspections/scan-breeding-site", response_model=None)
@router.post("/scan-breeding-site", response_model=None)
async def scan_breeding_site_endpoint(
    image: UploadFile = File(...),
    composite_ward_id: str = Form(default="NP-P3-D27-30608-W17"),
    water_volume_liters: float = Form(default=200.0),
    surface_area_sqm: float = Form(default=8.0),
    device_key_id: str | None = Form(default=None),
    cryptographic_exif_signature: str | None = Form(default=None),
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> BreedingSiteVisionResponse | JSONResponse:
    """
    PaliGemma (3B) Multimodal Entomological Triage with OAG Perceptual Hash Anti-Spoofing,
    Device-Secure Cryptographic EXIF Signature Verification & Monsoon Surge GPU Circuit Breaker:
    - Enforces Ward/Palika jurisdiction isolation.
    - Verifies magic bytes (JPEG/PNG/WEBP) and <= 10 MB limit.
    - Strips 100% of EXIF GPS/device serial metadata in memory via Pillow.
    - Rejects human portraits or Citizen ID documents under Individual Privacy Act, 2075.
    - Computes 64-bit perceptual hash (`dHash`), verifies device cryptographic EXIF signature, and rejects recycled/re-uploaded WhatsApp photos (Hamming <= 8).
    - If IDMC GPU node hits >= 90% VRAM or goes offline, trips the circuit breaker (`HTTP 202 Accepted`),
      returning deterministic EDCD dosage rules immediately and queueing vision in the background.
    """
    enforce_ward_isolation(
        principal, composite_ward_id, allow_read_only_nodal=False
    )

    raw_bytes = await image.read()
    try:
        sanitized_bytes, _exif_meta = strip_exif_and_validate_image(raw_bytes)
        scan_preview_id = f"SCAN-NP-{uuid.uuid4().hex[:10].upper()}"
        phash_meta = await verify_and_record_image_phash(
            session,
            image_bytes=sanitized_bytes,
            composite_ward_id=composite_ward_id,
            palika_code=principal.palika_code,
            inspector_id=principal.sub,
            scan_id=scan_preview_id,
            device_key_id=device_key_id,
            cryptographic_exif_signature=cryptographic_exif_signature,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc

    # Check IDMC GPU Circuit Breaker (Monsoon Surge Queueing)
    cb = get_gpu_circuit_breaker()
    if cb.state == "OPEN":
        queued_payload = await enqueue_monsoon_surge_vision_job(
            session,
            composite_ward_id=composite_ward_id,
            palika_code=principal.palika_code,
            inspector_id=principal.sub,
            dhash_hex=str(phash_meta["dhash_hex"]),
            water_volume_liters=water_volume_liters,
            surface_area_sqm=surface_area_sqm,
        )
        await append_worm_audit_log(
            session,
            event_type="PALIGEMMA_VISION_CIRCUIT_BREAKER_202",
            actor_id=principal.sub,
            actor_role=principal.role.value,
            palika_code=principal.palika_code,
            resource_id=f"vision_jobs/{queued_payload['job_id']}",
            payload={
                "composite_ward_id": composite_ward_id,
                "circuit_state": cb.state,
                "vram_utilization_pct": cb.vram_utilization_pct,
                "dhash_hex": phash_meta["dhash_hex"],
            },
        )
        return JSONResponse(content=queued_payload, status_code=status.HTTP_202_ACCEPTED)

    ward = (
        await session.execute(
            select(AdminBoundaryWard).where(
                AdminBoundaryWard.composite_ward_id == composite_ward_id
            )
        )
    ).scalar_one_or_none()
    ward_elev = ward.mean_elevation_m if ward is not None else 1304.0

    vision_svc = get_paligemma_vision_service()
    try:
        result, audit_meta = vision_svc.analyze_breeding_site_image(
            image_bytes=raw_bytes,
            composite_ward_id=composite_ward_id,
            ward_elevation_m=ward_elev,
            water_volume_liters=water_volume_liters,
            surface_area_sqm=surface_area_sqm,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc

    result.dhash_hex = str(phash_meta["dhash_hex"])
    result.device_key_id = str(phash_meta["device_key_id"])
    result.cryptographic_exif_signature = str(phash_meta["cryptographic_exif_signature"])

    await append_worm_audit_log(
        session,
        event_type="PALIGEMMA_VISION_TRIAGE",
        actor_id=principal.sub,
        actor_role=principal.role.value,
        palika_code=principal.palika_code,
        resource_id=f"vision_scans/{result.scan_id}",
        payload={
            "composite_ward_id": composite_ward_id,
            "container_type": result.container_type,
            "larvae_detected": result.larvae_detected,
            "dhash_hex": phash_meta["dhash_hex"],
            "device_key_id": phash_meta["device_key_id"],
            "cryptographic_exif_signature": phash_meta["cryptographic_exif_signature"],
            "exif_stripped": audit_meta["exif_stripped"],
            "remaining_exif_tags": audit_meta["remaining_exif_tags"],
        },
    )
    return result
