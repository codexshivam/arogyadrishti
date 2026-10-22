# Arogya Drishti (आरोग्य दृष्टि)

**National-Scale Vector-Borne Disease Surveillance, Satellite Bio-Climate Prediction & Autonomous Dispatch DPI**
*Aligned with NCVBDC, ICMR, WHO, IHIP & DPDP Act 2023 Standards*

[![License](https://img.shields.io/badge/License-Apache_2.0-crimson.svg)](LICENSE)
[![Region](https://img.shields.io/badge/GCP_Region-asia--south1_(Mumbai)-blue.svg)](#architecture)
[![Agent Skill](https://img.shields.io/badge/Agent_Skill-Open_Standard_v1.0-indigo.svg)](skills/vector-surveillance-skill/SKILL.md)

---

## Overview

**Arogya Drishti** shrinks the municipal mosquito-control response loop from **10 days on paper to 10 seconds** by combining:
1. **Open-Weight Multimodal AI (`google/gemma-4-12B-it`) + Vertex AI Gemini:** Detects stagnant water breeding containers (`Uncovered Overhead Tank`, `Discarded Tires`, `Cooler`, `Stagnant Drain`, `Algae/Larvae Presence`) and powers a multilingual (English / Hindi / Punjabi) field officer copilot using the standardized [Agent Skill Open Standard](skills/vector-surveillance-skill/SKILL.md).
2. **Live Google Earth Engine (GEE) Satellite Bio-Climate Engine:** Computes trailing 7-day MODIS Land Surface Temperature ($LST_{^\circ C}$), Sentinel-2 10m optical $NDWI$ / $NDVI$ (with automatic Sentinel-1 SAR radar fallback under monsoon cloud cover), and 14-day cumulative CHIRPS precipitation (`rain_14d_mm`).
3. **Scientifically Validated Entomological Indices:** Real-time calculation of WHO / NCVBDC **House Index ($HI\%$)**, **Container Index ($CI\%$)**, and **Breteau Index ($BI$)** with one-tap IHIP Form VC-1/VC-2 CSV & FHIR Bundle export.
4. **Zero-Training Hybrid Municipal Ledger:** Pairs **Cloud Firestore** (offline-first mobile persistence & geohash spatial queries) with a **5-tab Google Sheets v4 Master Workbook** (`1_Vans_Fleet`, `2_Health_Centers`, `3_Staff_Directory`, `4_Van_Requests`, `5_Alert_Logs`), **Google Maps Routes API v2** traffic-aware van dispatch, **Gmail SMTP/API** emergency alerts, and **Open Government Data (OGD) India (`api.data.gov.in`)** fallback directories.

## Composite Epidemiological Risk Formula

$$\text{RiskScore}_{(x,y,t)} = 0.35 \cdot E_{\text{GEE}}(x,y,t) + 0.40 \cdot V_{\text{Field}}(x,y,t) + 0.25 \cdot I_{\text{Vision}}(x,y,t)$$

---

## Repository Structure

```text
arogya-drishti/
├── LICENSE                                  # Apache-2.0 License
├── README.md                                # Architecture, DPI compliance & setup guide
├── SECURITY.md                              # DPDP Act 2023, CERT-In & OWASP MASVS policy
├── docker-compose.yml                       # Local & Cloud Run container orchestration
├── skills/
│   └── vector-surveillance-skill/           # Open-Source Agent Skill (Bonus Challenge)
│       ├── SKILL.md
│       ├── schema.json
│       └── harness/
│           ├── __init__.py
│           ├── gemma_agent_harness.py
│           └── skill_executor.py
├── backend/                                 # FastAPI Backend (Google Cloud Run asia-south1)
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app/
│       ├── main.py
│       ├── core/
│       │   ├── config.py
│       │   ├── security.py
│       │   └── exceptions.py
│       └── tools/
│           ├── gee_climate_tool/
│           ├── sheets_admin_tool/
│           ├── maps_routing_tool/
│           ├── gmail_alert_tool/
│           ├── vision_paligemma_tool/
│           └── ogd_india_gov_tool/
└── flutter_app/                             # Flutter Client (Android, iOS, Web)
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── core/
        └── features/                        # All 10 production screens
```

## Quick Start

1. Copy `.env.example` to `backend/.env` and populate your credentials (or mount via Secret Manager in Cloud Run).
2. Run the backend locally:
   ```bash
   cd backend
   ../.venv/bin/uvicorn app.main:app --reload --port 8080
   ```
3. Run the Flutter client:
   ```bash
   cd flutter_app
   flutter run
   ```
