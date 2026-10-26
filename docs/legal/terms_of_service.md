# Terms of Service — NidanIQ Nepal Sovereign Vector Surveillance DPI

**Sovereign Digital Public Infrastructure for Vector-Borne Disease Surveillance & Early Warning**
*Operating under the Public Health Service Act, 2075, Electronic Transactions Act, 2063 (2008), Local Government Operation Act, 2074, and National Cyber Security Policy, 2080 (2023).*

**Document Version:** 2.0.0
**Effective Date:** 2083-07-09 BS (October 26, 2026 AD)
**Jurisdiction:** Kathmandu, Government of Nepal

---

## 1. Authorized Public Health Personnel

Access to NidanIQ operational endpoints is restricted to accredited public health personnel registered in the Municipal & EDCD Staff Whitelist (`+977` Nepal Telecom / Ncell via Sparrow SMS & Aakash SMS):
- **Female Community Health Volunteers (`fchv` / महिला सामुदायिक स्वास्थ्य स्वयंसेविका)**
- **Ward Health Officers (`ward_health_officer` / Health Assistants, AHWs, Sanitary Inspectors at Ward BHSCs & UHPCs)**
- **Palika Health Chiefs (`palika_health_chief` / Chief of Municipal Public Health Division — Jan Swasthya Bibhag)**
- **EDCD Nodal Officers (`edcd_nodal` / MoHP EDCD Teku & Provincial Health Directorate Epidemiologists)**

## 2. EDCD National Dengue Control Protocol Compliance

All field interventions dispatched through NidanIQ adhere to the **EDCD Nepal National Guidelines on Prevention, Management and Control of Dengue**:
- Primary vector control prioritizes **"Search & Destroy" (*खोज र नष्ट गर अभियान* / Khoj Ra Nashta Gar)** Rapid Response Teams (RRT) and biological larviciding (*Bacillus thuringiensis israelensis* `Bti` WP/granules and `Temephos 50% EC`).
- Focal Ultra-Low Volume (ULV) space-spraying is strictly gated behind confirmed EWARS clinical virus transmission, Breteau Index (`BI >= 30`), and cryptographic authorization by a `palika_health_chief`.

## 3. Audit Trail & Electronic Transactions Act, 2063

Every login attempt, RBAC rejection, AI vision scan, RRT dispatch, ULV override, and MoHP IHMIS/DHIS2 push is permanently recorded in a SHA-256 hash-chained WORM audit ledger (`prev_hash` + `SHA-256(prev_hash || canonical_payload || timestamp_utc)`).
