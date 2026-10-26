# Security & Compliance Policy

**NidanIQ** is engineered as a secure sovereign **Digital Public Infrastructure (DPI)** for predictive vector-borne disease surveillance in the **Government of Nepal** (**Ministry of Health and Population — MoHP**, **Epidemiology and Disease Control Division — EDCD Teku**, and **753 Local Levels / Palikas**), adhering to statutory cybersecurity directives and data protection principles established under:

* **Constitution of Nepal (2072):** Article 28 (Right to Privacy), Article 35 (Right to Health), & Schedule 8 (Local Level Exclusive Health & Sanitation Jurisdiction)
* **National Cyber Security Policy, 2080 (2023 — National Cyber Security Centre / NCSC)**
* **Data Center and Cloud Service (Operation and Management) Directive, 2081 (DCCS Directive 2081 — MoCIT / DOIT)**
* **Individual Privacy Act, 2075 (2018) & Individual Privacy Regulation, 2077 (2020)**
* **Electronic Transactions Act, 2063 (2008)**
* **OWASP Mobile Application Security Verification Standard (MASVS L1) & OWASP Top 10 API Security** guidelines.

---

## 1. Supported Versions

Security updates, vulnerability patches, and cryptographic dependency remediations are actively maintained for the following releases:

| Component / Distribution | Version | Supported | Security Maintenance Status |
| :--- | :---: | :---: | :--- |
| **Mobile Client** | `1.0.x` | ✅ Yes | Active Security Maintenance (Flutter 3.24+, 256-bit AES-GCM Hive/SecureStorage) |
| **Backend & API** | `2.0.x` | ✅ Yes | Active Security Maintenance (Python 3.12+, PostgreSQL 16 / PostGIS 3.4 / vLLM) |
| **Citizen Portal** | `2.0.x` | ✅ Yes | Active Security Maintenance (Next.js 15 App Router, 15m ISR, MapLibre GL) |
| **Agent Skill** | `1.0.0` | ✅ Yes | Sovereign Nepal Vector Surveillance Agent Skill Standard |

---

## 2. Data Sovereignty & Nepal National Geofencing

* **Strict Nepal Sovereign Data Residency (IDMC Singha Durbar & Hetauda DR):** In accordance with **DCCS Directive 2081**, all bare-metal compute nodes, container runtimes, spatial databases, WORM object storage buckets, and AI inference engines execute within sovereign data center facilities at the **Government Integrated Data Management Center (IDMC, Singha Durbar, Kathmandu)** and the **Government Data Center (GDC, Hetauda DR site, Makwanpur)** (with local DigitalOcean staging bridging).
* **Zero Cross-Border Data Transfers:** In strict accordance with the **Individual Privacy Act, 2075** and DCCS Directive 2081, zero field surveillance records, telemetry streams, satellite overlays, or officer credentials are transferred outside the sovereign territorial boundaries of the Federal Democratic Republic of Nepal.
* **OAG 365-Day WORM Audit Trail (Mahalekha Parikshak Mandate):** As required for constitutional audits by the **Office of the Auditor General (OAG)** and NCSC Policy 2080, all administrative actions, AI vision scans, RRT vehicle dispatches, and chemical larvicide consumptions are committed to MinIO Object Lock in **`COMPLIANCE` mode** and PostgreSQL SHA-256 hash-chained tables (`prev_hash || canonical_payload || timestamp_utc`) protected by immutable database triggers blocking `UPDATE` and `DELETE` for a statutory 365-day retention lock.

---

## 3. Individual Privacy Act, 2075 Compliance & Data Minimization

