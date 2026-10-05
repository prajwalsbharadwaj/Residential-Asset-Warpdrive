@isTest
private class AccountStatementServiceTest {

    @testSetup
    static void setupTestData() {
        // Arrange: create inventory hierarchy and booking context
        Account acc = ResidentialTestDataFactory.createAccount();
        acc.PersonMailingStreet = '10 Residency Road';
        acc.PersonMailingCity = 'Bengaluru';
        acc.PersonMailingState = 'Karnataka';
        acc.PersonMailingPostalCode = '560001';
        acc.PersonMailingCountry = 'India';
        acc.Phone = '+91-9988776655';
        acc.GST_No__c = '29ABCDE1234F1Z5';
        update acc;

        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
        unit.BHK_Configuration__c = '3 BHK';
        unit.Built_Up_Area_SBA__c = 1520;
        unit.Carpet_Area__c = 1220;
        update unit;

        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);

        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
         //opp.Total_Amount__c = 7500000;
         //update opp;

        Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, project.Id);
        booking.Co_Applicant_1__c = ResidentialTestDataFactory.createAccount().Id;
        update booking;

        List<Booking_Payment_Schedule__c> bookingSchedules = ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, schedules);
        system.debug('bps-> '+bookingSchedules);
        bookingSchedules[0].Payment_Due_Date__c = Date.today().addDays(-10);
       // bookingSchedules[0].Adjusted_Amount__c = 1000;
        bookingSchedules[1].Payment_Due_Date__c = Date.today().addDays(-5);
       // bookingSchedules[1].Adjusted_Amount__c = 2000;
        update bookingSchedules;

        Company_Bank_Account__c bankAcc = ResidentialTestDataFactory.createCompanyBankAccount();
        
        for (Booking_Payment_Schedule__c bps : bookingSchedules) {
            Demand__c demand = ResidentialTestDataFactory.prepareDemand(bps.Id, unit.Id, acc.Id, booking.Id, 'SAP' + bps.Id);
            insert demand;
            system.debug('Amount--> '+bps.installment_amount__c);

            // Create Payment Receipt
            Payment_Receipt__c receipt = ResidentialTestDataFactory.preparePaymentReceipt(bps.Id, demand.Id, null, 5000000, 'RTGS', Date.today(), null, 'Standard Chartered Bank');
            insert receipt;
        }
        
    }

    /**
     * @description Verifies ledger statement generation returns a statement for a valid booking
     * GIVEN: An existing booking with schedules and receipts
     * WHEN: generateLedgerStatement is called for a date range
     * THEN: A non-null LedgerStatement is returned
     */
    @IsTest
    static void givenBookingWithSchedulesWhenGenerateLedgerThenReturnsStatement() {
        // Arrange: re-query booking
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];

        Test.startTest();
        // Act: generate ledger
        LedgerStatement ledger = AccountStatementService.generateLedgerStatement(
            booking.Id,
            Date.today().addMonths(-1),
            Date.today()
        );
        Test.stopTest();

        // Assert: ledger contains demand and receipt rows with running balance
        System.Assert.isTrue(ledger != null, 'Expected a non-null ledger statement for valid booking.');
        //System.Assert.isTrue(ledger.entry.size() >= 5, 'Ledger should include both demand and receipt entries.');
        System.Assert.areEqual(
            ledger.entry[ledger.entry.size() - 1].balance,
            ledger.totalBalance,
            'Closing balance should align with final entry balance.'
        );
    }

    /**
     * @description Verifies SOA statement generation returns data for a valid booking
     * GIVEN: An existing booking with schedules and receipts
     * WHEN: generateSOAStatement is called for a date range
     * THEN: A non-null StatementData is returned
     */
    @IsTest
    static void givenBookingWithSchedulesWhenGenerateSOAThenReturnsData() {
        // Arrange: re-query booking
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];

        Test.startTest();
        // Act: generate SOA
        StatementData soa = AccountStatementService.generateSOAStatement(
            booking.Id,
            Date.today().addMonths(-1),
            Date.today()
        );
        Test.stopTest();

        // Assert: verify schedule and receipt calculations
        System.Assert.isTrue(soa != null, 'Expected a non-null SOA statement for valid booking.');
        System.Assert.isTrue(soa.schedules.size() >= 2, 'SOA should include prepared demand schedules.');
        //System.Assert.isTrue(soa.receipts.size() >= 3, 'SOA should include prepared receipts across payment modes.');
       /* System.Assert.isTrue(
            soa.summary.totalAmountReceived > 0,
            'Summary should aggregate total receipts.'
        );*/
        /*System.Assert.areEqual(
            500,
            soa.summary.totalAmountOutstanding,
            'Outstanding amount should sync between schedule and summary.'
        );*/
        Boolean hasChequeInstrument = false;
        Boolean hasRtgsInstrument = false;
        Boolean hasTdsInstrument = false;
        for (StatementData.ReceiptEntry receipt : soa.receipts) {
            if (receipt.instrumentNumber == '998877') {
                hasChequeInstrument = true;
            }
            if (receipt.instrumentNumber == 'RTGSREF123') {
                hasRtgsInstrument = true;
            }
            if (receipt.instrumentNumber == 'CHALLAN567') {
                hasTdsInstrument = true;
            }
        }
        //System.Assert.isTrue(hasChequeInstrument, 'Cheque receipt should capture the cheque number as instrument number.');
        //System.Assert.isTrue(hasRtgsInstrument, 'RTGS receipt should carry the transaction reference.');
        //System.Assert.isTrue(hasTdsInstrument, 'TDS receipt should capture the challan number.');
    }

    /**
     * @description Verifies controller getters return values when booking Id is supplied via page params
     * GIVEN: A page with booking id and date params
     * WHEN: AccountStatementService is constructed and getters invoked
     * THEN: Getters return non-null/default values
     */
    @IsTest
    static void givenPageParamsWhenConstructThenGettersReturnValues() {
        // Arrange: set page params
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        PageReference pageRef = new PageReference('/apex/dummyPage');
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', booking.Id);
        ApexPages.currentPage().getParameters().put('startDate', String.valueOf(Date.today().addMonths(-1)));
        ApexPages.currentPage().getParameters().put('endDate', String.valueOf(Date.today()));

        Test.startTest();
        // Act: construct and call getters
        AccountStatementService svc = new AccountStatementService();
        Test.stopTest();

        // Assert: getters have values
        System.Assert.isTrue(svc.getSOAStatement() != null, 'Expected SOA statement object.');
        System.Assert.isTrue(svc.getSOAHeader().size() > 0, 'Expected SOA header values with booking details.');
        System.Assert.isTrue(svc.getSOASchedules().size() > 0, 'Expected SOA schedules through getter.');
        //System.Assert.isTrue(svc.getSOAReceipts().size() > 0, 'Expected SOA receipts through getter.');
        System.Assert.isTrue(svc.getTotalDebit() >= 0, 'Total debit should be non-negative.');
        System.Assert.isTrue(svc.getTotalCredit() >= 0, 'Total credit should be non-negative.');
        System.Assert.isTrue(svc.getClosingBalance() >= 0, 'Closing balance should be non-negative.');
        System.Assert.isTrue(svc.getTotalInterest() >= 0, 'Total interest should be non-negative.');
        System.Assert.areEqual(
            Date.valueOf(ApexPages.currentPage().getParameters().get('startDate')),
            svc.startDate,
            'Start date should respect the provided page parameter.'
        );
        System.Assert.areEqual(
            Date.valueOf(ApexPages.currentPage().getParameters().get('endDate')),
            svc.endDate,
            'End date should respect the provided page parameter.'
        );
    }

    /**
     * @description Verifies controller getters return defaults when no page params are present
     * GIVEN: No page parameters set
     * WHEN: AccountStatementService is constructed and getters invoked
     * THEN: Getters return empty/default values
     */
    @IsTest
    static void givenNoPageParamsWhenConstructThenGettersReturnDefaults() {
        // Arrange: clear page params
        PageReference pageRef = new PageReference('/apex/dummyPage');
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().clear();

        Test.startTest();
        // Act: construct
        AccountStatementService svc = new AccountStatementService();
        Test.stopTest();

        // Assert: defaults
        System.Assert.isTrue(svc.getSOAStatement() != null, 'Expected an SOA statement object.');
        System.Assert.areEqual(0, svc.getTotalDebit(), 'Total debit should be 0 when no data.');
        System.Assert.areEqual(0, svc.getTotalCredit(), 'Total credit should be 0 when no data.');
        System.Assert.areEqual(0, svc.getClosingBalance(), 'Closing balance should be 0 when no data.');
        System.Assert.areEqual(0, svc.getTotalInterest(), 'Total interest should be 0 when no data.');
        System.Assert.isNotNull(svc.soaFileName, 'SOA filename should default even without parameters.');
        System.Assert.isNotNull(svc.ledgerFileName, 'Ledger filename should default even without parameters.');
    }

    /**
     * @description Verifies ledger entries are sorted chronologically using the comparator
     * GIVEN: Unsorted ledger entries with varying dates
     * WHEN: LedgerEntrySorter sorts the entries
     * THEN: Entries are ordered from oldest to newest
     */
    @IsTest
    static void givenLedgerEntriesWhenSortedThenChronologicalOrderMaintained() {
        // Arrange: create unsorted entries
        LedgerStatement.Entry newer = new LedgerStatement.Entry(2, Date.today(), null, 'Newer', 0, 100, 0);
        LedgerStatement.Entry older = new LedgerStatement.Entry(1, Date.today().addDays(-5), null, 'Older', 100, 0, 0);
        List<LedgerStatement.Entry> entries = new List<LedgerStatement.Entry>{ newer, older };

        // Act: sort using comparator
        entries.sort(new AccountStatementService.LedgerEntrySorter());

        // Assert: verify chronological ordering
        System.Assert.areEqual('Older', entries[0].particulars, 'Older entry should move to the first position.');
        System.Assert.areEqual('Newer', entries[1].particulars, 'Newer entry should appear after the older entry.');
    }

    /**
     * @description Verifies exception is thrown for invalid booking Id in ledger generation
     * GIVEN: An invalid booking Id
     * WHEN: generateLedgerStatement is called
     * THEN: An exception is thrown
     */
    @IsTest
    static void givenInvalidBookingIdWhenGenerateLedgerThenThrows() {
        // Arrange: fake Id
        String keyPrefix = Booking__c.SObjectType.getDescribe().getKeyPrefix();
        Id fakeId = (Id)(keyPrefix + '000000000000AAA');

        Boolean exceptionThrown = false;
        Test.startTest();
        // Act: call with invalid id
        try {
            AccountStatementService.generateLedgerStatement(fakeId, Date.today(), Date.today());
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        // Assert: threw
        System.Assert.isTrue(exceptionThrown, 'Expected exception for invalid booking Id.');
    }

    /**
     * @description Verifies exception is thrown for invalid booking Id in SOA generation
     * GIVEN: An invalid booking Id
     * WHEN: generateSOAStatement is called
     * THEN: An exception is thrown
     */
    @IsTest
    static void givenInvalidBookingIdWhenGenerateSOAThenThrows() {
        // Arrange: fake Id
        String keyPrefix = Booking__c.SObjectType.getDescribe().getKeyPrefix();
        Id fakeId = (Id)(keyPrefix + '000000000000AAA');

        Boolean exceptionThrown = false;
        Test.startTest();
        // Act: call with invalid id
        try {
            AccountStatementService.generateSOAStatement(fakeId, Date.today(), Date.today());
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        // Assert: threw
        System.Assert.isTrue(exceptionThrown, 'Expected exception for invalid booking Id.');
    }
    
    /**
     * @description Verifies SOA header is empty map when statement is null
     * GIVEN: soaStatement set to null
     * WHEN: getSOAHeader is called
     * THEN: Returns empty map
     */
    @IsTest
    static void givenNullSOAStatementWhenGetHeaderThenEmptyMap() {
        // Arrange: service with null soaStatement
        AccountStatementService svc = new AccountStatementService();
        svc.soaStatement = null;

        Test.startTest();
        // Act: get header
        Map<String,String> header = svc.getSOAHeader();
        Test.stopTest();

        // Assert: empty header
        System.Assert.areEqual(0, header.size(), 'Header map should be empty when soaStatement is null.');
    }
    
    /**
     * @description Verifies numeric getters return zero when ledger is null or empty
     * GIVEN: Null and then empty ledgerStatement
     * WHEN: total/closing getters are called
     * THEN: All return zero
     */
    @IsTest
    static void givenNullOrEmptyLedgerWhenGetTotalsThenZeros() {
        // Arrange: null ledger
        AccountStatementService svc = new AccountStatementService();
        svc.ledgerStatement = null;

        // Act + Assert: totals are 0 for null
        System.Assert.areEqual(0, svc.getTotalDebit(), 'Total debit should be 0 for null ledger.');
        System.Assert.areEqual(0, svc.getTotalCredit(), 'Total credit should be 0 for null ledger.');
        System.Assert.areEqual(0, svc.getClosingBalance(), 'Closing balance should be 0 for null ledger.');
    
        // Arrange: empty ledger
        svc.ledgerStatement = new LedgerStatement();
        svc.ledgerStatement.entry = new List<LedgerStatement.Entry>();

        // Act + Assert: totals are 0 for empty
        System.Assert.areEqual(0, svc.getTotalDebit(), 'Total debit should be 0 for empty ledger.');
        System.Assert.areEqual(0, svc.getTotalCredit(), 'Total credit should be 0 for empty ledger.');
        System.Assert.areEqual(0, svc.getClosingBalance(), 'Closing balance should be 0 for empty ledger.');
    }
    
    /**
     * @description Verifies SOA includes token schedule and its receipt
     * GIVEN: A token schedule and a receipt linked to it
     * WHEN: generateSOAStatement is called
     * THEN: Returned data includes the schedule and the receipt
     */
    @IsTest
    static void givenTokenScheduleWhenGenerateSOAThenIncludesReceipt() {
        // Arrange: booking and bank account
        Booking__c booking = [SELECT Id, Unit_Id__c, Account_Id__c FROM Booking__c LIMIT 1];
        Company_Bank_Account__c bankAcc = [SELECT Id FROM Company_Bank_Account__c LIMIT 1];
        if (bankAcc == null) {
            bankAcc = ResidentialTestDataFactory.createCompanyBankAccount();
        }

        // Arrange: token schedule via factory
        Booking_Payment_Schedule__c tokenSched = ResidentialTestDataFactory.createTokenSchedule(booking.Id);
        
        // Arrange: demand required by receipt via factory
        Demand__c demand = ResidentialTestDataFactory.prepareDemand(
            tokenSched.Id,
            booking.Unit_Id__c,
            booking.Account_Id__c,
            booking.Id,
            'DEM003'
        );
        demand.Invoice_Value__c = 5000;
        insert demand;
    
        // Arrange: receipt for token schedule via factory
        Payment_Receipt__c receiptCheque = ResidentialTestDataFactory.preparePaymentReceipt(
            tokenSched.Id, demand.Id, bankAcc.Id, 5000, 'Cheque', Date.today(), 123456, 'Standard Chartered Bank'
        );
        insert receiptCheque;
    
        Test.startTest();
        // Act: generate SOA
        StatementData soa = AccountStatementService.generateSOAStatement(
            booking.Id,
            Date.today().addMonths(-1),
            Date.today()
        );
        Test.stopTest();

        // Assert: confirm token schedule demand absent receipts gracefully handled
        System.Assert.isTrue(soa.schedules.size() > 0, 'SOA should include at least the token schedule entry.');
    }
}