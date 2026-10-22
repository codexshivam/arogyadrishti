# Master Architectural Prompt for AI Coding Agent

## ROLE & OBJECTIVE

You are a Principal Full-Stack Architect, Epidemiological Data Systems Engineer, and Google Cloud Infrastructure Specialist. Build **Arogya Drishti**, a production-ready, national-scale Digital Public Infrastructure (DPI) application for the Government of India (aligned with NCVBDC, ICMR, and IHIP standards) to predict, track, and eliminate mosquito-borne diseases (Dengue, Malaria, Chikungunya, Japanese Encephalitis).

## STRICT NON-NEGOTIABLE GUARDRAILS (ZERO MOCK DATA POLICY)

1. **NO DEMO OR MOCK DATA:** You are strictly forbidden from using hardcoded JSON arrays, dummy coordinates, `Future.delayed()` fake network simulations, placeholder text, or mock responses. Every screen, chart, list, and action MUST query live Cloud Firestore collections, live Google Sheets API v4 ranges, live Google Earth Engine (GEE) satellite bands, live Google Maps Routes API, or live Open Government Data (OGD) India REST APIs (`api.data.gov.in`).

2. **MODULAR TOOL ISOLATION:** Every backend and AI tool must reside in its own dedicated directory with its own schema validation, exponential backoff retry logic, structured logging, and comprehensive error handling.

3. **GOVERNMENT OF INDIA SECURITY & DPI COMPLIANCE:**

   * **Data Sovereignty:** Pin all Google Cloud, Firebase, Vertex AI, and Cloud Storage resources to `asia-south1` (Mumbai) or `asia-south2` (Delhi).

   * **DPDP Act 2023 Compliance:** Implement automatic PII/face/license-plate redaction via Google Cloud DLP / Vision SafeSearch before persisting any field scan images to Cloud Storage. Never store citizen names—only aggregate household/container counts and official Local Government Directory (`lgd_code`) identifiers.

   * **CERT-In & OWASP MASVS:** Enforce Firebase Phone Auth OTP bound to pre-authorized staff records in Google Sheets via Custom JWT Claims, TLS 1.3 with certificate pinning in Flutter, and Cloud Armor rate-limiting headers on public endpoints.

   * **IHIP / WHO Scientific Formulas:** All entomological indices (House Index, Container Index, Breteau Index) must be mathematically computed from real field logs and exportable in NCVBDC VC-1/VC-2 FHIR-compatible CSV/JSON formats.

## 1. REPOSITORY & FOLDER ARCHITECTURE

Generate the complete monorepo with the following strict directory tree:

