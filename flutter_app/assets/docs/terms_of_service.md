# Terms of Service — Arogya Drishti (आरोग्य दृष्टि)

**National Digital Public Infrastructure for Vector-Borne Disease Control**
*Operating under the Information Technology Act, 2000, DPDP Act, 2023, and Municipal Public Health By-Laws*

**Document Version:** 1.0.0
**Effective Date:** October 23, 2026
**Last Updated:** October 23, 2026
**Jurisdiction:** Union Territory of Chandigarh, Republic of India

---

## 1. Acceptance of Terms and Agreement to Bound

These Terms of Service ("Terms" or "Agreement") constitute a legally binding agreement between you (the "User", "Authorized Officer", or "Field Worker") and the **Arogya Drishti Platform Authority**, operating in administrative coordination with the **Municipal Corporation of Chandigarh (MCC)** and the **Directorate of Health & Family Welfare** ("Authority", "We", "Us", or "Our").

BY AUTHENTICATING INTO THE AROGYA DRISHTI MOBILE APPLICATION VIA MOBILE NUMBER AND ONE-TIME PASSCODE (OTP), ACCESSING THE ADMINISTRATIVE COMMAND DASHBOARD, OR CONSUMING PLATFORM APIS, YOU EXPRESSLY ACKNOWLEDGE, AGREE, AND COVENANT THAT:
1. You have read, understood, and agreed to be legally bound by every provision of these Terms of Service;
2. You have read and accepted the companion [Privacy Policy](privacy_policy.md);
3. You possess the requisite legal and departmental authorization to act as an accredited health or sanitation agent of the Government of India or the relevant State/Union Territory Administration.

If you do not agree to these Terms in their entirety, you must immediately cease all access, close the application, and refrain from submitting any data or API calls.

---

## 2. Authorized Personnel and Access Eligibility

### A. Restrictive User Classification
The Arogya Drishti mobile client is a specialized Government Digital Public Infrastructure (DPI) tool engineered strictly for authorized public health and municipal vector control operations. Access is restricted exclusively to:
* **Accredited Frontline Workers:** Accredited Social Health Activists (ASHA), Auxiliary Nurse Midwives (ANM), and Multi-Purpose Health Workers (MPHW);
* **Municipal Sanitation Cadre:** Sanitary Sub-Inspectors, Sanitary Inspectors (SI), and Chief Sanitary Inspectors (CSI);
* **Clinical & Entomological Leadership:** Medical Officers of Health (MOH), District Surveillance Officers (DSO), Chief Medical Officers (CMO), and State Nodal Officers;
* **Emergency Dispatch Teams:** Municipal Ultra-Low Volume (ULV) fogging vehicle drivers and chemical spraying technicians.

### B. Authentication & Credential Security
* Access requires cryptographic verification of an Indian mobile number (+91) registered in the official Municipal Staff Directory.
* **Prohibition of Credential Sharing:** You shall not transfer, delegate, loan, disclose, or share your authentication session or device with unauthorized third parties or unverified civilians.
* Any act of impersonation, unauthorized credential acquisition, or simulated identity constitutes a cognizable offense punishable under **Section 43 and Section 66 of the Information Technology Act, 2000** and relevant sections of the Bharatiya Nyaya Sanhita (BNS).

---

## 3. Truthfulness, Integrity, and Accuracy of Field Surveillance Data

The mathematical accuracy of Arogya Drishti's 14-day predictive epidemiological models directly depends upon the empirical authenticity of on-ground entomological surveys:

1. **Mandatory Duty of Truthfulness:** Officers entering household inspection counts, container audits, and larval findings covenant that all logged metrics reflect genuine, physical, in-person surveys conducted at the specified geotagged coordinates.
2. **Prohibition of Fabricated Records ("Ghost Inspections"):** The submission of synthetic, fictitious, or falsified surveillance records—including logging uninspected houses, fabricating negative container counts, or simulating field presence via mock GPS locations—is strictly prohibited.
3. **Disciplinary & Legal Repercussions:** Falsification of statutory epidemiological logs directly jeopardizes public health containment during dengue, malaria, and chikungunya outbreaks. Any verified falsification shall be immediately escalated to the District Magistrate / Municipal Commissioner for disciplinary suspension and departmental proceedings under civil service conduct rules.

---

## 4. Artificial Intelligence, Computer Vision, and Decision Support Disclaimers

### A. Nature of AI Diagnostic Assistance
Arogya Drishti integrates cutting-edge artificial intelligence, including Google Earth Engine (GEE) satellite micro-climate telemetry, multi-variable epidemiological fusion models, and PaliGemma-powered edge computer vision:
* The automated detection of mosquito breeding sites, stagnant water surface classification, and larval identification bounding boxes represent **assistive, probabilistic decision-support diagnostics**.
* AI outputs are engineered to alert and prioritize vector hotspots; they do **not** replace professional clinical diagnosis or the statutory discretion of licensed entomologists and public health officers.

### B. Final Operational Authority
The ultimate operational decision to dispatch municipal chemical fogging vans, cordon off residential containment zones, issue containment challans, or apply chemical larvicides (such as Temephos, Bti, or Pyrethrum) remains with the licensed **Ward Sanitary Inspector**, the **Medical Officer of Health**, and the **District Health Authority**.

---

## 5. Prohibited Conduct and System Security

