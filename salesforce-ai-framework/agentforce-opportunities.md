# Salesforce Agentforce — Enterprise Real Estate Opportunity Blueprint

> **Strategic Architecture & Implementation Guide for Deploying Autonomous & Assistive Agents in Residential Real Estate CRM**

---

## 1. Executive Summary & Architecture

Salesforce **Agentforce** (powered by the Atlas Reasoning Engine) transforms real estate operations from static forms and delayed human queues into proactive, 24/7 autonomous experiences.

In a residential township development (such as Bhartiya City or Phoenix Mills), Agentforce operates across two primary domains:
1. **Customer-Facing Autonomous Agents**: Ingested via WhatsApp and Web Portals to handle pre-sales site visit discovery, localized neighborhood guidance, inventory recommendations, and post-sales payment ledger tracking.
2. **Internal Employee Assistive Agents**: Embedded in Salesforce Lightning to assist Sales Executives, Finance Controllers, and Channel Partner managers with instant cost sheets, UTR bank reconciliation, and lead intelligence.

```
                                  ┌────────────────────────────────────────────────────────┐
                                  │                     CHANNELS                           │
                                  │   WhatsApp  │  Experience Cloud  │  LWC Utility Bar    │
                                  └─────────────────────────┬──────────────────────────────┘
                                                            │
                                                            ▼
                                  ┌────────────────────────────────────────────────────────┐
                                  │             AGENTFORCE ATLAS REASONING ENGINE          │
                                  │      Intent Analysis  │  Context Evaluation            │
                                  └─────────────────────────┬──────────────────────────────┘
                                                            │
                     ┌──────────────────────────────────────┴──────────────────────────────────────┐
                     ▼                                                                             ▼
    ┌─────────────────────────────────┐                                           ┌─────────────────────────────────┐
    │     TOPICS & GUARDRAILS         │                                           │       ACTIONS & RETRIEVAL       │
    │  - Township Amenities & Geo     │                                           │  - Invocable Apex (Unit Query)  │
    │  - Unit Recommendation Engine   │                                           │  - Autolaunched Flows (Booking) │
    │  - Payment & Ledger Tracking    │                                           │  - Data Cloud Vector Grounding  │
    │  - Site Visit Appointment Mgr   │                                           │  - Prompt Templates / Citations │
    └─────────────────────────────────┘                                           └─────────────────────────────────┘
```

---

## 2. Comprehensive Agentforce Opportunity Matrix

| # | Agent Name | Audience | Channel | Primary Capabilities | Core Impact |
| :-: | :--- | :--- | :--- | :--- | :--- |
| **1** | **Township Concierge & Property Finder** | Prospective Buyers | WhatsApp, Portal | Neighborhood POIs (schools, hospitals), Unit recommendations, 3D tour links, Site Visit booking | **Zero Lead Leakage**, Instant 24/7 Response |
| **2** | **Post-Sales Financial & Ledger Agent** | Confirmed Buyers | WhatsApp, Buyer App | Payment/UTR verification, receipt status, overdue balance, Statement of Account (SOA) PDF | **80% Reduction in Call-Center Inquiries** |
| **3** | **Sales Executive Co-Pilot** | Sales Reps / Site Managers | Salesforce Lightning, Mobile | Pre-visit buyer briefs, instant CLP cost sheets, objection battlecards, dynamic quotation generation | **Saves 25 Mins per Site Visit** |
| **4** | **Finance Reconciliation Assistant** | Finance & Accounts | Salesforce Lightning | Unmatched UTR bank feed matching, dual maker-checker audit, overdue interest waiver evaluation | **Accelerates Month-End Ledger Close** |
| **5** | **Channel Partner (Broker) Concierge** | Real Estate Brokers | WhatsApp, Broker Portal | Client registration conflict check, commission milestone status, marketing collateral dispatch | **Fosters Broker Loyalty & Trust** |

---

## 3. Deep-Dive: The 5 High-Impact Agents

---

### Agent 1: Township Concierge & Property Finder (Buyer-Facing)
**Persona**: *Nikoo Township Digital Host*  
**Channel**: WhatsApp Business (Gupshup) & Experience Cloud Web Chat  
**Primary Goal**: Warm up cold portal leads, answer localized township living questions, recommend matching units, and confirm in-person site visits.

#### Topics & Conversational Guardrails
1. `Township_Infrastructure`: Answers distances to healthcare, international schools, transit corridors, IT parks, and internal amenities (supermarkets, Olympic swimming pools, central park).
2. `Inventory_Matchmaker`: Conversational discovery of budget, family configuration (2 vs 3 BHK), floor preference (low rise vs penthouse), and Vastu orientation (East/North facing).
3. `Site_Visit_Scheduler`: Proposes and confirms calendar slots, dispatches Google Maps pin and gate check-in QR code.