```
arogya-drishti/
├── LICENSE                                  # Apache-2.0 License (Required for Bonus Open-Source AI Prize)
├── README.md                                # Setup, architecture, DPI compliance, and deployment guide
├── docker-compose.yml                       # Local & Cloud Run orchestration
├── skills/                                  # BONUS CHALLENGE: Agent Skill Open Standard
│   └── vector-surveillance-skill/
│       ├── SKILL.md                         # Standardized Agent Skill specification & metadata
│       ├── schema.json                      # OpenAPI 3.1 / JSON Schema tool declarations
│       └── harness/
│           ├── __init__.py
│           ├── gemma_agent_harness.py       # Open-weight Gemma-2-9B-IT & PaliGemma-3B tool execution loop
│           └── skill_executor.py            # Sandboxed dispatcher connecting Agent Skill to backend tools
├── backend/                                 # Python 3.11 FastAPI Backend (Deployed on Google Cloud Run)
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app/
│   │   ├── main.py                          # FastAPI entry point, CORS, Cloud Armor & JWT middleware
│   │   ├── core/
│   │   │   ├── config.py                    # Pydantic BaseSettings validating all env vars at startup
│   │   │   ├── security.py                  # Firebase Admin JWT verification & DPDP PII scrubber
│   │   │   └── exceptions.py                # Standardized RFC 7807 Problem Details exception handlers
│   │   └── tools/                           # STRICTLY SEPARATED FOLDERS FOR EACH TOOL
│   │       ├── gee_climate_tool/
│   │       │   ├── __init__.py
│   │       │   ├── client.py                # Live Google Earth Engine MODIS, Sentinel-2 NDWI/NDVI, CHIRPS
│   │       │   └── exceptions.py
│   │       ├── sheets_admin_tool/
│   │       │   ├── __init__.py
│   │       │   ├── client.py                # Google Sheets API v4 (Vans, Centers, Staff, Dispatches)
│   │       │   └── exceptions.py
│   │       ├── maps_routing_tool/
│   │       │   ├── __init__.py
│   │       │   ├── client.py                # Google Maps Routes API v2 (Traffic-aware Van ETA & Polylines)
│   │       │   └── exceptions.py
│   │       ├── gmail_alert_tool/
│   │       │   ├── __init__.py
│   │       │   ├── client.py                # Gmail API / SMTP TLS automated HTML emergency dispatch
│   │       │   └── exceptions.py
│   │       ├── vision_paligemma_tool/
│   │       │   ├── __init__.py
│   │       │   ├── client.py                # PaliGemma-3B + Vertex AI Gemini Vision breeding site analyzer
│   │       │   └── exceptions.py
│   │       └── ogd_india_gov_tool/
│   │           ├── __init__.py
│   │           ├── client.py                # data.gov.in OGD API & LGD directory sync for PHCs & District Reps
│   │           └── exceptions.py
└── flutter_app/                             # Flutter 3.24+ Production Client (Android, iOS, Web)
    ├── pubspec.yaml
    ├── lib/
    │   ├── main.dart                        # Firebase initialization, Firestore offline persistence, GoRouter
    │   ├── core/
    │   │   ├── theme/app_theme.dart         # Crimson/White #8B0000 & #D32F2F medical theme ("Arogya Drishti")
    │   │   ├── network/api_client.dart      # Dio client with Firebase JWT interceptor & retry policy
    │   │   └── services/firestore_sync.dart # Offline-first Firestore settings & real-time stream providers
    │   └── features/
    │       ├── auth/                        # Screen 6: Officer Sign-In & OTP Verification
    │       ├── home/                        # Screen 1: Dashboard, Quick Actions, Field Vector Form & Modals
    │       ├── chat/                        # Screen 2: Multilingual Gemma-2 / Vertex AI Officer Copilot
    │       ├── stats/                       # Screen 3: HI, CI, BI Scientific Calculations & IHIP CSV Export
    │       ├── map/                         # Screen 4: Google Maps GIS Heatmap, Ward Polygons & Hotspots
    │       ├── settings/                    # Screen 5: Offline Cache Controls, Bhashini Localization, Legal
    │       ├── support/                     # Screen 7: 108/104 Hotlines, Escalation Tickets, District Rep Directory
    │       ├── centers/                     # Screen 8: Live PHC/CHC Directory (Google Sheets + OGD API)
    │       ├── vans/                        # Screen 9: Live Fogging Van Telemetry, Driver Call & Maps ETA
    │       └── scan/                        # Screen 10: AI Vector Site Camera Scanner + GEE Environmental Overlay

```

## 2. BACKEND TOOLS SPECIFICATION (SEPARATE FOLDERS, REAL LOGIC & ERROR HANDLING)

Implement each tool inside `backend/app/tools/<tool_name>/client.py` using `tenacity` for exponential backoff (`@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))`), strict Pydantic input/output models, and custom exceptions that return actionable HTTP status codes.

### Tool 1: `sheets_admin_tool` (Google Sheets API v4 Live Ledger)

* **Purpose:** Connects to the master Google Spreadsheet (`MASTER_SPREADSHEET_ID`) containing 5 live tabs: `1_Vans_Fleet`, `2_Health_Centers`, `3_Staff_Directory`, `4_Van_Requests`, and `5_Alert_Logs`.

