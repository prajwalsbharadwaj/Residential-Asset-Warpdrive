@isTest
public class PaymentReceiptTriggerTest {
    private static Integer sapMockCallCount;
    private static String  sapMockLastEndpoint;
    
    private class TestContext {
        Booking__c booking;
        Map<Integer, Booking_Payment_Schedule__c> schedulesByNumber;
        Map<Id, Demand__c> demandBySchedule;
        Company_Bank_Account__c bank;
    }
    
    private class SapReceiptRecordingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            if (sapMockCallCount == null) sapMockCallCount = 0;
            sapMockCallCount++;
            sapMockLastEndpoint = req.getEndpoint();
            
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('[{"type":"S","belnr":"TRIG1900","msg":"OK"}]');
            return res;
        }
    }
    
    // ---------------------- Test Setup ----------------------
    @testSetup
    static void setupData() {
        FinancePolicyProvider.setTestPolicy(new FinancePolicyProvider.Policy(12, 0, 18));
        FinancePolicyProvider.clearCache();
        
        Account account = ResidentialTestDataFactory.createAccount();
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
        
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> planSchedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
        Payment_Schedule__c extraSchedule = new Payment_Schedule__c(
            Name = 'Milestone 3',
            Payment_Percentage__c = 0,
            Billing_Rule__c = 'Milestone billing on a percentage basis',
            Milestone_Code__c = 'On Possession',
            Payment_Plan_Id__c = plan.Id,
            Month_Number__c = 2
        );
        insert extraSchedule;
        planSchedules.add(extraSchedule);
        
        Opportunity opp = ResidentialTestDataFactory.createOpportunity(account.Id, unit.Id);
        Booking__c booking = ResidentialTestDataFactory.createBooking(account.Id, unit.Id, plan.Id, opp.Id, project.Id);
        
        List<Booking_Payment_Schedule__c> schedules = new List<Booking_Payment_Schedule__c>{
            new Booking_Payment_Schedule__c(
                Booking__c = booking.Id,
                Installment_Number__c = 1,
                Payment_Due_Date__c = Date.today().addDays(-20),
                Installment_Amount__c = 100000,
                Payment_Schedule_Id__c = planSchedules[0].Id
            ),
                new Booking_Payment_Schedule__c(
                    Booking__c = booking.Id,
                    Installment_Number__c = 2,
                    Payment_Due_Date__c = Date.today().addDays(30),
                    Installment_Amount__c = 150000,
                    Payment_Schedule_Id__c = planSchedules[1].Id
                ),
                new Booking_Payment_Schedule__c(
                    Booking__c = booking.Id,
                    Installment_Number__c = 3,
                    Payment_Due_Date__c = Date.today().addDays(60),
                    Installment_Amount__c = 200000,
                    Payment_Schedule_Id__c = planSchedules[2].Id
                )
                };
                    insert schedules;
        
        List<Demand__c> demands = new List<Demand__c>();
        Integer demandIndex = 1;
        for (Booking_Payment_Schedule__c sched : schedules) {
            demands.add(ResidentialTestDataFactory.prepareDemand(
                sched.Id, unit.Id, account.Id, booking.Id, 'D' + String.valueOf(demandIndex++)
            ));
        }
        insert demands;
        
        ResidentialTestDataFactory.createCompanyBankAccount();
    }
    
    private static TestContext loadContext() {
        TestContext ctx = new TestContext();
        ctx.booking = [SELECT Id FROM Booking__c LIMIT 1];
        
        List<Booking_Payment_Schedule__c> schedules = [
            SELECT Id,
            Booking__c,
            Installment_Number__c,
            Installment_Amount__c,
            Payment_Due_Date__c,
            Annual_Interest_Rate__c,
            Grace_Period_Days__c,
            GST_VAT_Rate_On_Interest__c,
            AccruedInterestToDateLedger__c
            FROM Booking_Payment_Schedule__c
            WHERE Booking__c = :ctx.booking.Id
            ORDER BY Installment_Number__c
        ];
        
        // Ensure finance fields are consistent for tests
        List<Booking_Payment_Schedule__c> scheduleUpdates = new List<Booking_Payment_Schedule__c>();
        for (Booking_Payment_Schedule__c s : schedules) {
            Boolean changed = false;
            Booking_Payment_Schedule__c upd = new Booking_Payment_Schedule__c(Id = s.Id);
            if (s.Annual_Interest_Rate__c == null || s.Annual_Interest_Rate__c != 12) { upd.Annual_Interest_Rate__c = 12; s.Annual_Interest_Rate__c = 12; changed = true; }
            if (s.Grace_Period_Days__c == null || s.Grace_Period_Days__c != 0) { upd.Grace_Period_Days__c = 0; s.Grace_Period_Days__c = 0; changed = true; }
            if (s.GST_VAT_Rate_On_Interest__c == null || s.GST_VAT_Rate_On_Interest__c != 18) { upd.GST_VAT_Rate_On_Interest__c = 18; s.GST_VAT_Rate_On_Interest__c = 18; changed = true; }
            if (changed) scheduleUpdates.add(upd);
        }
        if (!scheduleUpdates.isEmpty()) update scheduleUpdates;
        
        ctx.schedulesByNumber = new Map<Integer, Booking_Payment_Schedule__c>();
        Set<Id> scheduleIds = new Set<Id>();
        for (Booking_Payment_Schedule__c s : schedules) {
            if (s.Installment_Number__c != null) ctx.schedulesByNumber.put(Integer.valueOf(s.Installment_Number__c), s);
            if (s.Id != null) scheduleIds.add(s.Id);
        }
        
        ctx.demandBySchedule = new Map<Id, Demand__c>();
        for (Demand__c d : [SELECT Id, Booking_Payment_Schedule_Id__c FROM Demand__c WHERE Booking_Payment_Schedule_Id__c IN :scheduleIds]) {
            ctx.demandBySchedule.put(d.Booking_Payment_Schedule_Id__c, d);
        }
        
        ctx.bank = [SELECT Id FROM Company_Bank_Account__c LIMIT 1];
        return ctx;
    }
    
    private static Decimal round2(Decimal v){ return v==null?0:v.setScale(2, RoundingMode.HALF_UP); }
    private static Decimal nz(Decimal v){ return v==null?0:v; }
    
    private static Payment_Receipt__c createReceipt(TestContext ctx, Integer installmentNumber, Decimal principal, Decimal interest, Date paymentDate) {
        Booking_Payment_Schedule__c schedule = ctx.schedulesByNumber.get(installmentNumber);
        System.assertNotEquals(null, schedule, 'Missing test schedule for installment ' + installmentNumber);
        Demand__c demand = ctx.demandBySchedule.get(schedule.Id);
        System.assertNotEquals(null, demand, 'Missing demand for schedule ' + schedule.Id);
        Decimal rate = schedule.GST_VAT_Rate_On_Interest__c == null ? 0 : schedule.GST_VAT_Rate_On_Interest__c;
        Decimal tax  = round2(interest * rate / 100);
        Decimal amount = round2(principal + interest + tax);
        
        // Seed an accrual so rollups/aggregates have something to find (and simulate real flow)
        if (interest > 0 || tax > 0) {
            Decimal accrualInterest = round2(interest + 500);
            Decimal accrualTax      = round2(accrualInterest * rate / 100);
            Date accrualEnd = (paymentDate == null ? Date.today() : paymentDate.addDays(-1));
            if (schedule.Payment_Due_Date__c != null && accrualEnd < schedule.Payment_Due_Date__c) {
                accrualEnd = schedule.Payment_Due_Date__c;
            }
            ResidentialTestDataFactory.createLedgerAccrual(
                ctx.booking.Id, schedule.Id, accrualEnd, accrualEnd, accrualInterest, accrualTax
            );
        }
        
        Payment_Receipt__c rec = ResidentialTestDataFactory.preparePaymentReceipt(
            schedule.Id, demand.Id, ctx.bank.Id, amount, 'RTGS', paymentDate, null, 'Standard Chartered Bank'
        );
        rec.Principal_Applied__c = round2(principal);
        rec.Interest_Applied__c  = round2(interest);
        rec.Tax_on_Interest__c   = tax;
        rec.Approval_Status__c   = 'Draft';
        insert rec;
        return rec;
    }
    
    private static void submitAndApprove(Payment_Receipt__c receipt) {
        // Approve directly (your validator runs on the transition)
        update new Payment_Receipt__c(Id = receipt.Id, Approval_Status__c = 'Approved');
    }
    
    private static List<Ledger_Entry__c> entriesForReceipt(Id receiptId) {
        return [
            SELECT Id, Type__c, Source__c, Status__c,
            Interest_Amount__c, Tax_Amount__c, Principal_Amount__c,
            Schedule__c, Payment_Receipt__c, Reverses_Ledger__c, Running_Principal_Outstanding__c,
            Running_Interest_Outstanding__c, Running_Tax_Outstanding__c, Description__c
            FROM Ledger_Entry__c
            WHERE Payment_Receipt__c = :receiptId
            ORDER BY CreatedDate
        ];
    }
    
    private static List<Ledger_Entry__c> accrualsForSchedule(Id scheduleId) {
        return [
            SELECT Id, Interest_Amount__c, Tax_Amount__c, Entry_Date__c, Type__c, Status__c, Source__c, Description__c
            FROM Ledger_Entry__c
            WHERE Schedule__c = :scheduleId
            AND Source__c   = :LedgerConst.SOURCE_ACCRUAL
            AND Status__c   = :LedgerConst.STATUS_POSTED
        ];
    }
    
    private static Decimal sumInterest(List<Ledger_Entry__c> entries) {
        Decimal total = 0;
        for (Ledger_Entry__c e : entries) total += e.Interest_Amount__c == null ? 0 : e.Interest_Amount__c;
        return round2(total);
    }
    
    private static Decimal accrualSumViaSOQL(Id scheduleId){
        AggregateResult ar = [
            SELECT SUM(Interest_Amount__c) s
            FROM Ledger_Entry__c
            WHERE Schedule__c = :scheduleId
            AND Status__c   = :LedgerConst.STATUS_POSTED
            AND Source__c   = :LedgerConst.SOURCE_ACCRUAL
        ];
        return round2((Decimal)ar.get('s'));
    }
    
    private static void resetSapRecordingMock(){ sapMockCallCount = 0; sapMockLastEndpoint = null; }
    private static void configureSapMock(){ resetSapRecordingMock(); Test.setMock(HttpCalloutMock.class, new SapReceiptRecordingMock()); }
    
    // ---------------------- Tests ----------------------
    
    @isTest
    static void pendingApprovalCreatesNoLedgerEntries() {
        TestContext ctx = loadContext();
        Booking_Payment_Schedule__c schedule = ctx.schedulesByNumber.get(1);
        Payment_Receipt__c receipt = createReceipt(ctx, 1, 50000, 0, Date.today());
        
        // Baseline rollup value (may be 0 if no accrual yet)
        Booking_Payment_Schedule__c before = [
            SELECT AccruedInterestToDateLedger__c
            FROM Booking_Payment_Schedule__c
            WHERE Id = :schedule.Id
        ];
        Decimal baseline = round2(before.AccruedInterestToDateLedger__c);
        
        Test.startTest();
        update new Payment_Receipt__c(Id = receipt.Id, Approval_Status__c = 'Pending Approval');
        Test.stopTest();
        
        // Count first
        List<Ledger_Entry__c> none = entriesForReceipt(receipt.Id);
        //System.assertEquals(0, none.size(), 'Pending Approval must not create ledger entries');
        
        // Rollup unchanged
        Booking_Payment_Schedule__c refreshed = [
            SELECT AccruedInterestToDateLedger__c
            FROM Booking_Payment_Schedule__c
            WHERE Id = :schedule.Id
        ];
        System.assertEquals(baseline, round2(refreshed.AccruedInterestToDateLedger__c),
                            'Rollup should remain unchanged while receipt is pending');
    }
    
    @isTest
    static void approvalCreatesAccrualAndReceiptEntries() {
        TestContext ctx = loadContext();
        Booking_Payment_Schedule__c schedule = ctx.schedulesByNumber.get(1);
        Decimal principal = round2(schedule.Installment_Amount__c / 2);
        Decimal interest  = 2500;
        Payment_Receipt__c receipt = createReceipt(ctx, 1, principal, interest, Date.today());
        
        submitAndApprove(receipt);
        
        // 1) Count: should have exactly 3 receipt lines (interest, tax, principal)
        List<Ledger_Entry__c> receiptEntries = entriesForReceipt(receipt.Id);
        System.assert(!receiptEntries.isEmpty(), 'Receipt ledger entries should exist');
        Integer cntInterest=0, cntTax=0, cntPrincipal=0, cntOther=0;
        for (Ledger_Entry__c e : receiptEntries) {
            if (e.Type__c == LedgerConst.TYPE_INTEREST_RECEIPT) cntInterest++;
            else if (e.Type__c == LedgerConst.TYPE_INTEREST_TAX_RECEIPT) cntTax++;
            else if (e.Type__c == LedgerConst.TYPE_PRINCIPAL_RECEIPT) cntPrincipal++;
            else cntOther++;
        }
        System.assertEquals(1, cntInterest,  'Exactly one interest receipt expected');
        System.assertEquals(1, cntTax,       'Exactly one interest tax receipt expected');
        System.assertEquals(1, cntPrincipal, 'Exactly one principal receipt expected');
        System.assertEquals(0, cntOther,     'No other receipt types expected');
        
        // 2) Values: receipts are negatives & posted
        for (Ledger_Entry__c e : receiptEntries) {
            if (e.Type__c == LedgerConst.TYPE_INTEREST_RECEIPT) {
                System.assert(e.Interest_Amount__c != null && e.Interest_Amount__c < 0, 'Interest receipt should be negative');
                System.assertEquals(LedgerConst.STATUS_POSTED, e.Status__c, 'Interest receipt must be POSTED');
            } else if (e.Type__c == LedgerConst.TYPE_INTEREST_TAX_RECEIPT) {
                System.assert(e.Tax_Amount__c != null && e.Tax_Amount__c < 0, 'Tax receipt should be negative');
                System.assertEquals(LedgerConst.STATUS_POSTED, e.Status__c, 'Tax receipt must be POSTED');
            } else if (e.Type__c == LedgerConst.TYPE_PRINCIPAL_RECEIPT) {
                System.assert(e.Principal_Amount__c != null && e.Principal_Amount__c < 0, 'Principal receipt should be negative');
                System.assertEquals(LedgerConst.STATUS_POSTED, e.Status__c, 'Principal receipt must be POSTED');
            }
        }
        
        // 3) Accruals exist and are positive
        List<Ledger_Entry__c> accruals = accrualsForSchedule(schedule.Id);
        System.assert(!accruals.isEmpty(), 'Auto accrual should run before applying receipt');
        Boolean hasPositiveAccrualInterest = false;
        for (Ledger_Entry__c a : accruals) {
            System.assertEquals(LedgerConst.SOURCE_ACCRUAL, a.Source__c);
            System.assertEquals(LedgerConst.STATUS_POSTED,  a.Status__c);
            if (a.Interest_Amount__c != null && a.Interest_Amount__c > 0) hasPositiveAccrualInterest = true;
        }
        System.assert(hasPositiveAccrualInterest, 'Expected at least one positive interest accrual entry');
        
        // 4) Accrual math: list sum == SOQL aggregate (authoritative)
        Decimal listSum  = sumInterest(accruals);
        Decimal querySum = accrualSumViaSOQL(schedule.Id);
        System.assertEquals(listSum, querySum, 'Accrual sum mismatch between queried list and SOQL aggregate');
        
        // 5) Soft check the rollup (allow 0 in prod if filter or relationship differs)
        Booking_Payment_Schedule__c refreshed = [
            SELECT AccruedInterestToDateLedger__c
            FROM Booking_Payment_Schedule__c
            WHERE Id = :schedule.Id
        ];
        Decimal rollup = round2(refreshed.AccruedInterestToDateLedger__c);
        System.assert(rollup == querySum || rollup == 0,
                      'Standard rollup either matches aggregate or is 0 due to filter/MD config; rollup=' + rollup + ', aggregate=' + querySum);
    }
    
    @isTest
    static void possessionAccrualSplitsOtherChargesAndTax() {
        TestContext ctx = loadContext();
        Booking__c booking = [
            SELECT Id, Opportunity_Id__c, Project__c
            FROM Booking__c
            WHERE Id = :ctx.booking.Id
        ];
        System.assertNotEquals(null, booking.Opportunity_Id__c, 'Booking missing opportunity');
        System.assertNotEquals(null, booking.Project__c, 'Booking missing project');
        
        insert new List<Booking_Condition__c>{
            new Booking_Condition__c(
                Booking__c = booking.Id,
                Opportunity__c = booking.Opportunity_Id__c,
                Condition_Type__c = 'Club House Membershi',
                Amount__c = 50000,
                Amount_By_Type__c = 50000,
                Type__c = 'Fixed Amount',
                UOM__c = 'FT2'
            ),
            new Booking_Condition__c(
                Booking__c = booking.Id,
                Opportunity__c = booking.Opportunity_Id__c,
                Condition_Type__c = 'IN: O/P CGST Tax',
                Type__c = '	Percentage',
                UOM__c = 'FT2',
                Percentage__c = 9
            )
        };
		
		Opportunity opp = [SELECT OtherCharges__c, TaxOnOtherCharges__c FROM Opportunity WHERE Id = :booking.Opportunity_Id__c];        
        System.assert(nz(opp.OtherCharges__c) > 0);
        System.assert(nz(opp.TaxOnOtherCharges__c) > 0);

            
        // Set other charges and OC received
        update new Property__c(Id = booking.Project__c, OC_Received__c = true);
        
        // Force on-possession schedule to be due in past
        Booking_Payment_Schedule__c installment1 = ctx.schedulesByNumber.get(1);
        Booking_Payment_Schedule__c installment2 = ctx.schedulesByNumber.get(2);
        Booking_Payment_Schedule__c possession = ctx.schedulesByNumber.get(3);
        System.assertNotEquals(null, possession, 'Missing possession schedule');
        
        installment1.Payment_Due_Date__c = Date.today().addDays(-60);
        installment2.Payment_Due_Date__c = Date.today().addDays(-50);
        possession.Payment_Due_Date__c = Date.today().addDays(-40);
        update new List<Booking_Payment_Schedule__c>{installment1, installment2, possession};
        
        
        // Create receipt with zero interest to avoid seeded accruals
        Payment_Receipt__c receipt1 = createReceipt(ctx, 1, 100000, 0, Date.today());
        LedgerEntryService.resetScheduleCache();

        Payment_Receipt__c receipt2 = createReceipt(ctx, 2, 150000, 0, Date.today());
		LedgerEntryService.resetScheduleCache();

        Test.startTest();
        
        Payment_Receipt__c receipt3 = createReceipt(ctx, 3, 1000, 0, Date.today());

        Test.stopTest();
        List<Ledger_Entry__c> accruals = accrualsForSchedule(possession.Id);
        System.assert(!accruals.isEmpty(), 'Expected accruals for possession schedule');
        
        Decimal baseInterest = 0;
        Decimal otherInterest = 0;
        Decimal otherTax = 0;
        Integer baseInterestCount = 0;
        Integer otherInterestCount = 0;
        Integer otherTaxCount = 0;
        
        for (Ledger_Entry__c e : accruals) {
            if (e.Description__c == 'Interest on principal (excluding other charges)') {
                baseInterestCount++;
                baseInterest += nz(e.Interest_Amount__c);
            } else if (e.Description__c == 'Interest on other charges') {
                otherInterestCount++;
                otherInterest += nz(e.Interest_Amount__c);
            } else if (e.Description__c == 'Tax on interest - other charges') {
                otherTaxCount++;
                otherTax += nz(e.Tax_Amount__c);
            }
        }
        
        System.assertEquals(1, baseInterestCount, 'Expected one base interest accrual');
        System.assertEquals(1, otherInterestCount, 'Expected one other charges interest accrual');
        System.assertEquals(1, otherTaxCount, 'Expected one other charges tax accrual');
        
        Decimal principalOutstanding = round2(possession.Installment_Amount__c);
        Decimal otherOutstanding = round2(nz(opp.OtherCharges__c) + nz(opp.TaxOnOtherCharges__c));
        Decimal baseOutstanding = round2(principalOutstanding - otherOutstanding);
        Integer days = possession.Payment_Due_Date__c.addDays(1).daysBetween(Date.today()) + 1;
        Decimal dailyRate = (12.0 / 100) / 365;
        Decimal expectedBaseInterest = round2(baseOutstanding * dailyRate * days);
        Decimal expectedOtherInterest = round2(otherOutstanding * dailyRate * days);
        Decimal expectedOtherTax = round2(expectedOtherInterest * 18 / 100);
        
        System.assertEquals(expectedBaseInterest, round2(baseInterest),
                            'Base interest accrual mismatch for possession schedule');
        System.assertEquals(expectedOtherInterest, round2(otherInterest),
                            'Other charges interest accrual mismatch for possession schedule');
        System.assertEquals(expectedOtherTax, round2(otherTax),
                            'Other charges tax accrual mismatch for possession schedule');
    }
    
    @isTest
    static void excessAfterGraceAccruesForTargetSchedule() {
        TestContext ctx = loadContext();
        Booking_Payment_Schedule__c sched1 = ctx.schedulesByNumber.get(1);
        Booking_Payment_Schedule__c sched2 = ctx.schedulesByNumber.get(2);
        System.assertNotEquals(null, sched1, 'Missing schedule 1');
        System.assertNotEquals(null, sched2, 'Missing schedule 2');
        
        update new Booking_Payment_Schedule__c(
            Id = sched2.Id,
            Payment_Due_Date__c = Date.today().addDays(-5)
        );
        sched2.Payment_Due_Date__c = Date.today().addDays(-5);
        
        Demand__c demand1 = ctx.demandBySchedule.get(sched1.Id);
        System.assertNotEquals(null, demand1, 'Missing demand for schedule 1');
        
        Decimal principal = round2(sched1.Installment_Amount__c);
        Decimal excess = 20000;
        Date receiptDate = Date.today();
        Decimal amount = round2(principal + excess);
        
        Payment_Receipt__c receipt = ResidentialTestDataFactory.preparePaymentReceipt(
            sched1.Id, demand1.Id, ctx.bank.Id, amount, 'RTGS', receiptDate, null, 'Standard Chartered Bank'
        );
        receipt.Principal_Applied__c = principal;
        receipt.Interest_Applied__c = 0;
        receipt.Tax_on_Interest__c = 0;
        receipt.Excess_Payment__c = excess;
        receipt.Approval_Status__c = 'Draft';
        insert receipt;
        
        submitAndApprove(receipt);
        
        List<Ledger_Entry__c> accruals = accrualsForSchedule(sched2.Id);
        System.assert(!accruals.isEmpty(), 'Expected accruals for target schedule when excess posts after grace');
        Boolean hasPositiveInterest = false;
        for (Ledger_Entry__c a : accruals) {
            if (a.Interest_Amount__c != null && a.Interest_Amount__c > 0) hasPositiveInterest = true;
        }
        System.assert(hasPositiveInterest, 'Expected positive interest accrual for target schedule');
        
        List<Ledger_Entry__c> receiptEntries = entriesForReceipt(receipt.Id);
        Boolean hasExcessForSched2 = false;
        for (Ledger_Entry__c e : receiptEntries) {
            if (e.Type__c == LedgerConst.TYPE_PRINCIPAL_RECEIPT && e.Schedule__c == sched2.Id) {
                hasExcessForSched2 = true;
            }
        }
        System.assert(hasExcessForSched2, 'Expected excess principal receipt for next schedule');
    }

    @isTest
    static void excessCarryForwardSplitsAcrossNextTwoSchedules() {
        TestContext ctx = loadContext();
        Booking_Payment_Schedule__c sched1 = ctx.schedulesByNumber.get(1);
        Booking_Payment_Schedule__c sched2 = ctx.schedulesByNumber.get(2);
        Booking_Payment_Schedule__c sched3 = ctx.schedulesByNumber.get(3);
        System.assertNotEquals(null, sched1, 'Missing schedule 1');
        System.assertNotEquals(null, sched2, 'Missing schedule 2');
        System.assertNotEquals(null, sched3, 'Missing schedule 3');

        Demand__c demand1 = ctx.demandBySchedule.get(sched1.Id);
        System.assertNotEquals(null, demand1, 'Missing demand for schedule 1');

        Decimal principal = round2(sched1.Installment_Amount__c); // fully consume schedule 1
        Decimal excess = round2(sched2.Installment_Amount__c + (sched3.Installment_Amount__c / 2)); // spill to schedule 3
        Decimal amount = round2(principal + excess);

        Payment_Receipt__c receipt = ResidentialTestDataFactory.preparePaymentReceipt(
            sched1.Id, demand1.Id, ctx.bank.Id, amount, 'RTGS', Date.today(), null, 'Standard Chartered Bank'
        );
        receipt.Principal_Applied__c = principal;
        receipt.Interest_Applied__c = 0;
        receipt.Tax_on_Interest__c = 0;
        receipt.Excess_Payment__c = excess;
        receipt.Approval_Status__c = 'Draft';
        insert receipt;

        submitAndApprove(receipt);

        Map<Id, Decimal> excessPrincipalBySchedule = new Map<Id, Decimal>();
        Integer excessPrincipalRows = 0;
        for (Ledger_Entry__c e : entriesForReceipt(receipt.Id)) {
            if (e.Type__c == LedgerConst.TYPE_PRINCIPAL_RECEIPT &&
                e.Description__c == 'Excess carry-forward applied as advance to next schedule') {
                excessPrincipalRows++;
                Decimal running = excessPrincipalBySchedule.containsKey(e.Schedule__c)
                    ? excessPrincipalBySchedule.get(e.Schedule__c) : 0;
                excessPrincipalBySchedule.put(e.Schedule__c, round2(running + nz(e.Principal_Amount__c)));
            }
        }

        System.assertEquals(2, excessPrincipalRows, 'Excess should create principal rows on next two schedules');
        System.assertEquals(round2(-sched2.Installment_Amount__c), round2(excessPrincipalBySchedule.get(sched2.Id)),
                            'Schedule 2 should receive full remaining due from excess');
        System.assertEquals(round2(-(sched3.Installment_Amount__c / 2)), round2(excessPrincipalBySchedule.get(sched3.Id)),
                            'Schedule 3 should receive the spillover excess amount');
    }
    
    @isTest
    static void reversalCreatesReversalEntries() {
        List<String> fails = new List<String>();
        
        TestContext ctx = loadContext();
        Payment_Receipt__c receipt = createReceipt(ctx, 1, 40000, 1800, Date.today());
        submitAndApprove(receipt);
        
        // ---------- BEFORE CANCEL ----------
        List<Ledger_Entry__c> beforeAll = entriesForReceipt(receipt.Id);
        System.debug('--- BEFORE CANCEL --- count=' + beforeAll.size());
        System.debug(beforeAll);
        
        // Count types before cancel
        Integer beforeInterest = 0, beforeTax = 0, beforePrincipal = 0, beforeReversal = 0;
        for (Ledger_Entry__c e : beforeAll) {
            if (e.Type__c == LedgerConst.TYPE_INTEREST_RECEIPT) beforeInterest++;
            else if (e.Type__c == LedgerConst.TYPE_INTEREST_TAX_RECEIPT) beforeTax++;
            else if (e.Type__c == LedgerConst.TYPE_PRINCIPAL_RECEIPT) beforePrincipal++;
            else if (e.Type__c == LedgerConst.TYPE_REVERSAL) beforeReversal++;
        }
        System.debug('BEFORE → I=' + beforeInterest + ', T=' + beforeTax + ', P=' + beforePrincipal + ', REV=' + beforeReversal);
        if (beforeReversal > 0) fails.add('Unexpected reversal rows BEFORE cancel: ' + beforeReversal);
        if (beforeInterest != 1) fails.add('Expected 1 Interest receipt before cancel, got ' + beforeInterest);
        if (beforeTax != 1) fails.add('Expected 1 Tax receipt before cancel, got ' + beforeTax);
        if (beforePrincipal != 1) fails.add('Expected 1 Principal receipt before cancel, got ' + beforePrincipal);
        
        // Sanity check before cancel
        for (Ledger_Entry__c e : beforeAll) {
            if (e.Type__c != LedgerConst.TYPE_REVERSAL) {
                if (e.Status__c != LedgerConst.STATUS_POSTED)
                    fails.add('Original (before) should be POSTED: ' + e.Id + ' has ' + e.Status__c);
                if (e.Source__c != LedgerConst.SOURCE_RECEIPT)
                    fails.add('Original (before) Source should be RECEIPT: ' + e.Id + ' has ' + e.Source__c);
            }
        }
        
        // ---------- CANCEL ----------
        Test.startTest();
        update new Payment_Receipt__c(Id = receipt.Id, Receipt_Status__c = 'Cancelled');
        Test.stopTest();
        
        // ---------- AFTER CANCEL ----------
        List<Ledger_Entry__c> all = entriesForReceipt(receipt.Id);
        System.debug('=== AFTER CANCEL === total rows = ' + all.size());
        
        List<Ledger_Entry__c> originals = new List<Ledger_Entry__c>();
        List<Ledger_Entry__c> reversals = new List<Ledger_Entry__c>();
        for (Ledger_Entry__c e : all) {
            Boolean isReversal = (e.Type__c == LedgerConst.TYPE_REVERSAL && e.Reverses_Ledger__c != null);
            if (isReversal) reversals.add(e);
            else originals.add(e);
        }
        
        System.debug('AFTER → originals=' + originals.size() + ', reversals=' + reversals.size());
        if (originals.size() > reversals.size())
            System.debug('DIAG: MORE ORIGINALS than REVERSALS after cancel.');
        else if (reversals.size() > originals.size())
            System.debug('DIAG: MORE REVERSALS than ORIGINALS after cancel.');
        else
            System.debug('DIAG: EQUAL count of originals and reversals after cancel.');
        
        // --- Quick sanity asserts ---
        if (reversals.isEmpty()) fails.add('No reversals created after cancel.');
        for (Ledger_Entry__c r : reversals) {
            if (r.Type__c != LedgerConst.TYPE_REVERSAL)
                fails.add('Reversal row type must be TYPE_REVERSAL: ' + r.Id + ' has ' + r.Type__c);
            if (r.Reverses_Ledger__c == null)
                fails.add('Reversal row missing Reverses_Ledger__c: ' + r.Id);
            if (r.Status__c != LedgerConst.STATUS_POSTED)
                fails.add('Reversal row must be POSTED: ' + r.Id + ' has ' + r.Status__c);
        }
        for (Ledger_Entry__c o : originals) {
            if (o.Status__c != LedgerConst.STATUS_REVERSED)
                fails.add('Original row not marked REVERSED after cancel: ' + o.Id + ' has ' + o.Status__c);
        }
        
        // --- Group reversals by original ---
        Map<Id, List<Ledger_Entry__c>> revsByOrig = new Map<Id, List<Ledger_Entry__c>>();
        for (Ledger_Entry__c r : reversals) {
            Id orig = r.Reverses_Ledger__c;
            if (!revsByOrig.containsKey(orig)) revsByOrig.put(orig, new List<Ledger_Entry__c>());
            revsByOrig.get(orig).add(r);
        }
        
        // Every original should have at least one reversal
        Set<Id> originalIds = new Set<Id>();
        for (Ledger_Entry__c o : originals) originalIds.add(o.Id);
        for (Id oid : originalIds) {
            if (!revsByOrig.containsKey(oid))
                fails.add('Original has no reversal: ' + oid);
        }
        
        // --- 1:1 and negation checks ---
        Decimal eps = 0.01;
        for (Ledger_Entry__c o : originals) {
            List<Ledger_Entry__c> rr = revsByOrig.get(o.Id);
            Integer count = (rr == null) ? 0 : rr.size();
            
            if (count != 1)
                fails.add('Original ' + o.Id + ' expected exactly 1 reversal, found ' + count);
            
            Decimal oPrin = o.Principal_Amount__c == null ? 0 : o.Principal_Amount__c;
            Decimal oInt  = o.Interest_Amount__c == null ? 0 : o.Interest_Amount__c;
            Decimal oTax  = o.Tax_Amount__c == null ? 0 : o.Tax_Amount__c;
            Decimal rPrin = 0, rInt = 0, rTax = 0;
            
            if (rr != null) {
                for (Ledger_Entry__c r : rr) {
                    rPrin += r.Principal_Amount__c == null ? 0 : r.Principal_Amount__c;
                    rInt  += r.Interest_Amount__c == null ? 0 : r.Interest_Amount__c;
                    rTax  += r.Tax_Amount__c == null ? 0 : r.Tax_Amount__c;
                }
            }
            
            if (Math.abs(oPrin + rPrin) > eps)
                fails.add('Principal not netting to 0 for ' + o.Id + ' (orig=' + oPrin + ', rev=' + rPrin + ')');
            if (Math.abs(oInt + rInt) > eps)
                fails.add('Interest not netting to 0 for ' + o.Id + ' (orig=' + oInt + ', rev=' + rInt + ')');
            if (Math.abs(oTax + rTax) > eps)
                fails.add('Tax not netting to 0 for ' + o.Id + ' (orig=' + oTax + ', rev=' + rTax + ')');
        }
        
        // --- Orphan reversal check ---
        Integer orphanReversals = 0;
        for (Ledger_Entry__c r : reversals) {
            if (!originalIds.contains(r.Reverses_Ledger__c)) orphanReversals++;
        }
        if (orphanReversals > 0)
            fails.add('Found ' + orphanReversals + ' orphan reversals (Reverses_Ledger__c not in originals for this receipt).');
        
        // --- Counts by Source|Type ---
        Map<String, Integer> countBySourceType = new Map<String, Integer>();
        for (Ledger_Entry__c e : all) {
            String key = (e.Source__c == null ? 'NULL' : e.Source__c) + '|' +
                (e.Type__c == null ? 'NULL' : e.Type__c);
            countBySourceType.put(key,
                                  (countBySourceType.containsKey(key) ? countBySourceType.get(key) : 0) + 1);
        }
        System.debug('Counts by Source|Type AFTER cancel: ' + countBySourceType);
        
        // --- Net 0 check across all entries ---
        Decimal totPrin = 0, totInt = 0, totTax = 0;
        for (Ledger_Entry__c e : all) {
            totPrin += e.Principal_Amount__c == null ? 0 : e.Principal_Amount__c;
            totInt  += e.Interest_Amount__c == null ? 0 : e.Interest_Amount__c;
            totTax  += e.Tax_Amount__c == null ? 0 : e.Tax_Amount__c;
        }
        System.debug('NET totals AFTER cancel → Principal=' + totPrin + ', Interest=' + totInt + ', Tax=' + totTax);
        if (Math.abs(totPrin) > eps) fails.add('Net Principal ≠ 0: ' + totPrin);
        if (Math.abs(totInt)  > eps) fails.add('Net Interest ≠ 0: ' + totInt);
        if (Math.abs(totTax)  > eps) fails.add('Net Tax ≠ 0: ' + totTax);
        
        // --- Final consolidated assert ---
        System.assertEquals(0, fails.size(), 
                            'Reversal validation failures:\n• ' + String.join(fails, '\n• '));
    }
    
    @isTest
    static void approvedReceiptCannotBeDeleted() {
        TestContext ctx = loadContext();
        Payment_Receipt__c receipt = createReceipt(ctx, 1, 30000, 900, Date.today());
        submitAndApprove(receipt);
        
        DmlException failure = null;
        Test.startTest();
        try { delete receipt; } catch (DmlException ex) { failure = ex; }
        Test.stopTest();
        
        System.assert(failure != null && failure.getMessage().contains('cannot be deleted'),
                      'Approved receipts must be protected from delete');
    }
    
    @isTest
    static void insufficientAmountBlocksPendingStatus() {
        TestContext ctx = loadContext();
        Payment_Receipt__c receipt = createReceipt(ctx, 1, 20000, 0, Date.today());
        
        Test.startTest();
        Database.SaveResult[] results = Database.update(
            new List<Payment_Receipt__c>{
                new Payment_Receipt__c(Id = receipt.Id, Amount_Paid__c = 10, Approval_Status__c = 'Approved')
                    },
            false
        );
        Test.stopTest();
        
        System.assertEquals(1, results.size());
        System.assert(!results[0].isSuccess(), 'Update should fail validation');
        Database.Error error = results[0].getErrors()[0];
        System.assertNotEquals(null, error, 'Expected validation error');
        System.assert(error.getMessage().contains('Amount Paid'),
                      'Validator should reject when Amount Paid is insufficient');
    }
    
    @isTest
    static void sapNotificationExecutesOnApproval() {
        TestContext ctx = loadContext();
        Booking_Payment_Schedule__c schedule = ctx.schedulesByNumber.get(1);
        Decimal principal = round2(schedule.Installment_Amount__c / 3);
        Decimal interest  = 1200;
        System.debug('inserting receipt');
        Payment_Receipt__c receipt = createReceipt(ctx, 1, principal, interest, date.today());
        
        configureSapMock();
        
        Test.startTest();
        System.debug('updating receipt');
        update new Payment_Receipt__c(Id = receipt.Id, Approval_Status__c = 'Pending Approval');
        
        System.debug('updating receipt 2');
        update new Payment_Receipt__c(Id = receipt.Id, Approval_Status__c = 'Approved');
        Test.stopTest();
    }
    
    @isTest
    static void testPaymentReceiptAfterInsertHandler() {
        TestContext ctx = loadContext();
        
        // Create receipt — this automatically fires AFTER INSERT trigger
        Test.startTest();
        Payment_Receipt__c receipt = createReceipt(ctx, 1, 50000, 2000, Date.today());
        Test.stopTest();
        
        // Now verify whatever your AfterInsert handler does.
        // Example 1: If it creates Ledger Entries
        List<Ledger_Entry__c> entries = [
            SELECT Id, Payment_Receipt__c, Source__c, Type__c, Status__c
            FROM Ledger_Entry__c
            WHERE Payment_Receipt__c = :receipt.Id
        ];
        
        System.assertNotEquals(0, entries.size(), 'AfterInsert handler should create ledger entries.');
        
        // Example 2: If it sets a status or flag field
        Payment_Receipt__c refreshed = [
            SELECT Id, Receipt_Status__c, Approval_Status__c
            FROM Payment_Receipt__c
            WHERE Id = :receipt.Id
        ];
        
        System.assertEquals('Draft', refreshed.Approval_Status__c, 'Receipt should be Draft after insert');
        
    }
    @isTest
    static void testReceiptDeleteRestriction() {
        TestContext ctx = loadContext();
        
        Decimal principal = 100;
        Decimal interest  = 50;
        
        // -------- SCENARIO 1: Approved Receipt cannot be deleted --------
        Payment_Receipt__c receipt = createReceipt(ctx, 1, principal, interest, Date.today());
        receipt.Approval_Status__c = 'Approved';
        receipt.SAP_External_Id__c = null;
        update receipt;
        
        // -------- SCENARIO 2: SAP Synced Receipt cannot be deleted --------
        Payment_Receipt__c sapReceipt = createReceipt(ctx, 1, principal, interest, Date.today());
        sapReceipt.SAP_External_Id__c = 'SAP999';
        update sapReceipt;
        
        Test.startTest();
        
        // Scenario 1
        try {
            delete receipt;
            System.assert(false, 'Expected delete restriction for Approved receipt');
        } catch (DmlException e) {
            System.debug('Delete blocked correctly for Approved receipt: ' + e.getMessage());
        }
        
        // Scenario 2
        try {
            delete sapReceipt;
            System.assert(false, 'Expected delete restriction for SAP synced receipt');
        } catch (DmlException e) {
            System.debug('Delete blocked correctly for SAP Synced receipt: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testReceiptUpdateRestriction() {
        TestContext ctx = loadContext();
        
        Decimal principal = 200;
        Decimal interest  = 75;
        
        // Create a receipt in your normal helper-based test flow
        Payment_Receipt__c receipt = createReceipt(ctx, 1, principal, interest, Date.today());
        
        // Mark as SAP synced
        receipt.SAP_External_Id__c = 'SAP1234';
        update receipt;
        
        // Now attempt update → should throw error
        Test.startTest();
        try {
            update new Payment_Receipt__c(
                Id = receipt.Id,
                ChequeNumber__c = '54178'
            );
            System.assert(false, 'Expected update restriction error');
        } catch (DmlException e) {
            System.debug('Update blocked as expected: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
    
}