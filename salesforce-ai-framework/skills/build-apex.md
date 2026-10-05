# Skill: Building Enterprise Apex Services & Triggers

## Purpose
This skill provides a structured, multi-layer methodology for AI agents and Salesforce engineers to design, build, and deploy robust, bulkified, and secure Apex services, controllers, and trigger frameworks.

---

## 1. Enterprise Pattern Architecture

```
                  ┌──────────────────────────────┐
                  │ LWC / Flow / Inbound Webhook │
                  └──────────────┬───────────────┘
                                 │
                                 ▼
                   ┌────────────────────────────┐
                   │   Apex Controller / API    │
                   │ (Parameter parsing, DTOs)  │
                   └─────────────┬──────────────┘
                                 │
                                 ▼
                   ┌────────────────────────────┐
                   │       Service Layer        │
                   │ (Business Logic & DML txn) │
                   └─────────────┬──────────────┘
                                 │
                   ┌─────────────┴──────────────┐
                   ▼                            ▼
     ┌───────────────────────────┐ ┌───────────────────────────┐
     │      Selector Layer       │ │    Domain / Trigger       │
     │   (Centralized Queries)   │ │  (Validation & Lifecycle) │
     └───────────────────────────┘ └───────────────────────────┘
```

---

## 2. Step-by-Step Implementation Sequence

### Step 1: Define the Data Transfer Object (DTO) & Custom Exceptions
Decouple client contracts from internal database schema:
```apex
public with sharing class BookingDTO {
    @AuraEnabled public Id unitId { get; set; }
    @AuraEnabled public Id customerId { get; set; }
    @AuraEnabled public Id paymentPlanId { get; set; }
    @AuraEnabled public Decimal tokenAmount { get; set; }
    @AuraEnabled public String paymentMode { get; set; }
    @AuraEnabled public String transactionRef { get; set; }
}

public class BookingException extends Exception {}
```

---

### Step 2: Implement the Selector Layer (`*Selector.cls`)
Centralize all SOQL queries for an SObject to eliminate query duplication and enforce `WITH USER_MODE`:
```apex
public inherited sharing class UnitsSelector {
    public static List<Unit__c> selectByIds(Set<Id> unitIds) {
        if (unitIds == null || unitIds.isEmpty()) {
            return new List<Unit__c>();
        }
        return [
            SELECT Id, Name, Status__c, Base_Price__c, Carpet_Area_SqFt__c, Floor__r.Tower__r.Project__c
            FROM Unit__c
            WHERE Id IN :unitIds
            WITH USER_MODE
        ];
    }

    public static List<Unit__c> selectAvailableByFloor(Id floorId) {
        return [
            SELECT Id, Name, Configuration__c, Base_Price__c, Status__c
            FROM Unit__c
            WHERE Floor__c = :floorId AND Status__c = 'Available'
            WITH USER_MODE
            ORDER BY Name ASC
        ];
    }
}
```

---

### Step 3: Implement the Service Layer (`*Service.cls`)
Encapsulate complex multi-object orchestration with database savepoint rollbacks:
```apex
public with sharing class BookingService {
    public static Booking__c createBooking(BookingDTO dto) {
        // 1. Validate Unit Availability via Selector
        List<Unit__c> units = UnitsSelector.selectByIds(new Set<Id>{ dto.unitId });
        if (units.isEmpty()) {
            throw new BookingException('Unit record not found.');
        }
        Unit__c unit = units[0];
        if (unit.Status__c != 'Available') {
            throw new BookingException('Selected unit is no longer available for booking.');
        }

        Savepoint sp = Database.setSavepoint();
        try {
            // 2. Instantiate and Insert Booking
            Booking__c newBooking = new Booking__c(
                Customer__c = dto.customerId,
                Unit__c = dto.unitId,
                Payment_Plan__c = dto.paymentPlanId,
                Booking_Date__c = Date.today(),
                Total_Booking_Amount__c = unit.Base_Price__c,
                Status__c = 'KYC in Progress'
            );
            insert as user newBooking;

            // 3. Update Unit Status
            unit.Status__c = 'Sold';
            update as user unit;

            // 4. Generate Down Payment Installment & Token Receipt
            Installment__c tokenInst = new Installment__c(
                Booking__c = newBooking.Id,
                Due_Date__c = Date.today(),
                Amount__c = dto.tokenAmount,
                Outstanding_Amount__c = 0,
                Paid_Amount__c = dto.tokenAmount,
                Status__c = 'Paid'
            );
            insert as user tokenInst;

            Receipt__c tokenReceipt = new Receipt__c(
                Installment__c = tokenInst.Id,
                Receipt_Date__c = Date.today(),
                Amount__c = dto.tokenAmount,
                Payment_Mode__c = dto.paymentMode,
                Transaction_Reference__c = dto.transactionRef,
                Status__c = 'Pending Reconciliation'
            );
            insert as user tokenReceipt;

            return newBooking;

        } catch (Exception ex) {
            Database.rollback(sp);
            throw new BookingException('Booking transaction failed: ' + ex.getMessage());
        }
    }
}
```

---

### Step 4: Implement the Controller Layer (`*Controller.cls`)
Expose methods to LWC using `@AuraEnabled` with robust exception translation:
```apex
public with sharing class BookingWizardController {
    @AuraEnabled
    public static Booking__c submitBooking(String bookingJson) {
        try {
            BookingDTO dto = (BookingDTO) JSON.deserialize(bookingJson, BookingDTO.class);
            return BookingService.createBooking(dto);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
```

---

### Step 5: Implement Trigger & Handler Framework
1. **Trigger Definition**:
   ```apex
   trigger BookingTrigger on Booking__c (before insert, after insert, before update, after update) {
       BookingTriggerHandler.getInstance().run();
   }
   ```
2. **Handler Implementation with Context Routing**:
   ```apex
   public with sharing class BookingTriggerHandler {
       private static BookingTriggerHandler instance;
       private static Boolean isBypassed = false;

       public static BookingTriggerHandler getInstance() {
           if (instance == null) instance = new BookingTriggerHandler();
           return instance;
       }

       public static void bypass() { isBypassed = true; }
       public static void clearBypass() { isBypassed = false; }

       public void run() {
           if (isBypassed) return;

           if (Trigger.isBefore && Trigger.isInsert) {
               onBeforeInsert((List<Booking__c>) Trigger.new);
           } else if (Trigger.isAfter && Trigger.isInsert) {
               onAfterInsert((List<Booking__c>) Trigger.new, (Map<Id, Booking__c>) Trigger.newMap);
           }
       }

       private void onBeforeInsert(List<Booking__c> newBookings) {
           // Field defaults, PAN validation
       }

       private void onAfterInsert(List<Booking__c> newBookings, Map<Id, Booking__c> newMap) {
           // Milestone schedule generation, SAP order queueing
       }
   }
   ```

---

## 3. Verification & Automated Test Run Checklist
Deploy code and execute targeted tests via Salesforce CLI:
```bash
# Deploy apex classes
sf project deploy start --source-dir force-app/main/default/classes --target-org <alias>

# Run apex tests with code coverage report
sf apex test run --tests BookingServiceTest --code-coverage --result-format human --target-org <alias>
```
Verify that test coverage exceeds **90%** and 100% of methods assert expected business logic.
