# NidanIQ — Nepal Sovereign Vector Surveillance & Early Warning DPI Architecture

## 1. Sovereign Mission & Scope
NidanIQ is a standalone, production-grade **FastAPI (Python 3.12+)** Digital Public Infrastructure (DPI) backend built exclusively for the **Government of Nepal**:
- **Ministry of Health and Population (MoHP)**
- **Epidemiology and Disease Control Division (EDCD Teku, Kathmandu)**
- **753 Local Levels / Palikas** (*Mahanagarpalika, Upamahanagarpalika, Nagarpalika, Gaunpalika*) across **7 Provinces** and **77 Districts**, starting with all **32 Wards of Kathmandu Metropolitan City (`palika_code="30608"`)**.

## 2. Core Architectural Pillars

### A. 4-Tier Federal Administrative Hierarchy (MoFAGA / NSO)
`Province (1–7)` → `District (77)` → `Palika / Local Level (753)` → `Ward (6,743 wards)`, keyed by canonical `composite_ward_id` (e.g., `NP-P3-D27-30608-W17`).

### B. Bikram Sambat (BS) & NPT Temporal Standard
All database records, audit trails, municipal ledgers, and API responses carry dual-date representations in `Asia/Kathmandu` (`UTC+05:45`, NPT) and **Bikram Sambat (`nepali-datetime`)** alongside BS date formatting (`2083 Kartik 9`). Daily fusion executes at `06:00 AM NPT` (`00:15 UTC`).

### C. Himalayan & Valley Terrain-Corrected Satellite Pipeline
Uses `NASA/NASADEM_HGT/001` (30m DEM) to compute terrain slope (`< 8.0°`) for Sentinel-1 C-band SAR standing-water detection (`VV < -16.5 dB`), preventing steep hill-shadow false positives, combined with the Altitude Biological Viability Curve ($V_{\text{elev}}$) for *Aedes aegypti* and *Aedes albopictus* up to `2,300m`.

### D. EDCD "Khoj Ra Nashta Gar" (*Search & Destroy Protocol*)
Prioritizes Rapid Response Team (RRT) physical source reduction and biological larviciding (*Bti* WP/granules and *Temephos 50% EC*), while gating focal ULV space-spraying behind `palika_health_chief` cryptographic sign-off, confirmed EWARS clinical transmission, and `BI >= 30`.
