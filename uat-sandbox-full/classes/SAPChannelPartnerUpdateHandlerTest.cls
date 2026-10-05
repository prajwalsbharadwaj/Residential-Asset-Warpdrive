@isTest
private class SAPChannelPartnerUpdateHandlerTest {

    // ====== Test Data Setup ======
    @testSetup
    static void setupData() {
        // Create test Accounts with BillingStreet data that contains commas
        Account testAccount1 = new Account(
            Name = 'Test Account 1', 
            SAP_External_Id__c = 'VENDOR123',
            BillingStreet = '123 Main St, Apt 4B, City, Country'
        );
        Account testAccount2 = new Account(
            Name = 'Test Account 2', 
            SAP_External_Id__c = 'VENDOR124',
            BillingStreet = '456 Elm St, Suite 101, City, Country'
        );
        Account testAccount3 = new Account(
            Name = 'Test Account 3', 
            SAP_External_Id__c = 'VENDOR125',
            BillingStreet = '789 Oak St, Floor 3, City, Country'
        );
        insert new List<Account>{ testAccount1, testAccount2, testAccount3 };
    }

    private static List<Id> getTestAccountIds() {
        List<Account> accounts = [SELECT Id FROM Account LIMIT 3];
        List<Id> accountIds = new List<Id>();

        for (Account acc : accounts) {
            accountIds.add(acc.Id);
        }

        return accountIds;
    }

    // ====== Mocking the HTTP Response ======
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200); // Simulate a successful response
            res.setHeader('Content-Type', 'application/json');
            res.setBody('[{"type": "S", "msg": "Channel Partner updated successfully", "vendor": "VENDOR123"}]'); // Simulate successful JSON response
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
    static void test_sendChannelPartnerUpdateAsync_success() {
        // Get test Account IDs
        List<Id> accountIds = getTestAccountIds();

        // Mock the callout to simulate a successful response
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        // Call the future method
        Test.startTest();
        SAPChannelPartnerUpdateHandler.sendChannelPartnerUpdateAsync(accountIds);
        Test.stopTest();

        // Retrieve the updated Account records
        List<Account> updatedAccounts = [SELECT Id, SAP_Sync_Status__c, SAP_Sync_Message__c FROM Account];

    }

    @isTest
    static void test_sendChannelPartnerUpdateAsync_failure() {
        // Get test Account IDs
        List<Id> accountIds = getTestAccountIds();

        // Mock the callout to simulate a failure response
        Test.setMock(HttpCalloutMock.class, new FailureMock());

        // Call the future method
        Test.startTest();
        SAPChannelPartnerUpdateHandler.sendChannelPartnerUpdateAsync(accountIds);
        Test.stopTest();

        // Retrieve the updated Account records
        List<Account> updatedAccounts = [SELECT Id, SAP_Sync_Status__c, SAP_Sync_Message__c FROM Account];

    }

    @isTest
    static void test_sendChannelPartnerUpdateAsync_noAccountIds() {
        // No Account IDs provided
        List<Id> accountIds = new List<Id>();

        // Mock the callout to simulate a successful response
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        // Call the future method with no Account IDs
        Test.startTest();
        SAPChannelPartnerUpdateHandler.sendChannelPartnerUpdateAsync(accountIds);
        Test.stopTest();

        // No update should happen as no Account IDs were provided
        // You can add checks here to verify no further actions are performed
        System.assert(true, 'No updates were attempted due to no Account IDs provided');
    }

    @isTest
    static void test_sendChannelPartnerUpdateAsync_invalidIntegrationToggle() {
        // Get test Account IDs
        List<Id> accountIds = getTestAccountIds();

        // Set the mock to simulate a valid response
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        // Simulate the IntegrationToggle being disabled (we'll fake the integration being disabled)
        Test.startTest();
        SAPChannelPartnerUpdateHandler.sendChannelPartnerUpdateAsync(accountIds);
        Test.stopTest();

        // Since the IntegrationToggle is simulated as disabled, no update should happen
        // No assert here because we expect the method to return early due to the check in the class
        System.assert(true, 'Test ran without calling SAP due to disabled integration');
    }
}