# Salesforce AI Framework — Testing Standards & Quality Assurance

## 1. Testing Philosophy
Testing in Salesforce is not merely a gate to pass the 75% deployment threshold; it is an automated verification suite that guarantees system reliability, boundary safety, and regression prevention.

### Core Targets
- **Target Coverage**: **90%+** across all Apex classes and triggers.
- **Assertion Coverage**: **100%** of test methods must contain meaningful `Assert.areEqual()`, `Assert.isTrue()`, or `Assert.fail()` statements. Tests without assertions are strictly rejected in code review.
- **Data Isolation**: Never use `@isTest(SeeAllData=true)` unless testing legacy standard price books that cannot be created programmatically.

---

## 2. Test Architecture & Structure

```
[Test Class: BookingServiceTest.cls]
  │
  ├── @TestSetup static void makeData()
  │     └── Uses TestDataFactory.cls to create base hierarchy (Project, Tower, Floor, Unit, Plan)
  │
  ├── @isTest static void testBookingConfirmation_Positive()
  │     └── System.runAs(salesUser) -> Test.startTest() -> Execute -> Test.stopTest() -> Assert
  │
  ├── @isTest static void testBookingConfirmation_Bulk200()
  │     └── 200 units booked simultaneously -> Assert zero limit exceptions
  │
  ├── @isTest static void testBookingCancellation_Negative()
  │     └── Attempt invalid state transition -> Assert custom exception thrown
  │
  └── @isTest static void testSAPSyncCallout_Mocked()
        └── Test.setMock(HttpCalloutMock.class, new SAPCalloutMock()) -> Assert payload & status
```

### Standard Structure of a Test Method
Every test method should follow the **AAA Pattern** (Arrange, Act, Assert):
```apex
@isTest
static void testCalculateOverdueInterest_Positive() {
    // 1. ARRANGE
    Installment__c inst = [SELECT Id, Amount__c, Due_Date__c, Outstanding_Amount__c FROM Installment__c LIMIT 1];
    inst.Due_Date__c = Date.today().addDays(-30);
    inst.Outstanding_Amount__c = 100000;
    update inst;

    // 2. ACT
    Test.startTest();
    InstallmentService.evaluateOverdueInterest(new List<Id>{ inst.Id });
    Test.stopTest();

    // 3. ASSERT
    Installment__c updatedInst = [SELECT Id, Days_Overdue__c, Overdue_Interest__c, Status__c FROM Installment__c WHERE Id = :inst.Id];
    Assert.areEqual(30, updatedInst.Days_Overdue__c, 'Days overdue should match elapsed days');
    Assert.areEqual('Overdue', updatedInst.Status__c, 'Installment status should flip to Overdue');
    // 100,000 * 18% * (30/365) = 1,479.45
    Assert.isTrue(updatedInst.Overdue_Interest__c > 1470 && updatedInst.Overdue_Interest__c < 1490, 'Interest calculated at 18% p.a.');
}
```

---

## 3. Centralized Test Data Factory (`TestDataFactory.cls`)
All test data must be synthesized through a centralized factory class to prevent brittle tests caused by schema modifications or validation rules:

```apex
@isTest
public class TestDataFactory {
    public static Project__c createProject(String name) {
        Project__c proj = new Project__c(
            Name = name,
            Location__c = 'Bengaluru',
            Status__c = 'Active',
            RERA_Registration_Number__c = 'PRM/KA/RERA/1251/472/PR/210526/' + String.valueOf(Crypto.getRandomInteger()).substring(0, 6)
        );
        insert proj;
        return proj;
    }

    public static List<Unit__c> createUnits(Id floorId, Integer count) {
        List<Unit__c> units = new List<Unit__c>();
        for (Integer i = 1; i <= count; i++) {
            units.add(new Unit__c(
                Name = 'Unit-' + i,
                Floor__c = floorId,
                Configuration__c = '3 BHK',
                Carpet_Area_SqFt__c = 1200,
                Super_Built_Up_Area_SqFt__c = 1550,
                Base_Price__c = 12000000,
                Status__c = 'Available'
            ));
        }
        insert units;
        return units;
    }
}
```

---

## 4. Bulk & Governor Limit Testing
- Test classes must validate that triggers and service classes handle **200 records** in a single DML operation.
- Use `Test.startTest()` and `Test.stopTest()` to reset governor limits specifically for the code under execution:
```apex
@isTest
static void testBulkInstallmentCreation() {
    List<Booking__c> bulkBookings = TestDataFactory.createBulkBookings(200);

    Test.startTest();
    InstallmentGeneratorService.generateSchedules(bulkBookings);
    Test.stopTest();

    Integer totalInstallments = [SELECT COUNT() FROM Installment__c WHERE Booking__c IN :bulkBookings];
    Assert.areEqual(200 * 5, totalInstallments, '5 milestones should be generated per booking');
}
```

---

## 5. Security & Persona Testing (`System.runAs`)
Verify that security rules and permission sets prevent unauthorized users from performing restricted operations:
```apex
@isTest
static void testFinanceUserCanReconcileReceipt() {
    User financeUser = TestDataFactory.createUserWithProfile('Finance_Demo');
    Receipt__c rcpt = [SELECT Id, Status__c FROM Receipt__c WHERE Status__c = 'Pending Reconciliation' LIMIT 1];

    System.runAs(financeUser) {
        Test.startTest();
        rcpt.Status__c = 'Confirmed';
        update rcpt;
        Test.stopTest();
    }

    Receipt__c verified = [SELECT Id, Status__c FROM Receipt__c WHERE Id = :rcpt.Id];
    Assert.areEqual('Confirmed', verified.Status__c, 'Finance persona is authorized to confirm receipt');
}
```

---

## 6. Callout Mocking Standards
When testing integrations, external HTTP requests are prohibited in Apex tests. You must register an `HttpCalloutMock`:

```apex
@isTest
public class SAPCalloutMock implements HttpCalloutMock {
    protected Integer statusCode;
    protected String status;
    protected String body;

    public SAPCalloutMock(Integer statusCode, String status, String body) {
        this.statusCode = statusCode;
        this.status = status;
        this.body = body;
    }

    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody(this.body);
        res.setStatusCode(this.statusCode);
        res.setStatus(this.status);
        return res;
    }
}
```

---

## 7. Lightning Web Component (LWC) Jest Testing
All custom LWCs with dynamic business logic must have corresponding Jest unit test specs located in `__tests__/myComponent.test.js`:
- Test DOM rendering with empty vs populated data.
- Test wire adapter provisioning using `emit()` from `@salesforce/sfdx-lwc-jest`.
- Test user interactions (button clicks, form inputs) and verify that custom events are dispatched with expected payloads.