#### Real-World Conversational Flow
> **Buyer**: *"Hi, I'm looking for a 3 BHK near Hebbal. How far is Aster CMI Hospital and are there any international schools inside the township?"*
>
> **Agentforce**: *"Hello! Welcome to Bhartiya City Nikoo Homes. 🏥 **Aster CMI Hospital** is just **12 minutes** away via the express flyover. Within the township itself, we have an on-campus **Chaman Bhartiya International School** (walking distance from Tower A & B), along with a 24/7 Apollo Pharmacy and Lulu Daily Supermarket.  
>  
> For a **3 BHK**, we have spacious options starting at **₹ 1.45 Cr** (1,480 sq.ft. carpet area) in Tower A with park-facing balconies. Would you like to see floor plans or schedule a VIP site tour this Saturday?"*

#### Actions & Invocable Tools
- `Get_Township_POI_Details`: Grounded in Salesforce Knowledge & Vector Database containing township master plan, distance matrix, and amenities.
- `Recommend_Units_By_Criteria`: Invocable Apex executing dynamic selective SOQL on `Unit__c` (`Status__c = 'Available'`).
- `Create_Site_Visit_Appointment`: Autolaunched Flow creating `Site_Visit__c` and generating WhatsApp confirmation message.

---

### Agent 2: Post-Sales Financial & Ledger Agent (Buyer-Facing)
**Persona**: *Residential Customer Care & Ledger Assistant*  
**Channel**: WhatsApp Business & Buyer Self-Service Portal  
**Primary Goal**: Instant answers on payment instruments, bank UTR tracking, receipt statuses, demand notices, and overdue balance.

#### Topics & Conversational Guardrails
1. `Payment_Status_Check`: Queries recent transactions, informs user if UTR is received and whether receipt is *Pending Reconciliation* or *Confirmed*.
2. `Milestone_Demand_Inquiry`: Explains current construction stage (e.g., "5th Floor Slab Casted") and upcoming due date.
3. `Statement_of_Account_Dispatch`: Generates official PDF Statement of Account and delivers directly in chat.

#### Real-World Conversational Flow
> **Buyer**: *"I transferred ₹ 9,65,000 via NEFT yesterday from ICICI Bank (UTR: ICICI-UTR-90182746192). Has my payment been acknowledged? Also, send my receipt."*
>
> **Agentforce**: *"Thank you, Mr. Hegde. I found your transaction:  
> - **Amount**: ₹ 9,65,000.00  
> - **UTR**: `ICICI-UTR-90182746192`  
> - **Status**: **Pending Reconciliation** (Logged in system; our Finance desk is completing standard bank clearing).  
>  
> Your official provisional receipt `RCPT-0001` has been generated. As soon as the bank statement clears (typically within 4-6 business hours), you will receive the final digitally signed receipt right here on WhatsApp!  
>  
> Would you like me to send your current **Statement of Account** showing your remaining milestone balance?"*

#### Actions & Invocable Tools
- `Query_Payment_By_UTR`: Invocable Apex querying `Receipt__c` and `Installment__c` by `Transaction_Reference__c`.
- `Generate_Statement_Of_Account_PDF`: Calls Visualforce rendering engine and returns a secure public `ContentDownloadHandler` URL.
- `Check_Milestone_Progress`: Queries `Tower__c.Construction_Status__c` and related `Payment_Milestone__c`.

---

### Agent 3: Sales Executive Co-Pilot (Internal)
**Persona**: *Site Sales Intelligence Assistant*  
**Channel**: Salesforce Lightning Desktop Utility Bar & Salesforce Mobile App  
**Primary Goal**: Empower sales representatives with pre-visit intelligence, automated pricing calculation, and objection handling during live walk-ins.

#### Capabilities & Use Cases
1. **Pre-Visit Briefing**: Summarizes incoming visitor's profile, prior phone call transcripts from Ozonetel CTI, family size, budget range, and preferred configurations.
2. **Instant Cost Sheet Calculation**:
   - Rep asks: *"Calculate cost sheet for Unit B-203 with 10:80:10 CLP, 5% GST, and covered car park."*
   - Agent invokes `PricingEngineService.cls`, computes Base Price, Floor Rise, PLC, GST, 1% TDS, and renders an interactive summary table with a "Generate PDF Quote" action.
3. **Inventory Soft-Locking**:
   - *"Put a 15-minute hold on Unit A-402 for customer Deepak Patel."*
   - Flips `Unit__c.Status__c = 'Blocked'` with expiry timestamp.

---

### Agent 4: Finance Reconciliation Assistant (Internal)
**Persona**: *Accounts & Treasury Co-Pilot*  
**Channel**: Salesforce Lightning (Finance Console)  
**Primary Goal**: Eliminate manual spreadsheet reconciliation between bank escrow statements, SAP FI, and Salesforce receipts.

#### Capabilities & Use Cases
1. **Automated UTR Matching**:
   - Ingests unallocated bank credit feeds from HDFC/ICICI Escrow accounts; uses fuzzy matching to map applicant PAN/Name/Amount to open `Installment__c` records.
   - Presents a 1-click confirmation queue: *"Matched UTR HDFC-89102 to Installment INST-0004 for Arjun Mehta (100% confidence). Confirm reconciliation?"*
