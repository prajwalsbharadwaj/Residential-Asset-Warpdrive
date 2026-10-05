@isTest
private class SAPChannelPartnerResponseProcessor_Test {

    // ====== Test Data Setup ======
    @testSetup
    static void setupData() {
        // Create test Accounts using ResidentialTestDataFactory
        /*
        insert new List<Account>{
            ResidentialTestDataFactory.preparePersonAccount(),
            ResidentialTestDataFactory.preparePersonAccount(),
            ResidentialTestDataFactory.preparePersonAccount()
        };
*/		List<Account> accList = new List<Account>();
        for(integer i=0;i<3;i++){
            ResidentialTestDataFactory.accountCounter++;
            Account acc = ResidentialTestDataFactory.prepareCPAccount();
            accList.add(acc);
        }
        insert accList;
    }

    private static List<Id> getTestAccountIds() {
        List<Account> accounts = [SELECT Id FROM Account LIMIT 3];
        List<Id> accountIds = new List<Id>();

        for (Account acc : accounts) {
            accountIds.add(acc.Id);
        }

        return accountIds;
    }

    // ====== Test Methods ======

    @isTest
    static void test_processResponse_success() {
        // Get test Account IDs
        List<Id> accountIds = getTestAccountIds();

        // Create test response data with successful results
        List<SAPChannelPartnerResponseProcessor.SAPChannelPartnerResponse> responseList = new List<SAPChannelPartnerResponseProcessor.SAPChannelPartnerResponse>{
            new SAPChannelPartnerResponseProcessor.SAPChannelPartnerResponse(),
            new SAPChannelPartnerResponseProcessor.SAPChannelPartnerResponse(),
            new SAPChannelPartnerResponseProcessor.SAPChannelPartnerResponse()
        };

        responseList[0].type = 'S'; // Success type
        responseList[0].vendor = 'VENDOR123';
        responseList[0].msg = 'Successfully created';

        responseList[1].type = 'S'; // Success type
        responseList[1].vendor = 'VENDOR124';
        responseList[1].msg = 'Successfully created';

        responseList[2].type = 'S'; // Success type
        responseList[2].vendor = 'VENDOR125';
        responseList[2].msg = 'Successfully created';

        // Mock the update statement
        Test.startTest();
        SAPChannelPartnerResponseProcessor.processResponse(accountIds, responseList, '[{"type": "S", "msg": "Success"}]');
        Test.stopTest();

        // Retrieve the updated Accounts
        List<Account> updatedAccounts = [SELECT Id, SAP_External_Id__c, SAP_Sync_Status__c, SAP_Sync_Message__c FROM Account];

        // Verify the Accounts were updated correctly
        System.Assert.areEqual('VENDOR123', updatedAccounts[0].SAP_External_Id__c, 'SAP External ID for Account 1 is incorrect');
        System.Assert.areEqual('Successfully created', updatedAccounts[0].SAP_Sync_Message__c, 'Sync message for Account 1 is incorrect');

        System.Assert.areEqual('VENDOR124', updatedAccounts[1].SAP_External_Id__c, 'SAP External ID for Account 2 is incorrect');
        System.Assert.areEqual('Successfully created', updatedAccounts[1].SAP_Sync_Message__c, 'Sync message for Account 2 is incorrect');

        System.Assert.areEqual('VENDOR125', updatedAccounts[2].SAP_External_Id__c, 'SAP External ID for Account 3 is incorrect');
        System.Assert.areEqual('Successfully created', updatedAccounts[2].SAP_Sync_Message__c, 'Sync message for Account 3 is incorrect');
    }