Users of Arogya Drishti are strictly forbidden from engaging in any of the following activities:
1. **Malicious Payloads & Cyber Exploits:** Attempting to inject SQL code, NoSQL payloads, cross-site scripting (XSS), malware, or harmful scripts into inspection forms, support ticket dialogues, or API parameters;
2. **Reverse Engineering & Scraping:** Decompiling, reverse engineering, disassembling, modifying, or scraping the Flutter application binary, backend APIs, or proprietary transmission index algorithms;
3. **Falsification of Emergency SOS Alerts:** Submitting false, malicious, or prank emergency vector outbreak tickets or van dispatch requests;
4. **Denial of Service (DoS):** Intentionally overloading the server infrastructure, bypassing SlowAPI rate limiters, or attempting denial-of-service attacks against Cloud Run or Firestore instances;
5. **Unauthorized External Data Leakage:** Exporting, leaking, or publishing confidential ward-level larval maps or citizen cluster locations to unauthorized media outlets, commercial marketing entities, or private organizations prior to formal governmental clearance.

Violations will result in instantaneous revocation of system privileges and immediate criminal referral to the Cyber Crime Police Station, UT Chandigarh and CERT-In.

---

## 6. Intellectual Property Rights and Open Source Standards

* **Platform Ownership:** The visual layout, graphic trademarks, backend algorithms, architectural schematics, and system documentation of Arogya Drishti are the intellectual property of the project creators (Team Rocket, Chandigarh University) and the sovereign Government of India / Municipal Corporation.
* **Open Source Agent Skill Standards:** Specific sub-modules—including the Autonomous Vector Surveillance Agent Skill (`skills/vector-surveillance-skill/`) and open integration harnesses—are released under the **Apache License, Version 2.0**. Use of these open components is governed by the terms specified in the root [`LICENSE`](../../LICENSE) file.
* **Epidemiological Data Sovereignty:** All aggregate disease surveillance indices, GIS vectors, and municipal inspection ledgers generated through the platform remain the permanent, sovereign public property of the Republic of India.

---

## 7. Limitation of Liability and Disclaimer of Warranties

### A. "As-Is" and "As-Available" Operational Basis
Arogya Drishti is provided on an "AS-IS" and "AS-AVAILABLE" basis for governmental public service. While engineered to achieve 99.9% uptime with high-availability serverless infrastructure, the Authority does not warrant that:
* The application will operate without uninterrupted, error-free periods during nationwide telecommunication outages;
* GPS coordinates provided by field devices will remain free of atmospheric or urban canyon drift;
* Earth Engine satellite passes will be free from temporary cloud cover obstruction (mitigated by automated Sentinel-1 SAR radar fallbacks).

### B. Limitation of Damages
TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE INDIAN LAW, NEITHER THE PLATFORM DEVELOPERS, MUNICIPAL AUTHORITIES, NOR GOVERNING HEALTH BODIES SHALL BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES ARISING FROM:
* Loss of field data resulting from physical hardware damage, device battery exhaustion, or extreme field weather conditions;
* Operational delays in fogging van arrivals due to severe vehicular traffic, civic blockades, or municipal mechanical breakdowns;
* Any clinical decisions or citizen medical interventions undertaken outside authorized public healthcare protocols.

---

## 8. Suspension, Revocation, and Termination of Service

The Platform Administrator reserves the sovereign right, without prior notice or liability, to:
1. Immediately suspend or permanently terminate an officer's access credentials upon verification of departmental transfer, retirement, resignation, or disciplinary action;
2. Revoke API tokens, invalidate JWT sessions, or blacklist IP addresses demonstrating malicious behavioral signatures or repeated unauthorized requests;
3. Suspend specific municipal wards from the automated dispatch pipeline during statewide civil emergencies or conflicting military drills.

---

## 9. Compliance with DPDP Act, 2023 and Data Protection

Officer personal data is collected and processed in strict adherence to the **Digital Personal Data Protection Act, 2023**. For detailed information regarding our data minimization practices, zero-citizen-PII redaction, and in-country sovereign storage in the **Google Cloud Platform Mumbai Region (`asia-south1`)**, please refer to our [Privacy Policy](privacy_policy.md).

---

## 10. Governing Law, Dispute Resolution, and Judicial Jurisdiction

1. **Governing Law:** These Terms of Service, their interpretation, validity, and enforcement shall be governed strictly and exclusively by the substantive laws of the **Republic of India**.
2. **Administrative Amicable Resolution:** In the event of any operational dispute, administrative grievance, or interpretation ambiguity between field staff and the platform administration, the parties shall first submit the matter for amicable resolution to the **Nodal Grievance Officer** and the **Commissioner, Municipal Corporation of Chandigarh**.
3. **Exclusive Judicial Jurisdiction:** Any unresolved legal proceeding, dispute, or lawsuit arising out of or in connection with these Terms or the use of Arogya Drishti shall be instituted exclusively in the competent Courts, Tribunals, or Forums located within the territorial limits of **Chandigarh, India**.

---

## 11. Official Contact Coordinates and Departmental Support

For legal inquiries, regulatory compliance queries, or statutory notifications, contact:

* **Authority:** Arogya Drishti Legal & Technical Compliance Cell
* **Nodal Officer:** Shri Shivam Yadav, Lead System Architect
* **Administrative Complex:** Municipal Corporation Building, Sector 17, Chandigarh — 160017, India
* **Legal Compliance Email:** `legal@arogyadrishti.in` / `academyxshivam@gmail.com`
* **Official Nodal Telephone:** +91 172 2700000 / +91 99155 49458
