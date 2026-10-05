@IsTest
private class DemandCollectionReportControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create Account, Project, Tower, Floor, Unit
        Account acc = ResidentialTestDataFactory.createAccount();
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);

        // Payment Plan & Schedules
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);

        // Opportunity & Booking
        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, project.Id);
        
        // Booking Payment Schedule
        List<Booking_Payment_Schedule__c> bpsList = ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, schedules);

        // Create Demand records
        for (Booking_Payment_Schedule__c bps : bpsList) {
            Demand__c demand = ResidentialTestDataFactory.prepareDemand(bps.Id, unit.Id, acc.Id, booking.Id, 'SAP' + bps.Id);
            insert demand;
            system.debug('Amount--> '+bps.installment_amount__c);

            // Create Payment Receipt
            Payment_Receipt__c receipt = ResidentialTestDataFactory.preparePaymentReceipt(bps.Id, demand.Id, null, 5000000, 'RTGS', Date.today(), null, 'Standard Chartered Bank');
            insert receipt;
        }
    }

    @IsTest
    static void testGetPaymentReceiptsPagination() {
        Date startDate = Date.today().addDays(-1);
        Date endDate = Date.today().addDays(1);
        
        // Test first page
        DemandCollectionReportController.PaymentReceiptResponse response = 
            DemandCollectionReportController.getPaymentReceipts(startDate, endDate, 1, 2);
        System.assertNotEquals(null, response.records);
        System.assert(response.totalRecords > 0);
        System.assert(response.pageNumber == 1);
        System.assert(response.pageSize == 2);
        System.assert(response.totalPages >= 1);

        // Test second page
        DemandCollectionReportController.PaymentReceiptResponse response2 = 
            DemandCollectionReportController.getPaymentReceipts(startDate, endDate, 2, 2);
        System.assertNotEquals(response.records, response2.records); // Different page
    }

    @IsTest
    static void testPaymentReceiptDTOMapping() {
        Date startDate = Date.today().addDays(-1);
        Date endDate = Date.today().addDays(1);

        DemandCollectionReportController.PaymentReceiptResponse response = 
            DemandCollectionReportController.getPaymentReceipts(startDate, endDate, 1, 10);

        for (DemandCollectionReportController.ReceiptsDto dto : response.records) {
            System.assertNotEquals(null, dto.Project);
            System.assertNotEquals(null, dto.UnitNo);
            System.assert(dto.ReceiptAmt != null);
            System.assert(dto.DemandInvoiceValue != null);
            System.assert(dto.PrevDuePrincipleOnly != null);
        }
    }

    @IsTest
    static void testPrevDuesCalculation() {
        // Query one booking
        Booking_Payment_Schedule__c bps = [SELECT Booking__c FROM Booking_Payment_Schedule__c LIMIT 1];
        Decimal prevDues = ReportSelector.getPrevDues(bps.Booking__c);
        System.assert(prevDues >= 0);
    }

    @IsTest
    static void testPaymentReceiptSelectorPagination() {
        Date startDate = Date.today().addDays(-1);
        Date endDate = Date.today().addDays(1);

        List<Payment_Receipt__c> receipts = ReportSelector.getPaymentReceipt(startDate, endDate, 1, 2);
        System.assert(receipts.size() <= 2);
    }

    @IsTest
    static void testEmptyResults() {
        // Future date with no receipts
        Date startDate = Date.today().addYears(1);
        Date endDate = Date.today().addYears(1).addDays(1);

        DemandCollectionReportController.PaymentReceiptResponse response = 
            DemandCollectionReportController.getPaymentReceipts(startDate, endDate, 1, 5);

        System.assertEquals(0, response.records.size());
        System.assertEquals(0, response.totalRecords);
    }
}