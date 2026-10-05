# Salesforce AI Framework — Security & Compliance Rules

## 1. Zero Trust Security Architecture
Every line of Apex, every LWC component, and every declarative configuration must operate on a **Zero Trust** principle:
- Never assume the executing user has authorization.
- Never rely on UI hiding or field disabling as a security barrier.
- Enforce record sharing, Object-Level Security (CRUD), and Field-Level Security (FLS) at the database layer.

---

## 2. Apex Sharing Enforcements
1. **Default `with sharing`**:
   - Every Apex class must explicitly declare its sharing posture.
   - Default to `with sharing` to enforce the current user's record-level sharing rules:
     ```apex
     public with sharing class BookingService { ... }
     ```
2. **`inherited sharing` for Reusable Utility Classes**:
   - Libraries, selector classes, and helper utilities should specify `inherited sharing` so that they respect the context of the calling class while maintaining security compliance.
3. **Strict Restrictions on `without sharing`**:
   - Use `without sharing` **only** for:
     - Public webhook ingestion endpoints (`@RestResource`).
     - System-level batch jobs executing as automated integration users.
     - Unauthenticated Guest User self-service flows (e.g., public enquiry forms).
   - Any class declared `without sharing` must be isolated, contain zero client-controllable dynamic queries, and be documented with an architectural justification.

---

## 3. Object-Level (CRUD) & Field-Level Security (FLS)

> [!CRITICAL]
> Apex runs in System Mode by default and ignores CRUD and FLS unless explicitly instructed otherwise.

### The Modern Standard: `USER_MODE`
Always use native Salesforce User Mode for queries and DML operations:

```apex
// ✅ Modern SOQL with User Mode
List<Booking__c> bookings = [
    SELECT Id, Name, Total_Booking_Amount__c, Status__c
    FROM Booking__c
    WHERE Customer__c = :customerId
    WITH USER_MODE
];

// ✅ Modern DML with User Mode
insert as user newBooking;
update as user updatedInstallments;
delete as user cancelledApplicant;
```

### Runtime Data Sanitization (`Security.stripInaccessible`)
When handling inbound records from external APIs or user-submitted forms before executing DML or returning untrusted data:
```apex
SObjectAccessDecision decision = Security.stripInaccessible(
    AccessType.CREATABLE,
    inboundBookings
);
insert decision.getRecords();
```

---

## 4. SOQL Injection & XSS Prevention
1. **Dynamic SOQL Defense**:
   - Never concatenate untrusted user input directly into dynamic query strings.
   - Always sanitize string inputs with `String.escapeSingleQuotes()` or utilize typed bind variables with `Database.queryWithBinds()`:
     ```apex
     // ❌ VULNERABLE TO SOQL INJECTION
     String query = 'SELECT Id FROM Unit__c WHERE Configuration__c = \'' + userInput + '\'';

     // ✅ SAFE: Static Bind Variables
     List<Unit__c> units = [SELECT Id FROM Unit__c WHERE Configuration__c = :userInput WITH USER_MODE];

     // ✅ SAFE: Database.queryWithBinds
     Map<String, Object> bindVars = new Map<String, Object>{ 'config' => userInput };
     List<Unit__c> units = Database.queryWithBinds('SELECT Id FROM Unit__c WHERE Configuration__c = :config WITH USER_MODE', bindVars, AccessLevel.USER_MODE);
     ```
2. **Cross-Site Scripting (XSS) in LWC**:
   - Lightning Web Security (LWS) and Locker Service isolate DOM execution.
   - Never inject unescaped strings into `element.innerHTML`. Use native template binding `{myVariable}` which automatically HTML-encodes content.

---

## 5. Sensitive Data & Statutory Compliance (India Real Estate / DPDP Act)

```
┌────────────────────────────────────────────────────────┐
│             Statutory PII & Financial Data             │
├──────────────────────┬─────────────────────────────────┤
│ Data Element         │ Protection Mechanism            │
├──────────────────────┼─────────────────────────────────┤
│ PAN Card             │ Regex validation, FLS restricted│
│ Aadhaar Number       │ Masked format (XXXXXXXX1234)    │
│ Bank Account / UTR   │ FLS limited to Finance persona  │
│ Cost Sheet Discounts │ Approval Process audit trail    │
│ RERA Escrow Split    │ Immutable formula / Trigger lock│
└──────────────────────┴─────────────────────────────────┘
```

1. **Aadhaar Masking Standard**:
   - Under UIDAI regulations and the Digital Personal Data Protection (DPDP) Act, raw 12-digit Aadhaar numbers must never be stored in plain text.
   - Store only masked representations (e.g., `XXXXXXXX9812`) or cryptographic document verification hashes issued by authorized intermediaries (e.g., Digio/NSDL).
2. **Field History Tracking & Audit Trail**:
   - Enable Field History Tracking on key commercial and lifecycle fields:
     - `Unit__c.Status__c`, `Unit__c.Base_Price__c`
     - `Booking__c.Status__c`, `Booking__c.Total_Booking_Amount__c`
     - `Installment__c.Outstanding_Amount__c`, `Installment__c.Interest_Waived__c`
     - `Receipt__c.Status__c`, `Receipt__c.Amount__c`
3. **Segregation of Duties (Maker-Checker)**:
   - Enforce dual-authorization for financial transactions:
     - Sales/CRM users can log a payment instrument (`Receipt__c` in `Pending Reconciliation`).
     - Only Finance users possessing the `Finance_Demo` permission set can approve or reconcile the receipt to `Confirmed`.
