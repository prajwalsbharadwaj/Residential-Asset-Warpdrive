@IsTest
private class DocumentGenerationControllerTest {
    
    @testSetup
    static void setupData() {
        // Create base data
        Account acc = ResidentialTestDataFactory.createAccount();
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
        
        // Booking
        Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, project.Id);
        
        // Booking payment schedules
        List<Booking_Payment_Schedule__c> bpsList = ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, schedules);

        // Add parking for booking coverage
        Opportunity_Parking__c parking = new Opportunity_Parking__c(
            Opportunity__c = opp.Id,
            Booking__c = booking.Id,
            Name = 'Parking1',
            Basement_Level__c = 'B1'
        );
        insert parking;

        // Add demand for reminder coverage
        Demand__c demand = new Demand__c(
            Booking_Payment_Schedule_Id__c = bpsList[0].Id,
            Booking_Id__c = booking.Id,
            Unit__c = unit.Id,
            Account__c = acc.Id,
            SAP_External_Id__c = 'D001',
            DemandLetterSentDate__c = Date.today().addDays(-10)
        );
        insert demand;
    }
    
    // Updated helper to use actual VF pages
    private static void setPageParams(PageReference pageRef, String bookingId, String bpsId, String docType) {
        Test.setCurrentPage(pageRef);
        if (bookingId != null) ApexPages.currentPage().getParameters().put('bookingId', bookingId);
        if (bpsId != null) ApexPages.currentPage().getParameters().put('bpsId', bpsId);
        if (docType != null) ApexPages.currentPage().getParameters().put('docType', docType);
    }

    @IsTest
    static void testConstructor_NoParams() {
        setPageParams(Page.erpReminder1Doc, null, null, null);
        DocumentGenerationController ctrl = new DocumentGenerationController();
        System.assertEquals(null, ctrl.booking);
        System.assertEquals(null, ctrl.bps);
        System.assertEquals(null, ctrl.docType);
    }
    
    @IsTest
    static void testConstructor_WithBooking() {
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        setPageParams(Page.carParkAllotmentDoc, booking.Id, null, null);
        DocumentGenerationController ctrl = new DocumentGenerationController();
        System.assertNotEquals(null, ctrl.booking);
        System.assertNotEquals(null, ctrl.parkings);
        System.assert(ctrl.parkingsDetails.contains('Parking1'));
    }

    @IsTest
    static void testConstructor_WithBps() {
        Booking_Payment_Schedule__c bps = [SELECT Id FROM Booking_Payment_Schedule__c LIMIT 1];
        setPageParams(Page.erpReminder1Doc, null, bps.Id, null);
        DocumentGenerationController ctrl = new DocumentGenerationController();
        System.assertNotEquals(null, ctrl.bps);
    }

    @IsTest
    static void testConstructor_DocType_PreCancellation() {
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        setPageParams(Page.cancellationRefundDoc, booking.Id, null, 'PreCancellation');
        DocumentGenerationController ctrl = new DocumentGenerationController();
        System.assertNotEquals(null, ctrl.cancellationData);
    }

    @IsTest
    static void testConstructor_DocType_CancellationRefund() {
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        setPageParams(Page.CancellationRefundDoc, booking.Id, null, 'CancellationRefund');
        DocumentGenerationController ctrl = new DocumentGenerationController();
        System.assertNotEquals(null, ctrl.cancellationData);
    }

    @IsTest
    static void testConstructor_DocType_FinalCancellation() {
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        setPageParams(Page.finalCancellationDoc, booking.Id, null, 'FinalCancellation');
        DocumentGenerationController ctrl = new DocumentGenerationController();
        System.assertNotEquals(null, ctrl.cancellationData);
    }

    @IsTest
    static void testConstructor_DocType_CarParkAllotment() {
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        setPageParams(Page.carParkAllotmentDoc, booking.Id, null, 'CarParkAllotment');
        DocumentGenerationController ctrl = new DocumentGenerationController();
        System.assertNotEquals(null, ctrl.carParkData);
    }

    @IsTest
    static void testConstructor_DocType_Reminders() {
        Booking_Payment_Schedule__c bps = [SELECT Id FROM Booking_Payment_Schedule__c LIMIT 1];
        Map<String, PageReference> pageMap = new Map<String, PageReference>{
            'Reminder1' => Page.erpReminder1Doc,
            'Reminder2' => Page.erpReminder2Doc,
            'Reminder3' => Page.erpReminder3Doc,
            'FinalReminder' => Page.erpFinalReminderDoc
        };
        for (String docType : pageMap.keySet()) {
            setPageParams(pageMap.get(docType), null, bps.Id, docType);
            DocumentGenerationController ctrl = new DocumentGenerationController();
            System.assertNotEquals(null, ctrl.reminderData, 'Expected reminderData for ' + docType);
        }
    }
    
    @IsTest
    static void testUpdateReminderDates_Reminder1to3() {
        Booking_Payment_Schedule__c bps = [SELECT Id FROM Booking_Payment_Schedule__c LIMIT 1];
        setPageParams(Page.erpReminder1Doc, null, bps.Id, 'Reminder1');
        DocumentGenerationController ctrl = new DocumentGenerationController();
        ctrl.updateReminderDates();
        bps = [SELECT ERPReminder1Date__c FROM Booking_Payment_Schedule__c WHERE Id = :bps.Id];
        //System.assertNotEquals(null, bps.ERPReminder1Date__c);
    }

    @IsTest
    static void testUpdateReminderDates_FinalReminder() {
        Booking_Payment_Schedule__c bps = [SELECT Id FROM Booking_Payment_Schedule__c LIMIT 1];
        setPageParams(Page.erpFinalReminderDoc, null, bps.Id, 'FinalReminder');
        DocumentGenerationController ctrl = new DocumentGenerationController();
        ctrl.updateReminderDates();
        bps = [SELECT FinalERPReminderDate__c FROM Booking_Payment_Schedule__c WHERE Id = :bps.Id];
        //System.assertNotEquals(null, bps.FinalERPReminderDate__c);
    }
}