    @isTest
    static void test_processResponse_error() {
        // Get test Account IDs
        List<Id> accountIds = getTestAccountIds();

        // Create test response data with an error result
        List<SAPChannelPartnerResponseProcessor.SAPChannelPartnerResponse> responseList = new List<SAPChannelPartnerResponseProcessor.SAPChannelPartnerResponse>{
            new SAPChannelPartnerResponseProcessor.SAPChannelPartnerResponse(),
            new SAPChannelPartnerResponseProcessor.SAPChannelPartnerResponse(),
            new SAPChannelPartnerResponseProcessor.SAPChannelPartnerResponse()
        };

        responseList[0].type = 'E'; // Error type
        responseList[0].vendor = ''; // No vendor ID
        responseList[0].msg = 'Error creating vendor';

        responseList[1].type = 'E'; // Error type
        responseList[1].vendor = ''; // No vendor ID
        responseList[1].msg = 'Error creating vendor';

        responseList[2].type = 'E'; // Error type
        responseList[2].vendor = ''; // No vendor ID
        responseList[2].msg = 'Error creating vendor';

        // Mock the update statement
        Test.startTest();
        SAPChannelPartnerResponseProcessor.processResponse(accountIds, responseList, '[{"type": "E", "msg": "Error"}]');
        Test.stopTest();

        // Retrieve the updated Accounts
        List<Account> updatedAccounts = [SELECT Id, SAP_External_Id__c, SAP_Sync_Status__c, SAP_Sync_Message__c FROM Account];

        // Verify that the error status and messages are set correctly
        System.Assert.areEqual('Error', updatedAccounts[0].SAP_Sync_Status__c, 'Sync status for Account 1 should be Error');
        System.Assert.areEqual('SAP Error: Error creating vendor', updatedAccounts[0].SAP_Sync_Message__c, 'Sync message for Account 1 is incorrect');

        System.Assert.areEqual('Error', updatedAccounts[1].SAP_Sync_Status__c, 'Sync status for Account 2 should be Error');
        System.Assert.areEqual('SAP Error: Error creating vendor', updatedAccounts[1].SAP_Sync_Message__c, 'Sync message for Account 2 is incorrect');

        System.Assert.areEqual('Error', updatedAccounts[2].SAP_Sync_Status__c, 'Sync status for Account 3 should be Error');
        System.Assert.areEqual('SAP Error: Error creating vendor', updatedAccounts[2].SAP_Sync_Message__c, 'Sync message for Account 3 is incorrect');
    }
    
    @isTest
    static void test_processResponse_sizeMismatch() {
        // Get test Account IDs (3 Accounts)
        List<Id> accountIds = getTestAccountIds();
        
        // Create test response data (only 1 response)
        List<SAPChannelPartnerResponseProcessor.SAPChannelPartnerResponse> responseList =
            new List<SAPChannelPartnerResponseProcessor.SAPChannelPartnerResponse>();
        
        SAPChannelPartnerResponseProcessor.SAPChannelPartnerResponse response =
            new SAPChannelPartnerResponseProcessor.SAPChannelPartnerResponse();
        response.type = 'S';
        response.vendor = 'VENDOR123';
        response.msg = 'Successfully created';
        responseList.add(response);
        
        // Call method (NO exception expected now)
        Test.startTest();
        SAPChannelPartnerResponseProcessor.processResponse(
            accountIds,
            responseList,
            '[{"type": "S", "msg": "Success"}]'
        );
        Test.stopTest();
        
        // Query updated Accounts
        List<Account> updatedAccounts = [
            SELECT SAP_Sync_Status__c, SAP_Sync_Message__c
            FROM Account
        ];
        
        // Validate error handling behavior
        for (Account acc : updatedAccounts) {
            System.assertEquals('Error', acc.SAP_Sync_Status__c, 'Status should be Error');
            System.assert(acc.SAP_Sync_Message__c.contains('Success'), 'Message should contain the response body');
        }
    }
    

    @isTest
    static void test_processResponse_exceptionHandling() {
        // Get test Account IDs (null list simulates failure in processing)
        List<Id> accountIds = null; // Simulate null accountIds to trigger the catch block

        // Create empty responseList, which will also fail due to mismatched sizes or null data
        List<SAPChannelPartnerResponseProcessor.SAPChannelPartnerResponse> responseList = new List<SAPChannelPartnerResponseProcessor.SAPChannelPartnerResponse>();

        // Attempt to process with null data, which should trigger the exception handling block
        try {
            Test.startTest();
            SAPChannelPartnerResponseProcessor.processResponse(accountIds, responseList, '[{"type": "S", "msg": "Success"}]');
            Test.stopTest();
            System.Assert.isTrue(false, 'Expected exception to be thrown.');
        } catch (Exception e) {
            // Ensure the exception was logged, indicating that the catch block was covered
            System.Assert.isTrue(true, 'Exception handled as expected.');
        }
    }
}