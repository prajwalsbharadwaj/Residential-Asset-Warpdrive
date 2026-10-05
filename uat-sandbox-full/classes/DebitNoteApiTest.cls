@isTest
private class DebitNoteApiTest {

    static String bookingNumber = 'BK123';
    static String unitCode = 'MAT001';
    static String customerReference = 'A0001';
    static String debitNoteNumber = 'DN100';

    @testSetup
    static void setupData() {
        // Person Account setup with exact SAP External Id for testing
        Id personRTId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('PersonAccount')
            .getRecordTypeId();

        Account acc = new Account(
            LastName = 'Test Account',
            SAP_External_Id__c = customerReference, // A0001
            RecordTypeId = personRTId
        );
        insert acc;

        // Hierarchy
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);

        // Ensure Unit SAP External Id is as expected
        unit.SAP_External_Id__c = unitCode;
        update unit;

        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        ResidentialTestDataFactory.createPaymentSchedules(plan.Id);

        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, project.Id);

        // Ensure Booking SAP External Id is as expected
        booking.SAP_External_Id__c = bookingNumber;
        update booking;
    }

    /**
     * @description Verifies successful Debit Note creation for valid payload
     * GIVEN: Valid references and booking context
     * WHEN: doPost is invoked
     * THEN: Response indicates Success
     */
    @IsTest
    static void givenValidPayloadWhenDoPostThenSuccess() {
        Map<String, Object> payload = new Map<String, Object>{
            'debitNoteNumber' => debitNoteNumber,
            'bookingNumber' => bookingNumber,
            'customerReference' => customerReference,
            'orderQty' => 10,
            'invoiceValue' => 5000,
            'taxValue' => 250,
            'unitCode' => unitCode
        };

        setMockRequest(new List<Map<String, Object>>{ payload });

        Test.startTest();
        DebitNoteApi.doPost();
        Test.stopTest();

        List<Object> response = (List<Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Map<String, Object> first = (Map<String, Object>) response[0];

        System.assertEquals('Success', first.get('status'));
        System.assertNotEquals(null, first.get('debitNoteId'));
        System.assertEquals('New debit note created successfully', first.get('message'));
    }

    @isTest
    static void testDoPost_MissingFields() {
        Map<String, Object> payload = new Map<String, Object>{
            'debitNoteNumber' => '',
            'customerReference' => '',
            'orderQty' => null,
            'invoiceValue' => null,
            'unitCode' => ''
        };

        setMockRequest(new List<Map<String, Object>>{ payload });

        Test.startTest();
        DebitNoteApi.doPost();
        Test.stopTest();

        List<Object> response = (List<Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Map<String, Object> first = (Map<String, Object>) response[0];

        System.assertEquals('Failure', first.get('status'));
        System.assert(((String)first.get('message')).contains('Missing required field'));
    }

    @isTest
    static void testDoPost_ReferenceNotFound() {
        Map<String, Object> payload = new Map<String, Object>{
            'debitNoteNumber' => 'DN200',
            'customerReference' => 'UNKNOWN_ACC',
            'unitCode' => 'UNKNOWN_UNIT',
            'orderQty' => 5,
            'invoiceValue' => 1000
        };

        setMockRequest(new List<Map<String, Object>>{ payload });

        Test.startTest();
        DebitNoteApi.doPost();
        Test.stopTest();

        List<Object> response = (List<Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Map<String, Object> first = (Map<String, Object>) response[0];

        System.assertEquals('Failure', first.get('status'));
        System.assert(((String)first.get('message')).contains('not found'));
    }

    @isTest
    static void testDoPost_DuplicateDebitNote() {
        // Safely get account
        Account acc;
        List<Account> accList = [SELECT Id FROM Account WHERE SAP_External_Id__c = :customerReference LIMIT 1];
        if (!accList.isEmpty()) acc = accList[0];

        // Safely get unit
        Unit__c unit;
        List<Unit__c> unitList = [SELECT Id FROM Unit__c WHERE SAP_External_Id__c = :unitCode LIMIT 1];
        if (!unitList.isEmpty()) unit = unitList[0];

        insert new Debit_Note__c(
            SAP_External_Id__c = 'DN300',
            Account__c = acc.Id,
            Unit__c = unit.Id,
            Order_Quantity__c = 10,
            Invoice_Value__c = 2000
        );

        Map<String, Object> payload = new Map<String, Object>{
            'debitNoteNumber' => 'DN300',
            'customerReference' => customerReference,
            'unitCode' => unitCode,
            'orderQty' => 10,
            'invoiceValue' => 2000
        };

        setMockRequest(new List<Map<String, Object>>{ payload });

        Test.startTest();
        DebitNoteApi.doPost();
        Test.stopTest();

        List<Object> response = (List<Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Map<String, Object> first = (Map<String, Object>) response[0];

        System.assertEquals('Failure', first.get('status'));
        System.assert(((String)first.get('message')).contains('already exists'));
    }

    @isTest
    static void testDoPost_ExceptionHandling() {
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
        RestContext.request.requestBody = Blob.valueOf('INVALID_JSON_BODY');
        RestContext.request.httpMethod = 'POST';
        RestContext.request.requestURI = '/services/apexrest/sap/v1/debit-note/';

        Test.startTest();
        DebitNoteApi.doPost();
        Test.stopTest();

        String responseBody = RestContext.response.responseBody.toString();
        System.assertEquals(500, RestContext.response.statusCode);
        System.assert(responseBody.contains('Unhandled exception'));
    }

    // Utility to mock REST request
    private static void setMockRequest(List<Map<String, Object>> payloadList) {
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
        RestContext.request.requestBody = Blob.valueOf(JSON.serialize(payloadList));
        RestContext.request.httpMethod = 'POST';
        RestContext.request.requestURI = '/services/apexrest/sap/v1/debit-note/';
    }
}