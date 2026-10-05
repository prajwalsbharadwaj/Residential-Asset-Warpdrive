@isTest
private class CreditNoteApiTest {

  
    static String demandNumber = 'DM123';
    static String bookingNumber = 'BK123';
    static String unitCode = 'MAT001';
    static String customerReference = 'A0001';

    @testSetup
static void setupData() {
    Id personRTId = Schema.SObjectType.Account
        .getRecordTypeInfosByDeveloperName()
        .get('PersonAccount')
        .getRecordTypeId();

    Account acc = new Account(
        LastName = 'Test',
        SAP_External_Id__c = customerReference, // "A0001"
        RecordTypeId = personRTId
    );
    insert acc;

    Property__c project = ResidentialTestDataFactory.createProject();
    Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
    Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
    Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
    unit.SAP_External_Id__c = unitCode; 
    update unit;

    Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
    List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
    Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
    Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, project.Id);
    booking.SAP_External_Id__c = bookingNumber; 
    update booking;

    List<Booking_Payment_Schedule__c> bpsList =
        ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, schedules);

    Demand__c demand = ResidentialTestDataFactory.prepareDemand(
        bpsList[0].Id, unit.Id, acc.Id, demandNumber 
    );
    demand.SAP_External_Id__c = demandNumber;
    insert demand;
}


    /**
     * @description Verifies successful Credit Note creation for valid payload
     * GIVEN: Valid references for demand, booking, account, and unit
     * WHEN: doPost is called with a correct payload
     * THEN: Response is Success with a created creditNoteId
     */
    @IsTest
    static void givenValidPayloadWhenDoPostThenSuccess() {
        Map<String, Object> payload = new Map<String, Object>{
            'creditNoteNumber' => 'CN100',
            'demandNumber' => demandNumber,
            'bookingNumber' => bookingNumber,
            'customerReference' => customerReference,
            'orderQty' => 10,
            'invoiceValue' => 15000,
            'taxValue' => 500,
            'unitCode' => unitCode
        };

        setMockRequest(new List<Map<String, Object>>{ payload });

        Test.startTest();
        CreditNoteApi.doPost();
        Test.stopTest();

        List<Object> response = (List<Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Map<String, Object> first = (Map<String, Object>) response[0];

        System.Assert.areEqual('Success', (String)first.get('status'), 'Expected Success status in response.');
        System.Assert.isTrue(first.get('creditNoteId') != null, 'Expected creditNoteId to be present.');
    }

    /**
     * @description Verifies failure when required fields are missing
     * GIVEN: A payload missing required fields
     * WHEN: doPost is called
     * THEN: Response indicates Failure with message
     */
    @IsTest
    static void givenMissingFieldsWhenDoPostThenFailure() {
        Map<String, Object> payload = new Map<String, Object>{
            'creditNoteNumber' => '',
            'customerReference' => '',
            'orderQty' => null,
            'invoiceValue' => null,
            'unitCode' => ''
        };

        setMockRequest(new List<Map<String, Object>>{ payload });

        Test.startTest();
        CreditNoteApi.doPost();
        Test.stopTest();

        List<Object> response = (List<Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Map<String, Object> first = (Map<String, Object>) response[0];

        System.Assert.areEqual('Failure', (String)first.get('status'), 'Expected Failure status for missing fields.');
        System.Assert.isTrue(((String)first.get('message')).contains('Missing required field'), 'Expected message to mention missing required field.');
    }

    /**
     * @description Verifies failure when account or unit references are not found
     * GIVEN: Payload with unknown customer reference and unit code
     * WHEN: doPost is called
     * THEN: Response indicates Failure with not found message
     */
    @IsTest
    static void givenUnknownReferencesWhenDoPostThenFailure() {
        Map<String, Object> payload = new Map<String, Object>{
            'creditNoteNumber' => 'CN200',
            'customerReference' => 'UNKNOWN_ACC',
            'unitCode' => 'UNKNOWN_UNIT',
            'orderQty' => 5,
            'invoiceValue' => 10000
        };

        setMockRequest(new List<Map<String, Object>>{ payload });

        Test.startTest();
        CreditNoteApi.doPost();
        Test.stopTest();

        List<Object> response = (List<Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Map<String, Object> first = (Map<String, Object>) response[0];

        System.Assert.areEqual('Failure', (String)first.get('status'), 'Expected Failure status for unknown references.');
        System.Assert.isTrue(((String)first.get('message')).contains('not found'), 'Expected message to contain not found.');
    }

    /**
     * @description Verifies duplicate credit note detection
     * GIVEN: An existing Credit Note with same external id
     * WHEN: doPost is called with same creditNoteNumber
     * THEN: Response indicates Failure already exists
     */
    @IsTest
    static void givenDuplicateCreditNoteWhenDoPostThenFailure() {
        Account acc = [SELECT Id FROM Account WHERE SAP_External_Id__c = :customerReference LIMIT 1];
        Unit__c unit = [SELECT Id FROM Unit__c WHERE SAP_External_Id__c = :unitCode LIMIT 1];

        insert new Credit_Note__c(
            SAP_External_Id__c = 'CN300',
            Account__c = acc.Id,
            Unit__c = unit.Id,
            Order_Quantity__c = 10,
            Invoice_Value__c = 10000
        );

        Map<String, Object> payload = new Map<String, Object>{
            'creditNoteNumber' => 'CN300',
            'customerReference' => customerReference,
            'unitCode' => unitCode,
            'orderQty' => 10,
            'invoiceValue' => 10000
        };

        setMockRequest(new List<Map<String, Object>>{ payload });

        Test.startTest();
        CreditNoteApi.doPost();
        Test.stopTest();

        List<Object> response = (List<Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Map<String, Object> first = (Map<String, Object>) response[0];

        System.Assert.areEqual('Failure', (String)first.get('status'), 'Expected Failure for duplicate credit note.');
        System.Assert.isTrue(((String)first.get('message')).contains('already exists'), 'Expected duplicate message.');
    }

    /**
     * @description Verifies exception path returns 500 with message
     * GIVEN: Invalid non-JSON request body
     * WHEN: doPost is executed
     * THEN: Response 500 with unhandled exception message
     */
    @IsTest
    static void givenInvalidJsonWhenDoPostThen500() {
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
        RestContext.request.requestBody = Blob.valueOf('This is not JSON');
        RestContext.request.httpMethod = 'POST';
        RestContext.request.requestURI = '/services/apexrest/sap/v1/credit-note/';

        Test.startTest();
        CreditNoteApi.doPost();
        Test.stopTest();

        String responseBody = RestContext.response.responseBody.toString();
        System.Assert.areEqual(500, RestContext.response.statusCode, 'Expected HTTP 500 for invalid JSON.');
        System.Assert.isTrue(responseBody.contains('Unhandled exception'), 'Expected unhandled exception message.');
    }

    private static void setMockRequest(List<Map<String, Object>> payloadList) {
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
        RestContext.request.requestBody = Blob.valueOf(JSON.serialize(payloadList));
        RestContext.request.httpMethod = 'POST';
        RestContext.request.requestURI = '/services/apexrest/sap/v1/credit-note/';
    }
}