@IsTest
public class BookingLedgerRecalcControllerTest {
    @TestSetup
    static void setupData() {
        FinancePolicyProvider.setTestPolicy(new FinancePolicyProvider.Policy(12, 0, 18));
        FinancePolicyProvider.clearCache();

        Account acc = ResidentialTestDataFactory.createAccount();
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        Booking__c booking = ResidentialTestDataFactory.createBooking(
            acc.Id,
            unit.Id,
            plan.Id,
            opp.Id,
            project.Id
        );
        List<Booking_Payment_Schedule__c> bpsList =
            ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, opp.Id, schedules);

        ensureFinanceFields(bpsList);

        Demand__c demand = ResidentialTestDataFactory.prepareDemand(
            bpsList[0].Id,
            unit.Id,
            acc.Id,
            booking.Id,
            'D1'
        );
        insert demand;

        Company_Bank_Account__c bank = ResidentialTestDataFactory.createCompanyBankAccount();

        Payment_Receipt__c receipt = ResidentialTestDataFactory.preparePaymentReceipt(
            bpsList[0].Id,
            demand.Id,
            bank.Id,
            50000,
            'RTGS',
            Date.today(),
            null,
            'Standard Chartered Bank'
        );
        receipt.Principal_Applied__c = 50000;
        receipt.Interest_Applied__c = 0;
        receipt.Tax_on_Interest__c = 0;
        receipt.Approval_Status__c = 'Draft';
        insert receipt;

        User adminUser = new User(
            FirstName = 'Admin',
            Alias = 'admnu',
            Email = 'admin.user@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1].Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'admin.user.' + String.valueOf(DateTime.now().getTime()) + '@example.com'
        );
        insert adminUser;
    }

    @IsTest
    static void startRecalculation_noAccess_throws() {
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        User adminUser = [SELECT Id FROM User WHERE Alias = 'admnu' LIMIT 1];
        System.runAs(adminUser) {
            BookingLedgerRecalcController.bypassAccessCheck = false;
            Test.startTest();
            try {
                BookingLedgerRecalcController.startRecalculation(booking.Id);
                System.assert(false, 'Expected exception for missing permission.');
            } catch (Exception e) {
                System.assert(e instanceof AuraHandledException, 'Unexpected exception: ' + e);
            } finally {
                Test.stopTest();
                BookingLedgerRecalcController.bypassAccessCheck = false;
            }
        }
    }

    @IsTest
    static void startRecalculation_interestWaiver_throws() {
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        Booking_Payment_Schedule__c bps = [SELECT Id FROM Booking_Payment_Schedule__c LIMIT 1];
        User adminUser = [SELECT Id FROM User WHERE Alias = 'admnu' LIMIT 1];

        Ledger_Entry__c waiver = new Ledger_Entry__c(
            Booking__c = booking.Id,
            Schedule__c = bps.Id,
            Entry_Date__c = Date.today(),
            Period_Start__c = Date.today(),
            Period_End__c = Date.today(),
            Type__c = LedgerConst.TYPE_INTEREST_WAIVER,
            Bucket__c = LedgerConst.BUCKET_BASIC,
            Source__c = LedgerConst.SOURCE_ACCRUAL,
            Status__c = LedgerConst.STATUS_POSTED
        );
        insert waiver;

        System.runAs(adminUser) {
            BookingLedgerRecalcController.bypassAccessCheck = true;
            Test.startTest();
            try {
                BookingLedgerRecalcController.startRecalculation(booking.Id);
                System.assert(false, 'Expected exception for interest waiver.');
            } catch (Exception e) {
                System.assert(e instanceof AuraHandledException, 'Unexpected exception: ' + e);
            } finally {
                Test.stopTest();
                BookingLedgerRecalcController.bypassAccessCheck = false;
            }
        }
    }

    @IsTest
    static void startRecalculation_and_processReceipt_rebuilds() {
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        Booking_Payment_Schedule__c bps = [SELECT Id FROM Booking_Payment_Schedule__c LIMIT 1];
        Payment_Receipt__c receipt = [SELECT Id FROM Payment_Receipt__c LIMIT 1];
        User adminUser = [SELECT Id FROM User WHERE Alias = 'admnu' LIMIT 1];

        ResidentialTestDataFactory.createLedgerAccrual(
            booking.Id,
            bps.Id,
            Date.today(),
            Date.today(),
            100,
            0
        );

        BookingLedgerRecalcController.StartResult result;
        Integer deletedCount;
        System.runAs(adminUser) {
            BookingLedgerRecalcController.bypassAccessCheck = true;
            try {
                Test.startTest();
                result = BookingLedgerRecalcController.startRecalculation(booking.Id);
                deletedCount = [SELECT COUNT() FROM Ledger_Entry__c WHERE Booking__c = :booking.Id];
                BookingLedgerRecalcController.processReceipt(booking.Id, receipt.Id);
            } finally {
                Test.stopTest();
                BookingLedgerRecalcController.bypassAccessCheck = false;
            }
        }

        System.assertEquals(1, result.receiptIds.size(), 'Expected one receipt for recalculation.');
        System.assertEquals(
            0,
            deletedCount,
            'Ledger entries should be deleted at start.'
        );
        System.assert(
            [SELECT COUNT() FROM Ledger_Entry__c WHERE Booking__c = :booking.Id] > 0,
            'Ledger entries should be recreated.'
        );
    }

    private static void ensureFinanceFields(List<Booking_Payment_Schedule__c> schedules) {
        if (schedules == null || schedules.isEmpty()) return;
        List<Booking_Payment_Schedule__c> updates = new List<Booking_Payment_Schedule__c>();
        for (Booking_Payment_Schedule__c s : schedules) {
            Boolean changed = false;
            Booking_Payment_Schedule__c upd = new Booking_Payment_Schedule__c(Id = s.Id);
            if (s.Annual_Interest_Rate__c == null || s.Annual_Interest_Rate__c != 12) {
                upd.Annual_Interest_Rate__c = 12;
                changed = true;
            }
            if (s.Grace_Period_Days__c == null || s.Grace_Period_Days__c != 0) {
                upd.Grace_Period_Days__c = 0;
                changed = true;
            }
            if (s.GST_VAT_Rate_On_Interest__c == null || s.GST_VAT_Rate_On_Interest__c != 18) {
                upd.GST_VAT_Rate_On_Interest__c = 18;
                changed = true;
            }
            if (changed) updates.add(upd);
        }
        if (!updates.isEmpty()) update updates;
    }
}