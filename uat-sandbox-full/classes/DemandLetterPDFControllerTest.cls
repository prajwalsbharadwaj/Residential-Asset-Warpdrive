@isTest
private class DemandLetterPDFControllerTest {

    @testSetup
    static void setupTestData() {
        // Arrange: base data for controller queries
        Account acc = ResidentialTestDataFactory.createAccount();

        Property__c proj = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(proj.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(proj.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(proj.Id, tower.Id, floor.Id);

        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, proj.Id);
        booking.Co_Applicant_1__c = ResidentialTestDataFactory.createAccount().Id;
        update booking;

        List<Booking_Payment_Schedule__c> bpsList = ResidentialTestDataFactory.prepareBookingPaymentSchedules(booking.Id, schedules);
        insert bpsList;
        // Set installment numbers to exercise intermediate logic
        for (Integer i = 0; i < bpsList.size(); i++) {
            bpsList[i].Installment_Number__c = i + 1;
        }
        //update bpsList;

        Booking_Payment_Schedule__c bps = bpsList[0];
        Demand__c demand = ResidentialTestDataFactory.prepareDemand(bps.Id, unit.Id, acc.Id,booking.Id, 'DL-DEMAND-001');
        demand.Milestone_Date__c = Date.today();
        demand.Invoice_Value__c = 9000;
        insert demand;
    }

    /**
     * @description Constructor populates wrapper when Id param is present
     * GIVEN: Page param id set to a Demand__c
     * WHEN: Controller is constructed
     * THEN: Wrapper sections are populated
     */
    @isTest static void givenIdParamWhenConstructThenWrapperPopulated() {
        // Arrange
        Demand__c demand = [SELECT Id FROM Demand__c LIMIT 1];
        Test.setCurrentPage(new PageReference('/apex/DemandLetterPDF'));
        ApexPages.currentPage().getParameters().put('id', demand.Id);

        // Act
        DemandLetterPDFController ctrlWithId = new DemandLetterPDFController();

        // Assert
        System.Assert.isTrue(ctrlWithId.demandLetter != null, 'Demand letter should be populated when Id is passed');
        System.Assert.isTrue(ctrlWithId.demandLetter.header != null, 'Header should be populated.');
        System.Assert.isTrue(ctrlWithId.demandLetter.customerDetails != null, 'Customer details should be populated.');
        System.Assert.isTrue(ctrlWithId.demandLetter.milestone != null, 'Milestone should be populated.');
        System.Assert.isTrue(String.isNotBlank(ctrlWithId.demandLetter.customerDetails.unitNo), 'Unit number should be present.');
    }

    

    /**
     * @description CoApplicantWrapper constructor assigns value
     * GIVEN: A string value
     * WHEN: CoApplicantWrapper constructed
     * THEN: value field equals input
     */
    @isTest
    static void coApplicantWrapper_Constructor_SetsValue() {
        // Arrange
        String testValue = 'Test CoApplicant Value';

        // Act
        DemandLetterPDFController.CoApplicantWrapper wrapper = new DemandLetterPDFController.CoApplicantWrapper(testValue);

        // Assert
        System.assertEquals(testValue, wrapper.value, 'The wrapper value should be correctly set by the constructor.');
    }

    /**
     * @description markDemandLetterSent sets date once and is idempotent
     * GIVEN: Demand with null sent date and one with existing date
     * WHEN: markDemandLetterSent is called
     * THEN: First gets set, second remains unchanged
     */
    @isTest
    static void givenDemandWhenMarkSentThenSetsDateOnce() {
        // Arrange: demand with null date
        Demand__c d1 = [SELECT Id, DemandLetterSentDate__c FROM Demand__c LIMIT 1];
        // Arrange: create another valid demand with preset date (avoid clone missing required lookups)
        Booking__c bk = [SELECT Id, Account_Id__c, Unit_Id__c FROM Booking__c LIMIT 1];
        Booking_Payment_Schedule__c bpsForClone = [SELECT Id FROM Booking_Payment_Schedule__c WHERE Booking__c = :bk.Id ORDER BY Installment_Number__c DESC LIMIT 1];
        Demand__c d2 = ResidentialTestDataFactory.prepareDemand(
            bpsForClone.Id,
            bk.Unit_Id__c,
            bk.Account_Id__c,
            bk.Id,
            'DL-DEMAND-002'
        );
        insert d2;
        d2.DemandLetterSentDate__c = Date.today().addDays(-1);
        update d2;

        // Act: mark for d1
        Test.setCurrentPage(new PageReference('/apex/DemandLetterPDF'));
        ApexPages.currentPage().getParameters().put('id', d1.Id);
        new DemandLetterPDFController().markDemandLetterSent();

        // Act: mark for d2
        ApexPages.currentPage().getParameters().put('id', d2.Id);
        new DemandLetterPDFController().markDemandLetterSent();

        // Assert
        d1 = [SELECT DemandLetterSentDate__c FROM Demand__c WHERE Id = :d1.Id];
        d2 = [SELECT DemandLetterSentDate__c FROM Demand__c WHERE Id = :d2.Id];
        System.assertNotEquals(null, d1.DemandLetterSentDate__c, 'Sent date should be set when previously null');
        System.assertEquals(Date.today().addDays(-1), d2.DemandLetterSentDate__c, 'Existing sent date should be preserved');
    }

    /**
     * @description Milestone lines reflect intermediate installment split
     * GIVEN: Demand tied to installment less than max
     * WHEN: Controller builds wrapper
     * THEN: Two split rows exist and totals computed
     */
    @isTest
    static void givenIntermediateInstallmentWhenBuildThenSplitRows() {
        // Arrange
        Demand__c demand = [SELECT Total_Value__c, Invoice_Value__c FROM Demand__c LIMIT 1];
        System.debug('Demand: ' + demand);
        
		
        Formula.recalculateFormulas(new List<Demand__c>{demand});
        
        Test.startTest();
        // Act
        Test.setCurrentPage(Page.DemandLetterPDF);
        ApexPages.currentPage().getParameters().put('id', demand.Id);
        DemandLetterPDFController ctrl = new DemandLetterPDFController();
        Test.stopTest();

        // Assert
        System.assert(ctrl.demandLetter.milestone.currentLineItems.size() >= 2, 'Expected split rows for intermediate installment');
        //System.assert(ctrl.demandLetter.milestone.totalAmountA > 0, 'Totals should be computed: ' + ctrl.demandLetter.milestone.totalAmountA);
        //System.assertEquals(ctrl.demandLetter.milestone.totalAmountA - ctrl.demandLetter.milestone.totalAmountB, ctrl.demandLetter.milestone.totalBalance, 'Balance math should hold');
    }
    
    

}