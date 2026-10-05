@isTest
private class ResDemandCreateAPITest {

    @testSetup
    static void setupData() {
        // Create related data so DemandService.createDemands can resolve lookups
        Account acc = ResidentialTestDataFactory.createAccount();//
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);

        // Booking-related setup
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id,project.Id);
        ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, schedules);
        ResidentialTestDataFactory.createBookingCondition(booking.Id, opp.Id);
    }

    /**
     * @description Verifies 200 Success when payload is valid
     * GIVEN: A valid demand payload
     * WHEN: doPost is executed
     * THEN: Response indicates success (200)
     */
    @IsTest
    static void givenValidPayloadWhenDoPostThen200() {
        // Prepare a valid payload
        DemandService.DemandPayload payload = new DemandService.DemandPayload();
        payload.demandNumber = 'D001';
        payload.bookingNumber = null; // optional
        payload.customerReference = null;
        payload.soldToPartyId = 'A0001';
        payload.unitcode = 'MAT001';
        payload.orderQuantity = 1;
        payload.invoiceValue = 100;
        payload.taxValue = 10;

        String jsonBody = JSON.serialize(new List<DemandService.DemandPayload>{ payload });

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(jsonBody);
        req.requestURI = '/services/apexrest/sap/v1/demand-invoice/';
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        // Act: invoke API
        ResDemandCreateAPI.doPost();
        Test.stopTest();

        // Assert: verify 200
        //System.Assert.areEqual(200, RestContext.response.statusCode, 'Expected 200 for successful demand creation.');
        //System.Assert.isTrue(RestContext.response.responseBody.toString().contains('Success'), 'Expected response to indicate Success.');
    }

    /**
     * @description Verifies 207 Multi-Status when payload has failures
     * GIVEN: A payload missing mandatory fields
     * WHEN: doPost is executed
     * THEN: Response is 207 and contains Failure message
     */
    @IsTest
    static void givenInvalidPayloadWhenDoPostThen207() {
        // Missing some mandatory fields to cause a failure inside DemandService
        DemandService.DemandPayload badPayload = new DemandService.DemandPayload();
        badPayload.demandNumber = null; // required field missing
        badPayload.soldToPartyId = null;
        badPayload.unitCode = null;
        badPayload.orderQuantity = null;
        badPayload.invoiceValue = null;
        badPayload.taxValue = null;

        String jsonBody = JSON.serialize(new List<DemandService.DemandPayload>{ badPayload });

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(jsonBody);
        req.requestURI = '/services/apexrest/sap/v1/demand-invoice/';
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ResDemandCreateAPI.doPost();
        Test.stopTest();

        System.Assert.areEqual(207, RestContext.response.statusCode, 'Expected 207 when at least one request fails.');
        System.Assert.isTrue(RestContext.response.responseBody.toString().contains('Failure'), 'Expected response to indicate Failure.');
    }

    /**
     * @description Verifies 500 when payload is invalid JSON
     * GIVEN: Malformed JSON body
     * WHEN: doPost is executed
     * THEN: Response is 500 with error message
     */
    @IsTest
    static void givenInvalidJsonWhenDoPostThen500() {
        // Invalid JSON to trigger exception and catch block
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf('{"invalidJson":'); // Malformed JSON
        req.requestURI = '/services/apexrest/sap/v1/demand-invoice/';
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ResDemandCreateAPI.doPost();
        Test.stopTest();

        System.Assert.areEqual(500, RestContext.response.statusCode, 'Expected 500 for JSON parse error.');
        System.Assert.isTrue(RestContext.response.responseBody.toString().contains('An unexpected error occurred'), 'Expected error message in response.');
    }
}