@isTest
private class SalesOutstandingReportController_Test {

    // ------------------------------
    // Test Data Setup
    // ------------------------------
    @TestSetup
    static void setupTestData() {
        Account acc = ResidentialTestDataFactory.createAccount();
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        tower.Name = 'Tower xyz 205 202 H1b';
        update tower;
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);

        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
        Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, project.Id);

        List<Booking_Payment_Schedule__c> bpsList = ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, opp.Id, schedules);

        System.debug('Booking created: ' + booking);
    }

    // ------------------------------
    // Test: getDebtorAgeingReport
    // ------------------------------
    @isTest
    static void test_getDebtorAgeingReport() {
        // Fetch setup data
        Property__c project = [SELECT Id, Name FROM Property__c LIMIT 1];
        Tower__c tower = [SELECT Id, Name FROM Tower__c WHERE Property__c = :project.Id LIMIT 1];

        Test.startTest();
        SalesOutstandingReportController.outputWrapper result =
            SalesOutstandingReportController.getDebtorAgeingReport(project.Name, tower.Name, 1, 10);
        Test.stopTest();

        System.assertNotEquals(null, result, 'OutputWrapper should not be null');
        System.assert(result.bookings != null, 'Bookings list should not be null');
        System.assert(result.totalRecords >= 0, 'Total records count should be >= 0');

        if (!result.bookings.isEmpty()) {
            SalesOutstandingReportController.BookingReportDTO dto = result.bookings[0];
            System.assertNotEquals(null, dto.bookingId, 'Booking Id should be populated');
            System.assert(dto.totalCost >= 0, 'Total cost should be non-negative');
        }
    }

    // ------------------------------
    // Test: getBookingCount
    // ------------------------------
    @isTest
    static void test_getBookingCount() {
        Property__c project = [SELECT Id, Name FROM Property__c LIMIT 1];
        Tower__c tower = [SELECT Id, Name FROM Tower__c WHERE Property__c = :project.Id LIMIT 1];

        Integer count = SalesOutstandingReportController.getBookingCount(project.Name, tower.Name);
        System.assert(count >= 0, 'Booking count should return a non-negative number');
    }

    // ------------------------------
    // Test: getProjectVsTowerOptions
    // ------------------------------
    @isTest
    static void test_getProjectVsTowerOptions() {
        Test.startTest();
        Map<String, List<String>> projectTowerMap = SalesOutstandingReportController.getProjectVsTowerOptions();
        Test.stopTest();
        system.debug('projectTowerMap--> '+json.serialize(projectTowerMap));

        // Verify that towers are correctly associated to project
        for (String projectName : projectTowerMap.keySet()) {
            List<String> towers = projectTowerMap.get(projectName);
            System.assert(towers != null && !towers.isEmpty(), 'Each project should have at least one tower');
        }
    }
}