* **Logic:**

  * `get_vans_fleet(ward_or_district)`: Reads `1_Vans_Fleet` and returns all vans with live `Vehicle_No`, `Driver_Name`, `Driver_Phone`, `Base_Lat`, `Base_Lng`, `Status` (`Available` / `Dispatched`), and `Chemical_Stock`.

  * `get_health_centers(lat, lng, radius_km)`: Reads `2_Health_Centers`, calculates Haversine distance from the officer's coordinates, and merges with live `ogd_india_gov_tool` records.

  * `lookup_authorized_staff(ward_village, district_lgd)`: Queries `3_Staff_Directory` by exact `LGD_Code` or normalized `Ward_or_Village` to retrieve `Village_Officer_Email`, `Village_Officer_Phone`, `District_Rep_Name`, `District_Rep_Phone`, and `District_Rep_Email`. If missing from the sheet, automatically falls back to `ogd_india_gov_tool` (`api.data.gov.in` district health nodal directory).

  * `log_van_request(...)` & `log_alert_dispatch(...)`: Appends verified dispatch rows to `4_Van_Requests` and `5_Alert_Logs` using atomic batch updates and updates the assigned van's `Status` cell in `1_Vans_Fleet` to `Dispatched`.

* **Error Handling:** Catch `gspread.exceptions.APIError` (e.g., HTTP 429 quota exceeded or 403 permission denied), log structured stack traces, and raise `SheetsIntegrationException` with retry headers.

### Tool 2: `gee_climate_tool` (Google Earth Engine Satellite Bio-Climate Engine)

* **Purpose:** Computes real-time entomological climate suitability for any `(latitude, longitude)` in India using official Earth Engine datasets.

* **Logic:**

  * Authenticate via Service Account (`ee.ServiceAccountCredentials`).

  * Query `MODIS/061/MOD11A1` over the trailing 7 days to compute Land Surface Temperature in Celsius: $LST_{^\circ C} = (\text{LST\_Day\_1km} \times 0.02) - 273.15$.

  * Query `COPERNICUS/S2_SR_HARMONIZED` (filtering cloudy pixels $< 20\%$) to compute NDWI $= \frac{B3 - B8}{B3 + B8}$ (stagnant surface water index) and NDVI $= \frac{B8 - B4}{B8 + B4}$ (canopy resting habitat).

  * Query `UCSB-CHG/CHIRPS/DAILY` over the trailing 14 days to compute cumulative precipitation in millimeters (`rain_14d_mm`).

  * Calculate the environmental risk component $E_{\text{GEE}} \in [0, 1]$ based on ICMR thermal windows ($26^\circ\text{C}–32^\circ\text{C}$ optimal for *Aedes aegypti*; $24^\circ\text{C}–30^\circ\text{C}$ for *Anopheles*) and 14-day lagged rainfall ($50\text{mm}–150\text{mm}$).

* **Error Handling:** If optical Sentinel-2 bands are occluded by heavy monsoon cloud cover (`sample().first()` returns `None`), automatically fall back to Sentinel-1 SAR radar backscatter (`COPERNICUS/S1_GRD` VV/VH polarization) to detect standing water through clouds.

### Tool 3: `maps_routing_tool` (Google Maps Routes API v2)

* **Purpose:** Selects the fastest available fogging/larvicidal van and computes real-time traffic ETA and encoded route polylines.

* **Logic:**

  * Receives `target_lat`, `target_lng` and the list of `Available` vans from `sheets_admin_tool`.

  * Calls `POST https://routes.googleapis.com/directions/v2:computeRoutes` with `routingPreference: "TRAFFIC_AWARE_OPTIMAL"` and `FieldMask: "routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline"`.

  * Ranks all candidate vans by lowest traffic-adjusted `duration`, selects the optimal van, and returns `eta_minutes`, `distance_km`, `encoded_polyline`, and driver contact details.

* **Error Handling:** Handle `ZERO_RESULTS`, network timeouts, or invalid coordinates by raising `RoutingUnavailableException` and falling back to road-network-adjusted Haversine distance only if the upstream Maps API returns a 5xx error.

### Tool 4: `vision_paligemma_tool` (Open-Weight PaliGemma-3B + Vertex AI Gemini Vision)

* **Purpose:** Powers the `AI Vector Scan` screen and automated PII scrubbing.