2. **Overdue Interest Audit & Waiver Checks**:
   - Validates whether an overdue interest amount (calculated at 18% p.a.) qualifies for discretionary waiver based on developer delegation-of-authority matrix.
3. **RERA 70:30 Escrow Allocation Audit**:
   - Verifies that 70% of gross receipt collections are credited strictly to the designated RERA project account before approving ERP sync.

---

### Agent 5: Channel Partner / Broker Concierge (Partner-Facing)
**Persona**: *Broker Alliance Assistant*  
**Channel**: WhatsApp Business & Experience Cloud Partner Central  
**Primary Goal**: Scale broker relationships by providing self-service lead tagging, commission transparency, and marketing collateral on demand.

#### Capabilities & Use Cases
1. **Lead Conflict & Tagging Verification**:
   - Broker prompts: *"Checking if buyer Rohit Sharma (9876543210) is active."*
   - Agent checks Salesforce: validates whether lead is existing or within the 60-day broker attribution window; instantly registers the lead under the broker's agency code (`Account.RecordType = 'Channel_Partner'`).
2. **Brokerage Payout Inquiries**:
   - Reports earned vs released brokerage: *"Unit A-102 (Suresh Hegde) has crossed 10% customer realization. Brokerage voucher of ₹ 1,45,000 has been approved and scheduled for payment on Friday."*
3. **Instant Collateral Dispenser**:
   - Dispatches approved high-res brochures, 3D walkthrough videos, and master price sheets formatted for broker client pitches.

---

## 4. Technical Architecture: How to Build These Agents in Salesforce

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        AGENTFORCE IMPLEMENTATION BUILDING BLOCKS                       │
├─────────────────────┬────────────────────────────────┬─────────────────────────────────┤
│ Component           │ Salesforce Technology          │ Real Estate Artifact            │
├─────────────────────┼────────────────────────────────┼─────────────────────────────────┤
│ Reasoning Engine    │ Atlas Reasoning Engine         │ Intent routing & decision trees │
│ Context Retrieval   │ Data Cloud Vector Grounding    │ Brochures, FAQs, POI Distances  │
│ Business Logic      │ Invocable Apex (@Invocable)    │ PricingEngine, InventorySearch  │
│ Transactions        │ Autolaunched Screen Flows      │ Booking Creation, Site Visit    │
│ Communications      │ Unified Messaging / WhatsApp   │ Gupshup / WhatsApp Business API │
│ Security & Guardrail│ Einstein Trust Layer           │ PII Masking, Prompt Defense     │
└─────────────────────┴────────────────────────────────┴─────────────────────────────────┘
```

### Invocable Apex Signature Example: `RecommendUnitsAction.cls`
```apex
public with sharing class RecommendUnitsAction {
    public class Request {
        @InvocableVariable(required=true label='Project Name')
        public String projectName;
        @InvocableVariable(required=true label='Configuration (e.g. 2 BHK, 3 BHK)')
        public String configuration;
        @InvocableVariable(required=false label='Max Budget')
        public Decimal maxBudget;
    }

    public class Response {
        @InvocableVariable(label='Available Units')
        public List<Unit__c> recommendedUnits;
        @InvocableVariable(label='Recommendation Summary')
        public String summaryMessage;
    }

    @InvocableMethod(label='Find Matching Units' description='Queries available units matching buyer budget and configuration')
    public static List<Response> findUnits(List<Request> requests) {
        Request req = requests[0];
        List<Unit__c> units = [
            SELECT Id, Name, Configuration__c, Carpet_Area_SqFt__c, Base_Price__c, Floor__r.Floor_Number__c, Floor__r.Tower__r.Name
            FROM Unit__c
            WHERE Status__c = 'Available'
              AND Configuration__c = :req.configuration
              AND Floor__r.Tower__r.Project__r.Name LIKE :('%' + req.projectName + '%')
              AND Base_Price__c <= :req.maxBudget
            WITH USER_MODE
            ORDER BY Base_Price__c ASC
            LIMIT 3
        ];

        Response res = new Response();
        res.recommendedUnits = units;
        res.summaryMessage = 'Found ' + units.size() + ' matching units available for booking.';
        return new List<Response>{ res };
    }
}
```

---

## 5. Strategic Pitch Narrative for Stakeholders

When pitching Agentforce to developers (e.g., Bhartiya City or Phoenix Mills leadership):

> *"Instead of building disjointed chatbots that merely output pre-scripted FAQ buttons, **Agentforce connects directly to your live Salesforce database, SAP inventory, and Escrow banking accounts**.  
>  
> Before a site visit, it acts as an intelligent digital host—answering nuanced lifestyle questions about schools, healthcare, and metro connectivity, while conversationally recommending the right unit for their budget.  
>  
> After booking, it eliminates repetitive calls to your accounts desk by instantly confirming bank UTR transfers, explaining receipt reconciliation states, and dispensing official Statements of Account—delivering an institutional, premium buying experience around the clock."*
