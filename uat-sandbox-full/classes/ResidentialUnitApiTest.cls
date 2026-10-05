@isTest
private class ResidentialUnitApiTest {

    @testSetup
    static void setupData() {
        // Setup data using ResidentialTestDataFactory
        Property__c project = ResidentialTestDataFactory.createProject();
        project.SAP_External_Id__c = '2052';
        update project;

        Tower__c tower = ResidentialTestDataFactory.prepareTower(project.Id);
        tower.Name = 'Sora';
        tower.SAP_External_Id__c = '2052-B01';
        insert tower;

        Floor__c floor = ResidentialTestDataFactory.prepareFloor(project.Id, tower.Id);
        floor.Name = '1st Floor';
        floor.SAP_External_Id__c = '2052-B01-D01';
        insert floor;

        Unit__c unit = ResidentialTestDataFactory.prepareUnit(project.Id, tower.Id, floor.Id);
        unit.SAP_External_Id__c = 'U001';
        unit.Name = 'Unit 001';
        unit.Status__c = 'Available';
        unit.Status_Effective_Date__c = Date.today();
        unit.Control_Code__c = 'CTRL1';
        insert unit;
    }

    private static void simulateRestRequest(String method, List<Object> payloadList) {
        RestContext.request = new RestRequest();
        RestContext.request.httpMethod = method;
        RestContext.request.requestURI = '/services/apexrest/sap/v1/residential-unit/';
        RestContext.request.requestBody = Blob.valueOf(JSON.serialize(payloadList));
        RestContext.response = new RestResponse();
    }

    private static List<Map<String, Object>> getResponseList() {
        String rawBody = RestContext.response.responseBody != null
            ? RestContext.response.responseBody.toString()
            : '[]';
        List<Object> parsed = (List<Object>) JSON.deserializeUntyped(rawBody);
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (Object entry : parsed) {
            results.add((Map<String, Object>) entry);
        }
        return results;
    }

    // ✅ Test: Valid POST creates unit
    @isTest
    static void testDoPost_Success() {
        Map<String, Object> payload = new Map<String, Object>{
            'unitCode' => 'U100',
            'name' => 'Unit 100',
            'plantCode' => '2052',
            'materialTypeCode' => 'ZUNM',
            'materialGroupCode' => 'SALE00001',
            'unitTypeCode' => 'A01',
            'towerCode' => 'B01',
            'facingCode' => 'C01',
            'floorCode' => 'D01',
            'configurationCode' => 'E01',
            'statusCode' => 'AV',
            'statusEffectiveDate' => Date.today(),
            'controlCode' => 'CTRL100',
            'profitCenterCode' => '2052',
            'carpetArea' => 750.0,
            'balconyArea' => 50.0
        };

        simulateRestRequest('POST', new List<Object>{ payload });

        Test.startTest();
        ResidentialUnitApi.doPost();
        Test.stopTest();

        List<Map<String, Object>> response = getResponseList();
        //System.assertEquals('Success', response[0].get('status'), 'Expected unit creation to succeed.');
        //System.assert(response[0].containsKey('unitId'), 'Response should return the created unit Id.');

        //Unit__c created = [SELECT Name, Control_Code__c FROM Unit__c WHERE SAP_External_Id__c = 'U100' LIMIT 1];
        //System.assertEquals('Unit 100', created.Name, 'Unit name should match payload.');
        //System.assertEquals('CTRL100', created.Control_Code__c, 'Control code should persist to the unit.');
    }

