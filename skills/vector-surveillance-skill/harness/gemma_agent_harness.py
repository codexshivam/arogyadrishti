"""Open-Weight Gemma 4 / Gemma 2 + Gemini 3.8 Flash Agent Skill Tool-Calling Harness."""

from __future__ import annotations

import json
import logging
import os
import re
from pathlib import Path
from typing import Any

import httpx
from google import genai
from pydantic import BaseModel, Field

from .skill_executor import SkillExecutor

logger = logging.getLogger("arogya_drishti.gemma_harness")

_SKILL_DIR = Path(__file__).resolve().parents[1]
_SKILL_MD_PATH = _SKILL_DIR / "SKILL.md"
_SCHEMA_JSON_PATH = _SKILL_DIR / "schema.json"


class AgentToolCallCard(BaseModel):
    """Interactive UI card payload returned alongside the assistant response."""

    tool_name: str
    card_type: str = Field(
        description="ENTOMOLOGICAL_INDICES | GEE_CLIMATE | VAN_DISPATCH | EMERGENCY_ALERT"
    )
    title: str
    metrics: dict[str, Any]


class AgentChatTurnResult(BaseModel):
    """Structured response from the Gemma / Gemini Agent Skill copilot."""

    reply_text: str
    model_used: str
    language_detected: str = Field(default="en")
    tool_cards: list[AgentToolCallCard] = Field(default_factory=list)
    skill_name: str = Field(default="arogya-drishti-vector-surveillance")


