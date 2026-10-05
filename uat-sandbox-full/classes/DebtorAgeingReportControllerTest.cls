@IsTest
private class DebtorAgeingReportControllerTest {

    // Test Data Setup
    @TestSetup
    static void setupTestData() {
       Account acc = ResidentialTestDataFactory.createAccount();
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        tower.Name = 'Tower xyz 001 204 H1b';
        update tower;
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);

        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
        Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, project.Id);
        list<Booking_Payment_Schedule__c> bpsList = ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, opp.Id, schedules);
        system.debug('booking created '+booking);
        
        
    }

    @IsTest
    static void testGetBookings_NormalCase() {
        
        Test.startTest();
        DebtorAgeingReportController.outputWrapper ow = DebtorAgeingReportController.getBookings('Tower xyz 001 204 H1b', 1, 5);
        Test.stopTest();

        System.assertNotEquals(null, ow, 'Output wrapper should not be null');
        System.assertNotEquals(null, ow.bookings, 'Bookings should not be null');
        System.assert(ow.bookings.size() > 0, 'Bookings list should contain data');
        System.assert(ow.totalRecords > 0, 'Total records should be positive');
        System.assertEquals(1, ow.pageNumber, 'Page number should match');
        System.assertEquals(5, ow.pageSize, 'Page size should match');
        System.assert(ow.totalPages >= 1, 'Total pages should be at least 1');
    }

    @IsTest
    static void testGetBookings_NullParams() {
        Test.startTest();
        DebtorAgeingReportController.outputWrapper ow = DebtorAgeingReportController.getBookings('Tower xyz 001 204 H1b', null, null);
        Test.stopTest();

        System.assertEquals(1, ow.pageNumber, 'Page number should default to 1');
        System.assertEquals(20, ow.pageSize, 'Page size should default to 20');
    }

    @IsTest
    static void testGetTowerOptions() {
        Test.startTest();
        List<String> towers = DebtorAgeingReportController.getTowerOptions();
        Test.stopTest();
    }

    @IsTest
    static void testEdgeCases_EmptyTower() {
        Test.startTest();
        DebtorAgeingReportController.outputWrapper ow = DebtorAgeingReportController.getBookings('NonexistentTower', 1, 5);
        Test.stopTest();

        System.assertEquals(0, ow.bookings.size(), 'No bookings should be returned for invalid tower');
        System.assertEquals(0, ow.totalRecords, 'Total records should be 0 for invalid tower');
    }
    
    @isTest
    static void amtDueInRange_test(){
        list<Booking_Payment_Schedule__c> bpsList = [SELECT Id, Installment_Amount__c,Payment_Due_Date__c, Outstanding_Principal__c FROM Booking_Payment_Schedule__c];

        for(Booking_Payment_Schedule__c bps:bpsList){
            bps.Payment_Due_Date__c = Date.today().addMonths(-3).addDays(10);
        }
        update bpsList;
        system.debug('bps--> '+json.serialize(bpsList[0]));
        test.startTest();
        DebtorAgeingReportController.amtDueInRange(bpsList, 0, 30, date.Today().addMonths(-3));
        test.stopTest();
        
    }
    
    @isTest
static void amtDueMoreThan365Days_test() {
    // Prepare test data
    Date bookingDate = Date.today();

    List<Booking_Payment_Schedule__c> bpsList = [SELECT Id, Installment_Amount__c,Payment_Due_Date__c, Outstanding_Principal__c FROM Booking_Payment_Schedule__c];
    for(Booking_Payment_Schedule__c bps:bpsList){
        bps.Payment_Due_Date__c = bookingDate.addDays(400);
        }
        update bpsList;
    Test.startTest();
    Decimal result = DebtorAgeingReportController.amtDueMoreThan365Days(bpsList, bookingDate);
    Test.stopTest();

    // Assert only the record with >365 days contributes to amount
    //System.assertEquals(1500, result, 'Only the record with due date > 365 days should be counted.');
}
    
    @isTest
static void getPicklistLabel_test() {
    // Choose a standard picklist field for testing (StageName on Opportunity)
    Schema.DescribeFieldResult fieldDesc = Opportunity.StageName.getDescribe();

    // Get one valid API value and label from the picklist
    List<Schema.PicklistEntry> entries = fieldDesc.getPicklistValues();
    String validApiValue = entries[0].getValue();
    String expectedLabel = entries[0].getLabel();

    // Test for valid API value
    String label = DebtorAgeingReportController.getPicklistLabel(Opportunity.StageName, validApiValue);
    System.assertEquals(expectedLabel, label, 'Should return correct picklist label for valid API value.');

    // Test for invalid API value (should return null)
    String invalidLabel = DebtorAgeingReportController.getPicklistLabel(Opportunity.StageName, 'InvalidValue');
    System.assertEquals(null, invalidLabel, 'Should return null for invalid API value.');

    // Test for blank API value (should return null)
    String blankLabel = DebtorAgeingReportController.getPicklistLabel(Opportunity.StageName, '');
    System.assertEquals(null, blankLabel, 'Should return null for blank API value.');
}


}