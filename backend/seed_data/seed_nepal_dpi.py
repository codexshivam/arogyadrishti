"""Idempotent database seeder for Government of Nepal Sovereign Vector Surveillance DPI."""

from __future__ import annotations

import asyncio
import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.bs_calendar import ad_to_bs_stamp
from app.core.rbac import NepalStaffRole
from app.core.security import (
    encrypt_field_aes256gcm,
    hash_nepal_phone,
    hash_secret_argon2id,
    normalize_nepal_phone,
)
from app.db.models import (
    AdminBoundaryWard,
    HealthFacility,
    RrtVehicleUnit,
    StaffUser,
    WardRiskDaily,
)
from app.db.session import get_session_factory, init_db_schema_and_triggers

_SEED_DIR = Path(__file__).resolve().parent

# Pre-authorized Nepal Public Health Staff Roster across all 4 roles (+977 NTC & Ncell)
SEED_STAFF_ROSTER: list[dict[str, Any]] = [
    {
        "id": "staff-fchv-kmc-w17",
        "phone": "+9779841000017",
        "full_name": "Sita Maharjan",
        "full_name_ne": "सीता महर्जन (महिला सामुदायिक स्वास्थ्य स्वयंसेविका)",
        "designation": "Female Community Health Volunteer (FCHV — Ward 17 Chhetrapati)",
        "role": NepalStaffRole.FCHV.value,
        "province_code": 3,
        "district_code": 27,
        "palika_code": "30608",
        "assigned_wards": ["NP-P3-D27-30608-W17"],
        "pin": "208317",
    },
    {
        "id": "staff-fchv-kmc-w12",
        "phone": "+9779841000012",
        "full_name": "Ganga Shrestha",
        "full_name_ne": "गंगा श्रेष्ठ (महिला सामुदायिक स्वास्थ्य स्वयंसेविका)",
        "designation": "Female Community Health Volunteer (FCHV — Ward 12 Teku)",
        "role": NepalStaffRole.FCHV.value,
        "province_code": 3,
        "district_code": 27,
        "palika_code": "30608",
        "assigned_wards": ["NP-P3-D27-30608-W12"],
        "pin": "208312",
    },
    {
        "id": "staff-who-kmc-w17",
        "phone": "+9779851000017",
        "full_name": "Ramesh Tuladhar",
        "full_name_ne": "रमेश तुलाधर (वार्ड स्वास्थ्य प्रमुख - वडा १७)",
        "designation": "Senior Health Assistant (HA) — KMC Ward 17 UHPC Chhetrapati",
        "role": NepalStaffRole.WARD_HEALTH_OFFICER.value,
        "province_code": 3,
        "district_code": 27,
        "palika_code": "30608",
        "assigned_wards": ["NP-P3-D27-30608-W17"],
        "pin": "208301",
    },
    {
        "id": "staff-who-kmc-w10",
        "phone": "+9779851000010",
        "full_name": "Bikash Adhikari",
        "full_name_ne": "विकास अधिकारी (वार्ड स्वास्थ्य प्रमुख - वडा १०)",
        "designation": "Health Assistant (HA) — KMC Ward 10 UHPC Baneshwor",
        "role": NepalStaffRole.WARD_HEALTH_OFFICER.value,
        "province_code": 3,
        "district_code": 27,
        "palika_code": "30608",
        "assigned_wards": ["NP-P3-D27-30608-W10"],
        "pin": "208310",
    },
    {
        "id": "staff-who-lmc-w03",
        "phone": "+9779851000303",
        "full_name": "Sushila Shakya",
        "full_name_ne": "सुशीला शाक्य (वार्ड स्वास्थ्य प्रमुख - ललितपुर वडा ३)",
        "designation": "Ward Health Officer — Lalitpur Metro Ward 3 Pulchowk",
        "role": NepalStaffRole.WARD_HEALTH_OFFICER.value,
        "province_code": 3,
        "district_code": 28,
        "palika_code": "30805",
        "assigned_wards": ["NP-P3-D28-30805-W03"],
        "pin": "208303",
    },
    {
        "id": "staff-chief-kmc-30608",
        "phone": "+9779851130608",
        "full_name": "Dr. Prakash Poudel",
        "full_name_ne": "डा. प्रकाश पौडेल (जनस्वास्थ्य महाशाखा प्रमुख - का.म.न.पा.)",
        "designation": "Chief, Public Health Department (Jan Swasthya Bibhag) — Kathmandu Metropolitan City",
        "role": NepalStaffRole.PALIKA_HEALTH_CHIEF.value,
        "province_code": 3,
        "district_code": 27,
        "palika_code": "30608",
        "assigned_wards": [f"NP-P3-D27-30608-W{w:02d}" for w in range(1, 33)],
        "pin": "306080",
    },
    {
        "id": "staff-nodal-edcd-teku",
        "phone": "+9779851201115",
        "full_name": "Dr. Gokarna Dahal",
        "full_name_ne": "डा. गोकर्ण दाहाल (इपिडिमियोलोजी तथा रोग नियन्त्रण महाशाखा, टेकु)",
        "designation": "Chief Nodal Epidemiologist — Vector Borne Disease Control Section, EDCD Teku",
        "role": NepalStaffRole.EDCD_NODAL.value,
        "province_code": 3,
        "district_code": 27,
        "palika_code": "30608",
        "assigned_wards": ["*"],
        "pin": "111500",
    },
]

