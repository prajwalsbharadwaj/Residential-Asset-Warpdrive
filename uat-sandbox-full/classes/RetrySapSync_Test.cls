@IsTest
private class RetrySapSync_Test {

    /* ======================================================================
       UNIVERSAL MOCKS MATCHING REAL ENDPOINTS USED BY SAP HANDLER
       (brokercreation + brokerupdate)
       ====================================================================== */

    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();

            // Match the handler's endpoints
            String ep = req.getEndpoint();
            if (ep == 'callout:SAP/brokercreation' || ep == 'callout:SAP/brokerupdate') {
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'application/json');
                res.setBody('[{"PARTNER":"12345","MESSAGE":"Success"}]');
            } else {
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"result":"ok"}');
            }
            return res;
        }
    }

    private class CreatedMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();

            String ep = req.getEndpoint();
            if (ep == 'callout:SAP/brokercreation' || ep == 'callout:SAP/brokerupdate') {
                res.setStatusCode(201);
                res.setBody('[{"PARTNER":"99999","MESSAGE":"Created"}]');
            } else {
                res.setStatusCode(201);
                res.setBody('{"result":"created"}');
            }
            return res;
        }
    }

    private class FailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();

            String ep = req.getEndpoint();
            if (ep == 'callout:SAP/brokercreation' || ep == 'callout:SAP/brokerupdate') {
                res.setStatusCode(500);
                res.setBody('{"error":"SAP Channel Partner Failure"}');
            } else {
                res.setStatusCode(500);
                res.setBody('{"error":"Simulated failure"}');
            }
            return res;
        }
    }

    private class ExceptionMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            throw new CalloutException('Simulated callout exception');
        }
    }

    /* ======================================================================
       TEST DATA
       ====================================================================== */

    @TestSetup
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
        booking.SAP_External_Id__c = '000000001';
        update booking;

        ResidentialTestDataFactory.createBookingCondition(booking.Id, opp.Id);
        ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, schedules);
        ResidentialTestDataFactory.createCompanyBankAccount();
    }

    private static Id getOneBookingId() {
        return [SELECT Id FROM Booking__c LIMIT 1].Id;
    }

    /* ======================================================================
       BOOKING CALLS
       ====================================================================== */

    @IsTest
    static void test_RetryBookingCalloutToSAP_success() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Id bookingId = getOneBookingId();

        Test.startTest();
        RetrySapSyncController.outputWrapper result =
            RetrySapSyncController.RetryBookingCalloutToSAP(bookingId);
        Test.stopTest();

        System.assertEquals(true, result.resp);
        System.assertNotEquals(null, result.responseMessage);
    }

    @IsTest
    static void test_RetryBookingCalloutToSAP_failure_response() {
        Test.setMock(HttpCalloutMock.class, new FailureMock());
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        delete b;

        Test.startTest();
        RetrySapSyncController.outputWrapper result =
            RetrySapSyncController.RetryBookingCalloutToSAP(b.Id);
        Test.stopTest();

        System.assertEquals(false, result.resp);
    }

    @IsTest
    static void test_RetryBookingCalloutToSAP_exception() {
        Test.setMock(HttpCalloutMock.class, new ExceptionMock());
        Id bookingId = getOneBookingId();

        Test.startTest();
        RetrySapSyncController.outputWrapper result =
            RetrySapSyncController.RetryBookingCalloutToSAP(bookingId);
        Test.stopTest();

        System.assertEquals(false, result.resp);
    }

    /* ======================================================================
       ACCOUNT CALLS
       ====================================================================== */

    @IsTest
    static void test_RetryAccountCalloutToSap_success() {
        Test.setMock(HttpCalloutMock.class, new CreatedMock());
        Id accId = [SELECT Id FROM Account LIMIT 1].Id;

        Test.startTest();
        RetrySapSyncController.outputWrapper result =
            RetrySapSyncController.RetryAccountCalloutToSap(accId);
        Test.stopTest();

        System.assertEquals(true, result.resp);
    }

    @IsTest
    static void test_RetryAccountCalloutToSap_failure() {
        Test.setMock(HttpCalloutMock.class, new FailureMock());
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        delete b;

        Test.startTest();
        RetrySapSyncController.outputWrapper result =
            RetrySapSyncController.RetryAccountCalloutToSap(b.Id);
        Test.stopTest();

        System.assertEquals(false, result.resp);
    }

    /* ======================================================================
       RECEIPT CALLS
       ====================================================================== */

    @IsTest
    static void test_RetryPaymentReceiptCalloutToSap_success() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        Company_Bank_Account__c bankAcc = [SELECT Id FROM Company_Bank_Account__c LIMIT 1];
        Booking_Payment_Schedule__c bps = [SELECT Id FROM Booking_Payment_Schedule__c LIMIT 1];

        Demand__c d = ResidentialTestDataFactory.prepareDemand(bps.Id, unit.Id, acc.Id, b.Id, 'Dem120xx9');
        insert d;

        Payment_Receipt__c receipt =
            ResidentialTestDataFactory.preparePaymentReceipt(bps.Id, d.Id, bankAcc.Id);
        ResidentialTestDataFactory.createPaymentReceipt(receipt);

        Test.startTest();
        RetrySapSyncController.outputWrapper result =
            RetrySapSyncController.RetryPaymentReceiptCalloutToSap(receipt.Id);
        Test.stopTest();

        System.assertEquals(true, result.resp);
    }

    @IsTest
    static void test_RetryPaymentReceiptCalloutToSap_exception() {
        Test.setMock(HttpCalloutMock.class, new ExceptionMock());

        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        Company_Bank_Account__c bankAcc = [SELECT Id FROM Company_Bank_Account__c LIMIT 1];
        Booking_Payment_Schedule__c bps = [SELECT Id FROM Booking_Payment_Schedule__c LIMIT 1];

        Demand__c d =
            ResidentialTestDataFactory.prepareDemand(bps.Id, unit.Id, acc.Id, b.Id, 'Dem120xx9');
        insert d;

        Payment_Receipt__c receipt =
            ResidentialTestDataFactory.preparePaymentReceipt(bps.Id, d.Id, bankAcc.Id);
        ResidentialTestDataFactory.createPaymentReceipt(receipt);

        Test.startTest();
        RetrySapSyncController.outputWrapper result =
            RetrySapSyncController.RetryPaymentReceiptCalloutToSap(receipt.Id);
        Test.stopTest();

        System.assertEquals(false, result.resp);
    }

    /* ======================================================================
       MISC
       ====================================================================== */

    @IsTest
    public static void getObjectApiNameTest() {
        Account ac = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        RetrySapSyncController.getObjectApiName(ac.Id);
        Test.stopTest();
    }

    /* ======================================================================
       CHANNEL PARTNER SYNC
       ====================================================================== */

    @IsTest
    static void test_RetryChannelPartnerCalloutToSap_success() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Id accId = [SELECT Id FROM Account LIMIT 1].Id;

        Test.startTest();
        RetrySapSyncController.outputWrapper result =
            RetrySapSyncController.RetryChannelPartnerCalloutToSap(accId);
        Test.stopTest();

        System.assertEquals(true, result.resp);
        System.assertNotEquals(null, result.responseMessage);
    }

    @IsTest
    static void test_RetryChannelPartnerCalloutToSap_failure() {
        Test.setMock(HttpCalloutMock.class, new FailureMock());

        Id accId = [SELECT Id FROM Account LIMIT 1].Id;

        Test.startTest();
        RetrySapSyncController.outputWrapper result =
            RetrySapSyncController.RetryChannelPartnerCalloutToSap(accId);
        Test.stopTest();

        System.assertEquals(false, result.resp);
        System.assertNotEquals(null, result.responseMessage);
    }
/*
    @IsTest
    static void test_RetryChannelPartnerCalloutToSap_exception() {
        Test.setMock(HttpCalloutMock.class, new ExceptionMock());

        Id accId = [SELECT Id FROM Account LIMIT 1].Id;

        Test.startTest();
        RetrySapSyncController.outputWrapper result =
            RetrySapSyncController.RetryChannelPartnerCalloutToSap(accId);
        Test.stopTest();

        System.assertEquals(false, result.resp);
        System.assert(result.responseMessage.contains('Exception'));
    }
    */
}