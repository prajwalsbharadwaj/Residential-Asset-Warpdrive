# Project Context & AI Persona Blueprint Template

> **Instructions for Author / AI Agent**: Populate this document to provide comprehensive domain context, architectural rules, and operational boundaries for any AI coding assistant or engineer onboarding onto the repository.

---

# Project Context: [Project Name, e.g., Residential Real Estate CRM]

## 1. Project Identity & Domain Background
- **Client / Developer**: [e.g., Bhartiya City Developers / Phoenix Mills]
- **Industry & Domain**: [e.g., Residential & Mixed-Use Real Estate Development]
- **Geographic Market**: [e.g., India (Bengaluru / Mumbai Metro)]
- **Regulatory Frameworks**:
  - **RERA**: Real Estate (Regulation and Development) Act (Mandates 70:30 bank escrow split, project registration disclosure, milestone-linked demands).
  - **Statutory Taxation**: 1% TDS under Section 194-IA on property value $\ge$ ₹50 Lakhs; 5% GST on Under-Construction CLP vs 0% GST (Schedule III) for Completed OC Received inventory.
  - **Data Privacy**: Digital Personal Data Protection (DPDP) Act (Mandates Aadhaar masking and PII encryption).

---

## 2. Business Objectives & Core KPIs
1. **Accelerate Speed-to-Call**: Ingest leads from portals (99acres, MagicBricks, Meta) into CTI within 60 seconds.
2. **Eliminate Inventory Double-Booking**: Atomic unit locking with real-time floor plate status.
3. **Automate Milestone Demands**: Generate CLP (Construction Linked Plan) installments with simple interest calculations at 18% p.a.
4. **Enforce Dual Maker-Checker Governance**: Ensure sales cannot confirm receipts without Finance Controller sign-off.

---

## 3. Technology Stack & System Landscape

```
┌────────────────────────────────────────────────────────┐
│                   System Landscape                     │
├────────────────────┬──────────────────┬────────────────┤
│ System / Layer     │ Technology       │ Purpose        │
├────────────────────┼──────────────────┼────────────────┤
│ Core CRM           │ Salesforce Ent.  │ Central System │
│ UI Components      │ LWC (Vanilla CSS)│ Custom portals │
│ ERP (Inventory/FI) │ SAP S/4HANA      │ Source of Truth│
│ Telephony / CTI    │ Ozonetel/Exotel  │ Click-to-call  │
│ Digital KYC/E-Sign │ Digio / DocuSign │ PAN/Aadhaar    │
│ Payment Gateway    │ Razorpay / HDFC  │ RERA Escrow PG │
│ Communications     │ Gupshup / Twilio │ WhatsApp / SMS │
└────────────────────┴──────────┴───────┴────────────────┘
```

---

## 4. Key Personas & Roles Matrix

| Persona Code | Role / Title | Primary Responsibilities | Default Profile / Perm Set |
| :--- | :--- | :--- | :--- |
| `P-SALES` | Sales Executive | Lead tours, site visits, unit locking, booking | `Sales_Exec_Demo` |
| `P-CRM` | Post-Sales Officer | KYC verification, demand dispatch, allotment | `CRM_Team_Demo` |
| `P-FIN` | Finance Controller| Receipt reconciliation, SAP sync, cancellations | `Finance_Demo` |
| `P-ADMIN` | System Administrator| Schema, flows, apex deployments, security | `Residential_Sales_Admin` |

---

## 5. Architectural Guardrails & Coding Conventions
- **UI Design System**:
  - Strict **Light-Mode** only. No dark backgrounds.
  - Primary Accent: `#00A859` (WarpDrive Emerald Green).
  - Mint Surface: `#ECFDF5` with `#A7F3D0` border and `#065F46` forest text.
  - Pill geometry (`border-radius: 9999px`) on all primary buttons.
  - Numbered circular badges (`01`, `02`, `04`).
- **Apex Standards**:
  - 100% bulkified (200 records).
  - Explicit sharing (`with sharing` by default).
  - User Mode enforced (`WITH USER_MODE`, `as user`).
  - Minimum 90% test coverage with meaningful assertions.
- **Integration Standards**:
  - Named Credentials only; zero hardcoded secrets.
  - Idempotency checks on all incoming webhooks.

---

## 6. Repository & Development Guidelines
- **Project Structure**: Source-format SFDX project (`force-app/main/default`).
- **Default Target Org**: `prajwalsfd@gmail.com`
- **CLI Commands**:
  ```bash
  # Deploy specific metadata
  sf project deploy start --source-dir force-app/main/default --target-org <alias>

  # Run all Apex tests
  sf apex test run --code-coverage --result-format human --target-org <alias>
  ```
