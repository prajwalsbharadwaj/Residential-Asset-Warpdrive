@IsTest
private class LedgerEntryServiceExcessReversalTest {
    @IsTest
    static void excessGoesToNextScheduleWhenCurrentNetOutstandingIsZero() {
        Account acc = ResidentialTestDataFactory.createAccount();
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan(false);
        

        List<Payment_Schedule__c> masterSchedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id, false);
        Payment_Schedule__c ps3 = new Payment_Schedule__c(
            Name = 'Milestone 3',
            Payment_Percentage__c = 0,
            Billing_Rule__c = 'Milestone billing on a percentage basis',
            Milestone_Code__c = 'On Possession',
            Payment_Plan_Id__c = plan.Id,
            Month_Number__c = 2
        );
        masterSchedules.add(ps3);

        masterSchedules[0].Milestone_Code__c = 'On Booking Amount';
        masterSchedules[1].Milestone_Code__c = 'On Installment 1';
        insert masterSchedules;

        plan.Active__c = true;
        plan.Approval_Status__c = 'Approved';
        update plan;

        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, project.Id);

        List<Booking_Payment_Schedule__c> schedules = ResidentialTestDataFactory.createBookingPaymentSchedules(
            booking.Id, masterSchedules
        );

        schedules[0].Payment_Due_Date__c = Date.newInstance(2025, 12, 12);
        schedules[0].Installment_Amount__c = 5449921;
        schedules[1].Payment_Due_Date__c = Date.newInstance(2025, 12, 27);
        schedules[1].Installment_Amount__c = 10899841;
        schedules[2].Payment_Due_Date__c = Date.newInstance(2026, 1, 26);
        schedules[2].Installment_Amount__c = 39649143;
        for (Booking_Payment_Schedule__c s : schedules) {
            s.Annual_Interest_Rate__c = 10;
            s.Grace_Period_Days__c = 15;
            s.GST_VAT_Rate_On_Interest__c = 18;
        }
        update schedules;

        Demand__c d1 = ResidentialTestDataFactory.prepareDemand(schedules[0].Id, unit.Id, acc.Id, booking.Id, 'DEM-S1');
        Demand__c d2 = ResidentialTestDataFactory.prepareDemand(schedules[1].Id, unit.Id, acc.Id, booking.Id, 'DEM-S2');
        insert new List<Demand__c>{ d1, d2 };

        Company_Bank_Account__c cba = ResidentialTestDataFactory.createCompanyBankAccount();

        Payment_Receipt__c receipt1 = ResidentialTestDataFactory.preparePaymentReceipt(
            schedules[0].Id, d1.Id, cba.Id, 5449921, 'RTGS', Date.newInstance(2025, 12, 1), null, 'State Bank of India'
        );
        receipt1.Principal_Applied__c = 5449921;
        receipt1.Interest_Applied__c = 0;
        receipt1.Tax_on_Interest__c = 0;
        insert receipt1;

        receipt1.Receipt_Status__c = 'Bounced';
        update receipt1;

        List<Ledger_Entry__c> receipt1Entries = [
            SELECT Id, Type__c, Status__c, Principal_Amount__c, Reverses_Ledger__c
            FROM Ledger_Entry__c
            WHERE Payment_Receipt__c = :receipt1.Id
        ];
        Ledger_Entry__c reversedEntry;
        Ledger_Entry__c reversalEntry;
        for (Ledger_Entry__c entry : receipt1Entries) {
            if (entry.Type__c == LedgerConst.TYPE_PRINCIPAL_RECEIPT
                && entry.Status__c == LedgerConst.STATUS_REVERSED
                && entry.Principal_Amount__c == -5449921) {
                reversedEntry = entry;
            }
            if (entry.Type__c == LedgerConst.TYPE_REVERSAL
                && entry.Status__c == LedgerConst.STATUS_POSTED
                && entry.Principal_Amount__c == 5449921) {
                reversalEntry = entry;
            }
        }
        System.Assert.areNotEqual(null, reversedEntry, 'Expected original principal receipt to be marked REVERSED.');
        System.Assert.areNotEqual(null, reversalEntry, 'Expected a POSTED reversal entry for the receipt.');
        System.Assert.areEqual(reversedEntry.Id, reversalEntry.Reverses_Ledger__c,
            'Reversal entry should point back to the reversed receipt entry.');

        Payment_Receipt__c receipt = ResidentialTestDataFactory.preparePaymentReceipt(
            schedules[0].Id, d1.Id, cba.Id, 5600000, 'RTGS', Date.newInstance(2025, 12, 29), null, 'State Bank of India'
        );
        receipt.Principal_Applied__c = 5449921;
        receipt.Interest_Applied__c = 0;
        receipt.Tax_on_Interest__c = 0;
        receipt.Excess_Payment__c = 150079;
        insert receipt;

        List<Ledger_Entry__c> receiptEntries = [
            SELECT Id, Schedule__c, Principal_Amount__c, Description__c, Type__c
            FROM Ledger_Entry__c
            WHERE Payment_Receipt__c = :receipt.Id
              AND Type__c = :LedgerConst.TYPE_PRINCIPAL_RECEIPT
        ];

        System.Assert.areEqual(2, receiptEntries.size(), 'Expected one principal receipt and one excess receipt entry.');

        Ledger_Entry__c excessEntry;
        for (Ledger_Entry__c entry : receiptEntries) {
            if (entry.Schedule__c == schedules[1].Id && entry.Principal_Amount__c == -150079) {
                excessEntry = entry;
                break;
            }
        }
        System.Assert.areNotEqual(null, excessEntry, 'Excess entry should be applied to the next schedule.');
        System.Assert.areEqual(-150079, excessEntry.Principal_Amount__c,
            'Excess principal should be recorded as a negative receipt on the target schedule.');
        System.Assert.areEqual('Excess carry-forward applied as advance to next schedule', excessEntry.Description__c);
    }
}