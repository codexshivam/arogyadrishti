"""Bilingual Nepali/English Gemma 4 (12B-it / 26B-A4B) Agent Copilot Router."""

from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.audit_worm import append_worm_audit_log
from app.core.rbac import (
    AuthenticatedStaffPrincipal,
    enforce_ward_isolation,
    get_current_staff,
)
from app.db.session import get_db_session
from app.schemas.dto import CopilotChatRequest, CopilotChatResponse
from app.services.gemma_agent_harness import get_gemma_nepal_harness

router = APIRouter(prefix="/api/v1/copilot", tags=["Sovereign Gemma 4 Bilingual Copilot"])


@router.post("/chat", response_model=CopilotChatResponse)
async def copilot_chat_endpoint(
    payload: CopilotChatRequest,
    principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    session: AsyncSession = Depends(get_db_session),
) -> CopilotChatResponse:
    """
    Execute sovereign Gemma 4 agent turn inside IDMC Singha Durbar with deterministic
    EDCD tool execution trace (`query_ward_risk`, `compute_edcd_larvicide_dose`,
    `find_nearest_rrt_and_route`, `lookup_nhfr_health_centers`, `draft_dhis2_ward_report`).
    """
    enforce_ward_isolation(
        principal, payload.composite_ward_id, allow_read_only_nodal=True
    )

    target_lang = payload.preferred_language or payload.language
    harness = get_gemma_nepal_harness()
    response = await harness.run_copilot_turn(
        session,
        query=payload.query,
        composite_ward_id=payload.composite_ward_id,
        language=target_lang,
    )

    await append_worm_audit_log(
        session,
        event_type="COPILOT_AGENT_TURN",
        actor_id=principal.sub,
        actor_role=principal.role.value,
        palika_code=principal.palika_code,
        resource_id=f"copilot/{payload.composite_ward_id}",
        payload={
            "composite_ward_id": payload.composite_ward_id,
            "tools_invoked": [t.tool_name for t in response.tool_traces],
        },
    )
    return response
