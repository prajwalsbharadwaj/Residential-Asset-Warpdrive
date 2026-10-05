@isTest
private class SAPCustomerIntegrationHandler_Test {

    // ===== MOCK HTTP RESPONSES =====
    private class SAPSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            // Create full mock SAP response
            List<SAPCustomerResponseProcessor.SAPCustomerResponse> mockResponses =
                new List<SAPCustomerResponseProcessor.SAPCustomerResponse>();
            
            SAPCustomerResponseProcessor.SAPCustomerResponse res =
                new SAPCustomerResponseProcessor.SAPCustomerResponse();
            
            res.TYPE     = 'S';               // Success indicator (most SAP APIs use S)
            res.SRNO     = '001';             // Dummy serial no.
            res.CUSTOMER = 'SAP1234567';
            res.MSG      = 'Customer Created';
            
            mockResponses.add(res);
            
            HttpResponse httpRes = new HttpResponse();
            httpRes.setHeader('Content-Type', 'application/json');
            httpRes.setBody(JSON.serialize(mockResponses));
            httpRes.setStatusCode(201);
            return httpRes;
        }
    }

    private class SAPErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setBody('{"error": "Server Error"}');
            res.setStatusCode(500);
            return res;
        }
    }

    private class SAPConnectionFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new System.CalloutException('Connection Failed');
        }
    }

    // ===== TEST DATA SETUP =====
    @testSetup
    static void makeData() {
        // Customer Account
        Account testAccount = ResidentialTestDataFactory.preparePersonAccount();
        testAccount.LastName = 'Success';
        testAccount.Sales_Org__c = 'Phoenix Kessaku';
        testAccount.Distribution_Channel__c = 'Channel sale(Broker)';
        testAccount.RecordTypeId = AccountHelper.RT_ID_CUSTOMER;
        testAccount.SAP_External_Id__c = null;
        testAccount.Division__c = 'Residential Sales';
        testAccount.BillingStreet = '123,Ghat,Mum,Maha';
        testAccount.BillingCity = 'Mumbai';
        testAccount.BillingPostalCode = '400001';
        testAccount.BillingCountryCode = 'IN';
        testAccount.BillingState = 'Maharashtra';

        insert testAccount;

        // Channel Partner Account
        Account cpAcc = new Account(
            LastName = 'CPTest',
            RecordTypeId = AccountHelper.RT_ID_CHANNEL_PARTNER,
            SAP_External_Id__c = null
        );
        insert cpAcc;
    }

    // ===== TEST METHODS =====

    @isTest
    static void testSuccessPath_AccountIsUpdated() {
        Account acc = [SELECT Id FROM Account WHERE LastName = 'Success' LIMIT 1];
        System.assertNotEquals(null, acc, 'Prerequisite account missing.');

        Test.setMock(HttpCalloutMock.class, new SAPSuccessMock());

        Test.startTest();
        SAPCustomerIntegrationHandler.sendCustomerDataAsync(new List<Id>{ acc.Id });
        Test.stopTest();

        Account updatedAcc = [SELECT SAP_External_Id__c, SAP_Sync_Status__c, SAP_Sync_Message__c 
                              FROM Account WHERE Id = :acc.Id];

        // After successful SAP callout
        System.assertEquals('Success', updatedAcc.SAP_Sync_Status__c,'Sync status should be Success after successful SAP callout.');
        System.assertEquals('Customer Created', updatedAcc.SAP_Sync_Message__c,'Message should be stored from SAP response.');
        System.assertEquals('SAP1234567', updatedAcc.SAP_External_Id__c,'SAP External Id should be set from SAP response.');
    }

    @isTest
    static void testServerError_LogsErrorAndDoesNotUpdate() {
        Account acc = [SELECT Id FROM Account WHERE LastName = 'Success' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new SAPErrorMock());

        Test.startTest();
        SAPCustomerIntegrationHandler.sendCustomerDataAsync(new List<Id>{ acc.Id });
        Test.stopTest();

        Account resultAcc = [SELECT SAP_Sync_Status__c, SAP_External_Id__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals(null, resultAcc.SAP_Sync_Status__c, 'Status should not be updated on server error.');
        System.assertEquals(null, resultAcc.SAP_External_Id__c, 'External Id should not be set on server error.');
    }

    @isTest
    static void testConnectionFailure_LogsErrorAndDoesNotUpdate() {
        Account acc = [SELECT Id FROM Account WHERE LastName = 'Success' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new SAPConnectionFailureMock());

        Test.startTest();
        SAPCustomerIntegrationHandler.sendCustomerDataAsync(new List<Id>{ acc.Id });
        Test.stopTest();

        Account resultAcc = [SELECT SAP_Sync_Status__c, SAP_External_Id__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals(null, resultAcc.SAP_Sync_Status__c, 'Status should not be updated on connection failure.');
        System.assertEquals(null, resultAcc.SAP_External_Id__c, 'External Id should not be set on connection failure.');
    }

    @isTest
    static void testBuildCustomerPayload_returnsWrapper() {
        Account acc = [SELECT Id FROM Account WHERE LastName = 'Success' LIMIT 1];

        List<SAPCustomerWrapper> payload = SAPCustomerIntegrationHandler.buildCustomerPayload(new List<Id>{ acc.Id });
        System.assertNotEquals(null, payload, 'Payload should not be null');
        System.assert(payload.size() > 0, 'Payload should contain at least one wrapper');
        System.assertEquals(acc.Id, payload[0].CUSTOMER_ID, 'Wrapper CUSTOMER_ID should match Account Id');
    }

    @isTest
    static void testEmptyList_returnsNullPayload() {
        List<SAPCustomerWrapper> payload = SAPCustomerIntegrationHandler.buildCustomerPayload(new List<Id>());
        System.assertEquals(null, payload, 'Payload should be null for empty input');
    }
}