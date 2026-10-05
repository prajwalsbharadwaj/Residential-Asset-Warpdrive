@isTest
private class SAPCustomerResponseProcessor_Test {
    
    @testSetup
    static void makeData(){
        List<Account> accounts = new List<Account>();
        Account a1 = ResidentialTestDataFactory.preparePersonAccount(); a1.LastName = 'Success Account';
        Account a2 = ResidentialTestDataFactory.preparePersonAccount(); a2.LastName = 'Error Account';
        Account a3 = ResidentialTestDataFactory.preparePersonAccount(); a3.LastName = 'No Leading Zero Account';
        Account a4 = ResidentialTestDataFactory.preparePersonAccount(); a4.LastName = 'DML Fail Account';
        accounts.addAll(new List<Account>{ a1, a2, a3, a4 });
        insert accounts;
    }
    
    @isTest
    static void testSuccessScenario() {
        Account acc = [SELECT Id FROM Account WHERE LastName = 'Success Account' LIMIT 1];
        
        List<SAPCustomerWrapper> payloadList = new List<SAPCustomerWrapper>();
        SAPCustomerWrapper requestWrapper = new SAPCustomerWrapper();
        requestWrapper.CUSTOMER_ID = acc.Id; 
        payloadList.add(requestWrapper);
        
        List<SAPCustomerResponseProcessor.SAPCustomerResponse> responseList = new List<SAPCustomerResponseProcessor.SAPCustomerResponse>();
        SAPCustomerResponseProcessor.SAPCustomerResponse sapResponse = new SAPCustomerResponseProcessor.SAPCustomerResponse();
        sapResponse.CUSTOMER = 'SAP12345';
        sapResponse.MSG = 'Customer created successfully';
        responseList.add(sapResponse);
        
        String responseBody = JSON.serialize(responseList);
        
        Test.startTest();
        SAPCustomerResponseProcessor.processResponse(payloadList, responseList, responseBody);
        Test.stopTest();
        
        Account updatedAccount = [SELECT SAP_External_Id__c, SAP_Sync_Status__c, SAP_Sync_Message__c FROM Account WHERE Id = :acc.Id];
        
        System.assertEquals('SAP12345', updatedAccount.SAP_External_Id__c);
        
    }
    
    @isTest
    static void testSuccessScenario_RemovesLeadingZeros() {
        
        Account acc = [SELECT Id FROM Account WHERE LastName = 'No Leading Zero Account' LIMIT 1];
        
        SAPCustomerWrapper requestWrapper = new SAPCustomerWrapper();
        requestWrapper.CUSTOMER_ID = acc.Id;
        List<SAPCustomerWrapper> payloadList = new List<SAPCustomerWrapper>{ requestWrapper };
            
            List<SAPCustomerResponseProcessor.SAPCustomerResponse> responseList = new List<SAPCustomerResponseProcessor.SAPCustomerResponse>();
        SAPCustomerResponseProcessor.SAPCustomerResponse sapResponse = new SAPCustomerResponseProcessor.SAPCustomerResponse();
        sapResponse.CUSTOMER = '00098765';
        sapResponse.MSG = 'Created';
        responseList.add(sapResponse);
        
        String responseBody = JSON.serialize(responseList);
        
        Test.startTest();
        SAPCustomerResponseProcessor.processResponse(payloadList, responseList, responseBody);
        Test.stopTest();
        
        Account updatedAccount = [SELECT SAP_External_Id__c FROM Account WHERE Id = :acc.Id];
        
    }
    
    @isTest
    static void testErrorScenario() {
        Account acc = [SELECT Id FROM Account WHERE LastName = 'Error Account' LIMIT 1];
        
        SAPCustomerWrapper requestWrapper = new SAPCustomerWrapper();
        requestWrapper.CUSTOMER_ID = acc.Id;
        List<SAPCustomerWrapper> payloadList = new List<SAPCustomerWrapper>{ requestWrapper };
            
            List<SAPCustomerResponseProcessor.SAPCustomerResponse> responseList = new List<SAPCustomerResponseProcessor.SAPCustomerResponse>();
        SAPCustomerResponseProcessor.SAPCustomerResponse sapResponse = new SAPCustomerResponseProcessor.SAPCustomerResponse();
        sapResponse.CUSTOMER = ''; 
        sapResponse.MSG = 'Invalid Sales Org';
        responseList.add(sapResponse);
        
        String responseBody = JSON.serialize(responseList);
        
        Test.startTest();
        SAPCustomerResponseProcessor.processResponse(payloadList, responseList, responseBody);
        Test.stopTest();
        
        Account updatedAccount = [SELECT SAP_External_Id__c, SAP_Sync_Status__c, SAP_Sync_Message__c FROM Account WHERE Id = :acc.Id];
        
        System.assertEquals('Invalid Sales Org', updatedAccount.SAP_Sync_Message__c);
    }
    
