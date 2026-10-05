# Residential Real Estate CRM — Demo Implementation

This repository contains a working, source-driven Salesforce CRM implementation designed for an Indian residential real estate developer. Built for stakeholder walkthroughs and live demos, it showcases the end-to-end buyer lifecycle from enquiry, site visits, and inventory selection to booking, milestone-based installment demand, payment receipt reconciliation, and overdue interest calculations.

---

## 1. What Got Deployed

### Custom Objects & Relationships
1. **`Project__c`**: Real estate township / project master (`Location__c`, `Status__c`, `RERA_Registration_Number__c`, `Total_Towers__c`, `Description__c`).
2. **`Tower__c`**: Tower / Wing / Block master (`Total_Floors__c`, `Construction_Status__c`) — Master-Detail to `Project__c`.
3. **`Floor__c`**: Floor level (`Floor_Number__c`, `Units_Per_Floor__c`) — Master-Detail to `Tower__c`.
4. **`Unit__c`**: Individual flat / apartment inventory (`Configuration__c`, `Carpet_Area_SqFt__c`, `Super_Built_Up_Area_SqFt__c`, `Base_Price__c`, `Total_Price__c`, `Status__c`, `SAP_Material_Code__c`) — Master-Detail to `Floor__c`.
5. **`Site_Visit__c`**: In-person visitor management (`Lead__c`, `Opportunity__c`, `Customer__c`, `Visit_Date_Time__c`, `Status__c`, `Rating__c`, `Feedback__c`, `Sales_Executive__c`).
6. **`Payment_Plan__c`**: Milestone template structures (`Plan_Type__c`, `Active__c`, `Description__c`).
7. **`Payment_Milestone__c`**: Construction/time milestone line items (`Milestone_Percentage__c`, `Milestone_Order__c`, `Trigger_Event__c`, `Days_From_Booking__c`) — Master-Detail to `Payment_Plan__c`.
8. **`Booking__c`**: Confirmed customer flat booking (`Customer__c`, `Opportunity__c`, `Unit__c`, `Payment_Plan__c`, `Booking_Date__c`, `Total_Booking_Amount__c`, `Status__c`, `SAP_Customer_Code__c`, `Tower_Incharge__c`).
9. **`Booking_Applicant__c`**: Multi-applicant junction (`Contact__c`, `Applicant_Role__c`, `Is_Financial_Applicant__c`, `PAN__c`, `Aadhaar_Masked__c`, `KYC_Status__c`) — Master-Detail to `Booking__c`.
10. **`Installment__c`**: Payment schedule row (`Payment_Milestone__c`, `Due_Date__c`, `Amount__c`, `Paid_Amount__c`, `Outstanding_Amount__c`, `Status__c`, `Overdue_Interest__c`, `Days_Overdue__c`, `Interest_Waived__c`) — Master-Detail to `Booking__c`.
11. **`Receipt__c`**: Payment instrument logging (`Installment__c`, `Receipt_Date__c`, `Amount__c`, `Payment_Mode__c`, `Transaction_Reference__c`, `Status__c`, `Reconciliation_Notes__c`).
12. **`Cancellation_Request__c`**: Exception handling & refund evaluation (`Booking__c`, `Request_Date__c`, `Reason__c`, `Status__c`, `Total_Paid_Amount__c`, `Cancellation_Charges__c`, `Refund_Amount__c`, `Remarks__c`).

### Standard Object Extensions & Record Types
- **`Opportunity`**: Tagged to `Project__c` and `Tagged_Unit__c`, with checkboxes `Booking_Form_Approved__c` and `Token_Payment_Received__c`.
- **`Lead`**: Tagged to `Project_Enquired__c`, `Budget_Range__c`, and `Configuration_Interested__c`. Real estate sources added: *Website, 99acres, MagicBricks, Facebook Ads, Walk-in, Channel Partner*.
- **`Account`**: Record Types `Customer` (Individual Buyer) and `Channel_Partner` (Broker Firm), with `RERA_Number__c` and `Agency_Name__c`.
- **Opportunity Sales Stages & Path**:
  `New` $\rightarrow$ `SV Scheduled` $\rightarrow$ `In Progress` $\rightarrow$ `SV Done` $\rightarrow$ `Qualified` $\rightarrow$ `Application In Progress` $\rightarrow$ `Booking Form in Approval` $\rightarrow$ `Booking Form Approved` $\rightarrow$ `Closed Won` / `Closed Lost`.
- **Booking Status Path**:
  `New` $\rightarrow$ `KYC in Progress` $\rightarrow$ `Approved` $\rightarrow$ `Active` $\rightarrow$ `Closed`.

### Dedicated Lightning Application & UX
- **`Residential_Sales_CRM`**: Custom Lightning app with tailored navigation bar, branded header theme, and custom tabs for all residential entities.
- **Custom Page Layouts**: 12 custom layouts grouping fields into Identification, Specifications/Financials, and Status.
- **Permission Sets & Profiles**:
  - `Admin` Profile: Full native Read, Write, Edit, Delete, View All, Modify All on all objects, plus FLS (Read/Edit) across all fields.
  - `Sales_Exec_Demo`: Pre-Sales & Sales team access (Leads, Opps, Quotes, Site Visits, Inventory view).
  - `CRM_Team_Demo`: Post-sales CRM team access (Bookings, Applicants, Installments, Receipts).
  - `Finance_Demo`: Finance team access (Receipt reconciliation, Cancellation reviews).
  - `Residential_Sales_Admin`: Full administrative and execution access.