* **Logic:**

  1. Run Google Cloud Vision SafeSearch & Face/License Plate detection on the raw uploaded image bytes; blur any detected human faces or vehicle plates in memory to enforce **DPDP Act 2023** compliance before uploading to Cloud Storage (`gs://`).

  2. Pass the sanitized image to the **PaliGemma-3B** open-weight model endpoint (hosted on Cloud Run GPU / Vertex AI Model Garden) to detect bounding boxes and classifications for breeding sources (`Uncovered Overhead Tank`, `Discarded Tires`, `Stagnant Drain`, `Cooler`, `Construction Water Pit`, `Algae/Larvae Presence`).

  3. Fuse the vision confidence $I_{\text{Vision}}$, GEE satellite suitability $E_{\text{GEE}}$, and Firestore ward Breteau Index $V_{\text{Field}}$ using the composite formula:


     $$
     \text{RiskScore}_{(x,y,t)} = 0.35 \cdot E_{\text{GEE}} + 0.40 \cdot V_{\text{Field}} + 0.25 \cdot I_{\text{Vision}}
     $$

  4. If $\text{RiskScore} \ge 0.70$, automatically invoke `sheets_admin_tool` and `gmail_alert_tool` to prioritize the ward and notify the assigned health officer.

### Tool 5: `gmail_alert_tool` (Automated Emergency Dispatch)

* **Purpose:** Sends immediate, structured HTML alert emails (with embedded Google Maps static links, GPS coordinates, Breteau Index, and GEE telemetry) to the local village assigned officer and CC's the District Representative when **Send Alert** is tapped or a scan is classified as `CRITICAL`.

* **Error Handling:** Validate recipient emails via regex and DNS MX lookup; retry transient SMTP/Gmail API 5xx errors and record the delivery message ID in Firestore and `5_Alert_Logs`.

### Tool 6: `ogd_india_gov_tool` (Open Government Data India & LGD Integration)

* **Purpose:** Queries `https://api.data.gov.in/resource/...` using `DATA_GOV_IN_API_KEY` to fetch official geocoded Primary Health Centers (PHCs), Community Health Centers (CHCs), LGD ward codes, and district nodal officer contact numbers across all 28 States and 8 UTs, syncing any missing entries into Firestore and Google Sheets.

## 3. BONUS CHALLENGE: OPEN-SOURCE AGENT SKILL (`SKILL.md` + TOOL WRAPPER)

Create a fully compliant, open-source agent skill inside `skills/vector-surveillance-skill/` adhering to the **Agent Skill Open Standard**:

1. **`skills/vector-surveillance-skill/SKILL.md`:**
   Include YAML frontmatter (`name: arogya-drishti-vector-surveillance`, `version: 1.0.0`, `license: Apache-2.0`, `models: [google/gemma-2-9b-it, google/paligemma-3b-pt-224, gemini-2.5-flash]`, `author: Team Rocket`) followed by exact tool invocation instructions, NCVBDC larvicidal chemical dosage lookup tables (Temephos 50% EC at 1 ppm, Bti dosage per sq meter, Pyrethrum space spray ratios), and WHO index interpretation rules ($HI > 1\%$, $BI > 20$).

2. **`skills/vector-surveillance-skill/harness/gemma_agent_harness.py`:**
   Write an open-source Python model harness that connects **Gemma-2-9B-IT** (via Vertex AI / Ollama / vLLM OpenAI-compatible tool-calling interface) to four executable tools:

   * `query_gee_microclimate(lat, lng)`

   * `compute_ward_entomological_indices(lgd_code)`

   * `dispatch_fogging_van(ward_village, lat, lng, notes)`

   * `trigger_emergency_ward_alert(ward_village, lat, lng, severity_notes)`

## 4. SCREEN-BY-SCREEN FLUTTER IMPLEMENTATION INSTRUCTIONS (ALL 10 SCREENS)

Build all 10 screens matching the "Arogya Drishti" visual system (`#8B0000` deep crimson cards, crisp white `#FFFFFF` surfaces, high-contrast typography). Use `flutter_riverpod` for state management and `cloud_firestore` with `Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED)`.

### Screen 1: `HomeScreen` (`/home`)

* **Header & Profile Card:** Bind directly to `FirebaseAuth.instance.currentUser` and the officer's Firestore profile (`users/{uid}`). Display officer name, assigned ward & city, verified phone number, `Account Settings` button, and `Log Out` button.

