# Reusable Personal Org Components & Pitch Catalog

This directory houses all custom modules, schemas, workflows, and Lightning Web Components originally built and demonstrated in the personal developer environment (`prajwalsfd@gmail.com`). 

These components are isolated from UAT deployments via `.forceignore` to ensure **100% safety of the client's `uat-sandbox`**. They serve as your **pitchable asset library** when presenting new residential CRM capabilities to clients.

---

## Directory Architecture

```
reusable-personal-components/
├── lwc/                           # Personal Pitch LWCs
│   ├── bookingKycHub/             # Booking Form & Customer KYC Verification Hub
│   ├── quoteCommercialEditor/     # Interactive Quote Commercial Editor & Discounts
│   ├── residentialCostSheet/      # Residential Cost Sheet & Pricing Breakdown
│   ├── customerLedgerHub/         # Financial Ledger, Demand Tracker & Collections
│   ├── digioVerificationHub/      # DigiO Aadhar/PAN e-KYC & Biometric e-Sign
│   ├── paymentGatewayCard/        # Razorpay/PayU Payment Gateway Direct Checkout
│   ├── sapSyncBanner/             # SAP S/4HANA Sync Status Header Banner
│   ├── sapSyncCard/               # SAP Customer/Sales Order Sync Actions Card
│   ├── allotmentLetterModal/      # Dynamic Allotment Letter Generator
│   ├── welcomeLetterModal/        # Welcome Letter PDF Generator Modal
│   ├── statementOfAccountModal/   # Statement of Account (SOA) Viewer Modal
│   └── bookingSnapshot/           # Executive Booking Snapshot Card
│
├── flexipages/                    # Personal Lightning Record Pages
│   ├── Booking_Record_Page.flexipage-meta.xml      # Booking with KYC & Ledger
│   ├── Opportunity_Record_Page.flexipage-meta.xml  # Deal with Cost Sheet & Payment Gateway
│   ├── Quote_Record_Page.flexipage-meta.xml        # Quote with Commercial Editor
│   ├── Lead_Record_Page.flexipage-meta.xml         # Lead Pipeline Layout
│   └── Account_Record_Page.flexipage-meta.xml      # Account Page Layout
│
├── quickActions/                  # Quick Action Definitions
│   ├── Booking__c.Generate_Allotment_Letter.quickAction-meta.xml
│   ├── Opportunity.Generate_Welcome_Letter.quickAction-meta.xml
│   └── Booking__c.View_Statement_Of_Account.quickAction-meta.xml
│
├── objects/                       # Personal Data Model & Custom Fields
│   ├── Booking_Applicant__c/      # Co-applicant tracking object
│   ├── Cancellation_Request__c/   # Cancellation and refund approvals
│   ├── Installment__c/            # Flat milestone installment tracking
│   ├── Payment_Milestone__c/      # Template payment plan milestones
│   ├── Project__c/                # Standalone project master object
│   ├── Receipt__c/                # Standalone cashiering receipts
│   └── Opportunity/fields/        # Fields: Tagged_Unit__c, Booking_Form_Approved__c, Token_Payment_Received__c
│
└── flows/                         # Automation & Interest Engines
    ├── Installment_Calculate_Overdue_Interest.flow-meta.xml # 18% p.a. daily interest accrual
    ├── Log_Receipt.flow-meta.xml                            # Instant receipt cashiering
    └── Opportunity_Closed_Won_Booking.flow-meta.xml         # Auto-booking creation on Closed-Won
```

---

## Pitch Catalog & Common-Ground Matrix

When pitching these features to the client and finding common ground, use this mapping to see how they connect to UAT:

| Personal Pitch Feature | What It Demonstrates to Client | How It Maps to UAT Enterprise Architecture |
| :--- | :--- | :--- |
| **Booking Form & KYC Hub** (`bookingKycHub`) | Multi-step applicant onboarding, PAN/Aadhar document upload, and KYC verification before booking lock. | Maps to UAT's `Booking__c` + `Co_Owner__c` + Digio e-Sign integration. |
| **Quote Commercial Editor** (`quoteCommercialEditor`) | Real-time unit quotation, parking add-on pricing, floor-rise calculations, and sales manager discount thresholds. | Maps to UAT's `Quote` + `Payment_Plan_Id__c` + discount approval matrices. |
| **Residential Cost Sheet** (`residentialCostSheet`) | Visual breakdown of Basic Sale Price (BSP), GST, club charges, car parking, and milestone schedule. | Maps to UAT's `Unit__c.Total_Cost__c` & `Payment_Schedule__c`. |
| **Customer Ledger Hub** (`customerLedgerHub`) | Real-time statement of dues, aging breakdown (30/60/90 days), and overdue interest penalty accrual. | Maps to UAT's `CustomerLedgerController` + `Ledger_Entry__c` + `Booking_Payment_Schedule__c`. |
| **DigiO KYC & e-Sign** (`digioVerificationHub`) | Automated KYC verification with UIDAI/NSDL and Aadhaar OTP e-Signing of allotment letters. | Can be plugged into UAT's `Booking__c` tripartite agreement flow. |
| **Payment Gateway Checkout** (`paymentGatewayCard`) | Instant payment link generation (UPI, Netbanking, Credit Card) for token amounts and milestone dues. | Maps to UAT's `Payment_Receipt__c` + ERP payment reconciliation. |
| **SAP S/4HANA Sync Cards** (`sapSyncBanner`, `sapSyncCard`) | Visual real-time indicator of whether customer master & sales orders are synced with SAP ERP. | Maps to UAT's native `Retry_SAP_Sync` quick actions and `SAP_Sync_Status__c` fields. |
| **Document Modals** (`allotmentLetterModal`, `welcomeLetterModal`, `statementOfAccountModal`) | One-click branded PDF generation and preview for Welcome Letters, Allotment Letters, and SOAs. | Maps to UAT's `generateWelcomeLetter`, `generateSOAbutton`, and `generateCarParkAllotmentLetter`. |

---

## Protection & Deployment Guardrails

1. **UAT Isolation Guarantee**:
   *   `reusable-personal-components/**` is listed in [`.forceignore`](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/.forceignore).
   *   Running any standard deploy command (e.g. `sf project deploy start`) will **never** package, touch, or deploy anything from this directory to `uat-sandbox`.
2. **Deploying to Personal Org Only**:
   *   To push or test these components in your personal developer org:
       ```bash
       sf project deploy start --source-dir reusable-personal-components --target-org prajwalsfd@gmail.com
       ```
3. **Primary Active Target**:
   *   Default org: `uat-sandbox` (`prajwal.bharadwajuat@warpdrivetech.in`).
   *   Primary directory: [`force-app/`](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/force-app).
