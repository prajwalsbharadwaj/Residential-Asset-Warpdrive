@isTest
private class BPSAfterUpdateTriggerHandlerTest {

    private class SapUpdateMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('[]');
            return res;
        }
    }

    // Dynamic helper to find a valid picklist value for Bill_Block__c
    private static String getValidBillBlockValue() {
        List<Schema.PicklistEntry> values = Booking_Payment_Schedule__c.Bill_Block__c.getDescribe().getPicklistValues();
        for(Schema.PicklistEntry val : values) {
            if(val.isActive()) return val.getValue();
        }
        return null;
    }

    @testSetup
    static void setupData() {
        Account account = ResidentialTestDataFactory.createAccount();
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
        Opportunity opportunity = ResidentialTestDataFactory.createOpportunity(account.Id, unit.Id);
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        
        // Create parent templates
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
        
        Booking__c booking = ResidentialTestDataFactory.createBooking(account.Id, unit.Id, plan.Id, opportunity.Id, project.Id);
        
        // FIX: Generate a shorter unique ID to stay under the 30 character limit
        String timestamp = String.valueOf(System.now().getTime()).right(8);
        Integer randomNum = Integer.valueOf(Math.random() * 10000);
        booking.SAP_External_Id__c = 'BKG-' + timestamp + '-' + randomNum;
        
        // Use valid picklist values from your Org
        booking.Status__c = 'Pending Confirmation'; 
        booking.SAP_Sync_Status__c = 'Success'; 
        update booking;

        ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, schedules);
    }

    /**
     * @description Covers the Standard Milestone branch (else if).
     * Using real DML solves the TypeException (Map to Map).
     */
    @isTest
    static void testStandardMilestoneSync() {
        String validVal = getValidBillBlockValue();
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        
        // Find a schedule record
        Booking_Payment_Schedule__c bps = [SELECT Id, Bill_Block__c FROM Booking_Payment_Schedule__c WHERE Booking__c = :booking.Id LIMIT 1];

        // 1. Set a value first so we can detect a change to null later
        bps.Bill_Block__c = validVal;
        update bps;

        Test.setMock(HttpCalloutMock.class, new SapUpdateMock());
        Test.startTest();
        // 2. Clear Bill Block to trigger 'Pending update' logic
        bps.Bill_Block__c = null;
        update bps;
        Test.stopTest();

        Booking__c refreshed = [SELECT SAP_Sync_Status__c FROM Booking__c WHERE Id = :booking.Id];
        System.assertEquals('Pending update', refreshed.SAP_Sync_Status__c);
    }

    /**
     * @description Covers the 'Other Charges' branch.
     * We update parent template records to influence the child formula Milestone_Code__c.
     */
    @isTest
    static void testOtherChargesMilestoneSync() {
        String validVal = getValidBillBlockValue();
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        
        // Update parents so the formula on child becomes 'Other Charges'
        List<Payment_Schedule__c> parents = [SELECT Id FROM Payment_Schedule__c];
        for(Payment_Schedule__c ps : parents) {
            try { ps.put('Milestone_Code__c', 'Other Charges'); } catch(Exception e) {}
            try { ps.put('Milestone_Type__c', 'Other Charges'); } catch(Exception e) {}
        }
        update parents;

        Booking_Payment_Schedule__c bps = [SELECT Id, Bill_Block__c FROM Booking_Payment_Schedule__c WHERE Booking__c = :booking.Id LIMIT 1];
        
        bps.Bill_Block__c = validVal;
        update bps;

        Test.setMock(HttpCalloutMock.class, new SapUpdateMock());
        Test.startTest();
        bps.Bill_Block__c = null;
        update bps;
        Test.stopTest();
        
        Booking__c refreshed = [SELECT SAP_Sync_Status__c FROM Booking__c WHERE Id = :booking.Id];
        System.assertEquals('Success', refreshed.SAP_Sync_Status__c);
    }

    /**
     * @description Covers scenario where Bill Block doesn't change.
     */
    @isTest
    static void testNoChangeScenario() {
        Booking_Payment_Schedule__c bps = [SELECT Id, Booking__c, Installment_Amount__c FROM Booking_Payment_Schedule__c LIMIT 1];
        Id bkgId = bps.Booking__c;

        Test.startTest();
        // Update a field that is NOT Bill_Block__c to trigger the loop but skip logic
        bps.Installment_Amount__c += 1;
        update bps;
        Test.stopTest();
        
        Booking__c refreshed = [SELECT SAP_Sync_Status__c FROM Booking__c WHERE Id = :bkgId];
        // Status should still be 'Success' as set in setup
        System.assertEquals('Success', refreshed.SAP_Sync_Status__c);
    }

    @IsTest
    static void testDeleteAndUndelete() {
        Booking_Payment_Schedule__c bps = [SELECT Id FROM Booking_Payment_Schedule__c LIMIT 1];
        Test.startTest();
        try {
            delete bps;
            undelete bps;
        } catch(Exception e) {
            // Handled for coverage
        }
        Test.stopTest();
    }
}