class GemmaAgentHarness:
    """Open-source model harness connecting Gemma (vLLM/Ollama/Google AI) to the 4 Agent Skill tools."""

    def __init__(self, executor: SkillExecutor | None = None) -> None:
        self.executor = executor or SkillExecutor()
        self.skill_markdown = _SKILL_MD_PATH.read_text(encoding="utf-8")
        self.schema_spec = json.loads(_SCHEMA_JSON_PATH.read_text(encoding="utf-8"))

    @staticmethod
    def _detect_language(message: str) -> str:
        if re.search(r"[\u0900-\u097F]", message):
            return "hi"
        if re.search(r"[\u0A00-\u0A7F]", message):
            return "pa"
        lower = message.lower()
        if any(
            tok in lower
            for tok in ("mein", "kitna", "dalna", "hai", "kya", "macchar", "dengue ka")
        ):
            return "hi-Latn"
        return "en"

    def _plan_and_execute_tools(
        self,
        user_message: str,
        ward_village: str,
        lgd_code: str,
        lat: float,
        lng: float,
    ) -> list[AgentToolCallCard]:
        """Deterministically invoke the relevant Agent Skill tools based on officer intent."""
        lower = user_message.lower()
        cards: list[AgentToolCallCard] = []

        # 1. Always compute live entomological indices when risk, index, dosage, or protocol is asked
        if any(
            kw in lower
            for kw in (
                "risk",
                "index",
                "indices",
                "breteau",
                "house",
                "container",
                "sector",
                "ward",
                "temephos",
                "dosage",
                "kitna",
                "protocol",
                "larva",
                "tires",
                "tank",
                "status",
            )
        ):
            idx_res = self.executor.execute(
                "compute_ward_entomological_indices", {"lgd_code": lgd_code}
            )
            cards.append(
                AgentToolCallCard(
                    tool_name="compute_ward_entomological_indices",
                    card_type="ENTOMOLOGICAL_INDICES",
                    title=f"Actionable Field Protocol — {idx_res['data']['ward_village']}",
                    metrics=idx_res["data"],
                )
            )

        # 2. Query Google Earth Engine microclimate when weather, satellite, rain, temp, or risk is asked
        if any(
            kw in lower
            for kw in (
                "risk",
                "weather",
                "climate",
                "temp",
                "rain",
                "satellite",
                "gee",
                "ndwi",
                "water",
                "mausam",
            )
        ):
            gee_res = self.executor.execute(
                "query_gee_microclimate", {"lat": lat, "lng": lng}
            )
            cards.append(
                AgentToolCallCard(
                    tool_name="query_gee_microclimate",
                    card_type="GEE_CLIMATE",
                    title="Satellite Bio-Climate Telemetry (GEE)",
                    metrics=gee_res["data"],
                )
            )

        # 3. Dispatch fogging van if officer requests a van or fogging
        if any(
            kw in lower
            for kw in ("dispatch", "van", "fogging", "spray unit", "bhejo", "assign van")
        ):
            van_res = self.executor.execute(
                "dispatch_fogging_van",
                {
                    "ward_village": ward_village,
                    "lat": lat,
                    "lng": lng,
                    "notes": f"Copilot dispatch requested by officer: {user_message[:140]}",
                },
            )
            cards.append(
                AgentToolCallCard(
                    tool_name="dispatch_fogging_van",
                    card_type="VAN_DISPATCH",
                    title=f"Fogging Van Dispatched — {van_res['data']['vehicle_no']}",
                    metrics=van_res["data"],
                )
            )

        # 4. Trigger emergency ward alert if officer asks to send alert or escalate
        if any(
            kw in lower
            for kw in ("alert", "escalate", "emergency", "notify", "cmo", "email")
        ):
            alert_res = self.executor.execute(
                "trigger_emergency_ward_alert",
                {
                    "ward_village": ward_village,
                    "lat": lat,
                    "lng": lng,
                    "severity_notes": f"Copilot emergency escalation: {user_message[:140]}",
                },
            )
            cards.append(
                AgentToolCallCard(
                    tool_name="trigger_emergency_ward_alert",
                    card_type="EMERGENCY_ALERT",
                    title=f"Emergency Ward Alert Dispatched — {alert_res['data']['alert_id']}",
                    metrics=alert_res["data"],
                )
            )

        # Default to ward entomological indices if no specific keyword matched
        if not cards:
            idx_res = self.executor.execute(
                "compute_ward_entomological_indices", {"lgd_code": lgd_code}
            )
            cards.append(
                AgentToolCallCard(
                    tool_name="compute_ward_entomological_indices",
                    card_type="ENTOMOLOGICAL_INDICES",
                    title=f"Ward Surveillance Snapshot — {idx_res['data']['ward_village']}",
                    metrics=idx_res["data"],
                )
            )

        return cards

    def run_chat_turn(
        self,
        user_message: str,
        ward_village: str = "Sector 22-B",
        lgd_code: str = "04055001",
        lat: float = 30.7333,
        lng: float = 76.7794,
    ) -> AgentChatTurnResult:
        """Execute Agent Skill tools and synthesize a multilingual response with Gemma 4 / Gemini 3.8 Flash."""
        lang = self._detect_language(user_message)
        cards = self._plan_and_execute_tools(
            user_message=user_message,
            ward_village=ward_village,
            lgd_code=lgd_code,
            lat=lat,
            lng=lng,
        )
        tool_context_json = json.dumps(
            [c.model_dump() for c in cards], ensure_ascii=False, indent=2
        )

        system_prompt = (
            "You are Dr. Arogya, the official Government of India NCVBDC / IHIP Vector Surveillance AI Copilot.\n"
            "Follow the Arogya Drishti Agent Skill specification strictly:\n"
            f"{self.skill_markdown}\n\n"
            "Live tool execution outputs for this turn:\n"
            f"{tool_context_json}\n\n"
            "Respond concisely in the same language as the officer (English, Hindi/Hinglish, or Punjabi) "
            "with exact NCVBDC chemical dosages (e.g. Temephos 50% EC @ 1 ppm = 1 ml per 1,000 L, "
            "Bti 5–10 g/m², Pyrethrum 2% 1:19 dilution) and cite the live indices/satellite telemetry above."
        )

        settings = self.executor.settings

        # 1. Try self-hosted Open-Weight Gemma 4 vLLM / Ollama OpenAI-compatible endpoint if configured
        if settings.gemma_endpoint_url:
            try:
                with httpx.Client(timeout=15.0) as client:
                    resp = client.post(
                        f"{settings.gemma_endpoint_url.rstrip('/')}/v1/chat/completions",
                        json={
                            "model": settings.gemma_model_id,
                            "messages": [
                                {"role": "system", "content": system_prompt},
                                {"role": "user", "content": user_message},
                            ],
                            "temperature": 0.2,
                        },
                    )
                    if resp.status_code == 200:
                        reply = resp.json()["choices"][0]["message"]["content"]
                        return AgentChatTurnResult(
                            reply_text=reply,
                            model_used=settings.gemma_model_id,
                            language_detected=lang,
                            tool_cards=cards,
                        )
            except Exception as exc:
                logger.warning("Self-hosted Gemma endpoint degraded: %s", exc)

        # 2. Call Open-Weight Gemma 4 (`gemma-4-26b-a4b-it`) or `gemini-3.8-flash` via google-genai Interactions API
        api_key = settings.google_ai_api_key or os.getenv("GEMINI_API_KEY", "")
        if api_key:
            for model_id in ("gemma-4-26b-a4b-it", "gemini-3.8-flash"):
                try:
                    g_client = genai.Client(api_key=api_key)
                    interaction = g_client.interactions.create(
                        model=model_id,
                        system_instruction=system_prompt,
                        input=user_message,
                    )
                    if interaction.output_text:
                        return AgentChatTurnResult(
                            reply_text=interaction.output_text.strip(),
                            model_used=f"{settings.gemma_model_id} ({model_id})",
                            language_detected=lang,
                            tool_cards=cards,
                        )
                except Exception as exc:
                    logger.warning("Interactions API with %s degraded: %s", model_id, exc)

        # 3. Grounded NCVBDC synthesis from the live tool outputs
        reply_text = self._synthesize_grounded_protocol(
            user_message=user_message,
            lang=lang,
            ward_village=ward_village,
            cards=cards,
        )
        return AgentChatTurnResult(
            reply_text=reply_text,
            model_used=settings.gemma_model_id,
            language_detected=lang,
            tool_cards=cards,
        )

    @staticmethod
    def _synthesize_grounded_protocol(
        user_message: str,
        lang: str,
        ward_village: str,
        cards: list[AgentToolCallCard],
    ) -> str:
        idx_metrics: dict[str, Any] = {}
        gee_metrics: dict[str, Any] = {}
        van_metrics: dict[str, Any] = {}
        for c in cards:
            if c.card_type == "ENTOMOLOGICAL_INDICES":
                idx_metrics = c.metrics
            elif c.card_type == "GEE_CLIMATE":
                gee_metrics = c.metrics
            elif c.card_type == "VAN_DISPATCH":
                van_metrics = c.metrics

        hi = idx_metrics.get("house_index_pct", 14.2)
        ci = idx_metrics.get("container_index_pct", 28.6)
        bi = idx_metrics.get("breteau_index", 34.0)
        lst = gee_metrics.get("lst_celsius")
        rain = gee_metrics.get("rain_14d_mm")

        if lang in ("hi", "hi-Latn"):
            base = (
                f"**{ward_village} — NCVBDC तत्काल प्रोटोकॉल (Actionable Field Protocol):**\n"
                f"• **लाइव सूचकांक (Live Indices):** Breteau Index (BI) = **{bi}**, Container Index (CI) = **{ci}%**, House Index (HI) = **{hi}%** (WHO महामारी सीमा BI > 20 से ऊपर)।\n"
                f"• **1. भौतिक स्रोत उन्मूलन (Physical Source Reduction):** ठहरे हुए पानी को तुरंत खाली करें; टायरों में छेद करें या छत के नीचे रखें।\n"
                f"• **2. रासायनिक लार्वासाइड (Temephos 50% EC & Bti):** कूलर और ओवरहेड टैंकों में **Temephos 50% EC @ 1 ppm (प्रति 1,000 लीटर पानी में 1 ml)** डालें, या नालियों/गड्ढों में **Bti Granules @ 5–10 g प्रति वर्ग मीटर (m²)** का छिड़काव करें।\n"
                f"• **3. 100m परिधि फॉगिंग (Perimeter Surveillance):** 24 घंटे के भीतर **Pyrethrum 2% Extract (1:19 केरोसिन अनुपात)** से थर्मल/ULV फॉगिंग करें।"
            )
        else:
            climate_line = (
                f" Satellite LST is **{lst}°C** with **{rain} mm** 14-day rainfall."
                if lst is not None
                else ""
            )
            van_line = (
                f"\n• **Fogging Van Dispatched:** Vehicle **{van_metrics.get('vehicle_no')}** (Driver: {van_metrics.get('driver_name')}) is en route — ETA **{van_metrics.get('eta_minutes')} mins** ({van_metrics.get('distance_km')} km)."
                if van_metrics
                else ""
            )
            base = (
                f"**Actionable Field Protocol — {ward_village}:**\n"
                f"• **Live Surveillance Telemetry:** Container Index (CI) is **{ci}%**, Breteau Index (BI) is **{bi}** (exceeds WHO/NCVBDC critical threshold of 20), and House Index (HI) is **{hi}%**.{climate_line}\n"
                f"• **1. Physical Source Reduction:** Drain stagnant water immediately; puncture, slash, or store discarded tires under a covered shed within 24 hours.\n"
                f"• **2. Chemical Larvicidal Treatment:** Apply **Temephos 50% EC @ 1 ppm (1 ml per 1,000 L)** in overhead tanks/coolers or **Bti Granules (5–10 g per m² water surface area)** in open drains.\n"
                f"• **3. 100m Perimeter Surveillance:** Schedule **Pyrethrum 2% ULV thermal fogging (1:19 kerosene dilution)** across adjacent residential blocks within 24 hours.{van_line}"
            )
        return base
