# Salesforce AI Framework — Integration Architecture Rules

## 1. Enterprise Integration Patterns Overview
Salesforce implementations must use robust, decoupled, and secure integration patterns to connect with external ERPs, payment gateways, telephony stacks, and third-party SaaS portals.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Integration Topologies                          │
├───────────────────────┬────────────────────────┬───────────────────────┤
│ Pattern               │ Salesforce Role        │ Typical Technology    │
├───────────────────────┼────────────────────────┼───────────────────────┤
│ Synchronous REST/OData│ Consumer (Outbound)    │ Named Credentials     │
│ Webhook Ingestion     │ Provider (Inbound)     │ Apex REST / Webhook   │
│ Asynchronous Event-Bus│ Pub/Sub Event Exchange │ Platform Events / CDC │
│ Scheduled Bulk Batch  │ Bulk ETL Reconciliation│ Batch Apex / MuleSoft │
└───────────────────────┴────────────────────────┴───────────────────────┘
```

---

## 2. Authentication & Secrets Management

> [!CRITICAL]
> **Zero Hardcoded Secrets Policy**: API keys, bearer tokens, client secrets, passwords, or endpoint base URLs must NEVER be hardcoded in Apex, Custom Labels, or source code repositories.

### Standards
1. **Named Credentials & External Credentials**:
   - Always use Salesforce **Named Credentials** combined with **External Credentials** (the modern standard replacing Legacy Named Credentials).
   - Configure authentication protocols (OAuth 2.0 Client Credentials, JWT Bearer, or Custom Header with Principals) declaratively in Setup.
   - Reference endpoints in Apex using the `callout:` prefix:
     ```apex
     HttpRequest req = new HttpRequest();
     req.setEndpoint('callout:SAP_MuleSoft_Gateway/api/v1/inventory/sync');
     req.setMethod('POST');
     req.setHeader('Content-Type', 'application/json');
     ```
2. **Mutual TLS (mTLS) & Certificates**:
   - For high-security banking or government touchpoints (e.g., Escrow bank APIs, NSDL/UIDAI KYC intermediaries), enforce 2-way TLS using Salesforce CA-Signed Certificates configured in Certificate and Key Management.

---

## 3. Resilience, Fault Tolerance & Idempotency
External services frequently experience intermittent latency, network dropouts, and transient HTTP 5xx errors. All integrations must implement defensive resilience patterns.

### 1. Idempotency Guarantees
- Webhooks and payment notifications are frequently redelivered by gateways (e.g., Razorpay, Gupshup).
- The receiving endpoint must verify the **Unique Event ID** or **Idempotency Key** against a dedicated audit object (`Integration_Log__c` or `Receipt__c.Transaction_Reference__c`) before executing business logic.
- If a transaction has already been processed, return `200 OK` immediately without repeating DML or triggering duplicate accounting entries.

### 2. Transaction Boundaries & Callout Limits
- Salesforce forbids making an HTTP callout after uncommitted DML operations in the same transaction ("You have uncommitted work pending").
- **Resolution**:
  - Perform all HTTP callouts before any DML operations.
  - Or offload the callout to an asynchronous **Queueable Apex** job implementing `Database.AllowsCallouts`.

### 3. Circuit Breaker & Exponential Backoff
- For outbound callout failures, do not aggressively retry in tight loops.
- Use Queueable job chaining with delay schedules:
  $$\text{Delay} = 2^{\text{attempt}} \times 30\text{ seconds}$$
- After 3-5 consecutive failures, flag the transaction as `Failed` in the Dead-Letter Queue (DLQ) and emit a notification to the System Administrator.

---

## 4. Inbound Webhook Security & Signature Verification
All public-facing inbound Apex REST endpoints (`@RestResource`) that receive webhooks from marketing portals, CTI, or payment gateways must validate request authenticity:

```apex
@RestResource(urlMapping='/v1/webhooks/razorpay/*')
global without sharing class RazorpayWebhookService {
    @HttpPost
    global static void handleWebhook() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String signature = req.headers.get('X-Razorpay-Signature');
        String payload = req.requestBody.toString();

        // 1. Validate cryptographic HMAC-SHA256 signature
        if (!verifySignature(payload, signature)) {
            res.statusCode = 401;
            res.responseBody = Blob.valueOf('{"error":"Invalid signature"}');
            return;
        }

        // 2. Enforce idempotency and process payload
        PaymentWebhookHandler.processPayload(payload);
        res.statusCode = 200;
        res.responseBody = Blob.valueOf('{"status":"received"}');
    }

    private static Boolean verifySignature(String payload, String signature) {
        String webhookSecret = Integration_Setting__mdt.getInstance('Razorpay_Webhook').Secret__c;
        Blob hmac = Crypto.generateMac('HmacSHA256', Blob.valueOf(payload), Blob.valueOf(webhookSecret));
        String calculatedSignature = EncodingUtil.convertToHex(hmac);
        return calculatedSignature.equals(signature);
    }
}
```

---

## 5. Domain-Specific Integration Standards (Real Estate & ERP)

### A. SAP S/4HANA (RE-FX, SD & FI)
1. **Inventory & Units (RE-FX)**:
   - Synchronize unit master data (Unit Number, Carpet Area, PLC, Base Rate) from SAP to Salesforce via a nightly Batch ETL or MuleSoft OData connector.
   - SAP RE-FX is the authoritative master for Unit architectural dimensions; Salesforce is the master for real-time customer reservations and lead tagging.
2. **Sales Order & Booking (SD)**:
   - When a Booking is marked `Approved`, dispatch an outbound asynchronous payload to SAP to create the Customer Master (`KNA1`) and Sales Contract (`VA41`).
   - Store the returned `SAP_Customer_Code__c` and `SAP_Contract_Number__c` on `Booking__c`.
3. **Receipt Clearing & General Ledger (FI)**:
   - When Finance approves a `Receipt__c` in Salesforce, invoke the SAP FI posting BAPI (`BAPI_ACC_DOCUMENT_POST`) to credit customer receivables and debit bank/escrow accounts.

### B. Telephony & CTI (Ozonetel / Exotel)
- **Click-to-Call**: LWC dispatches an outbound call initiation to the CTI agent browser session.
- **Call Disposition & Recording**: CTI provider posts call outcome (Duration, Talk Time, Audio URL, Disposition) to an inbound webhook, which auto-logs a completed `Task` or `Site_Visit__c` record against the matching `Lead` or `Contact`.

### C. Digital KYC & E-Sign (Digio / DocuSign)
- Generate the dynamic Application Form / Allotment Letter PDF in Salesforce.
- Transmit the document hash and applicant mobile/email to the e-Sign provider.
- Listen for the `DOCUMENT_COMPLETED` webhook, download the digitally signed tamper-proof PDF, and attach it to `Booking__c` as a `ContentVersion` record.

### D. RERA Escrow & Payment Gateways (Razorpay / HDFC)
- **Dual Escrow Split**: Payment links generated must split the gross collection strictly according to statutory RERA mandates:
  - **70%** routed to RERA Designated Project Construction Escrow Account.
  - **30%** routed to Builder General / Operational Account.
- Real-time webhooks update the matching `Installment__c` from `Due` to `Paid` and log a verified `Receipt__c`.

---

## 6. Logging & Observability Standard
Every integration touchpoint must write an execution log entry (`Integration_Log__c` or Platform Event `Log_Event__e`) capturing:
- `Service_Name__c`: e.g., `SAP_Contract_Sync`
- `Endpoint__c`: Sanitized URL (strip sensitive tokens)
- `HTTP_Status_Code__c`: e.g., `200`, `400`, `503`
- `Request_Payload__c`: Masked JSON (redact PAN, Aadhaar, CVV, passwords)
- `Response_Payload__c`: Masked response
- `Execution_Time_Ms__c`: Latency in milliseconds
- `Record_Id__c`: Related Salesforce Record ID
