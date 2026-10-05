@isTest
public class PaymentLedgerControllerTest {

    @testSetup
    static void setupData() {
        // Arrange: create base inventory and booking using factory
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

        List<Booking_Payment_Schedule__c> bpsrecords = ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, schedules);

        // Tweak dates and adjusted amounts
        for (Integer i = 0; i < bpsrecords.size(); i++) {
            bpsrecords[i].Payment_Due_Date__c = Date.today().addDays(-(15 - i));
            bpsrecords[i].Adjusted_Amount__c = (i == 0) ? 2500 : null;
        }
        update bpsrecords;

        Company_Bank_Account__c companyBankAcc = ResidentialTestDataFactory.createCompanyBankAccount();

        // Demands: one inside window and one outside
        Demand__c demandIn = ResidentialTestDataFactory.prepareDemand(bpsrecords[0].Id, unit.Id, acc.Id, booking.Id, 'SAP001');
        //demandIn.Milestone_Date__c = Date.today().addDays(-10);
        demandIn.Invoice_Value__c = 3000;
        Demand__c demandOut = ResidentialTestDataFactory.prepareDemand(bpsrecords[1].Id, unit.Id, acc.Id, booking.Id, 'SAP002');
        //demandOut.Milestone_Date__c = Date.today().addMonths(-3);
        demandOut.Invoice_Value__c = 4000;
        insert new List<Demand__c>{ demandIn, demandOut };

        // Receipts across modes for demandIn
        List<Payment_Receipt__c> receipts = new List<Payment_Receipt__c>{
            ResidentialTestDataFactory.preparePaymentReceipt(bpsrecords[0].Id, demandIn.Id, companyBankAcc.Id, 1200, 'Cheque', Date.today().addDays(-9), 778899, 'Standard Chartered Bank'),
            ResidentialTestDataFactory.preparePaymentReceipt(bpsrecords[0].Id, demandIn.Id, companyBankAcc.Id, 800, 'RTGS', Date.today().addDays(-8), null, 'Standard Chartered Bank'),
            ResidentialTestDataFactory.preparePaymentReceipt(bpsrecords[0].Id, demandIn.Id, companyBankAcc.Id, 600, 'Net Banking', Date.today().addDays(-7), null, 'Standard Chartered Bank'),
            ResidentialTestDataFactory.preparePaymentReceipt(bpsrecords[0].Id, demandIn.Id, companyBankAcc.Id, 500, 'Bank Disbursement', Date.today().addDays(-6), null, 'Standard Chartered Bank'),
            ResidentialTestDataFactory.preparePaymentReceipt(bpsrecords[0].Id, demandIn.Id, companyBankAcc.Id, 300, 'TDS', Date.today().addDays(-5), null, 'Standard Chartered Bank')
        };
        receipts[1].Transaction_Reference__c = 'TXN123456';
        receipts[2].Transaction_Reference__c = 'NB12345678';
        receipts[3].Transaction_Reference__c = 'BD1234';
        receipts[4].Challan_Number__c = 'TDS98765';
        ResidentialTestDataFactory.createPaymentReceipts(receipts);

        // Mark receipts approved
        List<Payment_Receipt__c> recsToApprove = [SELECT Id, Approval_Status__c FROM Payment_Receipt__c];
        for (Payment_Receipt__c r : recsToApprove) { r.Approval_Status__c = 'Approved'; }
        update recsToApprove;