# 6 Government Rapid Response Team (RRT) Vehicles with BA-2-JHA-... Government Plates
SEED_RRT_FLEET: list[dict[str, Any]] = [
    {
        "vehicle_id": "RRT-KMC-01",
        "plate_number": "BA-2-JHA-4101",
        "palika_code": "30608",
        "base_ward_id": "NP-P3-D27-30608-W12",
        "team_lead_name": "Hari Bahadur Thapa",
        "team_lead_name_ne": "हरि बहादुर थापा (आर.आर.टी. टेकु)",
        "driver_phone": "+9779841224101",
        "bti_stock_kg": 45.0,
        "temephos_stock_liters": 25.0,
        "ulv_equipment_mounted": True,
        "status": "AVAILABLE",
        "base_lat": 27.6948,
        "base_lng": 85.3049,
    },
    {
        "vehicle_id": "RRT-KMC-02",
        "plate_number": "BA-2-JHA-4102",
        "palika_code": "30608",
        "base_ward_id": "NP-P3-D27-30608-W17",
        "team_lead_name": "Subash Manandhar",
        "team_lead_name_ne": "सुवास मानन्धर (आर.आर.टी. क्षेत्रपाटी)",
        "driver_phone": "+9779841224102",
        "bti_stock_kg": 38.0,
        "temephos_stock_liters": 20.0,
        "ulv_equipment_mounted": True,
        "status": "AVAILABLE",
        "base_lat": 27.7124,
        "base_lng": 85.3065,
    },
    {
        "vehicle_id": "RRT-KMC-03",
        "plate_number": "BA-2-JHA-4103",
        "palika_code": "30608",
        "base_ward_id": "NP-P3-D27-30608-W10",
        "team_lead_name": "Dipak Karki",
        "team_lead_name_ne": "दिपक कार्की (आर.आर.टी. बानेश्वर)",
        "driver_phone": "+9779841224103",
        "bti_stock_kg": 42.0,
        "temephos_stock_liters": 18.0,
        "ulv_equipment_mounted": False,
        "status": "AVAILABLE",
        "base_lat": 27.6915,
        "base_lng": 85.3368,
    },
    {
        "vehicle_id": "RRT-KMC-04",
        "plate_number": "BA-2-JHA-4104",
        "palika_code": "30608",
        "base_ward_id": "NP-P3-D27-30608-W16",
        "team_lead_name": "Nabin Gurung",
        "team_lead_name_ne": "नवीन गुरुङ (आर.आर.टी. बालाजु)",
        "driver_phone": "+9779841224104",
        "bti_stock_kg": 50.0,
        "temephos_stock_liters": 30.0,
        "ulv_equipment_mounted": True,
        "status": "AVAILABLE",
        "base_lat": 27.7285,
        "base_lng": 85.3012,
    },
    {
        "vehicle_id": "RRT-KMC-05",
        "plate_number": "BA-2-JHA-4105",
        "palika_code": "30608",
        "base_ward_id": "NP-P3-D27-30608-W32",
        "team_lead_name": "Rajendra Khadka",
        "team_lead_name_ne": "राजेन्द्र खड्का (आर.आर.टी. कोटेश्वर)",
        "driver_phone": "+9779841224105",
        "bti_stock_kg": 36.0,
        "temephos_stock_liters": 15.0,
        "ulv_equipment_mounted": False,
        "status": "AVAILABLE",
        "base_lat": 27.6782,
        "base_lng": 85.3498,
    },
    {
        "vehicle_id": "RRT-LMC-06",
        "plate_number": "BA-2-JHA-4106",
        "palika_code": "30805",
        "base_ward_id": "NP-P3-D28-30805-W03",
        "team_lead_name": "Kiran Maharjan",
        "team_lead_name_ne": "किरण महर्जन (आर.आर.टी. पुल्चोक ललितपुर)",
        "driver_phone": "+9779841224106",
        "bti_stock_kg": 40.0,
        "temephos_stock_liters": 22.0,
        "ulv_equipment_mounted": True,
        "status": "AVAILABLE",
        "base_lat": 27.6784,
        "base_lng": 85.3168,
    },
]


