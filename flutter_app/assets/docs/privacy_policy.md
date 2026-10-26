# Privacy Policy — NidanIQ Nepal Sovereign Vector Surveillance DPI

**Sovereign Digital Public Infrastructure for Vector-Borne Disease Surveillance & Early Warning**
*Engineered in strict compliance with the Constitution of Nepal (2072) Article 28 & Article 35, Individual Privacy Act, 2075 (2018), Individual Privacy Regulation, 2077 (2020), Data Center and Cloud Service Directive, 2081 (DCCS 2081), and MoHP / EDCD Teku National Dengue Control Guidelines.*

**Document Version:** 2.0.0
**Effective Date:** 2083-07-09 BS (October 26, 2026 AD)
**Data Hosting Jurisdiction:** Government of Nepal — Integrated Data Management Center (IDMC, Singha Durbar Primary & Hetauda Disaster Recovery)

---

## 1. Statutory Mandate & Zero-Citizen-PII Architecture

NidanIQ operates exclusively for the **Government of Nepal** (**Ministry of Health and Population — MoHP**, **Epidemiology and Disease Control Division — EDCD Teku**, and **753 Local Levels / Palikas**).

Under the **Individual Privacy Act, 2075 (2018)**:
- **Zero-Citizen-PII Ingestion:** Field inspection and AI vision endpoints strictly reject and strip any citizen names, Citizenship Numbers (*Nagarikta*), National Identity Numbers (*Rastriya Parichayapatra / NID*), household phone numbers, or human facial portraits.
- **EXIF Metadata Stripping:** All uploaded breeding-site photographs have EXIF GPS and device serial tags stripped in memory before PaliGemma 3B multimodal analysis.
- **Spatial K-Anonymity:** Exact household inspection coordinates (`POINT(lng, lat)`) are AES-256-GCM encrypted at rest and accessible solely to authenticated Rapid Response Teams (RRT) and Ward Health Officers; public risk map endpoints expose only ward-level polygon aggregates and rounded 250m grid centroids.

## 2. Multi-Tenant Palika Isolation (Constitution of Nepal Schedule 8)

Pursuant to Schedule 8 of the Constitution of Nepal (2072) and the Local Government Operation Act, 2074, basic health and sanitation fall under Local Level (*Palika*) jurisdiction. PostgreSQL Row-Level Security (`SET LOCAL app.current_palika`) and asymmetric `EdDSA` JWT claims cryptographically isolate FCHVs and Ward Health Officers to their assigned `palika_code` and `composite_ward_id`.

## 3. Sovereign Data Residency (DCCS Directive 2081)

100% of operational databases (PostgreSQL 16 + PostGIS 3.4), cache layers (Redis 7), WORM audit archives (MinIO S3 Object Lock `COMPLIANCE` mode, 365-day retention), and open-weight AI inference (Gemma 4 & PaliGemma via local vLLM) execute within the **Integrated Data Management Center (IDMC), Singha Durbar, Kathmandu**.
