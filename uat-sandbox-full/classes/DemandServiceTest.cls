@isTest
private class DemandServiceTest {//
    
    @testSetup
    static void setupData() {
        Account acc1 = ResidentialTestDataFactory.createAccount(); // SAP_External_Id__c = 'A0001'
        Account acc2 = new Account(Name = 'Customer Ref', SAP_External_Id__c = 'CUST001');
        insert acc2;
        
        Property__c proj = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(proj.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(proj.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(proj.Id, tower.Id, floor.Id); // SAP_External_Id__c = 'MAT001'
        
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc1.Id, unit.Id);
        Booking__c booking = ResidentialTestDataFactory.createBooking(acc1.Id, unit.Id, plan.Id, opp.Id, proj.Id);
        ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, schedules);
        ResidentialTestDataFactory.createBookingCondition(booking.Id, opp.Id);
        
        booking.SAP_External_Id__c = 'BOOK001';
        update booking;
        
        List<Booking_Payment_Schedule__c> bpsList = ResidentialTestDataFactory.prepareBookingPaymentSchedules(booking.Id, schedules);
        for(Booking_Payment_Schedule__c bps: bpsList){
            bps.Bill_Block__c = null;
        }
        insert bpsList;
        
        Demand__c existingDemand = new Demand__c(
            SoldToPartyId__c = acc1.Id,
            Booking_Payment_Schedule_Id__c = bpsList[0].Id,
            Unit__c = unit.Id,
            Order_Qty__c = 10,
            Invoice_Value__c = 1000,
            Tax_Value__c = 100,
            SAP_External_Id__c = 'DUPLICATE001',
            Account__c = acc2.Id // populate required Account__c
        );
        insert existingDemand;
    }
    
    /**
* @description Verifies demand creation succeeds for valid payload
* GIVEN: Valid booking, account, and unit references
* WHEN: createDemands is called with a correct payload
* THEN: Status is Success and an sfId is returned
*/
    @IsTest
    static void givenValidPayloadWhenCreateDemandsThenSuccess() {
        DemandService.DemandPayload payload = new DemandService.DemandPayload();
        payload.demandNumber = 'NEW001';
        payload.bookingNumber = 'BOOK001';
        payload.customerReference = 'CUST001'; // Ensures Account__c is populated
        payload.soldToPartyId = 'A0001';
        payload.unitcode = 'U001';
        payload.orderQuantity = 5;
        payload.invoiceValue = 5000;
        payload.taxValue = 500;
        payload.milestoneDescription = 'Milestone 1';
        payload.milestoneDate = Date.today();
        payload.milestoneCode = 'Z0000';
        
        Map<String, Map<String, Object>> results = DemandService.createDemands(
            new List<DemandService.DemandPayload>{ payload }
        );
        System.Assert.areEqual('Success', (String)results.get('NEW001').get('status'), 'Expected Success status.');
        System.Assert.isTrue(results.get('NEW001').get('sfId') != null, 'Expected an sfId to be returned.');
    }
    
    /**
* @description Verifies failure when required fields are missing
* GIVEN: Empty payload
* WHEN: createDemands is called
* THEN: Returns Failure
*/
    @IsTest
    static void givenMissingFieldsWhenCreateDemandsThenFailure() {
        DemandService.DemandPayload payload = new DemandService.DemandPayload();
        Map<String, Map<String, Object>> results = DemandService.createDemands(
            new List<DemandService.DemandPayload>{ payload }
        );
        String key = results.keySet().iterator().next();
        System.Assert.areEqual('Failure', (String)results.get(key).get('status'), 'Expected Failure for missing fields.');
    }
    
    /**
* @description Verifies duplicates in input list are reported as failures
* GIVEN: Two payloads with same demandNumber
* WHEN: createDemands is invoked
* THEN: At least one failure is returned
*/
    @IsTest
    static void givenDuplicateDemandNumbersWhenCreateDemandsThenOneFails() {
        DemandService.DemandPayload payload1 = new DemandService.DemandPayload();
        payload1.demandNumber = 'DUPLICATE_IN_REQUEST';
        payload1.bookingNumber = 'BOOK001';
        payload1.customerReference = 'CUST001';
        payload1.soldToPartyId = 'A0001';
        payload1.unitcode = 'MAT001';
        payload1.orderQuantity = 1;
        payload1.invoiceValue = 100;
        payload1.taxValue = 10;
        
        DemandService.DemandPayload payload2 = new DemandService.DemandPayload();
        payload2.demandNumber = 'DUPLICATE_IN_REQUEST';
        payload2.bookingNumber = 'BOOK001';
        payload2.customerReference = 'CUST001';
        payload2.soldToPartyId = 'A0001';
        payload2.unitcode = 'MAT001';
        payload2.orderQuantity = 1;
        payload2.invoiceValue = 100;
        payload2.taxValue = 10;
        
        Map<String, Map<String, Object>> results = DemandService.createDemands(
            new List<DemandService.DemandPayload>{ payload1, payload2 }
        );
        Integer failCount = 0;
        for (Map<String, Object> val : results.values()) {
            if ('Failure'.equals(val.get('status'))) failCount++;
        }
        System.Assert.isTrue(failCount >= 1, 'Expected at least one failure due to duplicate demand number.');
    }
    