async def seed_nepal_sovereign_data(session: AsyncSession) -> dict[str, int]:
    """Idempotently seed all 32 KMC wards + sample Palikas, NHFR facilities, RRT fleet, and staff directory."""
    now_utc = datetime.now(UTC)
    stamp = ad_to_bs_stamp(now_utc)
    today_ad = now_utc.strftime("%Y-%m-%d")

    # 1. Seed Wards from kmc_32_wards_geojson.json
    geojson_path = _SEED_DIR / "kmc_32_wards_geojson.json"
    fc = json.loads(geojson_path.read_text(encoding="utf-8"))
    wards_seeded = 0
    risks_seeded = 0

    for feat in fc.get("features", []):
        props = feat["properties"]
        comp_id = str(props["composite_ward_id"])
        existing_ward = (
            await session.execute(
                select(AdminBoundaryWard).where(
                    AdminBoundaryWard.composite_ward_id == comp_id
                )
            )
        ).scalar_one_or_none()

        if existing_ward is None:
            ward_obj = AdminBoundaryWard(
                composite_ward_id=comp_id,
                province_code=int(props["province_code"]),
                province_name=str(props["province_name"]),
                district_code=int(props["district_code"]),
                district_name=str(props["district_name"]),
                palika_code=str(props["palika_code"]),
                palika_name=str(props["palika_name"]),
                palika_type=str(props["palika_type"]),
                ward_number=int(props["ward_number"]),
                locality_name=str(props["locality_name"]),
                locality_name_ne=str(props["locality_name_ne"]),
                mean_elevation_m=float(props["mean_elevation_m"]),
                centroid_lat=float(props["centroid_lat"]),
                centroid_lng=float(props["centroid_lng"]),
                dhis2_org_unit_uid=str(props["dhis2_org_unit_uid"]),
                geojson_str=json.dumps(feat["geometry"]),
                geom=None,
                updated_at_utc=now_utc,
                updated_at_bs=stamp.bs_combined_label,
            )
            session.add(ward_obj)
            wards_seeded += 1

        # Seed initial daily risk snapshot for each ward
        existing_risk = (
            await session.execute(
                select(WardRiskDaily).where(
                    WardRiskDaily.composite_ward_id == comp_id
                )
            )
        ).scalar_one_or_none()
        if existing_risk is None:
            w_num = int(props["ward_number"])
            is_hotspot = w_num in {10, 12, 14, 16, 17, 26, 32}
            bi = 34.5 if w_num in {12, 16, 17} else (24.0 if is_hotspot else 11.5)
            hi = round(bi * 0.42, 2)
            ci = round(bi * 0.55, 2)
            ppi = 1.45 if is_hotspot else 0.35
            comp_score = 78.4 if w_num in {12, 16, 17} else (58.2 if is_hotspot else 22.4)
            tier = (
                "CRITICAL_TIER_1"
                if comp_score >= 75.0
                else ("HIGH" if comp_score >= 50.0 else "SAFE")
            )
            ewars_cases = 14 if w_num in {12, 16, 17} else (4 if is_hotspot else 0)

            risk_row = WardRiskDaily(
                id=f"risk-{comp_id}-{today_ad}",
                composite_ward_id=comp_id,
                palika_code=str(props["palika_code"]),
                fusion_date_ad=today_ad,
                fusion_date_bs=stamp.bs_combined_label,
                house_index_hi=hi,
                container_index_ci=ci,
                breteau_index_bi=bi,
                pupae_per_person_ppi=ppi,
                sar_water_score=82.0 if is_hotspot else 25.0,
                gee_climate_score=76.0 if is_hotspot else 30.0,
                field_entomology_score=80.0 if is_hotspot else 20.0,
                historical_zscore=68.0 if is_hotspot else 15.0,
                nepali_news_nlp_score=74.0 if is_hotspot else 10.0,
                elevation_viability_factor=1.0,
                composite_risk_score=comp_score,
                risk_tier=tier,
                ewars_confirmed_cases=ewars_cases,
                lst_celsius=27.2,
                rainfall_14d_mm=142.5 if is_hotspot else 64.0,
                ndwi=0.31 if is_hotspot else 0.12,
                slope_deg=3.4,
                computed_at_utc=now_utc,
                computed_at_bs=stamp.bs_combined_label,
            )
            session.add(risk_row)
            risks_seeded += 1

    # 2. Seed NHFR Facilities
    nhfr_path = _SEED_DIR / "nhfr_sample_facilities.json"
    facilities_data = json.loads(nhfr_path.read_text(encoding="utf-8"))
    facilities_seeded = 0
    for fac in facilities_data:
        fac_id = str(fac["facility_id"])
        existing_fac = (
            await session.execute(
                select(HealthFacility).where(HealthFacility.facility_id == fac_id)
            )
        ).scalar_one_or_none()
        if existing_fac is None:
            session.add(
                HealthFacility(
                    facility_id=fac_id,
                    nhfr_code=str(fac["nhfr_code"]),
                    name_en=str(fac["name_en"]),
                    name_ne=str(fac["name_ne"]),
                    facility_type=str(fac["facility_type"]),
                    palika_code=str(fac["palika_code"]),
                    composite_ward_id=str(fac["composite_ward_id"]),
                    latitude=float(fac["latitude"]),
                    longitude=float(fac["longitude"]),
                    elevation_m=float(fac["elevation_m"]),
                    has_24x7_fever_clinic=bool(fac["has_24x7_fever_clinic"]),
                    ns1_elisa_available=bool(fac["ns1_elisa_available"]),
                    rapid_diagnostic_kit_stock=int(fac["rapid_diagnostic_kit_stock"]),
                    emergency_phone=str(fac["emergency_phone"]),
                    hello_swasthya_hotline=str(fac["hello_swasthya_hotline"]),
                    geom=None,
                )
            )
            facilities_seeded += 1

    # 3. Seed Whitelisted Staff Accounts
    staff_seeded = 0
    for staff in SEED_STAFF_ROSTER:
        norm_phone = normalize_nepal_phone(str(staff["phone"]))
        p_hash = hash_nepal_phone(norm_phone)
        existing_staff = (
            await session.execute(
                select(StaffUser).where(StaffUser.phone_hash == p_hash)
            )
        ).scalar_one_or_none()
        if existing_staff is None:
            session.add(
                StaffUser(
                    id=str(staff["id"]),
                    phone_hash=p_hash,
                    phone_encrypted=encrypt_field_aes256gcm(norm_phone),
                    full_name=str(staff["full_name"]),
                    full_name_ne=str(staff["full_name_ne"]),
                    designation=str(staff["designation"]),
                    role=str(staff["role"]),
                    province_code=int(staff["province_code"]),
                    district_code=int(staff["district_code"]),
                    palika_code=str(staff["palika_code"]),
                    assigned_wards_json=json.dumps(staff["assigned_wards"]),
                    pin_hash=hash_secret_argon2id(str(staff["pin"])),
                    is_active=True,
                    created_at_utc=now_utc,
                    created_at_bs=stamp.bs_combined_label,
                )
            )
            staff_seeded += 1

    # 4. Seed RRT Vehicle Units
    rrt_seeded = 0
    for rrt in SEED_RRT_FLEET:
        v_id = str(rrt["vehicle_id"])
        existing_rrt = (
            await session.execute(
                select(RrtVehicleUnit).where(RrtVehicleUnit.vehicle_id == v_id)
            )
        ).scalar_one_or_none()
        if existing_rrt is None:
            session.add(
                RrtVehicleUnit(
                    vehicle_id=v_id,
                    plate_number=str(rrt["plate_number"]),
                    palika_code=str(rrt["palika_code"]),
                    base_ward_id=str(rrt["base_ward_id"]),
                    team_lead_name=str(rrt["team_lead_name"]),
                    team_lead_name_ne=str(rrt["team_lead_name_ne"]),
                    driver_phone=str(rrt["driver_phone"]),
                    bti_stock_kg=float(rrt["bti_stock_kg"]),
                    temephos_stock_liters=float(rrt["temephos_stock_liters"]),
                    ulv_equipment_mounted=bool(rrt["ulv_equipment_mounted"]),
                    status=str(rrt["status"]),
                    base_lat=float(rrt["base_lat"]),
                    base_lng=float(rrt["base_lng"]),
                    updated_at_bs=stamp.bs_combined_label,
                )
            )
            rrt_seeded += 1

    await session.flush()
    return {
        "wards_seeded": wards_seeded,
        "risks_seeded": risks_seeded,
        "facilities_seeded": facilities_seeded,
        "staff_seeded": staff_seeded,
        "rrt_units_seeded": rrt_seeded,
    }


async def _main() -> None:
    await init_db_schema_and_triggers()
    factory = get_session_factory()
    async with factory() as session:
        summary = await seed_nepal_sovereign_data(session)
        await session.commit()
        print("Nepal Sovereign DPI Seed Summary:", json.dumps(summary, indent=2))


if __name__ == "__main__":
    asyncio.run(_main())
