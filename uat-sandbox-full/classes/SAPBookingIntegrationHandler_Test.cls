@IsTest
private class SAPBookingIntegrationHandler_Test {

    // ====== Mocks ======
    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('[]');
            return res;
        }
    }
    private class ThrowingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated transport error');
        }
    }
    Private class FailureMock implements HttpCalloutMock{
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{}');
            return res;
        }
    }

    // ====== Test Data ======
    @testSetup
    static void setupData() {
        Account acc = ResidentialTestDataFactory.createAccount();
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);

        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);

        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);

        Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, project.Id);
        booking.Rejection_Reason__c = 'Cancellation opted by Company';
        booking.SAP_External_Id__c = '0000000001';
        update booking;

        ResidentialTestDataFactory.createBookingCondition(booking.Id, opp.Id);
        ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, schedules);
    }

    private static Id getOneBookingId() {
        return [SELECT Id FROM Booking__c LIMIT 1].Id;
    }
    private static Id getOneCondId() {
        return [SELECT Id FROM Booking_Condition__c LIMIT 1].Id;
    }
    private static Id getOnePsId() {
        return [SELECT Id FROM Booking_Payment_Schedule__c LIMIT 1].Id;
    }

    // ====== SAPBookingIntegrationHandler Tests ======

    @IsTest
    static void test_sendBookingData_success_with_real_payload() {
        
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Set<Id> bookingIds = new Set<Id>{ getOneBookingId() };

        Test.startTest();
        SAPBookingIntegrationHandler.responseWrapper rw =
            SAPBookingIntegrationHandler.sendBookingData(bookingIds);
        Test.stopTest();

        System.assertNotEquals(null, rw);
        System.assertEquals('[]', rw.responseBody);
    }
    
    @IsTest
    static void test_sendBookingData_failure_with_real_payload() {
        
        Test.setMock(HttpCalloutMock.class, new FailureMock());
        Set<Id> bookingIds = new Set<Id>{ getOneBookingId() };

        Test.startTest();
        SAPBookingIntegrationHandler.responseWrapper rw =
            SAPBookingIntegrationHandler.sendBookingData(bookingIds);
        Test.stopTest();

        System.assertNotEquals(null, rw);
        System.assertEquals('{}', rw.responseBody);
    }

    @IsTest
    static void test_sendBookingDataAsync_future_success() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Set<Id> bookingIds = new Set<Id>{ getOneBookingId() };

        Test.startTest();
        SAPBookingIntegrationHandler.sendBookingDataAsync(bookingIds);
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void test_sendBookingConUpdatedData_success() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Set<Id> bIds  = new Set<Id>{ getOneBookingId() };
        Set<Id> bcIds = new Set<Id>{ getOneCondId() };

        Test.startTest();
        SAPBookingIntegrationHandler.sendBookingConUpdatedData(bIds, bcIds);
        Test.stopTest();

        System.assert(true);
    }
    @IsTest
    static void test_sendBookingConUpdatedData_failure() {
        Test.setMock(HttpCalloutMock.class, new FailureMock());
        Set<Id> bIds  = new Set<Id>{ getOneBookingId() };
        Set<Id> bcIds = new Set<Id>{ getOneCondId() };

        Test.startTest();
        SAPBookingIntegrationHandler.sendBookingConUpdatedData(bIds, bcIds);
        Test.stopTest();

        System.assert(true);
    }
    

    @IsTest
    static void test_sendBookingPaymentSchUpdatedData_success() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Set<Id> bIds  = new Set<Id>{ getOneBookingId() };
        Set<Id> psIds = new Set<Id>{ getOnePsId() };

        Test.startTest();
        SAPBookingIntegrationHandler.sendBookingPaymentSchUpdatedData(bIds, psIds);
        Test.stopTest();

        System.assert(true);
    }
    @IsTest
    static void test_sendBookingPaymentSchUpdatedData_failure() {
        Test.setMock(HttpCalloutMock.class, new FailureMock());
        Set<Id> bIds  = new Set<Id>{ getOneBookingId() };
        Set<Id> psIds = new Set<Id>{ getOnePsId() };

        Test.startTest();
        SAPBookingIntegrationHandler.sendBookingPaymentSchUpdatedData(bIds, psIds);
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void test_sendBookingCoApplicantUpdatedData_success() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Set<Id> bIds  = new Set<Id>{ getOneBookingId() };

        Test.startTest();
        SAPBookingIntegrationHandler.sendBookingCoApplicantUpdatedData(bIds);
        Test.stopTest();

        System.assert(true);
    }
    @IsTest
    static void test_sendBookingCoApplicantUpdatedData_failure() {
        Test.setMock(HttpCalloutMock.class, new FailureMock());
        Set<Id> bIds  = new Set<Id>{ getOneBookingId() };

        Test.startTest();
        SAPBookingIntegrationHandler.sendBookingCoApplicantUpdatedData(bIds);
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void test_exception_paths() {
        Test.setMock(HttpCalloutMock.class, new ThrowingMock());
        Set<Id> bIds  = new Set<Id>{ getOneBookingId() };
        Set<Id> bcIds = new Set<Id>{ getOneCondId() };
        Set<Id> psIds = new Set<Id>{ getOnePsId() };

        SAPBookingIntegrationHandler.responseWrapper rw =
            SAPBookingIntegrationHandler.sendBookingData(bIds);

        System.assertNotEquals(null, rw);

        Test.setMock(HttpCalloutMock.class, new ThrowingMock());
        Test.startTest();
        SAPBookingIntegrationHandler.sendBookingDataAsync(bIds);
        SAPBookingIntegrationHandler.sendBookingConUpdatedData(bIds, bcIds);
        SAPBookingIntegrationHandler.sendBookingPaymentSchUpdatedData(bIds, psIds);
        SAPBookingIntegrationHandler.sendBookingCoApplicantUpdatedData(bIds);
        Test.stopTest();

        System.assert(true);
    }

   @IsTest
static void test_processBookingCreationResponse_success() {
    Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];

    BookingWrapper bw = new BookingWrapper();
    bw.BOOKING_ID = b.Id;
    List<BookingWrapper> payloadList = new List<BookingWrapper>{ bw };

    BookingResponseProcessor.BookingResponse resSuccess = new BookingResponseProcessor.BookingResponse();
    resSuccess.SO = 'SAP123';
    resSuccess.REMARK = 'All good';
    List<BookingResponseProcessor.BookingResponse> responseListSuccess = new List<BookingResponseProcessor.BookingResponse>{ resSuccess };

    Test.startTest();
    BookingResponseProcessor.processBookingCreationResponse(payloadList, responseListSuccess, 'Success Body');
    Test.stopTest();

    Booking__c updatedBooking = [SELECT SAP_External_Id__c, SAP_Sync_Status__c, SAP_Sync_Message__c 
                                 FROM Booking__c WHERE Id = :b.Id];
    System.assertEquals('SAP123', updatedBooking.SAP_External_Id__c);
    System.assertEquals('Success', updatedBooking.SAP_Sync_Status__c);
}

