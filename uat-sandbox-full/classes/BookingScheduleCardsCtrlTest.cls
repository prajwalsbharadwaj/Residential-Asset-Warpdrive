@isTest
public class BookingScheduleCardsCtrlTest {

    @testSetup
    static void setupData() {
        // Create necessary data for testing
        
        // Create Account
        Account acc = ResidentialTestDataFactory.createAccount();
        
        // Create a Property (Project)
        Property__c proj = ResidentialTestDataFactory.createProject();
        
        // Create Tower, Floor, Unit
        Tower__c tower = ResidentialTestDataFactory.createTower(proj.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(proj.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(proj.Id, tower.Id, floor.Id);
        
        // Create Payment Plan and related Payment Schedules
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
        
        // Create Opportunity and Booking
        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, proj.Id);
        
        // Create related Booking Payment Schedules
        ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, opp.Id, schedules);
    }

    @IsTest
    static void testFetchSnapshotForBooking() {
        // Fetch a booking record
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        
        Test.startTest();
        // Call the fetchSnapshot method for the Booking object
        BookingInterestService.SnapshotDTO snapshot = BookingScheduleCardsCtrl.fetchSnapshot(booking.Id, 'Booking__c');
        Test.stopTest();

        // Assertions
        System.assertNotEquals(null, snapshot, 'Snapshot should not be null');
        System.assert(snapshot.schedules != null && !snapshot.schedules.isEmpty(), 'Schedules should be returned');
        System.assertNotEquals(null, snapshot.totalInstallmentAmount, 'Totals should be available on snapshot DTO');
    }

    @IsTest
    static void testFetchSnapshotForBookingPaymentSchedule() {
        // Fetch a Booking Payment Schedule record
        Booking_Payment_Schedule__c bps = [SELECT Id FROM Booking_Payment_Schedule__c LIMIT 1];
        
        Test.startTest();
        // Call the fetchSnapshot method for the Booking Payment Schedule object
        BookingInterestService.SnapshotDTO snapshot = BookingScheduleCardsCtrl.fetchSnapshot(bps.Id, 'Booking_Payment_Schedule__c');
        Test.stopTest();

        // Assertions
        System.assertNotEquals(null, snapshot, 'Snapshot should not be null');
        System.assert(snapshot.schedules != null && !snapshot.schedules.isEmpty(), 'Schedules should be returned');
        System.assertNotEquals(null, snapshot.totalInstallmentAmount, 'Totals should be available on snapshot DTO');
    }

    

    @IsTest
    static void testTaxCalculation() {
        // Fetch a booking record
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        
        Test.startTest();
        // Call the fetchSnapshot method for the Booking object
        BookingInterestService.SnapshotDTO snapshot = BookingScheduleCardsCtrl.fetchSnapshot(booking.Id, 'Booking__c');
        Test.stopTest();

        // Assertions
        System.assert(snapshot.totalTaxOnInterestTillToday >= 0, 'Tax Till Today should be non-negative');
        System.assert(snapshot.totalTaxOnInterestOutstanding >= 0, 'Tax Outstanding should be non-negative');
        System.assert(snapshot.schedules != null && !snapshot.schedules.isEmpty(), 'Schedules should be returned');

        // Ensure tax values are correctly calculated
        Decimal totalTaxReceived = snapshot.totalTaxOnInterestReceived;
        Decimal totalTaxOutstanding = snapshot.totalTaxOnInterestOutstanding;
        System.assert(totalTaxReceived >= 0, 'Total Tax Received should be non-negative');
        System.assert(totalTaxOutstanding >= 0, 'Total Tax Outstanding should be non-negative');
    }

    @IsTest
    static void testNextDueDate() {
        // Fetch a booking record
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];

        Test.startTest();
        // Call the fetchSnapshot method for the Booking object
        BookingInterestService.SnapshotDTO snapshot = BookingScheduleCardsCtrl.fetchSnapshot(booking.Id, 'Booking__c');
        Test.stopTest();

        // Assertions for next due date
        System.assertNotEquals(null, snapshot.nextDueDate, 'Next due date should not be null');
        System.assert(snapshot.nextDueDate >= Date.today(), 'Next due date should be today or in the future');
    }
}