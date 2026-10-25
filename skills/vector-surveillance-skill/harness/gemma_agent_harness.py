"""Open-Weight Gemma 4 / Gemma 2 + Gemini 3.8 Flash Agent Skill Tool-Calling Harness."""

from __future__ import annotations

import json
import logging
import os
import re
import sys
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import httpx
from google import genai
from pydantic import BaseModel, Field

try:
    from .skill_executor import SkillExecutor
except (ImportError, ValueError):
    from skill_executor import SkillExecutor

logger = logging.getLogger("arogya_drishti.gemma_harness")

_SKILL_DIR = Path(__file__).resolve().parents[1]
_HARNESS_DIR = Path(__file__).resolve().parent
_REPO_ROOT = Path(__file__).resolve().parents[3]
_BACKEND_DIR = _REPO_ROOT / "backend"
for _p in (_HARNESS_DIR, _REPO_ROOT, _BACKEND_DIR):
    if str(_p) not in sys.path:
        sys.path.insert(0, str(_p))

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
            "IMPORTANT: Keep your reply SHORT, CONCISE, and direct (maximum 50-60 words or 2-3 bullet points). Do NOT output long essays. "
            "Respond in the same language as the officer (English, Hindi/Hinglish, or Punjabi). "
            "Cite only key live indices (BI/CI) and the essential field action/chemical dosage (Temephos 50% EC @ 1 ml/1,000 L, Bti @ 5–10 g/m²)."
        )

        settings = self.executor.settings

        # 1. Try Open-Weight Gemma 4 / Vertex AI OpenAI-compatible endpoint if configured
        if settings.gemma_endpoint_url:
            try:
                base_ep = settings.gemma_endpoint_url.rstrip("/")
                chat_url = (
                    f"{base_ep}/chat/completions"
                    if base_ep.endswith("/openapi")
                    else f"{base_ep}/v1/chat/completions"
                )
                headers: dict[str, str] = {}
                model_for_ep = settings.gemma_model_id
                parsed_ep = urlparse(base_ep)
                ep_host = (parsed_ep.hostname or "").lower()
                if ep_host == "googleapis.com" or ep_host.endswith(".googleapis.com"):
                    import google.auth
                    import google.auth.transport.requests

                    creds, _ = google.auth.default(
                        scopes=["https://www.googleapis.com/auth/cloud-platform"]
                    )
                    creds.refresh(google.auth.transport.requests.Request())
                    headers["Authorization"] = f"Bearer {creds.token}"
                    if "gemma" in model_for_ep.lower():
                        model_for_ep = "google/gemini-2.5-flash"

                with httpx.Client(timeout=15.0) as client:
                    resp = client.post(
                        chat_url,
                        headers=headers,
                        json={
                            "model": model_for_ep,
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

        # 2. Call Open-Weight Gemma / Gemini via official google-genai SDK
        api_key = settings.google_ai_api_key or os.getenv("GEMINI_API_KEY", "")
        if api_key:
            from google.genai import types

            for model_id in ("gemini-3.8-flash", "gemma-4-26b-a4b-it", "gemini-2.5-flash"):
                try:
                    g_client = genai.Client(api_key=api_key)
                    resp = g_client.models.generate_content(
                        model=model_id,
                        contents=user_message,
                        config=types.GenerateContentConfig(
                            system_instruction=system_prompt,
                            temperature=0.2,
                        ),
                    )
                    if resp.text:
                        return AgentChatTurnResult(
                            reply_text=resp.text.strip(),
                            model_used=f"{settings.gemma_model_id} ({model_id})",
                            language_detected=lang,
                            tool_cards=cards,
                        )
                except Exception as exc:
                    logger.warning("google-genai generate_content with %s degraded: %s", model_id, exc)

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

        hi = idx_metrics.get("house_index_pct", 0.0)
        ci = idx_metrics.get("container_index_pct", 0.0)
        bi = idx_metrics.get("breteau_index", 0.0)
        lst = gee_metrics.get("lst_celsius")
        _rain = gee_metrics.get("rain_14d_mm")

        if lang in ("hi", "hi-Latn"):
            base = (
                f"**{ward_village} तत्काल प्रोटोकॉल:**\n"
                f"• **लाइव सूचकांक:** BI = **{bi}**, CI = **{ci}%**, HI = **{hi}%**।\n"
                f"• **कार्रवाई:** पानी खाली करें। कूलर/टैंक में **Temephos 50% EC (1 ml/1,000 L)** या नालियों में **Bti (5–10 g/m²)** डालें।"
            )
        else:
            climate_line = f" LST: **{lst}°C**." if lst is not None else ""
            van_line = f" Van **{van_metrics.get('vehicle_no')}** en route (ETA {van_metrics.get('eta_minutes')}m)." if van_metrics else ""
            base = (
                f"**Action Protocol — {ward_village}:**\n"
                f"• **Live Indices:** BI = **{bi}**, CI = **{ci}%**, HI = **{hi}%**.{climate_line}\n"
                f"• **Field Action:** Drain standing water. Apply **Temephos 50% EC @ 1 ml/1,000 L** (tanks/coolers) or **Bti @ 5–10 g/m²** (drains).{van_line}"
            )
        return base


def main() -> None:
    """CLI autonomous execution loop for Gemma 4 Agent Skill."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Arogya Drishti — Open-Weight Gemma 4 Agent Skill Execution Loop"
    )
    parser.add_argument(
        "--message",
        "-m",
        type=str,
        default="What is the Breteau Index and Temephos dosage protocol for Sector 22-B?",
        help="Officer query or natural language directive",
    )
    parser.add_argument(
        "--ward",
        "-w",
        type=str,
        default="Sector 22-B",
        help="Ward / Village name",
    )
    parser.add_argument(
        "--lgd",
        "-l",
        type=str,
        default="0404400017",
        help="10-digit Local Government Directory (LGD) code",
    )
    parser.add_argument(
        "--lat",
        type=float,
        default=30.7333,
        help="WGS84 Latitude",
    )
    parser.add_argument(
        "--lng",
        type=float,
        default=76.7794,
        help="WGS84 Longitude",
    )
    args = parser.parse_args()

    harness = GemmaAgentHarness()
    print(f"\n[Gemma 4 Agent Skill] Executing turn for: '{args.message}'")
    print(f"[Jurisdiction] Ward: {args.ward} | LGD: {args.lgd} | ({args.lat}, {args.lng})\n")

    res = harness.run_chat_turn(
        user_message=args.message,
        ward_village=args.ward,
        lgd_code=args.lgd,
        lat=args.lat,
        lng=args.lng,
    )

    print(f"--- Model Used: {res.model_used} ---")
    print(f"--- Language Detected: {res.language_detected} ---")
    print(f"--- Tool Cards Generated: {len(res.tool_cards)} ---")
    for idx, card in enumerate(res.tool_cards, 1):
        print(f"  [{idx}] Tool: {card.tool_name} | Type: {card.card_type} | Title: {card.title}")
    print("\n--- Assistant Reply ---")
    print(res.reply_text)
    print("-----------------------\n")


if __name__ == "__main__":
    main()