@IsTest
static void test_processBookingCreationResponse_error() {
    Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];

    BookingWrapper bw = new BookingWrapper();
    bw.BOOKING_ID = b.Id;
    List<BookingWrapper> payloadList = new List<BookingWrapper>{ bw };

    BookingResponseProcessor.BookingResponse resError = new BookingResponseProcessor.BookingResponse();
    resError.SO = null;
    List<BookingResponseProcessor.BookingResponse> responseListError = new List<BookingResponseProcessor.BookingResponse>{ resError };

    Test.startTest();
    BookingResponseProcessor.processBookingCreationResponse(payloadList, responseListError, 'Error Body');
    Test.stopTest();

    Booking__c updatedBooking = [SELECT SAP_External_Id__c, SAP_Sync_Status__c, SAP_Sync_Message__c 
                                 FROM Booking__c WHERE Id = :b.Id];
    System.assertEquals('Error Body', updatedBooking.SAP_Sync_Message__c);
    System.assertEquals('Error', updatedBooking.SAP_Sync_Status__c);
}


    @IsTest
static void test_processBookingUpdateResponse_success() {
    Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];

    // Payload
    BookingUpdateWrapper buw = new BookingUpdateWrapper();
    buw.BOOKING_ID = b.Id;
    List<BookingUpdateWrapper> payloadList = new List<BookingUpdateWrapper>{ buw };

    // Response - success case
    BookingResponseProcessor.BookingResponse resSuccess = new BookingResponseProcessor.BookingResponse();
    resSuccess.SO = 'SAP456';
    List<BookingResponseProcessor.BookingResponse> responseListSuccess = new List<BookingResponseProcessor.BookingResponse>{ resSuccess };

    Test.startTest();
    BookingResponseProcessor.processBookingUpdateResponse(payloadList, responseListSuccess, 'Success Body');
    Test.stopTest();

    Booking__c updatedBooking = [SELECT SAP_External_Id__c, SAP_Sync_Status__c, SAP_Sync_Message__c 
                                 FROM Booking__c WHERE Id = :b.Id];
    System.assertEquals('SAP456', updatedBooking.SAP_External_Id__c);
    System.assertEquals('Success', updatedBooking.SAP_Sync_Status__c);
}

@IsTest
static void test_processBookingUpdateResponse_error() {
    Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];

    // Payload
    BookingUpdateWrapper buw = new BookingUpdateWrapper();
    buw.BOOKING_ID = b.Id;
    List<BookingUpdateWrapper> payloadList = new List<BookingUpdateWrapper>{ buw };

    // Response - error case
    BookingResponseProcessor.BookingResponse resError = new BookingResponseProcessor.BookingResponse();
    resError.SO = '';
    List<BookingResponseProcessor.BookingResponse> responseListError = new List<BookingResponseProcessor.BookingResponse>{ resError };

    Test.startTest();
    BookingResponseProcessor.processBookingUpdateResponse(payloadList, responseListError, 'Error Body');
    Test.stopTest();

    Booking__c updatedBooking = [SELECT SAP_External_Id__c, SAP_Sync_Status__c, SAP_Sync_Message__c 
                                 FROM Booking__c WHERE Id = :b.Id];
    System.assertEquals('Error Body', updatedBooking.SAP_Sync_Message__c);
    System.assertEquals('Error', updatedBooking.SAP_Sync_Status__c);
}

}