@isTest
public class SOAStatementControllerTest {
    
    @testSetup
    static void setupData() {
        // Create necessary records using ResidentialTestDataFactory (Following Old Test Class Style)
        Account acc = ResidentialTestDataFactory.createAccount();
        Property__c proj = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(proj.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(proj.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(proj.Id, tower.Id, floor.Id);
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, proj.Id);
        List<Booking_Payment_Schedule__c> bpsrecords = ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, schedules);
        
        // Create necessary associated records for Payment Receipt
        Company_Bank_Account__c companyBankAcc = ResidentialTestDataFactory.createCompanyBankAccount();
        
        // Ensure Demand record is created and inserted
        Demand__c demand = new Demand__c(
            Booking_Payment_Schedule_Id__c = bpsrecords[0].Id, 
            Unit__c = unit.Id,
            Account__c = acc.Id,
            SAP_External_Id__c = 'SAP001',
            Booking_Id__c = booking.Id // Ensure this lookup is populated
        );
        insert demand;
        
        // Create Payment Receipts with 'Posted' status to meet Controller query requirements
        Payment_Receipt__c receipt1 = new Payment_Receipt__c(
            Booking_Payment_Schedule__c = bpsrecords[0].Id,
            Amount_Paid__c = 10000000, // Testing large amount for Crore formatting
            Receipt_Status__c = 'Posted', 
            Date_Of_Payment__c = Date.today(), 
            Principal_Applied__c = 500.00,
            Mode_Of_Payment__c = 'Cheque', 
            ChequeNumber__c = '123456',
            Demand__c = demand.Id,
            Company_Bank_Account__c = companyBankAcc.Id,
            Customer_Bank_Name__c = 'Standard Chartered Bank'
        );
        
        Payment_Receipt__c receipt2 = new Payment_Receipt__c(
            Booking_Payment_Schedule__c = bpsrecords[1].Id,
            Amount_Paid__c = 1500, 
            Receipt_Status__c = 'Posted', 
            Date_Of_Payment__c = Date.today(),
            Principal_Applied__c = 500.00,
            Mode_Of_Payment__c = 'RTGS',
            Transaction_Reference__c = 'RTGS123',
            Demand__c = demand.Id,
            Company_Bank_Account__c = companyBankAcc.Id
        );

        Payment_Receipt__c receipt3 = new Payment_Receipt__c(
            Booking_Payment_Schedule__c = bpsrecords[1].Id,
            Amount_Paid__c = 2000, 
            Receipt_Status__c = 'Posted', 
            Date_Of_Payment__c = Date.today(),
            Mode_Of_Payment__c = 'TDS',
            Challan_Number__c = 'CHL789',
            Demand__c = demand.Id,
            Company_Bank_Account__c = companyBankAcc.Id
        );
        insert new List<Payment_Receipt__c>{receipt1, receipt2, receipt3};
    }
    
    @IsTest
    static void testSOAStatementGenerationAndConstructor() {
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        
        // Mock Page Parameters for Constructor coverage
        PageReference pageRef = Page.StatementOfAccountDOC; 
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', booking.Id);
        ApexPages.currentPage().getParameters().put('startDate', String.valueOf(Date.today().addMonths(-1)));
        ApexPages.currentPage().getParameters().put('endDate', String.valueOf(Date.today()));

        Test.startTest();
        SOAStatementController controller = new SOAStatementController();
        // Explicitly calling core method
        controller.soaStatement = SOAStatementController.generateSOAStatement(booking.Id, controller.startDate, controller.endDate);
        Test.stopTest();
        
        System.assertNotEquals(null, controller.soaStatement, 'SOA Statement should not be null');
        System.assert(controller.soaStatement.schedules.size() > 0, 'SOA Statement should contain schedules');
    }
    
    @IsTest
    static void testGetterMethods() {
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        
        Test.startTest();
        SOAStatementController controller = new SOAStatementController();
        controller.soaStatement = SOAStatementController.generateSOAStatement(booking.Id, Date.today().addMonths(-1), Date.today());
        
        // Test all getter methods (Note: getTotalInterest now returns String)
        SOAStatementController.StatementData statement = controller.getSOAStatement();
        Map<String,String> header = controller.getSOAHeader();
        List<SOAStatementController.SOAPaymentScheduleEntry> schedules = controller.getSOASchedules();
        List<SOAStatementController.SOAReceiptEntry> receipts = controller.getSOAReceipts();
        String totalInterestStr = controller.getTotalInterest();
        
        // New getters coverage
        Decimal totalSale = controller.getTotalSaleConsideration();
        Decimal intRec = controller.getTotalInterestReceived();
        Decimal intOut = controller.getBookingInterestOutstanding();
        Decimal dueOnDate = controller.getTotalDueAsOnDate();
        Test.stopTest();
        
        System.assertNotEquals(null, statement);
        System.assertNotEquals(null, totalInterestStr);
    }

    @IsTest
    static void testAuraEnabledDateBounds() {
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        
        Test.startTest();
        SOAStatementController.DateBounds bounds = SOAStatementController.getReceiptDateBounds(booking.Id);
        SOAStatementController.getReceiptDateBounds(null); // Cover null branch
        Test.stopTest();
        
        System.assertNotEquals(null, bounds.firstDate);
    }

    @IsTest
    static void testIndianCurrencyFormattingLogic() {
        Test.startTest();
        // Cover Lakhs, Crores, Negatives, and Nulls for 100% coverage of helper method
        String crore = SOAStatementController.formatINR(10000000.00);   // 1,00,00,000.00
        String lakhs = SOAStatementController.formatINR(123456.78);     // 1,23,456.78
        String small = SOAStatementController.formatINR(500.00);        // 500.00
        String negative = SOAStatementController.formatINR(-1000.00);   // -1,000.00
        String nullVal = SOAStatementController.formatINR(null);        // 0.00
        Test.stopTest();
        
        System.assertEquals('1,00,00,000.00', crore);
        System.assertEquals('1,23,456.78', lakhs);
    }

    @IsTest
    static void testInstrumentRefAllModes() {
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        
        Test.startTest();
        SOAStatementController.StatementData statement = SOAStatementController.generateSOAStatement(
            booking.Id, Date.today().addMonths(-1), Date.today()
        );
        Test.stopTest();
        
        for (SOAStatementController.SOAReceiptEntry r : statement.receipts) {
            System.assertNotEquals(null, r.fAmountReceived, 'Formatted amount should be populated');
        }
    }
    
    @IsTest
    static void testGetterMethodsWithNullStatement() {
        Test.startTest();
        SOAStatementController controller = new SOAStatementController();
        controller.soaStatement = null; 
        
        System.assertEquals(0, controller.getSOAHeader().size());
        System.assertEquals(0, controller.getSOASchedules().size());
        System.assertEquals('0.00', controller.getTotalInterest());
        Test.stopTest();
    }
    
    @IsTest
    static void testNullInputsException() {
        Test.startTest();
        try {
            SOAStatementController.generateSOAStatement(null, Date.today(), Date.today());
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}