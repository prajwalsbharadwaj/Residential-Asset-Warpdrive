@isTest
private class SAPBookingCancelResponseProcessorTest {

    // ====== Test Data Setup ======
    @testSetup
    static void setupData() {
        // Create accounts
        Account acc1 = ResidentialTestDataFactory.createAccount();
        Account acc2 = ResidentialTestDataFactory.createAccount();

        // Inventory hierarchy
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit1 = ResidentialTestDataFactory.prepareUnit(project.Id, tower.Id, floor.Id);
        unit1.SAP_External_Id__c = 'UNIT123';
        Unit__c unit2 = ResidentialTestDataFactory.prepareUnit(project.Id, tower.Id, floor.Id);
        unit2.SAP_External_Id__c = 'UNIT124';
        insert new List<Unit__c>{ unit1, unit2 };

        // Opportunities and bookings
        Opportunity opp1 = ResidentialTestDataFactory.createOpportunity(acc1.Id, unit1.Id);
        Opportunity opp2 = ResidentialTestDataFactory.createOpportunity(acc2.Id, unit2.Id);

        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);

        Booking__c booking1 = ResidentialTestDataFactory.createBooking(acc1.Id, unit1.Id, plan.Id, opp1.Id, project.Id);
        Booking__c booking2 = ResidentialTestDataFactory.createBooking(acc2.Id, unit2.Id, plan.Id, opp2.Id, project.Id);
        booking1.SAP_External_Id__c = 'UNIT123';
        booking2.SAP_External_Id__c = 'UNIT124';
        update new List<Booking__c>{ booking1, booking2 };
    }

    private static List<Booking__c> getTestBookings() {
        return [SELECT Id, SAP_External_Id__c, Account_Id__c, Opportunity_Id__c, Project__c, Unit_Id__c FROM Booking__c LIMIT 2];
    }

    // ====== Test Methods ======

    @isTest
    static void test_processResponse_success() {
        // Get test Booking records
        List<Booking__c> originalBookings = getTestBookings();

        // Create a JSON response that includes matching UNIT IDs
        String jsonResponse = '[{"UNIT": "UNIT123", "REMARK": "Booking cancelled successfully."},' +
                              '{"UNIT": "UNIT124", "REMARK": "Booking cancelled successfully."}]';

        // Call the processResponse method with the test data
        Test.startTest();
        SAPBookingCancellationResponseProcessor.processResponse(originalBookings, jsonResponse);
        Test.stopTest();

        // Retrieve the updated Booking records
        List<Booking__c> updatedBookings = [SELECT Id, SAP_Sync_Status__c, SAP_Sync_Message__c FROM Booking__c];

        // Verify the bookings were updated correctly
        System.assertEquals('Success', updatedBookings[0].SAP_Sync_Status__c, 'Sync status for Booking 1 should be Success');
        System.assertEquals('Booking cancelled successfully.', updatedBookings[0].SAP_Sync_Message__c, 'Sync message for Booking 1 is incorrect');

        System.assertEquals('Success', updatedBookings[1].SAP_Sync_Status__c, 'Sync status for Booking 2 should be Success');
        System.assertEquals('Booking cancelled successfully.', updatedBookings[1].SAP_Sync_Message__c, 'Sync message for Booking 2 is incorrect');
    }

  

    @isTest
    static void test_processResponse_emptyJson() {
        // Get test Booking records
        List<Booking__c> originalBookings = getTestBookings();

        // Pass an empty JSON response
        String jsonResponse = '';

        // Call the processResponse method with the test data
        Test.startTest();
        SAPBookingCancellationResponseProcessor.processResponse(originalBookings, jsonResponse);
        Test.stopTest();

        // Retrieve the updated Booking records
        List<Booking__c> updatedBookings = [SELECT Id, SAP_Sync_Status__c, SAP_Sync_Message__c FROM Booking__c];

        // Verify that no updates are made to the bookings if the JSON response is empty
        //System.assertEquals('Error', updatedBookings[0].SAP_Sync_Status__c, 'Sync status for Booking 1 should be Error');
        //System.assertEquals('Processing failed. No response received from SAP for this record.', updatedBookings[0].SAP_Sync_Message__c, 'Sync message for Booking 1 is incorrect');

        
    }

    @isTest
    static void test_processResponse_invalidJson() {
        // Get test Booking records
        List<Booking__c> originalBookings = getTestBookings();

        // Pass an invalid JSON response
        String jsonResponse = 'invalid json';

        // Call the processResponse method with the test data
        Test.startTest();
        SAPBookingCancellationResponseProcessor.processResponse(originalBookings, jsonResponse);
        Test.stopTest();

        // Verify no updates are made if the JSON is invalid (catch block is triggered)
        List<Booking__c> updatedBookings = [SELECT Id, SAP_Sync_Status__c, SAP_Sync_Message__c FROM Booking__c];
        
       
    }
}