* **Zero Citizen PII Persistence:** Field inspection ledgers (`field_inspections`) never record citizen names, personal mobile numbers, Citizenship Certificate numbers (*Nagarikta*), National Identity Numbers (*NID*), or household voter identifiers. Surveillance records track strictly aggregate dwelling and container counts mapped to statutory Ministry of Federal Affairs and General Administration (**MoFAGA**) composite ward polygons (`composite_ward_id`).
* **In-Memory Visual Redaction & Face Scrubbing:** Field photographs captured by Female Community Health Volunteers (FCHVs) are scrubbed in memory via OpenCV/Pillow facial-detection filters and EXIF GPS strippers prior to any bytes entering the PaliGemma AI inference queue or MinIO object storage.
* **Data Minimization & Hybrid Auth:** Officers authenticate solely using pre-whitelisted departmental `+977` mobile numbers via Sparrow/Aakash SMS OTP. Operational asymmetric EdDSA (Ed25519) JWT tokens expire after 15 minutes with automated refresh rotation. System alerts route strictly through verified SMTP email and in-app push notifications (Zero SMS used for alerts to eliminate gateway waste).

---

## 4. Cryptographic Security & Threat Defenses

* **Hardware-Backed Device Storage:** In-app session secrets, auth tokens, and cryptographic keys are secured using `flutter_secure_storage` backed by Android Keystore / StrongBox (AES-256) and iOS Keychain.
* **Cryptographic Payload Signing & 64-bit dHash Anti-Replay:** Mobile inspection payloads are cryptographically signed on-device with hardware-backed private keys (`NP-EXIF-SIG-...`) and evaluated with 64-bit perceptual difference hashing (`dHash`) against ward history (Hamming distance $\le 8$ blocks recycled stock photos).
* **PostGIS `ST_DWithin` (100m) Geofencing & Mock-GPS Blocking:** Enforces Mahalekha Parikshak non-repudiation by rejecting field reports if mock location developer apps are active, if device clock drifts $> 300\text{s}$, or if the inspector is $> 100\text{m}$ away from the reported household parcel.
* **HashiCorp Vault 60-Minute Ephemeral DB Leases:** Zero static database credentials exist in production `.env` files. FastAPI dynamically requests short-lived PostgreSQL/PostGIS credentials expiring every 60 minutes (`TTL = 3600s`).
* **Wazuh 24/7 SIEM SOC & Active Response:** Real-time login anomaly analysis intercepts **Impossible Geolocation Travel** (e.g., Pokhara to Kathmandu within 60 seconds) and high-velocity brute force ($\ge 50$ attempts/min), immediately blacklisting the offending IP, revoking EdDSA JWTs, and dispatching SMS/Telegram alerts to DoIT/IDMC SysAdmins.
* **Zero Hardcoded Secrets Gate & CI/CD DevSecOps:** Repository commits are guarded by pre-commit hooks (`gitleaks`, `detect-private-key`), while GitHub Actions and GitLab CI run **Bandit** (Python security AST linter), **SonarQube** (code quality & security hotspots), and **Trivy** (Docker image and OS vulnerability scanning).

---

## 5. Vulnerability Disclosure & Incident Reporting

We welcome responsible security disclosures from cybersecurity researchers, academic institutions, and authorized public health agencies.

If you believe you have identified a potential security vulnerability within NidanIQ:

* **Do Not Open a Public GitHub Issue:** Please refrain from disclosing suspected vulnerabilities publicly or in community forums.
* **Submit a Private Vulnerability Report:** Submit a detailed advisory via [GitHub Private Vulnerability Reporting](https://github.com/codexshivam/nidaniq/security/advisories/new) or email our designated Institutional Data Protection Officer.
* **Include Reproduction Details:** Provide proof-of-concept steps, affected endpoints, request/response samples, and impact assessment.

### Statutory Turnaround Time (SLA)
* **Initial Acknowledgment:** Within 24 hours of receipt.
* **Triage & Remediation Plan:** Within 72 hours.
* **Formal Resolution & Fix Release:** Within 7 calendar days.

---

## 6. Official Institutional Coordinates & Security Contact

Under Section 13(2) of the **Individual Privacy Act, 2075** and **National Cyber Security Policy, 2080**:

| Attribute | Official Specification |
| :--- | :--- |
| **Entity Name** | **NidanIQ** |
| **Authority** | **Shivam Yadav** |
| **Headquarters** | **Bhaisepati, Lalitpur (Nepal)** |
| **Email** | `hello@shivm.com` |