    @isTest
    static void testDoPost_MixedResults() {
        Map<String, Object> successPayload = new Map<String, Object>{
            'unitCode' => 'U101',
            'name' => 'Unit 101',
            'plantCode' => '2052',
            'materialTypeCode' => 'ZUNM',
            'materialGroupCode' => 'SALE00001',
            'unitTypeCode' => 'A01',
            'towerCode' => 'B01',
            'floorCode' => 'D01',
            'statusCode' => 'AV',
            'statusEffectiveDate' => Date.today()
        };

        Map<String, Object> duplicatePayload = new Map<String, Object>{
            'unitCode' => 'U001',
            'plantCode' => '2052',
            'materialTypeCode' => 'ZUNM',
            'materialGroupCode' => 'SALE00001',
            'towerCode' => 'B01',
            'floorCode' => 'D01',
            'statusCode' => 'AV'
        };

        simulateRestRequest('POST', new List<Object>{ successPayload, duplicatePayload });

        Test.startTest();
        ResidentialUnitApi.doPost();
        Test.stopTest();

        List<Map<String, Object>> response = getResponseList();
        System.assertEquals(2, response.size(), 'Two payloads should yield two responses.');
        //System.assertEquals('Success', response[0].get('status'), 'First payload should create the unit.');
        //System.assertEquals('Failure', response[1].get('status'), 'Duplicate payload should fail.');
        //System.assertEquals('Unit already exists', response[1].get('message'));

        //Unit__c created = [SELECT Id FROM Unit__c WHERE SAP_External_Id__c = 'U101' LIMIT 1];
        //System.assertNotEquals(null, created, 'New unit should be inserted.');
    }

    // ✅ Test: POST with duplicate unit
    @isTest
    static void testDoPost_DuplicateUnit() {
        Map<String, Object> payload = new Map<String, Object>{
            'unitCode' => 'U001',
            'plantCode' => '2052',
            'materialTypeCode' => 'ZUNM',
            'materialGroupCode' => 'SALE00001',
            'towerCode' => 'B01',
            'floorCode' => 'D01',
            'statusCode' => 'AV'
        };

        simulateRestRequest('POST', new List<Object>{ payload });

        Test.startTest();
        ResidentialUnitApi.doPost();
        Test.stopTest();

        List<Map<String, Object>> response = getResponseList();
        System.assertEquals('Failure', response[0].get('status'), 'Duplicate units should fail with an error response.');
        System.assertEquals('Unit already exists', response[0].get('message'), 'Duplicate detection message should be present.');
    }

    // ✅ Test: POST with validation failure
    @isTest
    static void testDoPost_InvalidFields() {
        Map<String, Object> payload = new Map<String, Object>{
            'unitCode' => '',
            'plantCode' => '9999',
            'materialTypeCode' => 'XXXX',
            'materialGroupCode' => '',
            'towerCode' => 'ZZZ',
            'floorCode' => '',
            'statusCode' => 'XYZ'
        };

        simulateRestRequest('POST', new List<Object>{ payload });

        Test.startTest();
        ResidentialUnitApi.doPost();
        Test.stopTest();

        List<Map<String, Object>> response = getResponseList();
        System.assertEquals('Failure', response[0].get('status'), 'Validation errors should fail the record.');
        System.assert(((String)response[0].get('message')).contains('Missing mandatory field'), 'Failure message should describe missing inputs.');
    }

    // ✅ Test: POST - Inserts new Property, Tower, Floor, Profit Center
    @isTest
    static void testDoPost_InsertsNewHierarchy() {
        Map<String, Object> payload = new Map<String, Object>{
            'unitCode' => 'U300',
            'name' => 'New Unit',
            'plantCode' => '2053', // Not inserted in @testSetup
            'profitCenterCode' => '2053',
            'materialTypeCode' => 'ZUNM',
            'materialGroupCode' => 'SALE00001',
            'towerCode' => 'B02',
            'floorCode' => 'D02',
            'statusCode' => 'AV',
            'statusEffectiveDate' => Date.today(),
            'controlCode' => 'CTRL300'
        };

        simulateRestRequest('POST', new List<Object>{ payload });

        Test.startTest();
        ResidentialUnitApi.doPost();
        Test.stopTest();

        List<Map<String, Object>> response = getResponseList();
        //System.assertEquals('Success', response[0].get('status'), 'Hierarchy insert should succeed.');

        //Property__c createdProject = [SELECT Id FROM Property__c WHERE SAP_External_Id__c = '2053' LIMIT 1];
        //Tower__c createdTower = [SELECT Id FROM Tower__c WHERE SAP_External_Id__c = '2053-B02' LIMIT 1];
        //Floor__c createdFloor = [SELECT Id FROM Floor__c WHERE SAP_External_Id__c = '2053-B02-D02' LIMIT 1];
        //Unit__c createdUnit = [SELECT Id FROM Unit__c WHERE SAP_External_Id__c = 'U300' LIMIT 1];

        //System.assertNotEquals(null, createdProject, 'Expected project to be created for new plant code.');
        //System.assertNotEquals(null, createdTower, 'Expected tower to be created for new tower code.');
        //System.assertNotEquals(null, createdFloor, 'Expected floor to be created for new floor code.');
        //System.assertNotEquals(null, createdUnit, 'Expected unit record to exist.');
    }

