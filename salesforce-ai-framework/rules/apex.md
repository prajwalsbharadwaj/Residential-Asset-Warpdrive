# Salesforce AI Framework — Apex Development Rules

## 1. Architectural Principles & Layering
All Apex code must adhere to the Separation of Concerns (SoC) enterprise design pattern. Avoid monolithic classes that mix SOQL queries, business logic, DML operations, and presentation controllers.

```
[UI Layer: LWC / REST API / Flow]
          │
          ▼
[Controller / Orchestration Layer]  (e.g., InventoryExplorerController)
          │
          ▼
[Service Layer]                     (e.g., BookingService, PricingEngineService)
     │         │
     ▼         ▼
[Domain Layer] [Selector Layer]     (e.g., Bookings.cls, UnitsSelector.cls)
     │         │
     ▼         ▼
[Database / Schema Layer]
```

### Layer Responsibilities
1. **Controllers (`*Controller.cls`)**:
   - Thin entry points for LWC components or REST endpoints.
   - Responsible strictly for parameter parsing, input validation, invoking the Service Layer, and returning DTOs or throwing `AuraHandledException`.
   - Never perform direct SOQL queries or DML operations inside controllers.

2. **Service Layer (`*Service.cls`)**:
   - Encapsulates cross-object business logic, transaction orchestration, and third-party callouts.
   - Enforces transactional boundaries (all-or-none operations, `Savepoint` rollback).
   - Reusable across Controllers, Batch jobs, Schedulables, and Inbound Integrations.

3. **Selector Layer (`*Selector.cls`)**:
   - Sole authority for executing SOQL queries.
   - Enforces field consistency, centralizes query filters, handles subqueries, and guarantees object-level and field-level security checks.
   - Standardizes query ordering and limits.

4. **Domain Layer (`*Domain.cls` / Trigger Handlers)**:
   - Encapsulates entity-specific validation, default field values, state transitions, and business rules triggered by database DML events.

---

## 2. Trigger Architecture Standards
1. **One Trigger Per Object**:
   - Exactly one trigger per SObject (e.g., `BookingTrigger.trigger` on `Booking__c`).
   - The trigger must contain **zero business logic**. It should only instantiate and invoke a dedicated Trigger Handler class.
2. **Trigger Handler Framework**:
   - All handlers must inherit from a common `TriggerHandler` base class or implement an interface managing execution contexts (`beforeInsert`, `afterInsert`, `beforeUpdate`, `afterUpdate`, `beforeDelete`, `afterDelete`, `afterUndelete`).
   - Must implement recursion protection and bypass mechanisms:
     ```apex
     // Bypass during bulk data migrations or unit test setup
     TriggerHandler.bypass('BookingTriggerHandler');
     ```
3. **Context Guidelines**:
   - **`before` triggers**: Use strictly for field validations, default calculations, and modifying field values on the records being processed without issuing DML statements.
   - **`after` triggers**: Use when record IDs are required, or when modifying related child or parent records.

---

## 3. Governor Limits & Bulkification Defense

> [!CRITICAL]
> Every method and query must be designed to handle a full batch of **200 records** without breaching governor limits.

### Golden Rules:
1. **Zero Queries or DML in Loops**:
   - Never write `[SELECT ...]`, `insert`, `update`, `delete`, or `upsert` inside `for`, `while`, or `do-while` loops.
   - Accumulate records in lists or sets, query in bulk using the `IN :recordIds` clause, and perform single bulk DML operations.

```apex
// ❌ INCORRECT (Anti-Pattern: SOQL & DML in loop)
public void updateUnitStatuses(List<Booking__c> bookings) {
    for (Booking__c b : bookings) {
        Unit__c u = [SELECT Id, Status__c FROM Unit__c WHERE Id = :b.Unit__c];
        u.Status__c = 'Sold';
        update u; // Hits DML limit on batch > 150
    }
}

// ✅ CORRECT (Bulkified Pattern)
public void updateUnitStatuses(List<Booking__c> bookings) {
    Set<Id> unitIds = new Set<Id>();
    for (Booking__c b : bookings) {
        if (b.Unit__c != null) {
            unitIds.add(b.Unit__c);
        }
    }
    if (unitIds.isEmpty()) {
        return;
    }

    List<Unit__c> unitsToUpdate = [
        SELECT Id, Status__c 
        FROM Unit__c 
        WHERE Id IN :unitIds
        WITH USER_MODE
    ];

    for (Unit__c u : unitsToUpdate) {
        u.Status__c = 'Sold';
    }

    if (!unitsToUpdate.isEmpty()) {
        update as user unitsToUpdate;
    }
}
```