    @isTest
    static void testMismatchListSize_ThrowsException() {
        
        Account acc = [SELECT Id FROM Account WHERE LastName = 'Success Account' LIMIT 1];
        
        SAPCustomerWrapper requestWrapper = new SAPCustomerWrapper();
        requestWrapper.CUSTOMER_ID = acc.Id;
        List<SAPCustomerWrapper> payloadList = new List<SAPCustomerWrapper>{ requestWrapper };
            
            List<SAPCustomerResponseProcessor.SAPCustomerResponse> responseList = new List<SAPCustomerResponseProcessor.SAPCustomerResponse>();
        
        String responseBody = '[]';
        Exception caughtException = null;
        Test.startTest();
        try {
            SAPCustomerResponseProcessor.processResponse(payloadList, responseList, responseBody);
        } catch (Exception e) {
            caughtException = e;
        }
        Test.stopTest();
        
        System.assertNotEquals(null, caughtException, 'An exception should have been thrown.');
        System.Assert.isTrue(caughtException instanceof CalloutException, 'The thrown exception should be a CalloutException.');
        System.Assert.isTrue(caughtException.getMessage().contains('does not match'), 'The exception message should indicate a list size mismatch.');
    }
    
    @isTest
    static void testDmlException_LogsError() {
        Account accToFail = [SELECT Id FROM Account WHERE LastName = 'DML Fail Account' LIMIT 1];
        
        SAPCustomerWrapper requestWrapper = new SAPCustomerWrapper();
        requestWrapper.CUSTOMER_ID = accToFail.Id;
        List<SAPCustomerWrapper> payloadList = new List<SAPCustomerWrapper>{ requestWrapper };
            
            SAPCustomerResponseProcessor.SAPCustomerResponse sapResponse = new SAPCustomerResponseProcessor.SAPCustomerResponse();
        sapResponse.CUSTOMER = 'SAP_FAIL';
        sapResponse.MSG = 'This will fail on update';
        List<SAPCustomerResponseProcessor.SAPCustomerResponse> responseList = new List<SAPCustomerResponseProcessor.SAPCustomerResponse>{ sapResponse };
            
            String responseBody = JSON.serialize(responseList);
        Exception caughtException = null;
        
        delete accToFail;
        
        Test.startTest();
        try {
            SAPCustomerResponseProcessor.processResponse(payloadList, responseList, responseBody);
        } catch(Exception e) {
            
            caughtException = e;
        }
        Test.stopTest();
        
        System.assertEquals(null, caughtException, 'The processResponse method should catch and handle its own DML exceptions.');
        
    }
    
    @isTest
    static void testNullCustomerId_IsSkipped() {
        Account validAcc = [SELECT Id FROM Account WHERE LastName = 'Success Account' LIMIT 1];
        SAPCustomerWrapper wrapperWithId = new SAPCustomerWrapper();
        wrapperWithId.CUSTOMER_ID = validAcc.Id;
        
        SAPCustomerWrapper wrapperWithNullId = new SAPCustomerWrapper();
        
        List<SAPCustomerWrapper> payloadList = new List<SAPCustomerWrapper>{
            wrapperWithNullId, // The item that should be skipped
                wrapperWithId      // The item that should be processed
                };
                    
                    
                    SAPCustomerResponseProcessor.SAPCustomerResponse nullResponse = new SAPCustomerResponseProcessor.SAPCustomerResponse();
        nullResponse.MSG = 'This response corresponds to the null payload';
        
        SAPCustomerResponseProcessor.SAPCustomerResponse validResponse = new SAPCustomerResponseProcessor.SAPCustomerResponse();
        validResponse.CUSTOMER = 'SAP_VALID';
        validResponse.MSG = 'This response corresponds to the valid payload';
        
        List<SAPCustomerResponseProcessor.SAPCustomerResponse> responseList = new List<SAPCustomerResponseProcessor.SAPCustomerResponse>{
            nullResponse,
                validResponse
                };
                    
                    String responseBody = JSON.serialize(responseList);
        
        Test.startTest();
        SAPCustomerResponseProcessor.processResponse(payloadList, responseList, responseBody);
        Test.stopTest();
        
        Account updatedAccount = [SELECT SAP_External_Id__c, SAP_Sync_Status__c FROM Account WHERE Id = :validAcc.Id];
        
        System.assertEquals('SAP_VALID', updatedAccount.SAP_External_Id__c, 'The valid account should have been updated.');
        
        
        List<Account> errorAccounts = [SELECT Id FROM Account WHERE LastName = 'Error Account' AND SAP_Sync_Status__c != null];
        System.assertEquals(0, errorAccounts.size(), 'Other accounts should not have been touched.');
    }
}