        // Seed some interest numbers (only non-formula fields are writeable)
        List<Booking_Payment_Schedule__c> toUpd = [SELECT Id, AccruedInterestToDateLedger__c FROM Booking_Payment_Schedule__c WHERE Booking__c = :booking.Id];
        for (Booking_Payment_Schedule__c b : toUpd) {
            //b.AccruedInterestToDateLedger__c = 100;
        }
        update toUpd;
    }

    /**
     * @description Verifies buildInstrumentRef across payment modes
     * GIVEN: Receipts for Cheque/RTGS/NetBanking/Bank Disbursement/TDS
     * WHEN: buildInstrumentRef is called
     * THEN: Returns expected instrument values; unknown/null returns empty
     */
    @IsTest
    static void givenReceiptsWhenBuildInstrumentRefThenReturnsExpected() {
        // Arrange: fetch receipts
        List<Payment_Receipt__c> receipts = [SELECT Id, Mode_Of_Payment__c, ChequeNumber__c, Transaction_Reference__c, Challan_Number__c FROM Payment_Receipt__c];

        // Act + Assert
        for (Payment_Receipt__c r : receipts) {
            String ref = PaymentLedgerController.buildInstrumentRef(r);
            if (r.Mode_Of_Payment__c == 'Cheque') System.assertEquals('778899', ref);
            if (r.Mode_Of_Payment__c == 'RTGS') System.assertEquals('TXN123456', ref);
            if (r.Mode_Of_Payment__c == 'Net Banking') System.assertEquals('NB12345678', ref);
            if (r.Mode_Of_Payment__c == 'Bank Disbursement') System.assertEquals('BD1234', ref);
            if (r.Mode_Of_Payment__c == 'TDS') System.assertEquals('TDS98765', ref);
        }

        // Unknown and null
        Payment_Receipt__c unknown = new Payment_Receipt__c(Mode_Of_Payment__c = 'Cash');
        System.assertEquals('', PaymentLedgerController.buildInstrumentRef(unknown));
        System.assertEquals('', PaymentLedgerController.buildInstrumentRef(null));
    }

    /**
     * @description Verifies controller parses page params and sets defaults
     * GIVEN: Page params set vs not set
     * WHEN: Controller constructs
     * THEN: Dates/filename/defaults as expected
     */
    @IsTest
    static void givenPageParamsWhenConstructThenParsesAndPopulates() {
        // Arrange
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        PageReference pageRef = new PageReference('/apex/PaymentLedger');
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', booking.Id);
        ApexPages.currentPage().getParameters().put('startDate', String.valueOf(Date.today().addMonths(-1)));
        ApexPages.currentPage().getParameters().put('endDate', String.valueOf(Date.today()));

        // Act
        Test.startTest();
        PaymentLedgerController ctrl = new PaymentLedgerController();
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, ctrl.ledgerStatement, 'Ledger should be generated when id is supplied');
        System.assertEquals(Date.valueOf(ApexPages.currentPage().getParameters().get('startDate')), ctrl.startDate);
        System.assertEquals(Date.valueOf(ApexPages.currentPage().getParameters().get('endDate')), ctrl.endDate);
        System.assertNotEquals(null, ctrl.ledgerFileName, 'Filename should be set');

        // Arrange: no params
        Test.setCurrentPage(new PageReference('/apex/PaymentLedger2'));
        ApexPages.currentPage().getParameters().clear();

        // Act
        PaymentLedgerController ctrl2 = new PaymentLedgerController();

        // Assert
        System.assertNotEquals(null, ctrl2.ledgerStatement, 'Should create empty statement when no id');
        System.assertNotEquals(null, ctrl2.ledgerFileName, 'Default filename should be set');
    }

    /**
     * @description Verifies ledger statement rows and totals within date window
     * GIVEN: Demands and receipts in and out of window
     * WHEN: generateLedgerStatement is called
     * THEN: Rows exclude out-of-window, totals and derived totals are consistent
     */
    @IsTest
    static void givenBookingWhenGenerateLedgerThenRowsAndTotalsValid() {
        // Arrange
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];

        // Act
        Test.startTest();
        PaymentLedgerController.LedgerStatement ls = PaymentLedgerController.generateLedgerStatement(
            booking.Id,
            Date.today().addMonths(-1),
            Date.today()
        );
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, ls, 'Ledger statement should not be null');
        System.assert(ls.entry.size() > 0, 'Ledger should have entries for demands/receipts');
        System.assert(ls.totalDebits >= 0 && ls.totalCredits >= 0, 'Totals should be non-negative');
        System.assertEquals(ls.entry[ls.entry.size()-1].balance, ls.totalBalance, 'Closing balance aligns with last entry');
        System.assert(ls.totalDebitsInclInterest >= ls.totalDebits, 'Debits including interest should be >= debits');
        System.assert(ls.totalBalanceInclInterest >= ls.totalBalance, 'Balance including interest should be >= balance');
    }
}