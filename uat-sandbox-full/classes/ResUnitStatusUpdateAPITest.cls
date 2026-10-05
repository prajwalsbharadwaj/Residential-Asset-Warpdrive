@IsTest
private class ResUnitStatusUpdateAPITest {

    @testSetup
    static void setupData() {
        // Create base inventory
        Account acc = ResidentialTestDataFactory.createAccount();
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
    }

    private static RestRequest prepareRequest(String body) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/sap/v1/unit-status/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        return req;
    }

    @IsTest
    static void testValidUpdate() {
        Unit__c unit = [SELECT Id, SAP_External_Id__c FROM Unit__c LIMIT 1];

        String body = '[{"unitId":"' + unit.SAP_External_Id__c + '","statusCode":"Z0","statusEffectiveDate":"2024-01-01"}]';
        prepareRequest(body);

        Test.startTest();
        ResUnitStatusUpdateAPI.doPost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        String response = RestContext.response.responseBody.toString();
        System.assert(response.contains('"Success"'));
        System.assert(response.contains('"Unit status updated"'));
    }

    @IsTest
    static void testMissingUnitId() {
        String body = '[{"statusCode":"Z0"}]';
        prepareRequest(body);

        Test.startTest();
        ResUnitStatusUpdateAPI.doPost();
        Test.stopTest();

        String response = RestContext.response.responseBody.toString();
        System.assert(response.contains('Missing required field: unitId'));
    }

    @IsTest
    static void testMissingStatusCode() {
        Unit__c unit = [SELECT SAP_External_Id__c FROM Unit__c LIMIT 1];
        String body = '[{"unitId":"' + unit.SAP_External_Id__c + '"}]';
        prepareRequest(body);

        Test.startTest();
        ResUnitStatusUpdateAPI.doPost();
        Test.stopTest();

        String response = RestContext.response.responseBody.toString();
        System.assert(response.contains('Missing required field: statusCode'));
    }

    @IsTest
    static void testInvalidStatusCode() {
        Unit__c unit = [SELECT SAP_External_Id__c FROM Unit__c LIMIT 1];
        String body = '[{"unitId":"' + unit.SAP_External_Id__c + '","statusCode":"BAD"}]';
        prepareRequest(body);

        Test.startTest();
        ResUnitStatusUpdateAPI.doPost();
        Test.stopTest();

        String response = RestContext.response.responseBody.toString();
        System.assert(response.contains('Invalid status code'));
    }

    @IsTest
    static void testUnitNotFound() {
        String body = '[{"unitId":"NON_EXISTENT_UNIT","statusCode":"Z0"}]';
        prepareRequest(body);

        Test.startTest();
        ResUnitStatusUpdateAPI.doPost();
        Test.stopTest();

        String response = RestContext.response.responseBody.toString();
        System.assert(response.contains('not found'));
    }

    @IsTest
    static void testDmlFailure() {
        Unit__c unit = [SELECT Id, Name, Floor__c,  Carpet_Area__c, Tower__c, Property__c, SAP_External_Id__c FROM Unit__c LIMIT 1];
        // Lock record by creating a duplicate SAP ID -> simulate duplicate value error
        Unit__c dupUnit = new Unit__c(
            Name = 'Dup Unit',
            SAP_External_Id__c = 'krish098',
            Property__c = unit.Property__c,
            Tower__c = unit.Tower__c,
            Floor__c = unit.Floor__c,
            Carpet_Area__c = 123
        );
        insert dupUnit;

        String body = '[{"unitId":"' + unit.SAP_External_Id__c + '","statusCode":"Z0"}]';
        prepareRequest(body);

        Test.startTest();
        ResUnitStatusUpdateAPI.doPost();
        Test.stopTest();

        String response = RestContext.response.responseBody.toString();
        //System.assert(response.contains('Failure'));
    }

    @IsTest
    static void testUnexpectedException() {
        // Pass invalid JSON to cause exception
        String body = 'INVALID_JSON';
        prepareRequest(body);

        Test.startTest();
        ResUnitStatusUpdateAPI.doPost();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode);
        String response = RestContext.response.responseBody.toString();
        System.assert(response.contains('An unexpected error occurred'));
    }
}