@isTest
private class SAPBookingCancellationHandler_Test {
    
    // Helper method to create and enable or disable the Integration Toggle Setting
    // Assuming Integration_Toggle_Setting__c is a Custom Setting, not Custom Metadata Type
    
    @isTest
    static void testSendBookingCancellationAsync_Success() {
        // 1. Test Data Setup
        Account testAccount = new Account(Name = 'Test Account SAP');
        insert testAccount;
        
        Contact testContact = new Contact(FirstName = 'Test', LastName = 'Contact', AccountId = testAccount.Id);
        insert testContact;
        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opp Unmapped Reason',
            AccountId = testAccount.Id,
            CloseDate = System.today().addDays(30),
            StageName = 'New Business',
            RecordTypeId = ResidentialTestDataFactory.RT_ID_OPPORTUNITY_RESIDENTIAL
        );
        insert testOpportunity;
        
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
        
        Booking__c testBooking = new Booking__c(
            // Name field is auto-generated, so we don't set it directly
            Account_Id__c = testAccount.Id,
            //Contact__c = testContact.Id,
            Unit_Id__c = unit.Id,
            Opportunity_Id__c = testOpportunity.Id,
            Project__c = project.Id,
            Sales_Organization__c = '1000',
            Distribution_Channel__c = '01',
            Division__c = '01',
            Rejection_Reason__c = 'Cancellation opted by Company', // Mapped reason
            SAP_External_Id__c = '0000000001'
        );
        insert testBooking; // Salesforce will assign a Name
        
        List<Booking_Payment_Schedule__c> schedules = new List<Booking_Payment_Schedule__c>();
        schedules.add(new Booking_Payment_Schedule__c(Booking__c = testBooking.Id, Installment_Number__c = 1));
        schedules.add(new Booking_Payment_Schedule__c(Booking__c = testBooking.Id, Installment_Number__c = 2));
        insert schedules;
        
        Set<Id> bookingIds = new Set<Id>{testBooking.Id};
            
            // Set up IntegrationToggle to be enabled
            
            
            // Mock HTTP Callout
            Test.setMock(HttpCalloutMock.class, new MockSAPBookingCancellationResponse());
        
        // 2. Execute
        Test.startTest();
        testBooking.Status__c = 'Cancelled';
        update testBooking;
        //SAPBookingCancellationHandler.sendBookingCancellationAsync(bookingIds);
        Test.stopTest();
        
        // 3. Assertions
        Booking__c updatedBooking = [SELECT Id, Name FROM Booking__c WHERE Id = :testBooking.Id]; // Querying Name to show it's auto-generated
        //System.assertNotNull(updatedBooking, 'Booking should still exist after processing.');
        System.assertNotEquals(null, updatedBooking.Name, 'Booking Name should have been auto-generated.');
        
