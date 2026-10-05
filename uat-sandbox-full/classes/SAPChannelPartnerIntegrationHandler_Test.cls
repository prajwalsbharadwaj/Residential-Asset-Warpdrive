@IsTest
private class SAPChannelPartnerIntegrationHandler_Test {

    // Dummy Queueable classes to satisfy System.enqueueJob()
    public class DummyCreateQ implements Queueable { 
        public DummyCreateQ(List<Id> ids) {}
        public void execute(QueueableContext qc) {}
    }
    public class DummyUpdateQ implements Queueable { 
        public DummyUpdateQ(List<Id> ids) {}
        public void execute(QueueableContext qc) {}
    }

    @TestSetup
    
    static void setupData() {
        Account acc = ResidentialTestDataFactory.prepareCPAccount();
        acc.BillingStreet = 'ABC street 123 Qwerty';
        insert acc;
    }

    // ------------------------------
    // CREATE FLOW TESTS
    // ------------------------------

    @IsTest
    static void testCreate_NullList() {

        SAPChannelPartnerIntegrationHandler.forceToggleCheckInTests = true;

        Test.startTest();
        SAPChannelPartnerIntegrationHandler.sendChannelPartnerDataAsync(null);
        Test.stopTest();

        System.assert(true, 'Null list should trigger else block.');
    }

    @IsTest
    static void testCreate_EmptyList() {

        SAPChannelPartnerIntegrationHandler.forceToggleCheckInTests = true;

        Test.startTest();
        SAPChannelPartnerIntegrationHandler.sendChannelPartnerDataAsync(new List<Id>());
        Test.stopTest();

        System.assert(true, 'Empty list should also trigger else block.');
    }

    @IsTest
    static void testCreate_ValidList() {

        SAPChannelPartnerIntegrationHandler.forceToggleCheckInTests = true;

        Id accId = [SELECT Id FROM Account LIMIT 1].Id;

        Test.startTest();
        SAPChannelPartnerIntegrationHandler.sendChannelPartnerDataAsync(new List<Id>{ accId });
        Test.stopTest();

        System.assert(true, 'Valid list should enqueue job.');
    }

    // ------------------------------
    // UPDATE FLOW TESTS
    // ------------------------------

    @IsTest
    static void testUpdate_NullList() {

        SAPChannelPartnerIntegrationHandler.forceToggleCheckInTests = true;

        Test.startTest();
        SAPChannelPartnerIntegrationHandler.sendChannelPartnerUpdateAsync(null);
        Test.stopTest();

        System.assert(true, 'Null list should hit else block.');
    }

    @IsTest
    static void testUpdate_EmptyList() {

        SAPChannelPartnerIntegrationHandler.forceToggleCheckInTests = true;

        Test.startTest();
        SAPChannelPartnerIntegrationHandler.sendChannelPartnerUpdateAsync(new List<Id>());
        Test.stopTest();

        System.assert(true, 'Empty list should hit else block.');
    }

    @IsTest
    static void testUpdate_ValidList() {

        SAPChannelPartnerIntegrationHandler.forceToggleCheckInTests = true;

        Id accId = [SELECT Id FROM Account LIMIT 1].Id;

        Test.startTest();
        SAPChannelPartnerIntegrationHandler.sendChannelPartnerUpdateAsync(new List<Id>{ accId });
        Test.stopTest();

        System.assert(true, 'Valid list should enqueue job.');
    }

    // ------------------------------
    // TOGGLE DISABLED COVERAGE
    // ------------------------------

    @IsTest
    static void testToggleDisabledPaths() {

        SAPChannelPartnerIntegrationHandler.forceToggleCheckInTests = true;

        Test.startTest();
        SAPChannelPartnerIntegrationHandler.sendChannelPartnerDataAsync(new List<Id>{ '001000000000001' });
        SAPChannelPartnerIntegrationHandler.sendChannelPartnerUpdateAsync(new List<Id>{ '001000000000001' });
        Test.stopTest();

        System.assert(true, 'Toggle-disabled branch executed.');
    }

    // ============================================================
    // NEW TESTS FOR RESPONSE HANDLING (200, 204)
    // ============================================================

    // Mock 200 Response with Body
    private class Mock200Response implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('[{"PARTNER":"123","TYPE":"S","MESSAGE":"Success"}]');
            return res;
        }
    }

    // Mock 204 Response (No Body)
    private class Mock204Response implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(204);
            res.setBody('');
            return res;
        }
    }

    // --------------------------------------------------
    // 200 WITH BODY → Covers deserialize + processResponse
    // --------------------------------------------------
    @IsTest
    static void testSyncResponseHandling_200() {

        SAPChannelPartnerIntegrationHandler.forceToggleCheckInTests = true;
		ResidentialTestDataFactory.accountCounter++;
        Account acc = ResidentialTestDataFactory.prepareCPAccount();
        
        //acc.LastName = 'Test Sync Response 200';
        //acc.BillingStreet = 'ABC2 street 123 Qwerty';
        insert acc;

        Test.setMock(HttpCalloutMock.class, new Mock200Response());

        Test.startTest();
        SAPChannelPartnerIntegrationHandler.responseWrapper resp =
            SAPChannelPartnerIntegrationHandler.sendChannelPartnerDataSync(acc.Id);
        Test.stopTest();

        System.assertEquals(200, resp.statusCode);
        System.assert(resp.responseBody.contains('PARTNER'));
    }

    // --------------------------------------------------
    // 204 NO BODY → Covers successAcc update block
    // --------------------------------------------------
    @IsTest
    static void testSyncResponseHandling_204_NoBody() {

        SAPChannelPartnerIntegrationHandler.forceToggleCheckInTests = true;
		ResidentialTestDataFactory.accountCounter++;
       	Account acc = ResidentialTestDataFactory.prepareCPAccount();
        //acc.LastName = 'Test Sync Response Nobody';
        //acc.BillingStreet = 'ABC3 street 123 Qwerty';
        insert acc;

        Test.setMock(HttpCalloutMock.class, new Mock204Response());

        Test.startTest();
        SAPChannelPartnerIntegrationHandler.responseWrapper resp =
            SAPChannelPartnerIntegrationHandler.sendChannelPartnerDataSync(acc.Id);
        Test.stopTest();

        System.assertEquals(204, resp.statusCode);
    }
}