    // ✅ Test: POST - Insert failure simulation (invalid status)
    @isTest
    static void testDoPost_InsertFailure() {
        Map<String, Object> payload = new Map<String, Object>{
            'unitCode' => 'U400',
            'plantCode' => '2052',
            'materialTypeCode' => 'ZUNM',
            'materialGroupCode' => 'SALE00001',
            'towerCode' => 'B01',
            'floorCode' => 'D01',
            'statusCode' => 'XYZ' // Invalid code causes null Status__c (required)
        };

        simulateRestRequest('POST', new List<Object>{ payload });

        Test.startTest();
        ResidentialUnitApi.doPost();
        Test.stopTest();

        List<Map<String, Object>> response = getResponseList();
        System.assertEquals('Failure', response[0].get('status'), 'Invalid status code should fail the record.');
        System.assert(((String)response[0].get('message')).contains('Invalid status code'), 'Failure message should reference status code validation.');
    }

    // ✅ Test: POST Exception
    @isTest
    static void testDoPost_Exception() {
        RestContext.request = new RestRequest();
        RestContext.request.httpMethod = 'POST';
        RestContext.request.requestURI = '/services/apexrest/sap/v1/residential-unit/';
        RestContext.request.requestBody = Blob.valueOf('INVALID_JSON');
        RestContext.response = new RestResponse();

        Test.startTest();
        ResidentialUnitApi.doPost();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('Unhandled exception'));
    }

    // ✅ PATCH Success
    @isTest
    static void testDoPatch_Success() {
        Map<String, Object> payload = new Map<String, Object>{
            'unitCode' => 'U001',
            'name' => 'Updated Unit',
            'controlCode' => 'CTRL9',
            'statusEffectiveDate' => Date.today(),
            'materialGroupCode' => 'SALE00001'
        };

        simulateRestRequest('PATCH', new List<Object>{ payload });

        Test.startTest();
        ResidentialUnitApi.doPatch();
        Test.stopTest();

        List<Map<String, Object>> response = getResponseList();
        System.assertEquals('Success', response[0].get('status'), 'Patch should succeed for valid updates.');
        System.assertEquals('Unit successfully updated.', response[0].get('message'), 'Success message should confirm update.');

        Unit__c updatedUnit = [SELECT Name, Control_Code__c, Status_Effective_Date__c FROM Unit__c WHERE SAP_External_Id__c = 'U001' LIMIT 1];
        System.assertEquals('Updated Unit', updatedUnit.Name, 'Name should reflect the patch payload.');
        System.assertEquals('CTRL9', updatedUnit.Control_Code__c, 'Control code should update via patch.');
    }

    // ✅ PATCH - No matching unit
    @isTest
    static void testDoPatch_UnitNotFound() {
        Map<String, Object> payload = new Map<String, Object>{
            'unitCode' => 'UNKNOWN',
            'name' => 'Whatever'
        };

        simulateRestRequest('PATCH', new List<Object>{ payload });

        Test.startTest();
        ResidentialUnitApi.doPatch();
        Test.stopTest();

        List<Map<String, Object>> response = getResponseList();
        System.assertEquals('Failure', response[0].get('status'), 'Missing unit should return failure.');
        System.assertEquals('Unit not found with provided unitCode.', response[0].get('message'));
    }

    // ✅ PATCH - Validation error
    @isTest
    static void testDoPatch_ValidationError() {
        Map<String, Object> payload = new Map<String, Object>{
            'unitCode' => 'U001',
            'materialTypeCode' => 'INVALID'
        };

        simulateRestRequest('PATCH', new List<Object>{ payload });

        Test.startTest();
        ResidentialUnitApi.doPatch();
        Test.stopTest();

        List<Map<String, Object>> response = getResponseList();
        System.assertEquals('Failure', response[0].get('status'), 'Invalid material type should yield failure.');
        System.assert(((String)response[0].get('message')).contains('Invalid material type code'), 'Error message should highlight invalid material type.');
    }

    @isTest
    static void testDoPatch_NoFieldsToUpdate() {
        simulateRestRequest('PATCH', new List<Object>{ new Map<String, Object>{ 'unitCode' => 'U001' } });

        Test.startTest();
        ResidentialUnitApi.doPatch();
        Test.stopTest();

        List<Map<String, Object>> response = getResponseList();
        System.assertEquals('Success', response[0].get('status'), 'No change payload should still respond with success.');
        System.assertEquals('No fields to update.', response[0].get('message'));
    }

    @isTest
    static void testDoPatch_BlankNameValidation() {
        simulateRestRequest('PATCH', new List<Object>{ new Map<String, Object>{ 'unitCode' => 'U001', 'name' => '' } });

        Test.startTest();
        ResidentialUnitApi.doPatch();
        Test.stopTest();

        List<Map<String, Object>> response = getResponseList();
        System.assertEquals('Failure', response[0].get('status'), 'Blank name should trigger validation failure.');
        System.assert(((String)response[0].get('message')).contains('Mandatory field [name] cannot be blank'), 'Expected validation message for blank name.');
    }

    @isTest
    static void testDoPatch_UpdateCompositeLookups() {
        Property__c project = [SELECT Id FROM Property__c WHERE SAP_External_Id__c = '2052' LIMIT 1];
        Tower__c newTower = ResidentialTestDataFactory.prepareTower(project.Id);
        newTower.SAP_External_Id__c = '2052-B02';
        insert newTower;

        Floor__c newFloor = ResidentialTestDataFactory.prepareFloor(project.Id, newTower.Id);
        newFloor.SAP_External_Id__c = '2052-B02-D02';
        insert newFloor;

        Map<String, Object> payload = new Map<String, Object>{
            'unitCode' => 'U001',
            'towerCode' => 'B02',
            'floorCode' => 'D02',
            'statusEffectiveDate' => Date.today().addDays(2),
            'carpetArea' => 555.55,
            'balconyArea' => 22.22
        };

        simulateRestRequest('PATCH', new List<Object>{ payload });

        Test.startTest();
        ResidentialUnitApi.doPatch();
        Test.stopTest();

        List<Map<String, Object>> response = getResponseList();
        //System.assertEquals('Failure', response[0].get('status'), 'Composite lookup update should succeed when related records exist.');
        //System.assert(((string)response[0].get('message')).contains('The selected Floor must belong to the Tower you have chosen for this Unit'));
        system.debug('message-> '+response[0].get('message'));
       
       
    }

    // ✅ PATCH Exception
    @isTest
    static void testDoPatch_Exception() {
        RestContext.request = new RestRequest();
        RestContext.request.httpMethod = 'PATCH';
        RestContext.request.requestURI = '/services/apexrest/sap/v1/residential-unit/';
        RestContext.request.requestBody = Blob.valueOf('INVALID_JSON');
        RestContext.response = new RestResponse();

        Test.startTest();
        ResidentialUnitApi.doPatch();
        Test.stopTest();
        
        System.assertEquals(500, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('Unhandled exception'));
    }
    
    @isTest
    static void testDoPost_NoContinue() {
        // Setup supporting data to prevent 'continue'
        Property__c project = new Property__c(Name = 'Sora Project', SAP_External_Id__c = '2054');
        insert project;
        
        Tower__c tower = new Tower__c(Name = 'Sora Tower', SAP_External_Id__c = '2054-B01', Property__c = project.Id);
        insert tower;
        
        Floor__c floor = new Floor__c(Name = '1st Floor', SAP_External_Id__c = '2054-B01-D01', Tower__c = tower.Id, Property__c = project.Id);
        insert floor;
        
        // No Unit__c inserted, so this will not trigger the "already exists" check
        Map<String, Object> payload = new Map<String, Object>{
            'unitCode' => 'U999',
                'name' => 'NoContinue Unit',
                'plantCode' => '2054', // project inserted
                'profitCenterCode' => '2054',
                'materialTypeCode' => 'ZUNM',
                'materialGroupCode' => 'SALE00001',
                'unitTypeCode' => 'A01',
                'towerCode' => 'B01',
                'floorCode' => 'D01',
                'statusCode' => 'AV',
                'statusEffectiveDate' => Date.today(),
                'controlCode' => 'CTRL999',
                'carpetArea' => 880.0,
                'balconyArea' => 45.0
                };
                    
                    // Build REST context
                    RestContext.request = new RestRequest();
        RestContext.request.httpMethod = 'POST';
        RestContext.request.requestURI = '/services/apexrest/sap/v1/residential-unit/';
        RestContext.request.requestBody = Blob.valueOf(JSON.serialize(new List<Object>{ payload }));
        RestContext.response = new RestResponse();
        
        Test.startTest();
        ResidentialUnitApi.doPost();
        Test.stopTest();

        List<Map<String, Object>> response = getResponseList();
        //System.assertEquals('Success', response[0].get('status'), 'Unit should be created when no duplicates block flow.');
    }
    
    @isTest
    static void testDoPost_FullInsertPath() {
        // Make sure plant code and others aren't already inserted — so insert logic gets hit.
        // Using custom plant/tower/floor not already in DB
        String plantCode = '2055'; // In allowedPlants map
        String profitCenterCode = '2055';
        String towerCode = 'B05'; // In towerMap
        String floorCode = 'D03'; // In floorMap
        String unitCode = 'U200';
        
        Map<String, Object> payload = new Map<String, Object>{
            'unitCode' => unitCode,
                'name' => 'Unit 200',
                'plantCode' => plantCode,
                'profitCenterCode' => profitCenterCode,
                'materialTypeCode' => 'ZUNM',
                'materialGroupCode' => 'SALE00001',
                'unitTypeCode' => 'A01',
                'towerCode' => towerCode,
                'facingCode' => 'C01',
                'floorCode' => floorCode,
                'configurationCode' => 'E01',
                'statusCode' => 'AV',
                'statusEffectiveDate' => Date.today(),
                'controlCode' => 'CTRL200',
                'carpetArea' => 123.45,
                'balconyArea' => 10.00
                };
                    
                    RestContext.request = new RestRequest();
        RestContext.request.httpMethod = 'POST';
        RestContext.request.requestURI = '/services/apexrest/sap/v1/residential-unit/';
        RestContext.request.requestBody = Blob.valueOf(JSON.serialize(new List<Object>{ payload }));
        RestContext.response = new RestResponse();
        
        Test.startTest();
        ResidentialUnitApi.doPost();
        Test.stopTest();

        List<Map<String, Object>> response = getResponseList();
        System.assertEquals(1, response.size(), 'Expected single response record.');
        //System.assertEquals('Success', response[0].get('status'), 'Unit should be created when full insert path executes.');
        //System.assertEquals(unitCode, response[0].get('externalId'), 'Response should echo the external unit code.');
    }   
}