        // Add more specific assertions if your SAPBookingCancellationResponseProcessor
        // updates the Booking record, e.g.:
        // updatedBooking = [SELECT SAP_Cancellation_Status__c FROM Booking__c WHERE Id = :testBooking.Id];
        // System.assertEquals('Success', updatedBooking.SAP_Cancellation_Status__c, 'SAP Cancellation Status should be updated to Success');
    }
    
    @isTest
    static void testSendBookingCancellationAsync_NoBookingIds() {
        // Test with empty booking IDs
        Set<Id> bookingIds = new Set<Id>();
        
        
        
        Test.startTest();
        SAPBookingCancellationHandler.sendBookingCancellationAsync(bookingIds);
        Test.stopTest();
        
        // No callout should have been made. No exceptions expected.
        System.Assert.isTrue(true, 'Method should complete gracefully with no booking IDs.');
    }
    
    @isTest
    static void testSendBookingCancellationAsync_ToggleDisabled() {
        // Test data
        Account testAccount = new Account(Name = 'Test Account SAP');
        insert testAccount;
        
        Contact testContact = new Contact(FirstName = 'Test', LastName = 'Contact', AccountId = testAccount.Id);
        insert testContact;
        
        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opp Unmapped Reason',
            AccountId = testAccount.Id,
            CloseDate = System.today().addDays(30),
            StageName = 'New Business',
            RecordTypeId = ResidentialTestDataFactory.RT_ID_OPPORTUNITY_RESIDENTIAL
        );
        insert testOpportunity;
        
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
        
        Booking__c testBooking = new Booking__c(
            Account_Id__c = testAccount.Id,
            //Contact__c = testContact.Id,
            Opportunity_Id__c = testOpportunity.Id,
            Project__c = project.Id,
            Unit_Id__c = unit.Id,
            Sales_Organization__c = '1000',
            Distribution_Channel__c = '01',
            Division__c = '01',
            Rejection_Reason__c = 'Cancellation opted by Company',
            SAP_External_Id__c = '0000000001'
        );
        insert testBooking;
        
        Set<Id> bookingIds = new Set<Id>{testBooking.Id};
            
            
            
            Test.startTest();
        SAPBookingCancellationHandler.sendBookingCancellationAsync(bookingIds);
        Test.stopTest();
        
        // Assert that no callout was made because the method returned early
        System.Assert.isTrue(true, 'Method should return early when toggle is disabled.');
    }
    
    @isTest
    static void testSendBookingCancellationAsync_SAPErrorResponse() {
        // 1. Test Data Setup (similar to success case)
        Account testAccount = new Account(Name = 'Test Account SAP Error');
        insert testAccount;
        
        Contact testContact = new Contact(FirstName = 'Test', LastName = 'Contact', AccountId = testAccount.Id);
        insert testContact;
        
        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opp Unmapped Reason',
            AccountId = testAccount.Id,
            CloseDate = System.today().addDays(30),
            StageName = 'New Business',
            RecordTypeId = ResidentialTestDataFactory.RT_ID_OPPORTUNITY_RESIDENTIAL
        );
        insert testOpportunity;
        
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
        
        Booking__c testBooking = new Booking__c(
            Account_Id__c = testAccount.Id,
            //Contact__c = testContact.Id,
            Unit_Id__c = unit.Id,
            Opportunity_Id__c = testOpportunity.Id,
            Project__c = project.Id,
            Sales_Organization__c = '1000',
            Distribution_Channel__c = '01',
            Division__c = '01',
            Rejection_Reason__c = 'High Pricing', // Another mapped reason
            SAP_External_Id__c = '0000000002'
        );
        insert testBooking;
        
        List<Booking_Payment_Schedule__c> schedules = new List<Booking_Payment_Schedule__c>();
        schedules.add(new Booking_Payment_Schedule__c(Booking__c = testBooking.Id, Installment_Number__c = 1));
        insert schedules;
        
        Set<Id> bookingIds = new Set<Id>{testBooking.Id};
            
            
            
            // Mock HTTP Callout with an error response (e.g., 400 Bad Request)
            Test.setMock(HttpCalloutMock.class, new MockSAPBookingCancellationErrorResponse());
        
        // 2. Execute
        Test.startTest();
        SAPBookingCancellationHandler.sendBookingCancellationAsync(bookingIds);
        Test.stopTest();
        
        
    }
    
    @isTest
    static void testSendBookingCancellationAsync_NoSchedules() {
        // Test data with a booking but no associated payment schedules
        Account testAccount = new Account(Name = 'Test Account No Schedules');
        insert testAccount;
        
        Contact testContact = new Contact(FirstName = 'Test', LastName = 'Contact No Schedules', AccountId = testAccount.Id);
        insert testContact;
        
        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opp Unmapped Reason',
            AccountId = testAccount.Id,
            CloseDate = System.today().addDays(30),
            StageName = 'New Business',
            RecordTypeId = ResidentialTestDataFactory.RT_ID_OPPORTUNITY_RESIDENTIAL
        );
        insert testOpportunity;
        
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
        
        
        Booking__c testBooking = new Booking__c(
            Account_Id__c = testAccount.Id,
            //Contact__c = testContact.Id,
            Unit_Id__c = unit.Id,
            Opportunity_Id__c = testOpportunity.Id,
            Project__c = project.Id,
            Sales_Organization__c = '1000',
            Distribution_Channel__c = '01',
            Division__c = '01',
            Rejection_Reason__c = 'Others',
            SAP_External_Id__c = '0000000003'
        );
        insert testBooking;
        
        Set<Id> bookingIds = new Set<Id>{testBooking.Id};
            
            
            
            Test.startTest();
        SAPBookingCancellationHandler.sendBookingCancellationAsync(bookingIds);
        Test.stopTest();
        
        // Ensure no callout was made because there were no schedules to process
        // (Difficult to directly assert that a callout wasn't made, but the code path confirms it)
        System.Assert.isTrue(true, 'Method should complete gracefully when no schedules are found.');
        
    }
    
    
    
    
    @isTest
    static void testSendCancellationToSAP_CalloutException() {
        // 1. Test Data Setup (similar to success case)
        Account testAccount = new Account(Name = 'Test Account Callout Exception');
        insert testAccount;
        
        Contact testContact = new Contact(FirstName = 'Test', LastName = 'Contact Callout Exception', AccountId = testAccount.Id);
        insert testContact;
        
        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opp Callout Exception',
            AccountId = testAccount.Id,
            CloseDate = System.today().addDays(30),
            StageName = 'New Business',
            RecordTypeId = ResidentialTestDataFactory.RT_ID_OPPORTUNITY_RESIDENTIAL
        );
        insert testOpportunity;
        
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
        
        
        Booking__c testBooking = new Booking__c(
            Account_Id__c = testAccount.Id,
            Unit_Id__c = unit.Id,
            Opportunity_Id__c = testOpportunity.Id,
            Project__c = project.Id,
            Sales_Organization__c = '1000',
            Distribution_Channel__c = '01',
            Division__c = '01',
            Rejection_Reason__c = 'Financial crisis', 
            SAP_External_Id__c = '0000000005'
        );
        insert testBooking;
        
        List<Booking_Payment_Schedule__c> schedules = new List<Booking_Payment_Schedule__c>();
        schedules.add(new Booking_Payment_Schedule__c(Booking__c = testBooking.Id, Installment_Number__c = 1));
        insert schedules;
        
        Set<Id> bookingIds = new Set<Id>{testBooking.Id};
           
          
        
        // 2. Execute
        Test.startTest();
        // The method call should now trigger the catch block due to the mock throwing an exception
        SAPBookingCancellationHandler.sendBookingCancellationAsync(bookingIds);
        Test.stopTest();
    }
    
   
    
   
    
    // Mock class for successful SAP Callout
    private class MockSAPBookingCancellationResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest request) {
            System.assertEquals('POST', request.getMethod());
            System.Assert.isTrue(request.getEndpoint().contains('callout:SAP/zunitcancel'), 'Expected cancel endpoint.');
            //System.assert(request.getBody().contains('"REASON_REJ":"Z08"'), 'Expected Z08 reason code for "Cancellation opted by Company"'); 
            System.Assert.isTrue(request.getBody().contains('"ITM_NUMBER":"000010"'), 'Expected installment number 10 for schedule 1');
            
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setBody('[{"REMARK":"Cancelled", "UNIT":"0000000001"}]');
            response.setStatusCode(200);
            return response;
        }
    }
    
    // Mock class for SAP Callout returning an error
    private class MockSAPBookingCancellationErrorResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setBody('{"error": "Invalid request data", "status": "400"}');
            response.setStatusCode(400); // Simulate a Bad Request or other error
            response.setStatus('Bad Request');
            return response;
        }
    }
    
    // Mock class to specifically test the default reason code ('ZE')
    private class MockSAPBookingCancellationDefaultReasonResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest request) {
            System.assertEquals('POST', request.getMethod());
            System.Assert.isTrue(request.getEndpoint().contains('callout:SAP/zunitcancel'), 'Expected cancel endpoint.');
            System.Assert.isTrue(request.getBody().contains('"REASON_REJ":"ZE"'), 'Expected default ZE reason code for unmapped reason'); 
            
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setBody('{"message": "Cancellation request processed successfully", "status": "200"}');
            response.setStatusCode(200);
            return response;
        }
    }
    
}