    /**
* @description Verifies failure when a demand already exists with same external id
* GIVEN: Existing Demand__c with same SAP_External_Id__c
* WHEN: createDemands is called
* THEN: Returns Failure for that demandNumber
*/
    @IsTest
    static void givenExistingDemandWhenCreateDemandsThenFailure() {
        DemandService.DemandPayload payload = new DemandService.DemandPayload();
        payload.demandNumber = 'DUPLICATE001';
        payload.bookingNumber = 'BOOK001';
        payload.customerReference = 'CUST001';
        payload.soldToPartyId = 'A0001';
        payload.unitcode = 'MAT001';
        payload.orderQuantity = 1;
        payload.invoiceValue = 100;
        payload.taxValue = 10;
        
        Map<String, Map<String, Object>> results = DemandService.createDemands(
            new List<DemandService.DemandPayload>{ payload }
        );
        System.Assert.areEqual('Failure', (String)results.get('DUPLICATE001').get('status'), 'Expected Failure for duplicate existing demand.');
    }
    
    /**
* @description Verifies failure when SoldToPartyId is not found
* GIVEN: Non-existent soldToPartyId
* WHEN: createDemands is called
* THEN: Returns Failure
*/
    @IsTest
    static void givenUnknownSoldToPartyWhenCreateDemandsThenFailure() {
        DemandService.DemandPayload payload = new DemandService.DemandPayload();
        payload.demandNumber = 'ACCNOTFOUND';
        payload.bookingNumber = 'BOOK001';
        payload.customerReference = 'CUST001';
        payload.soldToPartyId = 'NON_EXISTENT';
        payload.unitcode = 'MAT001';
        payload.orderQuantity = 1;
        payload.invoiceValue = 100;
        payload.taxValue = 10;
        
        Map<String, Map<String, Object>> results = DemandService.createDemands(
            new List<DemandService.DemandPayload>{ payload }
        );
        System.Assert.areEqual('Failure', (String)results.get('ACCNOTFOUND').get('status'), 'Expected Failure for unknown SoldToPartyId.');
    }
    
    /**
* @description Verifies failure when customer reference is not found
* GIVEN: Invalid customer reference
* WHEN: createDemands is called
* THEN: Returns Failure
*/
    @IsTest
    static void givenUnknownCustomerReferenceWhenCreateDemandsThenFailure() {
        DemandService.DemandPayload payload = new DemandService.DemandPayload();
        payload.demandNumber = 'CUSTREFNOTFOUND';
        payload.bookingNumber = 'BOOK001';
        payload.soldToPartyId = 'A0001';
        payload.customerReference = 'INVALID_CUST';
        payload.unitcode = 'MAT001';
        payload.orderQuantity = 1;
        payload.invoiceValue = 100;
        payload.taxValue = 10;
        
        Map<String, Map<String, Object>> results = DemandService.createDemands(
            new List<DemandService.DemandPayload>{ payload }
        );
        System.Assert.areEqual('Failure', (String)results.get('CUSTREFNOTFOUND').get('status'), 'Expected Failure for unknown customer reference.');
    }
    
    /**
* @description Verifies failure when unit code is not found
* GIVEN: Invalid unit code
* WHEN: createDemands is called
* THEN: Returns Failure
*/
    @IsTest
    static void givenUnknownUnitCodeWhenCreateDemandsThenFailure() {
        DemandService.DemandPayload payload = new DemandService.DemandPayload();
        payload.demandNumber = 'UNITNOTFOUND';
        payload.bookingNumber = 'BOOK001';
        payload.customerReference = 'CUST001';
        payload.soldToPartyId = 'A0001';
        payload.unitcode = 'INVALID_UNIT';
        payload.orderQuantity = 1;
        payload.invoiceValue = 100;
        payload.taxValue = 10;
        
        Map<String, Map<String, Object>> results = DemandService.createDemands(
            new List<DemandService.DemandPayload>{ payload }
        );
        System.Assert.areEqual('Failure', (String)results.get('UNITNOTFOUND').get('status'), 'Expected Failure for unknown unit code.');
    }
    
    /**
* @description Verifies failure when booking number is not found
* GIVEN: Invalid booking number
* WHEN: createDemands is called
* THEN: Returns Failure
*/
    @IsTest
    static void givenUnknownBookingWhenCreateDemandsThenFailure() {
        DemandService.DemandPayload payload = new DemandService.DemandPayload();
        payload.demandNumber = 'BOOKNOTFOUND';
        payload.bookingNumber = 'INVALID_BOOK';
        payload.customerReference = 'CUST001';
        payload.soldToPartyId = 'A0001';
        payload.unitcode = 'MAT001';
        payload.orderQuantity = 1;
        payload.invoiceValue = 100;
        payload.taxValue = 10;
        
        Map<String, Map<String, Object>> results = DemandService.createDemands(
            new List<DemandService.DemandPayload>{ payload }
        );
        System.Assert.areEqual('Failure', (String)results.get('BOOKNOTFOUND').get('status'), 'Expected Failure for unknown booking number.');
    }
    
    /**
* @description Verifies empty input returns empty result map
* GIVEN: Empty list
* WHEN: createDemands is called
* THEN: Returns empty map
*/
    @IsTest
    static void givenEmptyInputWhenCreateDemandsThenEmptyResult() {
        Map<String, Map<String, Object>> results = DemandService.createDemands(new List<DemandService.DemandPayload>());
        System.Assert.areEqual(0, results.size(), 'Expected empty result map for empty input.');
    }
}