---
name: arogya-drishti-vector-surveillance
version: 1.0.0
license: Apache-2.0
author: Team Rocket (Chandigarh University)
repository: https://github.com/codexshivam/arogyadrishti
homepage: https://arogyadrishti.in
models:
  - google/gemma-4-26b-it
  - google/gemma-4-4b
  - google/gemma-2-9b-it
  - gemini-3.8-flash
keywords:
  - gemma-4
  - open-weight-ai
  - ncvbdc
  - epidemiology
  - vector-surveillance
  - dengue-control
  - smart-governance
description: Autonomous epidemiological agent skill for vector-borne disease triage, micro-climate GEE extraction, and municipal fogging van dispatch conforming to the Agent Skill Open Standard and powered by open-weight Gemma 4.
---

# Arogya Drishti — Vector Surveillance & Autonomous Triage Agent Skill

**Compliant with the Agent Skill Open Standard | Licensed under Apache 2.0 | Powered by Open-Weight Gemma 4**
*Repository: [https://github.com/codexshivam/arogyadrishti](https://github.com/codexshivam/arogyadrishti)*
*License: [Apache License, Version 2.0](../../LICENSE)*

This Agent Skill equips open-weight foundational models (**Gemma 4 26B-IT** and **Gemma 4 4B**), open-weight vision-language models (**PaliGemma 3B**), and sovereign cloud models (**Gemini 3.8 Flash**) with deterministic tool execution and NCVBDC/WHO epidemiological protocols for Indian municipal sanitary inspectors, district nodal officers, and frontline ASHA health workers.

---

## 1. Executable Tools (`schema.json`)

Always invoke one or more of the following four tools before answering questions about live ward risk, weather suitability, or municipal dispatch:

1. **`query_gee_microclimate(lat, lng)`**
   - Queries Google Earth Engine (`MODIS/061/MOD11A1` LST, `COPERNICUS/S2_SR_HARMONIZED` NDWI/NDVI with `COPERNICUS/S1_GRD` SAR radar fallback, and `UCSB-CHG/CHIRPS/DAILY` 14-day cumulative rainfall).
   - Use whenever an officer asks about weather, temperature, standing water, or climate risk at a coordinate.

2. **`compute_ward_entomological_indices(lgd_code)`**
   - Aggregates live Cloud Firestore `field_logs` for the specified Local Government Directory (`lgd_code`, e.g., `"0404400017"` for Ward 17 Sector 22 Chandigarh or `"0404400014"` for Ward 14 Dhanas) and computes:
     - **House Index ($HI\%$):** $\frac{\text{Infested Houses}}{\text{Inspected Houses}} \times 100$
     - **Container Index ($CI\%$):** $\frac{\text{Positive Containers}}{\text{Inspected Containers}} \times 100$
     - **Breteau Index ($BI$):** $\frac{\text{Positive Containers}}{\text{Inspected Houses}} \times 100$

3. **`dispatch_fogging_van(ward_village, lat, lng, notes)`**
   - Reads available municipal fogging vans from `1_Vans_Fleet` in the Master Google Sheet, computes traffic-aware optimal routing via Google Maps Routes API v2, marks the selected van `Dispatched`, and appends an audit row to `4_Van_Requests`.

4. **`trigger_emergency_ward_alert(ward_village, lat, lng, severity_notes)`**
   - Resolves the pre-authorized Village Officer and District Nodal Representative from `3_Staff_Directory` (or `api.data.gov.in` OGD directory), validates MX records, dispatches a structured HTML emergency email, and appends an audit row to `5_Alert_Logs`.

---

## 2. NCVBDC Larvicidal & Adulticidal Chemical Dosage Lookup Table

When advising field officers in English, Hindi, Hinglish, or Punjabi, quote the exact **National Center for Vector Borne Disease Control (NCVBDC)** dosage:

| Chemical Formulation | Target Habitat | Standard NCVBDC Dosage | Dilution & Field Application Protocol |
|---|---|---|---|
| **Temephos 50% EC** | Potable/domestic overhead tanks, desert coolers, curing tanks | **1 ppm** active ingredient | **1 ml of Temephos 50% EC per 1,000 Liters** of water (or create a stock solution of 2.5 ml in 1 L water and apply 400 ml per 1,000 L). Re-apply every 14 days. |
| **Bacillus thuringiensis israelensis (Bti) 5% WP** | Non-potable stagnant drains, construction pits, marshy pools | **0.5 g per m²** of water surface | Suspend **10 g of Bti WP in 1 L water** and spray **20 ml per m²** of water surface area. |
| **Bti Granules / Briquets** | Perifocal tires, ornamental ponds, clogged rainwater channels | **5–10 g per m²** | Broadcast uniformly over stagnant water surface; effective for 2–3 weeks. |
| **Pyrethrum Extract 2% (Indoor Space Spray)** | Immediate 100m household perimeter around Dengue/Malaria positive cases | **1:19 dilution** in deodorized kerosene | Mix **1 part Pyrethrum 2% extract with 19 parts kerosene** (0.1% ready-to-use solution); fog @ 30–60 ml per 100 m³ indoor volume. |
| **Malathion 95% Technical (ULV Thermal Fogging)** | Outdoor municipal sector-wide vector suppression ($BI > 20$) | **0.5 L per hectare** | Vehicle-mounted ULV / thermal fogger operating at 8–10 km/h during dawn/dusk wind $< 10\text{ km/h}$. |

---

## 3. WHO & NCVBDC Entomological Threshold Interpretation Rules

| Index | Low / Safe | Moderate Vigilance | High / Epidemic Action Required | Mandatory Intervention |
|---|---|---|---|---|
| **House Index ($HI\%$)** | $< 1.0\%$ | $1.0\% - 5.0\%$ | **$> 5.0\%$ (Critical Outbreak)** | Immediate house-to-house larval source reduction + Temephos 1 ppm. |
| **Container Index ($CI\%$)** | $< 5.0\%$ | $5.0\% - 10.0\%$ | **$> 10.0\%$ (Severe Level)** | Puncture/drain discarded tires, cover overhead tanks, apply Bti. |
| **Breteau Index ($BI$)** | $< 5.0$ | $5.0 - 20.0$ | **$> 20.0$ (Priority Fogging)** / **$> 50.0$ (Epidemic Zone)** | Invoke `dispatch_fogging_van` and `trigger_emergency_ward_alert` immediately. |

---

## 4. Open-Weight Model Orchestration & Sandboxed Execution

The skill is executed through [`harness/gemma_agent_harness.py`](harness/gemma_agent_harness.py) and [`harness/skill_executor.py`](harness/skill_executor.py):
* **Self-Hosted / Edge Deployment:** Gemma 4 open-weight weights running via vLLM, Ollama, or llama.cpp in local municipal environments with zero cloud egress.
* **Deterministic Sandboxing:** Tool calls undergo strict allow-list validation and parameter type casting against [`schema.json`](schema.json) before touching databases or external gateways.
* **Full Open-Source License:** Released under the [Apache License, Version 2.0](../../LICENSE) as part of the public Arogya Drishti repository.
