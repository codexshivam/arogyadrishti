"""Devanagari & English Nepali Civic News Signal Miner (Onlinekhabar, Setopati, Ekantipur, Gorkhapatra, Ratopati)."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from app.core.bs_calendar import ad_to_bs_stamp

NEPALI_CIVIC_PORTALS: tuple[str, ...] = (
    "Onlinekhabar (onlinekhabar.com)",
    "Setopati (setopati.com)",
    "Ekantipur / Kantipur Daily (ekantipur.com)",
    "Gorkhapatra National Daily (gorkhapatraonline.com)",
    "Ratopati (ratopati.com)",
)

# Devanagari & English outbreak precursor keywords and weights
PRECURSOR_KEYWORDS: dict[str, float] = {
    "डेंगु": 28.0,
    "लामखुट्टे": 20.0,
    "जमेको पानी": 18.0,
    "ढल जाम": 15.0,
    "फोहर": 12.0,
    "ज्वरो": 16.0,
    "टेकु अस्पताल": 18.0,
    "खोज र नष्ट गर": 10.0,
    "dengue": 25.0,
    "mosquito": 18.0,
    "stagnant water": 18.0,
    "waterlogging": 15.0,
    "fever cluster": 20.0,
}

# Gazetteer mapping Nepali/English locality names to canonical Nepal composite_ward_id
NEPAL_LOCALITY_GAZETTEER: dict[str, str] = {
    "naxal": "NP-P3-D27-30608-W01",
    "नक्साल": "NP-P3-D27-30608-W01",
    "maharajgunj": "NP-P3-D27-30608-W03",
    "महाराजगञ्ज": "NP-P3-D27-30608-W03",
    "chabahil": "NP-P3-D27-30608-W07",
    "चाबहिल": "NP-P3-D27-30608-W07",
    "baneshwor": "NP-P3-D27-30608-W10",
    "बानेश्वर": "NP-P3-D27-30608-W10",
    "teku": "NP-P3-D27-30608-W12",
    "टेकु": "NP-P3-D27-30608-W12",
    "kalimati": "NP-P3-D27-30608-W13",
    "कालीमाटी": "NP-P3-D27-30608-W13",
    "kalanki": "NP-P3-D27-30608-W14",
    "कलंकी": "NP-P3-D27-30608-W14",
    "balaju": "NP-P3-D27-30608-W16",
    "बालाजु": "NP-P3-D27-30608-W16",
    "chhetrapati": "NP-P3-D27-30608-W17",
    "क्षेत्रपाटी": "NP-P3-D27-30608-W17",
    "thamel": "NP-P3-D27-30608-W26",
    "ठमेल": "NP-P3-D27-30608-W26",
    "lainchaur": "NP-P3-D27-30608-W26",
    "लैनचौर": "NP-P3-D27-30608-W26",
    "minbhawan": "NP-P3-D27-30608-W31",
    "मीनभवन": "NP-P3-D27-30608-W31",
    "koteshwor": "NP-P3-D27-30608-W32",
    "कोटेश्वर": "NP-P3-D27-30608-W32",
    "patan": "NP-P3-D28-30805-W03",
    "पाटन": "NP-P3-D28-30805-W03",
    "pulchowk": "NP-P3-D28-30805-W03",
    "पुल्चोक": "NP-P3-D28-30805-W03",
    "jawalakhel": "NP-P3-D28-30805-W04",
    "जावलाखेल": "NP-P3-D28-30805-W04",
}

DEFAULT_CURATED_HEADLINES: list[dict[str, str]] = [
    {
        "source": "Onlinekhabar",
        "headline": "काठमाडौंको क्षेत्रपाटी, बालाजु र टेकु क्षेत्रमा डेंगु र ज्वरोका बिरामी बढे, जमेको पानी हटाउन महानगरको अपिल",
    },
    {
        "source": "Setopati",
        "headline": "बानेश्वर र कोटेश्वरमा ढल जाम र जमेको पानीले लामखुट्टे बढ्यो, खोज र नष्ट गर अभियान तीव्र",
    },
    {
        "source": "Ekantipur",
        "headline": "कालीमाटी र कलंकीका टायर वर्कसपहरूमा एडिज लामखुट्टेको लार्भा भेटियो",
    },
    {
        "source": "Gorkhapatra",
        "headline": "पाटन र जावलाखेलमा डेंगु नियन्त्रणका लागि महिला सामुदायिक स्वास्थ्य स्वयंसेविका परिचालन",
    },
    {
        "source": "Ratopati",
        "headline": "ठमेल, लैनचौर र महाराजगञ्जमा घरदैलो लार्भा परीक्षण अभियान सञ्चालन",
    },
]


@dataclass(frozen=True)
class CivicNlpWardSignal:
    composite_ward_id: str
    nlp_risk_score: float
    matched_keywords: list[str]
    matched_portals: list[str]
    timestamp_bs: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "composite_ward_id": self.composite_ward_id,
            "nlp_risk_score": self.nlp_risk_score,
            "matched_keywords": self.matched_keywords,
            "matched_portals": self.matched_portals,
            "timestamp_bs": self.timestamp_bs,
        }


class NepaliNewsNlpService:
    """Mine Devanagari and English civic headlines to compute Pillar-5 outbreak precursor scores [0, 100]."""

    def analyze_headlines_for_ward(
        self,
        composite_ward_id: str,
        headlines: list[dict[str, str]] | None = None,
    ) -> CivicNlpWardSignal:
        corpus = headlines if headlines is not None else DEFAULT_CURATED_HEADLINES
        matched_kw: set[str] = set()
        matched_sources: set[str] = set()
        raw_score = 0.0

        # Identify which gazetteer tokens map to this ward
        ward_tokens = [
            token
            for token, w_id in NEPAL_LOCALITY_GAZETTEER.items()
            if w_id == composite_ward_id
        ]

        for item in corpus:
            text = str(item.get("headline") or "")
            text_lower = text.lower()
            source = str(item.get("source") or "Nepali Civic Bulletin")

            ward_mentioned = any(tok in text_lower or tok in text for tok in ward_tokens)
            if not ward_mentioned and ward_tokens:
                continue

            for kw, weight in PRECURSOR_KEYWORDS.items():
                if kw in text or kw in text_lower:
                    matched_kw.add(kw)
                    matched_sources.add(source)
                    raw_score += weight

        if not matched_kw:
            # Baseline seasonal monsoon civic awareness signal
            raw_score = 15.0

        clipped = round(min(100.0, max(0.0, raw_score)), 2)
        stamp = ad_to_bs_stamp()
        return CivicNlpWardSignal(
            composite_ward_id=composite_ward_id,
            nlp_risk_score=clipped,
            matched_keywords=sorted(matched_kw),
            matched_portals=sorted(matched_sources) if matched_sources else ["Baseline Seasonal Bulletin"],
            timestamp_bs=stamp.bs_combined_label,
        )


_nepali_nlp_service = NepaliNewsNlpService()


def get_nepali_news_nlp_service() -> NepaliNewsNlpService:
    """Return singleton Nepali Civic News NLP service."""
    return _nepali_nlp_service
