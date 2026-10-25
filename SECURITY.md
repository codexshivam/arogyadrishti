# Security & Compliance Policy

NidanIQ is engineered as sovereign National Digital Public Infrastructure (DPI) for predictive vector-borne disease surveillance in India, adhering strictly to **MeitY**, **CERT-In Cyber Security Directions**, the **Digital Personal Data Protection (DPDP) Act, 2023**, and **OWASP MASVS L1** requirements.

---

## 1. Supported Versions

Security updates, vulnerability patches, and cryptographic dependency remediations are actively maintained for the following releases:

| Component / Distribution | Version | Supported | Security Maintenance Status |
| :--- | :--- | :---: | :--- |
| **Mobile DPI Client (Android & iOS)** | `1.0.x` | ✅ Yes | Active Security Maintenance (Flutter 3.24+) |
| **Backend API Gateway (FastAPI)** | `1.0.x` | ✅ Yes | Active Security Maintenance (Python 3.14) |
| **Autonomous Agent Skill** | `1.0.0` | ✅ Yes | Apache 2.0 Agent Skill Standard |

---

## 2. Data Sovereignty & Indian Geofencing

- **Strict Indian Residency (`asia-south1`):** All cloud compute, serverless runtimes, document stores, object storage buckets, and AI inference workloads execute exclusively within the **Google Cloud Platform Mumbai Region (`asia-south1`)**.
- **Zero Cross-Border Data Transfers:** In strict accordance with Section 16 of the DPDP Act, 2023, no field surveillance records, telemetry streams, or officer credentials are transferred outside the territorial boundaries of the Republic of India.
- **CERT-In 180-Day WORM Audit Trail:** As mandated by CERT-In Cyber Security Directions (No. 20(3)/2022-CERT-In), all administrative access, data fusion operations, and emergency dispatches are streamed to tamper-proof Write-Once-Read-Many (WORM) storage buckets with an immutable 180-day retention lock.

---

## 3. Digital Personal Data Protection (DPDP) Act, 2023 Compliance

- **Zero Citizen PII Persistence:** Field inspection ledgers (`field_logs`) never record citizen names, mobile numbers, Aadhaar numbers, or domestic identity documents. Surveillance records track strictly aggregate dwelling and container counts mapped to statutory Local Government Directory (`lgd_code`) polygons.
- **In-Memory Visual Redaction:** Field photographs uploaded through the inspection pipeline are scrubbed in-memory via face-detection and license-plate blurring filters prior to any bytes being persisted to Google Cloud Storage (`gs://`).
- **Data Minimization:** Officers authenticate solely using departmental phone numbers matched against pre-authorized municipal rosters. Operational JWT tokens expire after 24 hours.

---

## 4. Cryptographic Security & Threat Defenses

- **Hardware-Backed Device Storage:** In-app session secrets, auth tokens, and cryptographic keys are secured using `flutter_secure_storage` backed by Android Keystore (AES-256) and iOS Keychain.
- **Application Attestation:** Cloud endpoints verify cryptographic device integrity via Firebase App Check before accepting field ingestion payloads.
- **Zero Hardcoded Secrets Gate:** Repository commits are guarded by pre-commit hooks (`gitleaks`, `detect-private-key`) ensuring zero API keys, service account JSON files, or production secrets enter version control.
- **CodeQL Advanced Static Analysis:** Continuous automated static application security testing (SAST) monitors the codebase for taint propagation, SQL/command injection, and unauthorized data leakage.

---

## 5. Vulnerability Disclosure & Incident Reporting

We welcome responsible security disclosures from cybersecurity researchers, academic institutions, and authorized public health agencies.

If you believe you have identified a potential security vulnerability within NidanIQ:

1. **Do Not Open a Public GitHub Issue:** Please refrain from disclosing suspected vulnerabilities publicly or in community forums.
2. **Submit a Private Vulnerability Report:** Submit a detailed advisory via [GitHub Private Vulnerability Reporting](https://github.com/codexshivam/NidanIQ/security/advisories/new) or email our designated Data Protection Officer.
3. **Include Reproduction Details:** Provide proof-of-concept steps, affected endpoints, request/response samples, and impact assessment.

### Statutory Turnaround Time (SLA)
- **Initial Acknowledgment:** Within **24 hours** of receipt.
- **Triage & Remediation Plan:** Within **72 hours**.
- **Formal Resolution & Fix Release:** Within **7 calendar days**.

---

## 6. Official Institutional Coordinates & Data Protection Officer

Under Section 13(2) of the DPDP Act, 2023 and Rule 5(9) of the IT Rules, 2011:

| Attribute | Official Specification |
| :--- | :--- |
| **Entity Name** | **NidanIQ** |
| **Headquarters** | Mohali, Punjab (India) |
| **Data Sovereignty Region** | Mumbai (`asia-south1`), Republic of India |
| **Official Institutional Email** | `support@example.com` |
| **Official Grievance Desk** | `grievance.dpo@example.com` |
| **Data Protection Officer (DPO)** | **Shivam Yadav** |
| **Official Designation** | Data Protection Officer (DPO) |
| **Institutional Department** | NidanIQ Project Secretariat |
| **Physical Office Address** | Mohali, Punjab (India) |
| **Dedicated Redressal Email** | `grievance.dpo@example.com` |
| **Emergency Escalation Email** | `emergency@example.com` |
| **Telephone Helpline** | +91 172 2700000 |
| **Statutory Resolution SLA** | Acknowledged in 24 hours; resolved in 7 calendar days |
