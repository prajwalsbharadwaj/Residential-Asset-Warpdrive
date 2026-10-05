# Understanding the Project: End-to-End Residential Real Estate Flow

## Executive Overview
This document outlines the comprehensive end-to-end business and technical lifecycle of an enterprise Indian residential real estate CRM implementation (modeled on premier developments such as **Bhartiya City Nikoo Homes** and **Phoenix Mills**).

It synthesizes the multi-persona operational journey, custom object architecture, declarative automations, and external ERP/banking touchpoints into a unified master reference.

---

## 1. High-Level Lifecycle Map

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        End-to-End Buyer & Operational Journey                          │
└───────┬───────────────────┬────────────────────┬──────────────────┬────────────────────┘
        │                   │                    │                  │
        ▼                   ▼                    ▼                  ▼
┌───────────────┐   ┌───────────────┐   ┌────────────────┐   ┌──────────────┐
│ 1. PRE-SALES  │   │ 2. SITE VISIT │   │ 3. PRICING &   │   │ 4. BOOKING   │
│ & LEAD INGEST │──▶│ & INVENTORY   │──▶│ COST SHEET     │──▶│ CONFIRMATION │
│ Portals + CTI │   │ LWC Floorplate│   │ CLP + GST/TDS  │   │ KYC & E-Sign │
└───────────────┘   └───────────────┘   └────────────────┘   └──────┬───────┘
                                                                    │
                                                                    ▼
                                                            ┌──────────────┐
                                                            │ 5. MILESTONE │
                                                            │ DEMAND & SOAK│
                                                            │ Escrow + SAP │
                                                            └──────┬───────┘
                                                                    │
                                                                    ▼
                                                            ┌──────────────┐
                                                            │ 6. HANDOVER  │
                                                            │ OR EXCEPTION │
                                                            │ Cancellation │
                                                            └──────────────┘
```

---

## 2. Detailed Lifecycle Stages

### Stage 1: Lead Capture & Pre-Sales Qualification
1. **Multi-Channel Lead Ingestion**:
   - Inbound enquiries stream from property portals (99acres, MagicBricks, Housing.com) and Meta/Google Ads via webhooks or Lead API into `Lead`.
   - Fields captured: `Project_Enquired__c`, `Budget_Range__c`, `Configuration_Interested__c`, and `LeadSource`.
2. **Telephony Integration (CTI)**:
   - Ozonetel/Exotel CTI automatically triggers a pop-up in the pre-sales agent console.
   - Click-to-call initiates contact within 60 seconds (Speed-to-Call metric). Call duration and recording links log to completed tasks.
3. **Qualification & Site Visit Scheduling**:
   - Agent qualifies budget, timeline, and funding readiness.
   - When buyer agrees to visit, agent creates a `Site_Visit__c` record linked to the Lead, auto-notifying the site sales manager via WhatsApp.

---

### Stage 2: Site Visit & Interactive Inventory Exploration
1. **Reception & Registration**:
   - Customer arrives at the sales gallery; receptionist checks in the visitor, updating `Site_Visit__c.Status__c = 'Conducted'`.
2. **Interactive LWC Inventory Explorer**:
   - The Sales Executive opens the **`Inventory Explorer`** LWC on their tablet/desktop.
   - Navigates the physical township hierarchy:
     $$\text{Project\_\_c} \longrightarrow \text{Tower\_\_c} \longrightarrow \text{Floor\_\_c} \longrightarrow \text{Unit\_\_c}$$
   - Color-coded status tiles render available inventory:
     - <span style="color:#00A859; font-weight:bold;">Available</span> (Emerald Green `#00A859`)
     - <span style="color:#D97706; font-weight:bold;">Blocked / Hold</span> (Amber)
     - <span style="color:#64748B; font-weight:bold;">Sold</span> (Slate Gray)
3. **Atomic Unit Soft-Lock**:
   - Sales Executive places a temporary 15-minute soft-lock on the selected unit, flipping `Unit__c.Status__c = 'Blocked'` to prevent concurrency collisions with other sales lounges.

---

### Stage 3: Opportunity Negotiation, Dynamic Pricing & Cost Sheet
1. **Lead Conversion**:
   - Lead converts into an `Opportunity` and `Account` (Customer Record Type).
   - Opportunity fields: `Tagged_Unit__c`, `Project__c`, `StageName = 'In Progress'`.
2. **Dynamic Pricing Engine**:
   - The Apex Pricing Engine evaluates the commercial cost sheet:
     $$\text{Agreement Value} = \text{Base Price} + \text{Floor Rise} + \text{PLC (Park/Corner View)} + \text{Amenities} + \text{Clubhouse}$$
   - **Statutory Taxes & Withholding**:
     - **GST**: 5% on under-construction CLP units; 0% (Schedule III) for Completed projects with Occupancy Certificate (OC).
     - **1% TDS (Section 194-IA)**: Auto-computed if total consideration $\ge$ ₹ 50,00,000.
3. **Payment Plan Selection**:
   - Buyer selects a structured plan from `Payment_Plan__c` (e.g., *Construction Linked Plan 10:80:10*, *Down Payment Plan*, or *Subvention Plan*).

---

