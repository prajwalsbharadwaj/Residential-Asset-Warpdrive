@isTest
private class BookingPaymentScheduleTriggerTest {

    private class SapUpdateMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('[]');
            return res;
        }
    }

    @testSetup
    static void setupData() {
        Account account = ResidentialTestDataFactory.createAccount();
        account.PersonMailingState = 'Karnataka';
        account.PersonMailingCountry = 'India';
        update account;

        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
        Opportunity opportunity = ResidentialTestDataFactory.createOpportunity(account.Id, unit.Id);
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
        Booking__c booking = ResidentialTestDataFactory.createBooking(account.Id, unit.Id, plan.Id, opportunity.Id, project.Id);
        booking.SAP_External_Id__c = 'BKG-TEST-001';
        update booking;
        ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, schedules);
    }

    /**
     * @description Ensures booking sync status updates and callout executes when bill block changes.
     * GIVEN: A booking payment schedule with a different bill block value.
     * WHEN: The record is updated through the trigger.
     * THEN: The parent booking is flagged for sync and the future call is invoked.
     */
    @isTest
    static void givenBillBlockChangeWhenScheduleUpdatedThenBookingMarkedForSync() {
        Booking__c booking = [SELECT Id, SAP_Sync_Status__c FROM Booking__c LIMIT 1];
        Booking_Payment_Schedule__c schedule = [
            SELECT Id, Bill_Block__c
            FROM Booking_Payment_Schedule__c
            WHERE Booking__c = :booking.Id
            ORDER BY Installment_Number__c
            LIMIT 1
        ];

        schedule.Bill_Block__c = null;

        Test.setMock(HttpCalloutMock.class, new SapUpdateMock());
        Test.startTest();
        update schedule;
        Test.stopTest();

        Booking__c refreshed = [SELECT SAP_Sync_Status__c FROM Booking__c WHERE Id = :booking.Id];
        System.assert.areEqual('Pending update', refreshed.SAP_Sync_Status__c, 'Booking should be flagged for SAP sync when bill block changes.');
    }

    /**
     * @description Confirms no sync occurs when bill block remains the same.
     * GIVEN: A booking payment schedule updated without touching the bill block.
     * WHEN: The trigger fires.
     * THEN: The booking sync flag remains untouched and no callout is required.
     */
    @isTest
    static void givenNoBillBlockChangeWhenScheduleUpdatedThenBookingRemainsUnchanged() {
        Account account = ResidentialTestDataFactory.preparePersonAccount();
        account.SAP_External_Id__c = 'A0002';
        account.LastName = 'Person2';
        account.PersonMailingState = 'Karnataka';
        account.PersonMailingCountry = 'India';
        insert account;
		
        ResidentialTestDataFactory.projectCounter = 2;
        ResidentialTestDataFactory.towerCounter = 2;
        ResidentialTestDataFactory.unitCounter = 2;
        ResidentialTestDataFactory.floorCounter = 2;
        
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
        Opportunity opportunity = ResidentialTestDataFactory.createOpportunity(account.Id, unit.Id);
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
        Booking__c booking = ResidentialTestDataFactory.createBooking(account.Id, unit.Id, plan.Id, opportunity.Id, project.Id);
        ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, schedules);

        Booking_Payment_Schedule__c schedule = [
            SELECT Id, Bill_Block__c, Installment_Amount__c
            FROM Booking_Payment_Schedule__c
            WHERE Booking__c = :booking.Id
            LIMIT 1
        ];
        schedule.Installment_Amount__c += 100;

        Test.startTest();
        update schedule;
        Test.stopTest();

        Booking__c refreshed = [SELECT SAP_Sync_Status__c FROM Booking__c WHERE Id = :booking.Id];
        System.assert.isNull(refreshed.SAP_Sync_Status__c, 'Booking should not change when bill block is untouched.');
    }

    @IsTest
    static void testDeleteTrigger() {
        Booking_Payment_Schedule__c schedule = [
            SELECT Id, Bill_Block__c
            FROM Booking_Payment_Schedule__c
            LIMIT 1
        ];

        Test.startTest();
        delete schedule;
        Test.stopTest();
    }

    @IsTest
    static void testUndeleteTrigger() {
        Booking_Payment_Schedule__c schedule = [
            SELECT Id, Bill_Block__c
            FROM Booking_Payment_Schedule__c
            LIMIT 1
        ]; 
        delete schedule;
        
        Test.startTest();
        undelete schedule;
        Test.stopTest();
    }
}