### Declarative Automation (Flows & Approvals)
1. **`Opportunity_Closed_Won_Booking` (Record-Triggered Flow)**:
   When an Opportunity reaches `Closed Won` with a tagged unit, it auto-creates a `Booking__c` record with customer details and commercial amount, and updates the `Unit__c.Status__c` to `Sold`.
2. **`Installment_Calculate_Overdue_Interest` (Record-Triggered Flow)**:
   When an Installment has `Status__c = 'Due'`, `Interest_Waived__c = false`, and `Due_Date__c < TODAY`, it calculates simple interest at **18% p.a.** on `Outstanding_Amount__c`, sets `Status__c = 'Overdue'`, and records `Days_Overdue__c`.
3. **`Log_Receipt` (Screen Flow) & Quick Action**:
   Guided modal on `Installment__c` allowing CRM users to log payments, auto-defaulting `Status__c = 'Pending Reconciliation'` and linking to the installment.
4. **`Receipt_Approval_Process` (Approval Process)**:
   Enforces Finance cross-check for receipts starting in `Pending Reconciliation`. Approving the record automatically updates `Status__c = 'Confirmed'`.

---

## 2. Demo Data Summary

The org is pre-seeded with realistic Indian residential real estate data (`scripts/apex/load_demo_data.apex`):

- **Projects (2)**:
  - *Bhartiya City Nikoo Homes IV* (Thanisandra Main Rd, Bengaluru; RERA: `PRM/KA/RERA/1251/472/PR/210526/004123`)
  - *Bhartiya City Leela Residences* (Hebbal, Bengaluru; RERA: `PRM/KA/RERA/1251/309/PR/190820/002814`)
- **Towers (4)**: Tower A (Aspire), Tower B (Breeze), Tower 1 (Orchid), Tower 2 (Palms).
- **Floors (12)**: 3 floors per tower.
- **Units (72)**: 6 units per floor across 2 BHK, 2.5 BHK, 3 BHK, 4 BHK configurations with realistic carpet areas (980 – 2,250 sq.ft.) and prices (₹ 95L – ₹ 2.6Cr). Statuses reflect a live mix of *Available*, *Blocked*, and *Sold*.
- **Leads (10)**: Across top property portals and ad sources (Website, 99acres, MagicBricks, FB Ads, Walk-in, Channel Partner).
- **Opportunities (5)**: At various stage gates across the pipeline.
- **Bookings (3 + auto-created)**:
  - *Booking 1 (Arjun Mehta)*: Active booking with paid token installment.
  - *Booking 2 (Meera Nambiar)*: In-flight deal used to demo live Opportunity Closed Won transition.
  - *Booking 3 (Suresh Hegde)*: Features a deliberately **Overdue Installment** (due 45 days ago) with ₹ 21,415.07 accrued interest calculated at 18% p.a.
- **Receipts (2)**:
  - `RCPT-0000`: Confirmed token payment for Booking 1.
  - `RCPT-0001`: **Pending Reconciliation** payment (₹ 9,65,000 via NEFT/RTGS with UTR `ICICI-UTR-90182746192`) ready for the live approval demonstration.
- **Cancellation Request (1)**: Draft request on Booking 1 to show exception handling.

---

## 3. Walkthrough Click-Path for Stakeholders

Follow this narrative sequence to deliver an impactful, cohesive demonstration:

```
[1. App Launcher] -> Select "Residential Sales CRM"
      |
[2. Inventory]   -> Open "Bhartiya City Nikoo Homes IV" -> Drill down: Tower A -> Floor 1 -> Units
      |
[3. Lead & SV]   -> Open Lead "Deepak Patel" (Walk-in) -> Show Site Visit (Conducted / Hot)
      |
[4. Opportunity] -> Open Opp "Vikram Malhotra - Nikoo A-102 Deal" -> Show Stage Path & Tagged Unit
      |
[5. LIVE FLOW 1] -> Open Opp "Meera Nambiar - Nikoo B-203 Deal"
                 -> Advance Stage: Click "Closed Won" on Stage Path -> Save
                 -> Observe: Unit B-203 turns "Sold" and new Booking record is created automatically!
      |
[6. Booking]     -> Open Booking for "Suresh Hegde"
                 -> Inspect "Booking Applicants" junction (Primary & Co-Applicant, PAN, KYC Status)
                 -> Scroll to "Installments" related list
      |
[7. LIVE FLOW 2] -> Open Installment "INST-0004" (Milestone: Agreement Execution)
                 -> Observe: Days Overdue = 45, Overdue Interest = ₹ 21,415.07 (18% p.a. simple interest formula)
      |
[8. LIVE FLOW 3] -> On the Installment, click the quick action: "Log Receipt"
                 -> Enter Payment Mode = NEFT, UTR = "HDFC-RTGS-89102", Submit
                 -> Verify: Receipt is created with Status = "Pending Reconciliation"
      |
[9. APPROVAL]    -> Open Receipt "RCPT-0001"
                 -> Scroll to "Approval History" -> Click "Approve" (as Finance User)
                 -> Observe: Receipt Status flips to "Confirmed" (triggering simulated SAP accounting sync)
```

---

## 4. Useful CLI Commands

- **Open Org:**
  ```bash
  sf org open --target-org prajwalsfd@gmail.com
  ```
- **Re-seed Demo Data:**
  ```bash
  sf apex run --file scripts/apex/load_demo_data.apex --target-org prajwalsfd@gmail.com
  ```
- **Retrieve Package Metadata:**
  ```bash
  sf project retrieve start --target-org prajwalsfd@gmail.com
  ```
