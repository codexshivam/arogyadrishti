# Security, Cryptography & Compliance Policy — SwasthyaDrishti (स्वास्थ्यदृष्टि)
### National Cyber Security Policy 2080 (NCSC) & Individual Privacy Act 2075 Compliance Standard

[![Sovereign Infrastructure](https://img.shields.io/badge/Data_Residency-IDMC_Singha_Durbar_%7C_Hetauda_DR-0B3D91.svg?style=for-the-badge)](https://doit.gov.np)
[![Cryptographic Non-Repudiation](https://img.shields.io/badge/Audit_Standard-OAG_Mahalekha_Parikshak_WORM-059669.svg?style=for-the-badge)](https://oag.gov.np)
[![Zero Citizen PII](https://img.shields.io/badge/Privacy-Individual_Privacy_Act_2075-DC2626.svg?style=for-the-badge)](https://lawcommission.gov.np)
[![Zero SMS Alert Waste](https://img.shields.io/badge/Notification_Policy-Zero_SMS_Alert_Cost-D97706.svg?style=for-the-badge)](https://mohp.gov.np)

---

## 1. Statutory Governance & Regulatory Foundation

SwasthyaDrishti is deployed as a critical sovereign Digital Public Infrastructure (DPI) asset for the **Government of Nepal** (**Ministry of Health and Population — MoHP** and **Epidemiology and Disease Control Division — EDCD Teku**). Its security architecture is governed by five statutory instruments:

1. **Constitution of Nepal (2072):**
   - **Article 28 (Right to Privacy):** Guarantees privacy of person, residence, property, documents, and correspondence.
   - **Article 35 (Right to Health):** Establishes basic healthcare as a fundamental citizen right.
   - **Schedule 8 (Local Level Powers):** Grants the 753 Municipalities (*Palikas*) autonomous authority over local health, sanitation, and vector control.
2. **Individual Privacy Act, 2075 (2018) & Individual Privacy Regulation, 2077 (2020):** Mandates explicit purpose specification, strict data minimization, and immediate anonymization of sensitive health metrics.
3. **Data Center and Cloud Service (Operation and Management) Directive, 2081 (DCCS Directive 2081 — MoCIT / DOIT):** Forbids hosting sovereign public health databases outside Nepal's borders.
4. **National Cyber Security Policy, 2080 (2023 — National Cyber Security Centre / NCSC):** Enforces 24/7 SOC monitoring, automated incident response, strict access control, and periodic vulnerability audits.
5. **Electronic Transactions Act, 2063 (2008):** Recognizes asymmetric digital signatures and immutable audit trails as legally admissible evidence before courts of law and the **Office of the Auditor General (OAG / *महालेखा परीक्षक*)**.

---

## 2. Zero-Trust Sovereign Infrastructure (Bypassing Hyperscaler Lock-In)

Under **DCCS Directive 2081**, SwasthyaDrishti rejects closed foreign cloud infrastructure (AWS, Microsoft Azure, Google Cloud). The entire platform is deployed to bare-metal enterprise servers housed at:
- **Primary Data Center:** Government Integrated Data Management Center (**IDMC**), Singha Durbar, Kathmandu.
- **Disaster Recovery (DR) Site:** Government Data Center (**GDC**), Hetauda, Makwanpur District.

```
+-----------------------------------------------------------------------------------------------------------------------+
|                                    IDMC SINGHA DURBAR BARE-METAL SOVEREIGN BOUNDARY                                   |
+-----------------------------------------------------------------------------------------------------------------------+
|  [External Network]                                                                                                   |
|         |                                                                                                             |
|         v (TLS 1.3 Only, Mutual TLS enforced for internal nodes)                                                      |
|  [Hardware Border Firewall & WAF]                                                                                     |
|         |                                                                                                             |
|         +---> [Wazuh 24/7 SOC Agent] (Monitors brute force, impossible travel, MITRE ATT&CK T1110)                    |
|         |                                                                                                             |
|         v                                                                                                             |
|  [Sovereign Docker Swarm / Compose Service Mesh]                                                                      |
|     |                                                                                                                 |
|     +---> [FastAPI Core Engine] <----> [HashiCorp Vault] (Leases 60-min Ephemeral DB Credentials)                     |
|     |                                                                                                                 |
|     +---> [PostgreSQL 16 + PostGIS 3.4] (PostGIS ST_Contains, ST_DWithin 100m, Row-Level Security)                   |
|     |                                                                                                                 |
|     +---> [MinIO Object Lock WORM] (COMPLIANCE Mode: 365-day immutability, zero delete/overwrite)                     |
|     |                                                                                                                 |
|     +---> [Sovereign AI vLLM Node] (PaliGemma 3B + Gemma 4 running on local GPUs, Zero external API calls)            |
|     |                                                                                                                 |
|     +---> [OSRM Road Routing Engine] (Offline Nepal OpenStreetMap graph for tactical RRT van dispatch)                |
+-----------------------------------------------------------------------------------------------------------------------+
```

### In-Transit Security: TLS 1.3 & Mutual TLS (mTLS)
- **Protocol Ceiling & Floor:** System configurations explicitly enforce `TLSv1_3`. Legacy protocols (`TLS 1.0`, `TLS 1.1`, and `TLS 1.2`) are strictly disabled at the socket level (`ssl.TLSVersion.TLSv1_3`).
- **Internal Service Mesh mTLS:** All communication between FastAPI core nodes, the PostgreSQL spatial database (`sslmode=verify-full`), Redis caching nodes, and local vLLM AI containers requires mutual X.509 client certificate presentation. No internal service trusts another implicitly.

---

## 3. Cryptographic Identity & Hybrid Authentication

To reconcile stringent operational security with fiscal sustainability across 52,000+ field workers (FCHVs, Ward Officers, Lab Technicians, Health Chiefs), SwasthyaDrishti enforces a **Hybrid Authentication & Notification Model**:

```
+-----------------------------------------------------------------------------------------------------------------------+
|                                   HYBRID AUTHENTICATION & COMMUNICATION FLOW                                          |
+-----------------------------------------------------------------------------------------------------------------------+
|                                                                                                                       |
|  1. IDENTITY & LOGIN (Security Critical)           2. SYSTEM ALERTS & REPORTS (Cost Critical)                         |
|  ======================================           ==========================================                         |
|  - Strictly Phone Number (+977) + SMS OTP          - Strictly Verified Email / In-App Push                            |
|  - Pre-whitelisted in MoHP/EDCD Directory          - Zero SMS used for SLA alerts, RRT dispatch, or reports           |
|  - EdDSA (Ed25519) Asymmetric JWT minted           - Eliminates crippling NPR 18+ Lakh/yr SMS gateway cost            |
|  - Token includes: staff_id, role, palika_code     - Requires 2-step verification (15-min OTP)                        |
|                                                                                                                       |
+-----------------------------------------------------------------------------------------------------------------------+
```

### A. Asymmetric EdDSA JWTs & Key Rotation
- **Token Signing:** Identity tokens are minted using the asymmetric **Ed25519 (EdDSA)** algorithm. Public verification keys are distributed to microservices via an internal JSON Web Key Set (`JWKS`), allowing stateless token verification without exposing the signing private key.
- **Session Revocation:** JWTs carry a unique `jti` (JWT ID). If Wazuh detects suspicious behavior, the `jti` is immediately pushed to Redis with an instant revocation TTL.
- **Nagarik App SSO Readiness:** The auth gateway includes OpenID Connect (OIDC) endpoints prepared to integrate with the Government of Nepal's **Nagarik App (*नागरिक एप*)** Single Sign-On once the national federated identity gateway goes live.

### B. Anti-Spam Sliding-Window Email Rate Limiting
To prevent malicious staff or compromised accounts from abusing the government's SMTP relay, linking official emails (`POST /api/v1/users/me/email`) is restricted by a sliding-window rate limiter:
- **Maximum 3 verification requests per hour per user.**
- OTPs expire after **15 minutes**.
- Every email verification event is committed to the WORM audit log (`ACTION: EMAIL_VERIFIED`).

---

## 4. Anti-Fraud & OAG Audit Integrity (Non-Repudiation)

Government auditors from the **Office of the Auditor General (OAG / *महालेखा परीक्षक*)** routinely flag digital surveillance projects when field workers can fabricate inspection reports from home. SwasthyaDrishti enforces non-repudiation across four immutable pillars:

```
+-----------------------------------------------------------------------------------------------------------------------+
|                               MAHALEKHA PARIKSHAK (OAG) FIELD INTEGRITY CONTROLS                                      |
+-----------------------------------------------------------------------------------------------------------------------+
|                                                                                                                       |
|  [ 1. PostGIS ST_DWithin (100m) ]           [ 2. Device Clock Anti-Tamper ]                                           |
|  - Forces spatial intersection check        - Compares device clock with IDMC NPT NTP server                          |
|  - Inspector MUST be within 100 meters      - Submissions with drift > 300s are blocked                               |
|    of reported household / bahal            - Blocks fake GPS / mock location developer tools                         |
|                                                                                                                       |
|  [ 3. Hardware-Backed EXIF Signature ]      [ 4. 64-bit dHash Recycled Photo Block ]                                  |
|  - Pillow scrubs PII EXIF metadata          - Calculates 64-bit difference hash (dHash)                               |
|  - Payload signed locally via Android       - Compares against ward inspection history                                |
|    Keystore / iOS Secure Enclave            - Hamming distance <= 8 triggers RECYCLED_IMAGE_FRAUD                     |
|                                                                                                                       |
+-----------------------------------------------------------------------------------------------------------------------+
```

1. **PostGIS `ST_DWithin` 100m Household Anchor:** Every inspection forces an asynchronous spatial evaluation against the cadastral parcel:
   ```sql
   SELECT ST_DWithin(
       ST_SetSRID(ST_MakePoint(inspector_lng, inspector_lat), 4326)::geography,
       ST_SetSRID(ST_MakePoint(target_house_lng, target_house_lat), 4326)::geography,
       100.0
   );
   ```
   If the distance exceeds $100.0\,\text{m}$, submission is automatically rejected.
2. **Device Clock Drift & Mock Location Detection:** Field applications interrogate the OS location subsystem (`isFromMockProvider` / `isMockLocation`). If mock locations are enabled or if the client device clock diverges from IDMC National NTP time by $>300\,\text{seconds}$, the submission is blocked.
3. **Cryptographic Payload Signing:** Before image upload, the mobile app signs the combined tuple `(sanitized_image_bytes, dhash_hex, ward_id, timestamp)` using an asymmetric private key stored in the device's hardware security container (Android StrongBox / Apple Secure Enclave). The backend validates this signature before admitting the record to the database.
4. **64-Bit Difference Hashing (`dHash`):** To prevent workers from re-uploading yesterday's larvae snapshot or downloading stock internet images:
   - The image is downsampled to an $8 \times 9$ grayscale matrix.
   - 64 horizontal gradient comparisons are evaluated to generate a 16-character hexadecimal hash.
   - If the Hamming distance between the new upload and any snapshot submitted in that ward within the past 30 days is $\le 8$, the record is flagged for supervisor review.

---

## 5. Immutable 365-Day WORM Audit Ledger

To prevent corrupt officials or compromised administrators from retroactively altering dispatch logs, Breteau Indices, or chemical larvicide inventories:

1. **PostgreSQL Hash-Chained WORM Ledger:** All audit records are written to an append-only table `worm_audit_logs`. Each record contains a cryptographic link to its predecessor:
   $$\text{Hash}_n = \text{SHA-256}\left( \text{Hash}_{n-1} \parallel \text{CanonicalJSON}(\text{Payload}_n) \parallel \text{Timestamp}_{\text{UTC}} \right)$$
2. **PostgreSQL Database Triggers:** An immutable trigger intercepts all statements:
   ```sql
   CREATE OR REPLACE FUNCTION enforce_worm_audit_immutability()
   RETURNS TRIGGER AS $$
   BEGIN
       RAISE EXCEPTION 'WORM Violation: Records in worm_audit_logs cannot be modified or deleted.';
   END;
   $$ LANGUAGE plpgsql;
   ```
3. **MinIO Object Lock in `COMPLIANCE` Mode:** Audit ledgers and daily 1-Tap GIOMS PDF briefs are archived to MinIO object storage with Object Lock enabled in **`COMPLIANCE` mode** for a retention duration of **365 days**. Even an IDMC root system administrator cannot delete or overwrite these files before the statutory retention period expires.

---

## 6. DevSecOps Pipeline & Continuous Verification

Security is integrated directly into the CI/CD deployment pipelines (`.github/workflows/devsecops.yml` and `.gitlab-ci.yml`):

```
+-----------------------------------------------------------------------------------------------------------------------+
|                                  CONTINUOUS DEVSECOPS & SIEM ARCHITECTURE                                             |
+-----------------------------------------------------------------------------------------------------------------------+
|                                                                                                                       |
|  [Git Commit] ---> [Bandit] -------------> [SonarQube] ------------> [Trivy] -------------> [Production IDMC Deploy] |
|                    (Python Security        (Code Quality &           (Container & OS         (Bare-Metal Docker)      |
|                     AST Linter)             Security Hotspots)        Vulnerability Scan)                             |
|                                                                                                                       |
|  [Runtime Production] <-----------------------------------------------------------------------------------------------+
|         |                                                                                                             |
|         v                                                                                                             |
|  [Wazuh 24/7 SOC Agent]                                                                                               |
|  - Real-time login anomaly analysis                                                                                   |
|  - Brute Force (>= 50 attempts/min) -> Automated IP Blacklist                                                         |
|  - Impossible Travel (Pokhara to Kathmandu within 1 min) -> JWT Revocation + SysAdmin Telegram Alert                  |
|                                                                                                                       |
|  [HashiCorp Vault]                                                                                                    |
|  - Leases short-lived database credentials (TTL = 3600 seconds)                                                       |
|  - Ephemeral user v_mohp_<random> automatically destroyed upon lease expiration                                       |
|                                                                                                                       |
+-----------------------------------------------------------------------------------------------------------------------+
```

1. **HashiCorp Vault 60-Minute Ephemeral Leases:** The FastAPI backend does not maintain static database passwords in `.env` files. It dynamically authenticates to HashiCorp Vault via AppRole and requests ephemeral PostgreSQL credentials valid for exactly 60 minutes (`TTL = 3600s`).
2. **Wazuh 24/7 SOC Active Response:** If an attacker attempts to brute force staff accounts ($50\times/\text{min}$) or triggers an **Impossible Travel** condition (e.g., Ward Health Officer logging in from Pokhara, followed 60 seconds later by a login from an IP in Kathmandu), the Wazuh active response engine:
   - Blacklists the offending IP address in the local firewall.
   - Revokes the officer's active EdDSA JWT tokens.
   - Emits a Level-15 alert to the DoIT / IDMC Security Operations Center.
   - Dispatches an emergency SMS + Telegram alert to the on-call System Administrator.

---

## 7. Data Minimization & Privacy Act 2075 Compliance

SwasthyaDrishti enforces an uncompromising **Zero-Citizen-PII Architecture**:

- **No Citizen Identifiers:** The database schema has zero fields for citizen names, citizenship card numbers (*Nagarikta*), National Identity Card (*NID*) numbers, or personal mobile numbers.
- **In-Memory Facial Scrubber:** Any image uploaded containing human faces or portraits is rejected at the edge prior to entering the PaliGemma inference queue.
- **Spatial K-Anonymity:** Exact household GPS coordinates are encrypted with **AES-256-GCM** using a rotating master key. All public endpoints (e.g., Citizen Transparency Portal) truncate coordinates to **250m spatial grid centroids** or ward polygon boundaries.

---

## 8. Incident Reporting & Vulnerability Disclosure

If you discover a security vulnerability in SwasthyaDrishti, please do not open a public GitHub issue. Report it immediately to the national response team:

- **Institutional Authority:** Epidemiology and Disease Control Division (EDCD), Teku, Kathmandu
- **Cyber Coordination:** National Cyber Security Centre (NCSC), Ministry of Communication and Information Technology
- **Emergency Public Health Hotline:** **1115** (Hello Swasthya / *हेलो स्वास्थ्य*)
- **Direct Technical Reporting:** `security@nidaniq.gov.np` | PGP Key Fingerprint: `9D2A 4F18 B7C3 8920 E14D 6A5B 3F10 8891 NPT2 083`