2. **Heap Size Conservation**:
   - When querying large volumes of records in Batch Apex, use SOQL `for` loops to process records in chunks of 200 without loading the entire dataset into memory:
     ```apex
     for (List<Installment__c> chunk : [SELECT Id, Amount__c FROM Installment__c WHERE Status__c = 'Due']) {
         // Process chunk
     }
     ```

---

## 4. SOQL & Database Best Practices
1. **Always Filter Selectively**:
   - Ensure queries utilize indexed fields (Standard: `Id`, `Name`, `CreatedDate`, `RecordType`; Custom: Lookups, Master-Detail, fields marked as `External ID` or `Unique`).
   - Avoid leading wildcards in `LIKE` queries (`LIKE '%abc'` causes full table scans; use `LIKE 'abc%'`).
2. **Selective Field Retrieval**:
   - Never query fields you do not intend to use. Avoid querying long text or rich text areas unless required.
3. **Bind Variables & Injection Prevention**:
   - Always use bind variables (`:myVar`).
   - If dynamic SOQL (`Database.query()`) is unavoidable, sanitize all user inputs using `String.escapeSingleQuotes()` or use typed bind maps with `Database.queryWithBinds()`.

---

## 5. Asynchronous Apex Standards
1. **Queueable Apex**:
   - Preferred over `@future` because Queueable supports complex object parameters, returns job IDs, and enables job chaining.
   - Implement `Database.AllowsCallouts` when external API calls are executed.
   - Implement `TransactionFinalizer` to capture and recover from unhandled exceptions.
2. **Batch Apex**:
   - Use for processing large datasets (> 50,000 records) or scheduled nightly reconciliations (e.g., daily SAP inventory sync).
   - Keep `start()` query locator concise and indexed.
   - Batch size should default to 200, or lower (50-100) if CPU timeouts or heavy callouts occur.
3. **Schedulable Apex**:
   - Schedulable classes should only instantiate and enqueue a Batch or Queueable job; never execute heavy business logic directly in `execute(SchedulableContext)`.

---

## 6. Exception Handling & Transaction Integrity
1. **Transactional Rollback via Savepoints**:
   - When executing multiple related DML statements across objects, wrap them in a try-catch block with a database savepoint:
   ```apex
   Savepoint sp = Database.setSavepoint();
   try {
       insert newBooking;
       insert newInstallments;
       update linkedUnit;
   } catch (Exception ex) {
       Database.rollback(sp);
       // Log to custom Log__c object or platform event
       Logger.error('Booking creation failed', ex);
       throw new AuraHandledException('Unable to confirm booking: ' + ex.getMessage());
   }
   ```
2. **User-Facing Exceptions**:
   - Never expose raw database exceptions or stack traces to UI users.
   - Transform caught exceptions into descriptive, user-friendly messages via `AuraHandledException`.

---

## 7. Apex Code Hygiene Checklist
- [ ] Class and method names follow camelCase (`calculateTax`) and PascalCase (`PricingEngineService`).
- [ ] Constants are `public static final` in uppercase (`DEFAULT_TAX_RATE = 0.05`).
- [ ] No hardcoded Salesforce record IDs (use Custom Metadata Types, Hierarchy Custom Settings, or Developer Names).
- [ ] Every class specifies sharing (`with sharing`, `without sharing`, or `inherited sharing`).
- [ ] Methods are focused and do not exceed 40-50 lines of code.
- [ ] Methods have clear ApexDoc comments documenting parameters, return values, and thrown exceptions.