### Stage 4: Booking Confirmation, Multi-Applicant KYC & E-Sign
1. **Booking Record Creation**:
   - When the Opportunity advances to `Closed Won` or the Booking Form is signed, the `Opportunity_Closed_Won_Booking` flow instantiates a `Booking__c` record.
   - `Unit__c.Status__c` permanently locks to `Sold`.
2. **Multi-Applicant KYC Capture**:
   - Junction object `Booking_Applicant__c` records each co-buyer linked to `Contact`:
     - Primary Applicant vs. Co-Applicant.
     - PAN validation and masked Aadhaar (`Aadhaar_Masked__c = 'XXXXXXXX9812'`).
     - Digital KYC verification via Digio intermediary API.
3. **Token Receipt & ERP Synchronization**:
   - Buyer pays the initial token advance (e.g., ₹ 2,00,000 via Razorpay).
   - A `Receipt__c` is logged with `Status__c = 'Pending Reconciliation'`.
   - Salesforce fires an asynchronous Queueable job to SAP S/4HANA to generate the Customer Master (`KNA1`) and Sales Order (`VA41`).

---

### Stage 5: Construction Milestones, Demand Generation & Financial Ledger
1. **Civil Milestone Trigger**:
   - As physical tower construction advances (e.g., *Completion of 5th Floor Slab*), the Project Engineer marks the milestone completed.
2. **Installment Schedule Generation**:
   - System activates child `Installment__c` records linked to `Booking__c`:
     $$\text{Installment Amount} = \text{Total Agreement Value} \times \text{Milestone\_Percentage\_\_c}$$
   - Demand Notice PDF generated and dispatched via automated Gupshup WhatsApp and email.
3. **Statutory RERA Dual-Escrow Routing**:
   - Payment links dynamically split gross inflows:
     - **70%** routed to RERA Designated Project Construction Escrow Bank Account.
     - **30%** routed to Builder Operational Account.
4. **Dual Maker-Checker Receipt Reconciliation**:
   - Sales/CRM logs inbound bank UTR into `Receipt__c` (`Pending Reconciliation`).
   - Only a Finance user with the `Finance_Demo` permission set can click **Approve**, shifting status to `Confirmed`.
   - Confirmed status updates `Installment__c.Paid_Amount__c` and clears outstanding balance.
5. **Overdue Interest Calculation**:
   - If an installment remains unpaid past `Due_Date__c`, the scheduled job/flow calculates simple interest at **18% p.a.**:
     $$\text{Interest} = \text{Outstanding Amount} \times 0.18 \times \left(\frac{\text{Days Overdue}}{365}\right)$$
   - Recorded on `Installment__c.Overdue_Interest__c` and displayed on the buyer's Statement of Account.

---

### Stage 6: Exception Handling, Transfer & Handover
1. **Cancellation & Forfeiture Evaluation**:
   - If a buyer requests cancellation, a `Cancellation_Request__c` record is raised.
   - System evaluates statutory deductions (Earnest Money Deposit forfeiture, brokerage recovery) and routes the net refund for Finance sign-off.
   - Upon final approval, `Booking__c.Status__c = 'Closed'` and `Unit__c.Status__c` reverts to `Available`.
2. **Key Handover & Possession**:
   - Once all installments, interest, maintenance charges, and stamp duty are 100% cleared, a digital Possession Letter is generated, and the unit transitions to `Handed Over`.

---

## 3. Custom Object Architecture Summary

| Object Name | Standard / Custom | Parent Entity | Business Purpose |
| :--- | :--- | :--- | :--- |
| `Project__c` | Custom Master | - | Real estate township master (RERA number, location) |
| `Tower__c` | Custom Master | `Project__c` (MD) | Wing / Tower master with construction status |
| `Floor__c` | Custom Master | `Tower__c` (MD) | Floor level in tower |
| `Unit__c` | Custom Inventory | `Floor__c` (MD) | Flat inventory (carpet area, price, status) |
| `Site_Visit__c` | Custom Activity | `Lead` / `Opp` / `Cust` | In-person customer tour tracking |
| `Payment_Plan__c` | Custom Template | - | Milestone template (CLP, Down Payment) |
| `Payment_Milestone__c`| Custom Template | `Payment_Plan__c` (MD)| Slab percentage and construction trigger |
| `Booking__c` | Custom Transact | `Unit__c` / `Account` | Confirmed flat allotment record |
| `Booking_Applicant__c`| Custom Junction | `Booking__c` (MD) | Multi-buyer KYC and financial applicant tracking |
| `Installment__c` | Custom Transact | `Booking__c` (MD) | Milestone installment schedule and overdue interest |
| `Receipt__c` | Custom Transact | `Installment__c` (MD) | Bank payment instruments & reconciliation status |
| `Cancellation_Request__c`| Custom Exception | `Booking__c` (Lookup)| Forfeiture and refund approval workflow |

---

## 4. Cross-Reference Index
- For integration APIs and external protocol specs, refer to:
  [INTEGRATION_TOUCHPOINTS_PITCH_GUIDE.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/INTEGRATION_TOUCHPOINTS_PITCH_GUIDE.md)
- For demo walkthrough click-paths and sample records, refer to:
  [README.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/README.md)
- For coding rules and styling tokens, explore:
  [salesforce-ai-framework/README.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/salesforce-ai-framework/README.md)
