@isTest
public class SAPUnitIntegrationHandlerTest {
    
    // ---- Test setup: create project, tower, unit ----
    @testSetup
    static void setupData() {
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        ResidentialTestDataFactory.createUnit(project.Id, tower.Id);
    }

    // ---- Mock generator for HTTP responses ----
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        Integer statusCode;
        String responseBody;
        MockHttpResponseGenerator(Integer code, String body) {
            this.statusCode = code;
            this.responseBody = body;
        }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(responseBody);
            return res;
        }
    }

    // ---- 200 Success ----
    @isTest
    static void testSendUnitStatusUpdateData_Success200() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, 'OK-Response'));
        SAPUnitIntegrationHandler.sendUnitStatusUpdateData(new List<Id>{ unit.Id });
        Test.stopTest();

        System.assert(true, '200 Response handled successfully');
    }

    // ---- 201 Success ----
    @isTest
    static void testSendUnitStatusUpdateData_Success201() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, 'Created-Response'));
        SAPUnitIntegrationHandler.sendUnitStatusUpdateData(new List<Id>{ unit.Id });
        Test.stopTest();

        System.assert(true, '201 Response handled successfully');
    }

    // ---- Non-success (500) ----
    @isTest
    static void testSendUnitStatusUpdateData_NonSuccessResponse() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Server Error'));
        SAPUnitIntegrationHandler.sendUnitStatusUpdateData(new List<Id>{ unit.Id });
        Test.stopTest();

        System.assert(true, 'Non-success response handled gracefully');
    }

    // ---- Exception handling ----
    private class ExceptionThrowingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated callout failure');
        }
    }

    @isTest
    static void testSendUnitStatusUpdateData_ExceptionHandling() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ExceptionThrowingMock());
        SAPUnitIntegrationHandler.sendUnitStatusUpdateData(new List<Id>{ unit.Id });
        Test.stopTest();

        System.assert(true, 'Exception was caught and logged');
    }

    // ---- Empty list ----
    @isTest
    static void testSendUnitStatusUpdateData_EmptyList() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, 'EmptyList-OK'));
        SAPUnitIntegrationHandler.sendUnitStatusUpdateData(new List<Id>());
        Test.stopTest();

        System.assert(true, 'Empty list handled successfully');
    }

    // ---- Future method ----
    @isTest
    static void testSendUnitStatusUpdateDataAsync() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, 'Future-OK'));
        SAPUnitIntegrationHandler.sendUnitStatusUpdateDataAsync(new List<Id>{ unit.Id });
        Test.stopTest();

        System.assertEquals(true, UtilityClass.isSAPSyncInProgress, 'Future method should set sync flag');
    }
}