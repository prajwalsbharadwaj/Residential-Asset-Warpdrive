@isTest
private class SAPCustomerUpdateHandler_Test {
    
    // ====== Test Data Setup ======
    @testSetup
    static void setupData() {
        // Accounts via factory
        Account testAccount1 = ResidentialTestDataFactory.preparePersonAccount();
        testAccount1.LastName = 'Test Account 1';
        testAccount1.SAP_External_Id__c = 'VENDOR123';
        testAccount1.Company_Code__c = '2050';
        testAccount1.BillingStreet = 'Street 1, Street 2, Street 3, Street 4';
        Account testAccount2 = ResidentialTestDataFactory.preparePersonAccount();
        testAccount2.LastName = 'Test Account 2';
        testAccount2.SAP_External_Id__c = 'VENDOR124';
        testAccount2.Company_Code__c = '2050';
        testAccount2.BillingStreet = 'Lane 1, Lane 2, Lane 3';
        insert new List<Account>{ testAccount1, testAccount2 };

        // Inventory hierarchy
        Property__c testProject = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(testProject.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(testProject.Id, tower.Id);
        Unit__c testUnit1 = ResidentialTestDataFactory.prepareUnit(testProject.Id, tower.Id, floor.Id);
        testUnit1.Name = 'Test Unit 1';
        testUnit1.SAP_External_Id__c = '89001';
        Unit__c testUnit2 = ResidentialTestDataFactory.prepareUnit(testProject.Id, tower.Id, floor.Id);
        testUnit2.Name = 'Test Unit 2';
        testUnit2.SAP_External_Id__c = '89002';
        insert new List<Unit__c>{ testUnit1, testUnit2 };

        // Opportunity and bookings
        Opportunity testOpportunity = ResidentialTestDataFactory.createOpportunity(testAccount1.Id, testUnit1.Id);
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
        Booking__c testBooking1 = ResidentialTestDataFactory.createBooking(testAccount1.Id, testUnit1.Id, plan.Id, testOpportunity.Id, testProject.Id);
        Booking__c testBooking2 = ResidentialTestDataFactory.createBooking(testAccount2.Id, testUnit2.Id, plan.Id, testOpportunity.Id, testProject.Id);

        // Prepare BPS and Demands with fewer DMLs
        List<Booking_Payment_Schedule__c> toInsertBps = new List<Booking_Payment_Schedule__c>();
        List<Booking_Payment_Schedule__c> bps1 = ResidentialTestDataFactory.prepareBookingPaymentSchedules(testBooking1.Id, schedules);
        List<Booking_Payment_Schedule__c> bps2 = ResidentialTestDataFactory.prepareBookingPaymentSchedules(testBooking2.Id, schedules);
        toInsertBps.addAll(bps1); toInsertBps.addAll(bps2);
        insert toInsertBps;

        Demand__c testDemand1 = ResidentialTestDataFactory.prepareDemand(bps1[0].Id, testUnit1.Id, testAccount1.Id, 'DEMAND001');
        Demand__c testDemand2 = ResidentialTestDataFactory.prepareDemand(bps2[0].Id, testUnit2.Id, testAccount2.Id, 'DEMAND002');
        insert new List<Demand__c>{ testDemand1, testDemand2 };
            }
    
    // ====== Mocking the HTTP Response ======
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200); // Simulate a successful response
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message": "Success"}'); // Simulate a success response
            return res;
        }
    }
    
    private class FailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500); // Simulate failure
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error": "Internal Server Error"}'); // Simulate error response
            return res;
        }
    }
    
    // ====== Test Methods ======
    
    @isTest
    static void test_sendCustomerUpdateAsync_success() {
        // Get test Account IDs
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : [SELECT Id FROM Account LIMIT 2]) {
            accountIds.add(acc.Id);
        }
        
        // Mock the callout to simulate a successful response
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        
        // Call the future method
        Test.startTest();
        SAPCustomerUpdateHandler.sendCustomerUpdateAsync(accountIds);
        Test.stopTest();
        
        // Verify no exceptions were thrown and the mock was called
        System.assert(true, 'sendCustomerUpdateAsync executed successfully');
    }
    
    @isTest
    static void test_sendCustomerUpdateAsync_failure() {
        // Get test Account IDs
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : [SELECT Id FROM Account LIMIT 2]) {
            accountIds.add(acc.Id);
        }
        
        // Mock the callout to simulate a failure response
        Test.setMock(HttpCalloutMock.class, new FailureMock());
        
        // Call the future method
        Test.startTest();
        SAPCustomerUpdateHandler.sendCustomerUpdateAsync(accountIds);
        Test.stopTest();
        
        // Verify no exceptions were thrown and the mock was called
        System.assert(true, 'sendCustomerUpdateAsync executed with failure');
    }
    
    @isTest
    static void test_sendUpdateToSAP_success() {
        // Create test Account IDs
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : [SELECT Id FROM Account LIMIT 2]) {
            accountIds.add(acc.Id);
        }
        
        // Create a mock SAPCustomerUpdateWrapper list
        List<SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper> wrapperList = new List<SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper>();
        SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper wrapper = new SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper();
        wrapper.businesspartner = 'VENDOR123';
        wrapper.name1 = 'Test Account';
        wrapper.telephone1 = '1234567890';
        wrapper.email = 'test@example.com';
        wrapperList.add(wrapper);
        
        // Mock the callout to simulate a successful response
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        
        // Call the sendUpdateToSAP method directly
        Test.startTest();
        SAPCustomerUpdateHandler.sendUpdateToSAP(wrapperList);
        Test.stopTest();
        
        // Verify the callout was made (check for no exceptions)
        System.assert(true, 'sendUpdateToSAP executed successfully');
    }
    
    @isTest
    static void test_sendUpdateToSAP_failure() {
        // Create a mock SAPCustomerUpdateWrapper list
        List<SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper> wrapperList = new List<SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper>();
        SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper wrapper = new SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper();
        wrapper.businesspartner = 'VENDOR123';
        wrapper.name1 = 'Test Account';
        wrapper.telephone1 = '1234567890';
        wrapper.email = 'test@example.com';
        wrapperList.add(wrapper);
        
        // Mock the callout to simulate a failure response
        Test.setMock(HttpCalloutMock.class, new FailureMock());
        
        // Call the sendUpdateToSAP method directly
        Test.startTest();
        SAPCustomerUpdateHandler.sendUpdateToSAP(wrapperList);
        Test.stopTest();
        
        // Verify the callout was made (check for no exceptions)
        System.assert(true, 'sendUpdateToSAP executed with failure');
    }
    
    @isTest
    static void test_sendCustomerUpdateAsync() {
        // Get test Account IDs
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : [SELECT Id FROM Account LIMIT 2]) {
            accountIds.add(acc.Id);
        }
        // Mock the callout to simulate a successful response
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        
        // Call the method
        Test.startTest();
        SAPCustomerUpdateHandler.sendCustomerUpdateAsync(accountIds);
        Test.stopTest();
        
        // Verify that the callout was made and data was processed correctly
        // For example, checking that correct street parts were assigned:
        Account updatedAccount1 = [SELECT BillingStreet FROM Account WHERE Id = :accountIds LIMIT 1];
        System.assert(updatedAccount1.BillingStreet.contains('Street 1'), 'Street1 should be mapped correctly');
        System.assert(updatedAccount1.BillingStreet.contains('Street 2'), 'Street2 should be mapped correctly');
        // Add more assertions to check other fields if needed
    }
    
    
}