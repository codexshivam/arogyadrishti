"""MoHP eLMIS (Electronic Logistics Management Information System) & Provincial PHLMC Stockout Predictor.

Tracks 9 critical vector-borne disease commodities across:
Central Medical Store (Teku / Pathlaiya) -> 7 Provincial PHLMCs -> 753 Palika Health Stores -> Basic Health Service Centers.
Automatically generates Provincial PHLMC eLMIS requisition orders when `days_remaining < 10`.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from typing import Literal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.bs_calendar import ad_to_bs_stamp
from app.db.models.nationwide_expansion import ElmisCommodityStock, LabSurveillanceRecord
from app.db.models.ward_risk_daily import WardRiskDaily
from app.schemas.dto import (
    ElmisCommodityItemForecast,
    ElmisPalikaForecastResponse,
    ElmisRequisitionOrderDTO,
)

PROVINCIAL_PHLMC_HUBS: dict[int, str] = {
    1: "PHLMC Biratnagar (Koshi Province)",
    2: "PHLMC Janakpurdham / Pathlaiya Central Transit (Madhesh Province)",
    3: "PHLMC Hetauda & Central Medical Store Teku (Bagmati Province)",
    4: "PHLMC Pokhara (Gandaki Province)",
    5: "PHLMC Butwal (Lumbini Province)",
    6: "PHLMC Surkhet (Karnali Province)",
    7: "PHLMC Dhangadhi (Sudurpashchim Province)",
}

DEFAULT_COMMODITY_CATALOG: list[tuple[str, str, str, float, float]] = [
    ("NS1_RDT", "डेंगु NS1/IgM द्रुत परीक्षण किट", "kits", 140.0, 22.0),
    ("MALARIA_RDT", "औलो Pf/Pv द्रुत परीक्षण किट", "kits", 120.0, 10.0),
    ("RK39_RDT", "कालाजार rK39 द्रुत परीक्षण किट", "kits", 65.0, 4.5),
    ("BTI_GRANULES_KG", "जैविक लार्भिसाइड Bti (वाटर डिस्पर्सिबल पाउडर)", "kg", 28.0, 4.2),
    ("TEMEPHOS_L", "टेमेफोस ५०% ई.सी. (Temephos 50% EC)", "liters", 18.0, 1.5),
    ("LLIN_NETS", "कीटनाशकयुक्त झुल (LLIN Bed-Nets)", "nets", 95.0, 14.0),
    ("DOXYCYCLINE_TABS", "डक्सिसाइक्लिन १०० मि.ग्रा. (Scrub Typhus)", "tablets", 320.0, 45.0),
    ("ORS_PACKETS", "जीवनजल (ORS पुनर्जलीय झोल प्याकेट)", "packets", 450.0, 65.0),
    ("PARACETAMOL_TABS", "प्यारासिटामोल ५०० मि.ग्रा. (NSAID निषेधित)", "tablets", 1200.0, 180.0),
]


def infer_province_from_palika(palika_code: str) -> int:
    """Infer Nepal Province (1..7) from 5-digit NSO/MoFAGA Palika code prefix."""
    if palika_code and palika_code[0].isdigit():
        first_digit = int(palika_code[0])
        if 1 <= first_digit <= 7:
            return first_digit
    return 3


async def ensure_palika_elmis_stocks(
    db: AsyncSession,
    palika_code: str,
) -> list[ElmisCommodityStock]:
    """Ensure all 9 statutory eLMIS commodities exist for the requested Palika."""
    stmt = select(ElmisCommodityStock).where(ElmisCommodityStock.palika_code == palika_code)
    result = await db.execute(stmt)
    existing = list(result.scalars().all())
    if existing:
        return existing

    prov = infer_province_from_palika(palika_code)
    now_utc = datetime.now(UTC)
    stamp = ad_to_bs_stamp(now_utc)
    seeded: list[ElmisCommodityStock] = []
    for code, name_ne, unit, stock, daily_burn in DEFAULT_COMMODITY_CATALOG:
        row = ElmisCommodityStock(
            id=str(uuid.uuid4()),
            palika_code=palika_code,
            phlmc_province_code=prov,
            store_tier="PALIKA_HEALTH_STORE",
            commodity_code=code,
            commodity_name_ne=name_ne,
            unit=unit,
            current_stock=stock,
            daily_baseline_burn=daily_burn,
            updated_at_utc=now_utc,
            updated_at_bs=stamp.bs_combined_label,
        )
        db.add(row)
        seeded.append(row)
    await db.commit()
    return seeded


async def forecast_elmis_stockout_for_palika(
    db: AsyncSession,
    palika_code: str,
) -> ElmisPalikaForecastResponse:
    """
    Compute 14-day projected commodity burn rates from Palika composite vector risk +
    NPHL Teku serotype shift multipliers, and auto-generate Provincial PHLMC eLMIS
    requisition payloads when `days_remaining < 10.0`.
    """
    stocks = await ensure_palika_elmis_stocks(db, palika_code)
    prov = stocks[0].phlmc_province_code if stocks else infer_province_from_palika(palika_code)
    phlmc_hub = PROVINCIAL_PHLMC_HUBS.get(prov, PROVINCIAL_PHLMC_HUBS[3])

    # Query mean composite risk for the Palika
    risk_stmt = select(func.avg(WardRiskDaily.composite_risk_score)).where(
        WardRiskDaily.palika_code == palika_code
    )
    risk_res = await db.execute(risk_stmt)
    mean_risk = float(risk_res.scalar() or 68.0)

    # Check if NPHL Teku logged a dengue serotype shift in this province
    lab_stmt = (
        select(LabSurveillanceRecord)
        .where(
            LabSurveillanceRecord.province_code == prov,
            LabSurveillanceRecord.record_type == "DENGUE_SEROTYPE_SHIFT",
        )
        .order_by(LabSurveillanceRecord.recorded_at_utc.desc())
        .limit(1)
    )
    lab_res = await db.execute(lab_stmt)
    lab_record = lab_res.scalar_one_or_none()
    ade_mult = float(lab_record.ade_surge_multiplier) if lab_record else 1.0

    # Outbreak surge multiplier scales from 1.0x (safe) up to 2.4x (critical tier + ADE shift)
    outbreak_mult = round(max(1.0, (0.75 + (mean_risk / 85.0)) * ade_mult), 2)

    forecasts: list[ElmisCommodityItemForecast] = []
    requisitions: list[ElmisRequisitionOrderDTO] = []
    stamp = ad_to_bs_stamp()

    for item in stocks:
        proj_burn = round(max(0.1, item.daily_baseline_burn * outbreak_mult), 2)
        days_rem = round(item.current_stock / proj_burn, 1)
        imminent = days_rem < 10.0
        # Target 30 days of outbreak-adjusted buffer stock
        target_30d = round(proj_burn * 30.0, 1)
        reorder_qty = round(max(0.0, target_30d - item.current_stock), 1)

        forecasts.append(
            ElmisCommodityItemForecast(
                commodity_code=item.commodity_code,
                commodity_name_ne=item.commodity_name_ne,
                unit=item.unit,
                current_stock=item.current_stock,
                daily_baseline_burn=item.daily_baseline_burn,
                projected_daily_outbreak_burn=proj_burn,
                days_remaining=days_rem,
                stockout_imminent=imminent,
                recommended_reorder_qty=reorder_qty,
            )
        )

        if imminent:
            priority: Literal[
                "EMERGENCY_AIR_OR_CONVOY", "URGENT_PHLMC_DISPATCH", "ROUTINE"
            ] = (
                "EMERGENCY_AIR_OR_CONVOY"
                if (days_rem < 4.5 or prov in (6, 7))
                else "URGENT_PHLMC_DISPATCH"
            )
            req_id = f"ELMIS-REQ-{stamp.bs_year}-P{prov}-{item.commodity_code[:6]}-{uuid.uuid4().hex[:4].upper()}"
            requisitions.append(
                ElmisRequisitionOrderDTO(
                    requisition_id=req_id,
                    palika_code=palika_code,
                    phlmc_province_code=prov,
                    source_depot=phlmc_hub,
                    destination_store=f"Palika Health Store #{palika_code}",
                    priority=priority,
                    commodity_code=item.commodity_code,
                    quantity_requested=reorder_qty,
                    unit=item.unit,
                    justification_ne=(
                        f"मौज्दात {days_rem} दिन मात्र बाँकी (< १० दिन सीमा); १४-दिने प्रकोप प्रक्षेपण ({outbreak_mult}x) "
                        f"अनुसार {phlmc_hub} बाट आकस्मिक निकासा माग।"
                    ),
                )
            )

    return ElmisPalikaForecastResponse(
        palika_code=palika_code,
        phlmc_province_code=prov,
        phlmc_hub_name=phlmc_hub,
        outbreak_surge_multiplier=outbreak_mult,
        commodities=forecasts,
        auto_requisitions=requisitions,
    )