* **Live Location & Search Bar:** Use `geolocator` + `geocoding` to resolve the officer's live GPS coordinate into a ward/sector name when tapping `Current`, or allow searching any Indian village/ward via Google Places / LGD lookup.

* **3 Quick Action Cards (`Scan`, `Request Van`, `Send Alert`):**

  * `Scan` navigates to `/scan`.

  * `Request Van` and `Send Alert` open a reusable **Modal Bottom Sheet (`ActionDispatchBottomSheet`)** featuring a live Google Maps pin selector, auto-filled GPS coordinates, a dynamic Ward/Village dropdown populated from `3_Staff_Directory` in Google Sheets, and a severity notes input.

  * Submitting `Request Van` calls `POST /api/v1/dispatch-action` (`action_type: "REQUEST_VAN"`), appends the request to Google Sheets, assigns the nearest van via Google Maps Routes API, and shows the assigned van's live ETA.

  * Submitting `Send Alert` calls `POST /api/v1/dispatch-action` (`action_type: "SEND_ALERT"`), logs to Google Sheets, and triggers an immediate automated email via `gmail_alert_tool` to the local village assigned person retrieved from Google Sheets.

* **Field Vector Inspection Form Card:**

  * Inputs: `Village / Ward`, `Larvicidal Treatment` dropdown (`Temephos 50% EC Applied`, `Bti Applied`, `Pyrethrum Spray`, `Source Drained`, `None`), `Houses Inspected`, `Houses Positive`, `Containers Checked`, `Containers Positive`.

  * On tapping **Save Offline & Queue Sync**, validate inputs, compute $HI$, $CI$, and $BI$ immediately, and write to `firestore.collection('field_logs')`. Firestore's offline persistence queues the write locally when offline and automatically syncs when network connectivity returns.

### Screen 2: `ChatScreen` (`/chat`)

* **Multilingual AI Copilot:** Connects to `POST /api/v1/agent/chat` powered by the **Gemma-2-9B-IT / Vertex AI Agent Skill harness**.

* Streams real-time responses with interactive tool-result cards: if the officer asks *"What is the current risk in my sector?"* or *"Dispatch a van to Sector 22-B"*, render the live Breteau Index card, satellite micro-climate metrics, and direct action confirmation inside the chat stream.

### Screen 3: `StatsScreen` (`/stats`)

* **Real-Time Epidemiological Calculations:** Listen to `firestore.collection('field_logs').where('lgd_code', isEqualTo: currentWardLgd)` and dynamically compute and display:

  * **House Index (**$HI\%$**)** with trend delta and WHO threshold progress bar.

  * **Container Index (**$CI\%$**)** with container category breakdown.

  * **Breteau Index (**$BI$**)** with epidemic risk status badge.

* **Weekly Vector Index Trends Chart:** Render a real `fl_chart` multi-line graph aggregating the past 8 weeks of Firestore inspection logs alongside GEE rainfall correlation.

* **Export CSV Report & Escalation:** Implement `Export CSV Report` using the `csv` and `share_plus` packages to generate an IHIP/NCVBDC-standardized CSV file from live Firestore documents, and wire `Escalate to District HQ` to notify the District Representative fetched from Google Sheets / OGD API.

### Screen 4: `MapScreen` (`/map`)

* Embed `GoogleMap` (`google_maps_flutter`) rendering:

  1. Real-time heatmap circles (`Circle` overlays) colored by each ward's live composite risk score from Firestore.

  2. Custom markers for positive larval breeding sites logged via `field_logs` and `ai_scans`.

  3. Interactive bottom card displaying the selected ward's live $HI$, $CI$, $BI$, GEE Land Surface Temperature, and a one-tap `Dispatch Van Here` button.

### Screen 5: `SettingsScreen` (`/settings`)

* Live Firestore offline queue indicator (listening to `snapshots(includeMetadataChanges: true)` to count documents where `metadata.hasPendingWrites == true`), a manual `Force Cloud Sync` trigger (`FirebaseFirestore.instance.waitForPendingWrites()`), language selector (English, Hindi, Punjabi via Cloud Translation / Bhashini API), and DPDP Act 2023 compliance disclosures.

### Screen 6: `AuthScreen` (`/auth`)

