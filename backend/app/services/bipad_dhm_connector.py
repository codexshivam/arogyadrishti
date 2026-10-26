"""NDRRMA BIPAD Portal (`bipadportal.gov.np`) & DHM (`dhm.gov.np`) Ground Weather Station (AWS) Fusion Service.

Eliminates steep Himalayan/Mahabharat valley cloud-shadow bias by fusing DHM ground AWS telemetry
with MODIS/CHIRPS satellite passes and applies a 14-day Post-Disaster Outbreak Multiplier for
Dengue, Malaria, and Scrub Typhus following river corridor flood/landslide alerts.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.bs_calendar import ad_to_bs_stamp
from app.db.models.escalation_ticket import EscalationTicket
from app.schemas.dto import DisasterWeatherFusionRequest, DisasterWeatherFusionResponse
from app.services.multi_vector_engine import parse_composite_ward_parts


async def fuse_bipad_disaster_and_dhm_weather(
    db: AsyncSession,
    req: DisasterWeatherFusionRequest,
    actor_id: str = "system-bipad-dhm-fusion",
) -> DisasterWeatherFusionResponse:
    """
    Fuse DHM ground AWS rainfall/temperature readings with satellite MODIS/CHIRPS data
    and apply a 14-day Post-Disaster Outbreak Multiplier when NDRRMA BIPAD flood/landslide
    alerts fire in a Palika/Ward.
    """
    _prov, _dist, palika_code, _ward = parse_composite_ward_parts(req.composite_ward_id)

    # Detect valley cloud/shadow bias when ground AWS differs from satellite by >= 15 mm or >= 2.5 C
    rain_diff = abs(req.dhm_ground_rainfall_24h_mm - req.satellite_chirps_rainfall_mm)
    temp_diff = abs(req.dhm_ground_temp_celsius - req.satellite_modis_lst_celsius)
    cloud_bias_corrected = rain_diff >= 15.0 or temp_diff >= 2.5

    # Ground-truth weighted sensor fusion (70% DHM AWS ground station + 30% satellite pass)
    fused_rain = round(
        0.70 * req.dhm_ground_rainfall_24h_mm + 0.30 * req.satellite_chirps_rainfall_mm,
        2,
    )
    fused_temp = round(
        0.70 * req.dhm_ground_temp_celsius + 0.30 * req.satellite_modis_lst_celsius,
        2,
    )

    # Compute 14-day Post-Disaster Outbreak Multiplier
    multiplier = 1.0
    if req.bipad_flood_inundation_alert:
        multiplier += 0.35
    if req.bipad_landslide_alert:
        multiplier += 0.15
    if fused_rain >= 100.0:
        multiplier += 0.15
    multiplier = round(min(1.65, multiplier), 2)

    outbreak_window_days = 14 if multiplier > 1.0 else 0

    # Post-flood receding pools spike Dengue & Malaria; flood-displaced rodents/bush spike Scrub Typhus
    adj_dengue = round(min(100.0, req.baseline_composite_risk * multiplier), 2)
    adj_malaria = round(
        min(100.0, (req.baseline_composite_risk * 0.92 + (12.0 if req.bipad_flood_inundation_alert else 0.0)) * multiplier),
        2,
    )
    adj_scrub = round(
        min(
            100.0,
            (req.baseline_composite_risk * 0.88 + (18.0 if (req.bipad_flood_inundation_alert or req.bipad_landslide_alert) else 0.0))
            * multiplier,
        ),
        2,
    )

    pre_alert_dispatched = False
    if max(adj_dengue, adj_malaria, adj_scrub) >= 70.0 and multiplier > 1.0:
        now_utc = datetime.now(UTC)
        stamp = ad_to_bs_stamp(now_utc)
        esc = EscalationTicket(
            id=str(uuid.uuid4()),
            ticket_code=f"BIPAD-DHM-{uuid.uuid4().hex[:6].upper()}",
            composite_ward_id=req.composite_ward_id,
            palika_code=palika_code,
            reported_by_id=actor_id,
            severity_tier="CRITICAL_2H",
            sla_hours=2,
            category=f"BIPAD_POST_DISASTER_{req.river_corridor}_OUTBREAK_PRE_ALERT",
            summary_sanitized=(
                f"NDRRMA BIPAD + DHM AWS ({req.dhm_aws_station_id}) Post-Disaster Alert in {req.composite_ward_id} "
                f"({req.river_corridor} corridor): Fused rain={fused_rain}mm, temp={fused_temp}C, "
                f"14-day multiplier={multiplier}x. Dengue={adj_dengue}, Malaria={adj_malaria}, ScrubTyphus={adj_scrub}."
            ),
            status="OPEN_PALIKA_CHIEF_PRE_ALERT",
            sla_due_at_utc=now_utc + timedelta(hours=2),
            created_at_utc=now_utc,
            created_at_bs=stamp.bs_combined_label,
        )
        db.add(esc)
        await db.commit()
        pre_alert_dispatched = True

    directive_ne = (
        f"विपद् पूर्व-सूचना ({req.river_corridor} कोरिडोर / {req.dhm_aws_station_id}): "
        f"१४-दिने प्रकोप गुणक {multiplier}x लागू। बाढी पछिको जमेको पानीमा Bti लार्भिसाइड छर्कन र "
        f"स्वास्थ्य चौकीमा स्क्रब टाइफसका लागि Doxycycline तथा NS1/Malaria RDT तयारी अवस्थामा राख्न निर्देशित।"
    )
    directive_en = (
        f"NDRRMA BIPAD & DHM AWS ({req.dhm_aws_station_id}) Post-Disaster Pre-Alert ({req.river_corridor} corridor): "
        f"14-day outbreak multiplier {multiplier}x active. Deploy Bti larviciding in receding flood pools and "
        f"pre-position Doxycycline, ORS, and Dengue/Malaria RDTs at Ward Health Posts within 48 hours."
    )

    return DisasterWeatherFusionResponse(
        composite_ward_id=req.composite_ward_id,
        palika_code=palika_code,
        river_corridor=req.river_corridor,
        dhm_aws_station_id=req.dhm_aws_station_id,
        cloud_shadow_bias_corrected=cloud_bias_corrected,
        fused_rainfall_mm=fused_rain,
        fused_temperature_celsius=fused_temp,
        post_disaster_multiplier=multiplier,
        outbreak_window_days=outbreak_window_days,
        adjusted_dengue_risk=adj_dengue,
        adjusted_malaria_risk=adj_malaria,
        adjusted_scrub_typhus_risk=adj_scrub,
        palika_chief_pre_alert_dispatched=pre_alert_dispatched,
        pre_alert_directive_ne=directive_ne,
        pre_alert_directive_en=directive_en,
    )
