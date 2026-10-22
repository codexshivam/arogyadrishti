# Security & Compliance Policy — Arogya Drishti

Arogya Drishti is engineered as national-scale Digital Public Infrastructure (DPI) for vector-borne disease surveillance in India, adhering to **MeitY**, **CERT-In**, **DPDP Act 2023**, and **OWASP MASVS L1** requirements.

## 1. Data Sovereignty & Residency
- All cloud compute, storage, database, and AI inference workloads are pinned strictly to **`asia-south1` (Mumbai, India)**.
- Cloud Run services (`arogya-drishti-api` and `arogya-gemma-vllm`), Cloud Firestore (Native mode), Cloud Storage buckets, and Vertex AI endpoints execute within Indian borders.

## 2. Digital Personal Data Protection (DPDP) Act 2023 Compliance
- **Zero Citizen PII Persistence:** Field inspection logs (`field_logs`) never store citizen names, phone numbers, or Aadhaar identifiers. Only aggregate household/container counts and official Local Government Directory (`lgd_code`) identifiers are recorded.
- **Automated Visual Redaction:** Every breeding-site photo uploaded via `/api/v1/scan-breeding-site` is processed in-memory through Google Cloud Vision SafeSearch, Face Detection, and License Plate / OCR text bounding-box blurring **before** any bytes are persisted to Google Cloud Storage (`gs://`).
- **Log Scrubbing:** Backend structured logs scrub phone numbers, email addresses, and bearer tokens via regex filters prior to emission.

## 3. Authentication, Authorization & Secrets Management
- **Staff Pre-Authorization:** Firebase Phone Auth (`+91` OTP) is bound to pre-authorized municipal officers listed in `3_Staff_Directory` of the Master Google Sheet via `/api/v1/auth/verify-staff`, which mints Custom JWT Claims (`role`, `assigned_lgd_code`).
- **App Attestation:** Firebase App Check headers are verified by backend middleware.
- **Zero Repository Keys:** Service account keys and API credentials are prohibited from version control and enforced via `gitleaks` and `detect-private-key` pre-commit hooks. Production Cloud Run workloads use Workload Identity and Google Secret Manager.

## 4. Reporting a Vulnerability
Please report suspected security issues to the Team Rocket security maintainers via private disclosure before opening a public issue.