* **Officer Sign-In:** Mobile number input (`+91`) with Firebase Phone Auth (`verifyPhoneNumber`) and a 6-digit OTP pin input.

* Upon OTP verification, call `/api/v1/auth/verify-staff` to validate that the phone number exists in the `3_Staff_Directory` Google Sheet before minting the officer session.

### Screen 7: `SupportScreen` (`/support`)

* **One-Tap Emergency Helplines:** Direct `url_launcher` (`tel:`) buttons for National Vector Control / Ambulance (`108`, `104`, Municipal Control Room).

* **Escalation Ticket Form:** Submits tickets directly to Firestore and Google Sheets.

* **Live Ward & District Representative Directory:** Fetches the real-time contact list of Village Officers and District Representatives (CMO / District Malaria Officer) from `GET /api/v1/contacts?district_lgd=...` (backed by Google Sheets + `data.gov.in` OGD API) with one-tap Call and Email buttons.

### Screen 8: `CentersScreen` (`/centers`)

* Calls `GET /api/v1/centers?lat=...&lng=...` which merges the `2_Health_Centers` Google Sheet with the `data.gov.in` Health Facility Registry.

* Displays a mini Google Map with PHC/CHC pins, live filter chips (`All`, `PHC`, `Testing Lab`, `Dengue Ward`), RDT kit availability, free dengue bed counts, and one-tap `Call Center` and `Directions` (launching Google Maps navigation).

### Screen 9: `VansScreen` (`/vans`)

* Calls `GET /api/v1/vans` (backed by `1_Vans_Fleet` and `4_Van_Requests` in Google Sheets).

* Displays a live telemetry map showing active fogging vans, their encoded route polylines from Google Maps Routes API, real-time traffic ETA countdowns, driver name, vehicle registration number, chemical tank status, one-tap `Call Driver`, and a bottom button to open the `Request Van` modal.

### Screen 10: `ScanScreen` (`/scan`)

* Integrates the device camera (`camera` / `image_picker`) with live GPS tagging (`geolocator`).

* Captures a photo of a suspected breeding site and uploads `multipart/form-data` (`image`, `lat`, `lng`, `ward_lgd`) to `POST /api/v1/scan-breeding-site`.

* Displays the real response from `vision_paligemma_tool` + `gee_climate_tool`:

  * Annotated image preview, Composite Risk Tier (`CRITICAL` / `HIGH` / `MODERATE` / `LOW`), AI confidence percentage, detected container type, live GEE Land Surface Temperature (°C), NDWI stagnant water index, 14-day rainfall (mm), recommended NCVBDC larvicide dosage, and confirmation of automated priority email/van escalation if risky.

## 5. PUBLIC PREDICTION API & DEPLOYMENT READINESS

1. **Public DPI Endpoint (`GET /api/v1/risk-index?lat={float}&lng={float}`):**

   * Expose a documented, rate-limited REST endpoint where any external civic app, researcher, or hospital passes `lat` and `lng` and receives the real-time JSON payload combining Google Earth Engine telemetry (`lst_celsius`, `ndwi`, `ndvi`, `rainfall_14d_mm`), local Firestore ward indices (`hi`, `ci`, `bi`), composite risk score, and preventive advisories.

2. **Deployment Artifacts:**

   * Write a multi-stage production `backend/Dockerfile` running `gunicorn -k uvicorn.workers.UvicornWorker`.

   * Write `cloudbuild.yaml` and a deployment script `deploy.sh` that builds the container, deploys the FastAPI service to **Google Cloud Run (`asia-south1`)**, deploys `firestore.rules` and `firestore.indexes.json` (ensuring composite indexes for `lgd_code` + `timestamp`), and builds the Flutter web & Android release APK (`flutter build apk --release` and `flutter build web --release`).

   * Provide an `.env.example` listing all required keys (`GOOGLE_APPLICATION_CREDENTIALS`, `MASTER_SPREADSHEET_ID`, `GOOGLE_MAPS_API_KEY`, `DATA_GOV_IN_API_KEY`, `VERTEX_AI_PROJECT_ID`, `SMTP_USER`, `SMTP_PASSWORD`).
