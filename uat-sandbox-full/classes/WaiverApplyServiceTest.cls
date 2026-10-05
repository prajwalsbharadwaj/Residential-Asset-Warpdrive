@IsTest
private class WaiverApplyServiceTest {

    // ========= Test scaffolding =========

    private class TestContext {
        Account acc;
        Property__c project;
        Tower__c tower;
        Floor__c floor;
        Unit__c unit;
        Payment_Plan__c plan;
        List<Payment_Schedule__c> planScheds;
        Opportunity opp;
        Booking__c booking;
        Booking_Payment_Schedule__c s1;
        Booking_Payment_Schedule__c s2;
        List<Demand__c> demands;
        Company_Bank_Account__c bank;
    }

    private class SapReceiptRecordingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.debug('===WaiverLogs=== HttpCalloutMock hit: ' + req.getEndpoint());
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('[{"type":"S","belnr":"TRIG1900","msg":"OK"}]');
            return res;
        }
    }

    private static Integer demandIdx = 1;

    // ======= Utilities / Diagnostics =======

    private static Decimal nz(Decimal d){ return d == null ? 0 : d; }

    private static Company_Bank_Account__c createUniqueBankAccount() {
        Company_Bank_Account__c bank = ResidentialTestDataFactory.prepareCompanyBankAccount();
        Integer rnd = Math.mod(Math.abs(Crypto.getRandomInteger()), 1000);
        String suffix = String.valueOf(rnd).leftPad(3, '0');
        bank.Name = 'ACC-' + suffix;
        bank.House_Bank_Id__c = 'HB' + suffix;
        bank.Company_Name__c = '2050';
        insert bank;
        return bank;
    }

    private class CountKey {
        Id schedId; String source; String type; String status;
        CountKey(Id s, String so, String t, String st){ schedId = s; source = so; type = t; status = st; }
        public Boolean equals(Object o){
            CountKey k = (CountKey)o;
            return schedId == k.schedId && source == k.source && type == k.type && status == k.status;
        }
        public Integer hashCode(){
            return (String.valueOf(schedId) + '|' + source + '|' + type + '|' + status).hashCode();
        }
    }

    private static Map<CountKey,Integer> countLedgerByKey(Set<Id> scheduleIds){
        Map<CountKey,Integer> out = new Map<CountKey,Integer>();
        if (scheduleIds == null || scheduleIds.isEmpty()) return out;
        for (AggregateResult ar : [
            SELECT Schedule__c s, Source__c so, Type__c t, Status__c st, COUNT(Id) c
            FROM Ledger_Entry__c
            WHERE Schedule__c IN :scheduleIds
            GROUP BY Schedule__c, Source__c, Type__c, Status__c
        ]){
            CountKey key = new CountKey(
                (Id)ar.get('s'),
                (String)ar.get('so'),
                (String)ar.get('t'),
                (String)ar.get('st')
            );
            out.put(key, (Integer)ar.get('c'));
        }
        return out;
    }

    private static Integer getCount(Map<CountKey,Integer> m, Id s, String so, String t, String st){
        CountKey key = new CountKey(s, so, t, st);
        return m.containsKey(key) ? m.get(key) : 0;
    }

    private static void dumpLedgerMatrix(Id bookingId) {
        System.debug('===WaiverLogs=== LEDGER MATRIX for booking ' + bookingId);
        for (AggregateResult ar : [
            SELECT Status__c st, Source__c so, Type__c ty, COUNT(Id) c
            FROM Ledger_Entry__c
            WHERE Booking__c = :bookingId
            GROUP BY Status__c, Source__c, Type__c
            ORDER BY Status__c, Source__c, Type__c
        ]) {
            System.debug('===WaiverLogs=== • Status=' + (String)ar.get('st') +
                         ', Source=' + (String)ar.get('so') +
                         ', Type='   + (String)ar.get('ty') +
                         ' => count=' + (Integer)ar.get('c'));
        }
    }

    // Sum of posted accrual interest by schedule (truth for “accrued”)
    private static Map<Id, Decimal> postedAccrualInterestBySchedule(Set<Id> schedIds) {
        Map<Id, Decimal> out = new Map<Id, Decimal>();
        if (schedIds.isEmpty()) return out;
        for (AggregateResult ar : [
            SELECT Schedule__c sid, SUM(Interest_Amount__c) s
            FROM Ledger_Entry__c
            WHERE Schedule__c IN :schedIds
              AND Status__c   = :LedgerConst.STATUS_POSTED
              AND Source__c   = :LedgerConst.SOURCE_ACCRUAL
            GROUP BY Schedule__c
        ]) {
            out.put((Id)ar.get('sid'), (Decimal)ar.get('s'));
        }
        return out;
    }

    // Sum of posted waiver interest (negative) by schedule (truth for “waived”)
    private static Map<Id, Decimal> postedWaiverInterestBySchedule(Set<Id> schedIds) {
        Map<Id, Decimal> out = new Map<Id, Decimal>();
        if (schedIds.isEmpty()) return out;
        for (AggregateResult ar : [
            SELECT Schedule__c sid, SUM(Interest_Amount__c) s
            FROM Ledger_Entry__c
            WHERE Schedule__c IN :schedIds
              AND Status__c   = :LedgerConst.STATUS_POSTED
              AND Type__c     = :LedgerConst.TYPE_INTEREST_WAIVER
            GROUP BY Schedule__c
        ]) {
            out.put((Id)ar.get('sid'), (Decimal)ar.get('s'));
        }
        return out;
    }

    private static List<Ledger_Entry__c> waiverRows(Id bookingId){
        return [
            SELECT Id, Schedule__c, Type__c, Status__c, Interest_Amount__c, Tax_Amount__c
            FROM Ledger_Entry__c
            WHERE Booking__c = :bookingId
              AND Status__c  = :LedgerConst.STATUS_POSTED
              AND Type__c IN :new List<String>{
                  LedgerConst.TYPE_INTEREST_WAIVER, LedgerConst.TYPE_INTEREST_TAX_WAIVER
              }
            ORDER BY Schedule__c, Type__c, Id
        ];
    }

    private static void assertNoErrorLogsAndDumpIfAny(Id bookingId){
        List<Error_Log__c> logs = [
            SELECT Id, Name, Error_Message__c, Triggered_From__c, Status_Code__c, Error_Type__c
            FROM Error_Log__c
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
        if (!logs.isEmpty()){
            for (Error_Log__c l : logs){
                System.debug('===WaiverLogs=== ERROR LOG -> Id=' + l.Id +
                             ', Name=' + l.Name +
                             ', From=' + l.Triggered_From__c +
                             ', Type=' + l.Error_Type__c +
                             ', Code=' + l.Status_Code__c +
                             ', Msg='  + l.Error_Message__c);
            }
        }
        System.assertEquals(0, logs.size(), 'No Error_Log__c rows should be created during waiver processing.');
    }

    // ========= Test data setup =========

    private static TestContext createContext() {
        System.debug('===WaiverLogs=== START createContext');
        Test.setMock(HttpCalloutMock.class, new SapReceiptRecordingMock());

        TestContext ctx = new TestContext();

        ctx.acc     = ResidentialTestDataFactory.createAccount();
        ctx.project = ResidentialTestDataFactory.createProject();
        ctx.tower   = ResidentialTestDataFactory.createTower(ctx.project.Id);
        ctx.floor   = ResidentialTestDataFactory.createFloor(ctx.project.Id, ctx.tower.Id);
        ctx.unit    = ResidentialTestDataFactory.createUnit(ctx.project.Id, ctx.tower.Id, ctx.floor.Id);

        ctx.plan       = ResidentialTestDataFactory.createPaymentPlan();
        ctx.planScheds = ResidentialTestDataFactory.createPaymentSchedules(ctx.plan.Id);

        ctx.opp     = ResidentialTestDataFactory.createOpportunity(ctx.acc.Id, ctx.unit.Id);
        ctx.booking = ResidentialTestDataFactory.createBooking(ctx.acc.Id, ctx.unit.Id, ctx.plan.Id, ctx.opp.Id, ctx.project.Id);

        List<Booking_Payment_Schedule__c> created = ResidentialTestDataFactory.createBookingPaymentSchedules(ctx.booking.Id, ctx.opp.Id, ctx.planScheds);
        List<Booking_Payment_Schedule__c> schedules = [
            SELECT Id, Booking__c, Payment_Due_Date__c,
                   AccruedInterestToDateLedger__c, Interest_Received__c, Interest_Waived__c,
                   Annual_Interest_Rate__c, Grace_Period_Days__c, GST_VAT_Rate_On_Interest__c
            FROM Booking_Payment_Schedule__c
            WHERE Id IN :created
            ORDER BY Payment_Due_Date__c ASC, Id ASC
        ];
        System.assert(schedules.size() >= 2, 'Factory must create at least 2 schedules');

        ctx.s1 = schedules[0];
        ctx.s2 = schedules[1];

        // Finance knobs
        ctx.s1.Payment_Due_Date__c = Date.today().addDays(1);
        ctx.s2.Payment_Due_Date__c = Date.today().addDays(2);
        ctx.s1.Annual_Interest_Rate__c = 12;
        ctx.s2.Annual_Interest_Rate__c = 12;
        ctx.s1.Grace_Period_Days__c = 0;
        ctx.s2.Grace_Period_Days__c = 0;
        ctx.s1.GST_VAT_Rate_On_Interest__c = 18;
        ctx.s2.GST_VAT_Rate_On_Interest__c = 18;
        ctx.s1.Interest_Waived__c = 0;
        ctx.s2.Interest_Waived__c = 0;
        update new List<Booking_Payment_Schedule__c>{ ctx.s1, ctx.s2 };

        // Demands
        ctx.demands = new List<Demand__c>();
        for (Booking_Payment_Schedule__c sched : new List<Booking_Payment_Schedule__c>{ ctx.s1, ctx.s2 }) {
            ctx.demands.add(new Demand__c(
                Booking_Payment_Schedule_Id__c = sched.Id,
                Booking_Id__c = ctx.booking.Id,
                Unit__c = ctx.unit.Id,
                Account__c = ctx.acc.Id,
                SAP_External_Id__c = 'DEM-' + demandIdx++
            ));
        }
        insert ctx.demands;

        // Accruals (POSTED/ACCRUAL)
        Date accrualDate = Date.today().addDays(-3);
        for (Booking_Payment_Schedule__c sched : new List<Booking_Payment_Schedule__c>{ ctx.s1, ctx.s2 }) {
            ResidentialTestDataFactory.createLedgerAccrual(
                ctx.booking.Id, sched.Id, accrualDate, accrualDate, 200, 36
            );
        }

        // Receipt (POSTED interest+tax)
        ctx.bank = createUniqueBankAccount();
        Payment_Receipt__c receipt = new Payment_Receipt__c(
            Booking_Payment_Schedule__c = ctx.s1.Id,
            Demand__c = ctx.demands[0].Id,
            Amount_Paid__c = 500,
            Date_Of_Payment__c = Date.today().addDays(-1),
            Principal_Applied__c = 0,
            Interest_Applied__c = 50,
            Tax_on_Interest__c = 9,
            Company_Bank_Account__c = ctx.bank.Id,
            Mode_Of_Payment__c = 'RTGS',
            Customer_Bank_Name__c = 'AXIS Bank'
        );
        insert receipt;
        update new Payment_Receipt__c(Id = receipt.Id, Approval_Status__c = 'Approved');

        // Refresh schedules
        schedules = [
            SELECT Id, Booking__c, AccruedInterestToDateLedger__c, Interest_Received__c, Interest_Waived__c
            FROM Booking_Payment_Schedule__c
            WHERE Id IN :new List<Id>{ ctx.s1.Id, ctx.s2.Id }
        ];
        ctx.s1 = schedules[0];
        ctx.s2 = schedules[1];

        // Verify prerequisites by **counts** (don’t depend on rollups)
        Map<CountKey,Integer> tallies = countLedgerByKey(new Set<Id>{ ctx.s1.Id, ctx.s2.Id });
        Integer acc1 = getCount(tallies, ctx.s1.Id, LedgerConst.SOURCE_ACCRUAL, LedgerConst.TYPE_INTEREST_ACCRUAL_BASIC, LedgerConst.STATUS_POSTED)
                     + getCount(tallies, ctx.s1.Id, LedgerConst.SOURCE_ACCRUAL, LedgerConst.TYPE_INTEREST_ACCRUAL_OTHER, LedgerConst.STATUS_POSTED);
        Integer acc2 = getCount(tallies, ctx.s2.Id, LedgerConst.SOURCE_ACCRUAL, LedgerConst.TYPE_INTEREST_ACCRUAL_BASIC, LedgerConst.STATUS_POSTED)
                     + getCount(tallies, ctx.s2.Id, LedgerConst.SOURCE_ACCRUAL, LedgerConst.TYPE_INTEREST_ACCRUAL_OTHER, LedgerConst.STATUS_POSTED);
        Integer rInt1 = getCount(tallies, ctx.s1.Id, LedgerConst.SOURCE_RECEIPT, LedgerConst.TYPE_INTEREST_RECEIPT, LedgerConst.STATUS_POSTED);
        Integer rTax1 = getCount(tallies, ctx.s1.Id, LedgerConst.SOURCE_RECEIPT, LedgerConst.TYPE_INTEREST_TAX_RECEIPT, LedgerConst.STATUS_POSTED);
        System.debug('===WaiverLogs=== Posted accrual count s1=' + acc1 + ', s2=' + acc2);
        System.debug('===WaiverLogs=== Posted receipt count s1 (interest,tax)=(' + rInt1 + ',' + rTax1 + ')');
        System.assertEquals(1, rInt1, 'Expect 1 interest receipt for s1');
        System.assertEquals(1, rTax1, 'Expect 1 tax receipt for s1');
        System.assert(acc1 > 0 && acc2 > 0, 'Expect accruals on both schedules');

        dumpLedgerMatrix(ctx.booking.Id);
        System.debug('===WaiverLogs=== END createContext');

        return ctx;
    }

    private static void assertFieldEqualsLedger(Id sId, Decimal fieldWaived, Map<Id, Decimal> waiverSums){
        Decimal ledgerSum = nz(waiverSums.get(sId)); // negative
        Decimal expectedField = -ledgerSum;          // field should store positive waived
        System.debug('===WaiverLogs=== Field vs Ledger check for ' + sId +
                     ' -> field=' + fieldWaived + ', ledgerSum=' + ledgerSum +
                     ', expectedField=' + expectedField);
        System.assertEquals(expectedField, fieldWaived,
            'Interest_Waived__c must equal absolute sum of posted waiver interest rows for the schedule.');
    }

    private static void assertPostedWaivers(Id bookingId, Id s1, Id s2, Integer expectedRowsTotal){
        List<Ledger_Entry__c> rows = waiverRows(bookingId);
        System.debug('===WaiverLogs=== Waiver rows count=' + rows.size());
        for (Ledger_Entry__c le : rows){
            System.debug('===WaiverLogs=== WAIVER ROW -> Id=' + le.Id + ', Sch=' + le.Schedule__c +
                         ', Type=' + le.Type__c + ', Int=' + le.Interest_Amount__c +
                         ', Tax=' + le.Tax_Amount__c + ', Status=' + le.Status__c);
        }
        System.assertEquals(expectedRowsTotal, rows.size(), 'Expected total posted waiver rows mismatch.');

        Integer s1Int = 0, s1Tax = 0, s2Int = 0, s2Tax = 0;
        for (Ledger_Entry__c le : rows){
            System.assertEquals(LedgerConst.STATUS_POSTED, le.Status__c, 'Waiver row must be POSTED');
            if (le.Schedule__c == s1){
                if (le.Type__c == LedgerConst.TYPE_INTEREST_WAIVER) s1Int++;
                if (le.Type__c == LedgerConst.TYPE_INTEREST_TAX_WAIVER) s1Tax++;
            } else if (le.Schedule__c == s2){
                if (le.Type__c == LedgerConst.TYPE_INTEREST_WAIVER) s2Int++;
                if (le.Type__c == LedgerConst.TYPE_INTEREST_TAX_WAIVER) s2Tax++;
            }
        }
        if (s1 != null) System.assert(s1Int > 0 && s1Tax > 0, 's1 must have both waiver rows');
        if (s2 != null) System.assert(s2Int > 0 && s2Tax > 0, 's2 must have both waiver rows');
    }

    // ========= TESTS =========

    @IsTest
    static void testServiceDirectInvocation() {
        System.debug('===WaiverLogs=== START testServiceDirectInvocation');
        TestContext ctx = createContext();

        // Service path (bypasses trigger)
        insert new Interest_Waiver_Request__c(
            Booking__c = ctx.booking.Id,
            Waiver_Amount__c = 300,
            Status__c = 'Approved'
        );

        Test.startTest();
        WaiverApplyService.applyForBookings(new Set<Id>{ ctx.booking.Id });
        Test.stopTest();

        // Validate rows & schedule fields
        assertPostedWaivers(ctx.booking.Id, ctx.s1.Id, ctx.s2.Id, 4);

        Map<Id, Booking_Payment_Schedule__c> sch = new Map<Id, Booking_Payment_Schedule__c>([
            SELECT Id, Interest_Waived__c
            FROM Booking_Payment_Schedule__c
            WHERE Id IN :new List<Id>{ ctx.s1.Id, ctx.s2.Id }
        ]);

        // Cross-check field vs ledger (to detect double-writing by other automation)
        Map<Id, Decimal> waiverSums = postedWaiverInterestBySchedule(new Set<Id>{ ctx.s1.Id, ctx.s2.Id });
        assertFieldEqualsLedger(ctx.s1.Id, sch.get(ctx.s1.Id).Interest_Waived__c, waiverSums);
        assertFieldEqualsLedger(ctx.s2.Id, sch.get(ctx.s2.Id).Interest_Waived__c, waiverSums);

        // Expected business outcome
        System.assertEquals(150, sch.get(ctx.s1.Id).Interest_Waived__c, 's1 waived should be 150 after service call');
        System.assertEquals(150, sch.get(ctx.s2.Id).Interest_Waived__c, 's2 waived should be 150 after service call');

        assertNoErrorLogsAndDumpIfAny(ctx.booking.Id);
    }

    @IsTest
    static void testTriggerAppliesWaiverAndCreatesLedgerEntries() {
        System.debug('===WaiverLogs=== START testTriggerAppliesWaiverAndCreatesLedgerEntries');
        TestContext ctx = createContext();

        Interest_Waiver_Request__c request = new Interest_Waiver_Request__c(
            Booking__c = ctx.booking.Id, Waiver_Amount__c = 300, Status__c = 'Draft'
        );
        insert request;

        Test.startTest();
        request.Status__c = 'Approved';
        update request;
        Test.stopTest();

        assertPostedWaivers(ctx.booking.Id, ctx.s1.Id, ctx.s2.Id, 4);

        Map<Id, Booking_Payment_Schedule__c> sch = new Map<Id, Booking_Payment_Schedule__c>([
            SELECT Id, Interest_Waived__c
            FROM Booking_Payment_Schedule__c
            WHERE Id IN :new List<Id>{ ctx.s1.Id, ctx.s2.Id }
        ]);

        Map<Id, Decimal> waiverSums = postedWaiverInterestBySchedule(new Set<Id>{ ctx.s1.Id, ctx.s2.Id });
        assertFieldEqualsLedger(ctx.s1.Id, sch.get(ctx.s1.Id).Interest_Waived__c, waiverSums);
        assertFieldEqualsLedger(ctx.s2.Id, sch.get(ctx.s2.Id).Interest_Waived__c, waiverSums);

        System.assertEquals(150, sch.get(ctx.s1.Id).Interest_Waived__c);
        System.assertEquals(150, sch.get(ctx.s2.Id).Interest_Waived__c);

        assertNoErrorLogsAndDumpIfAny(ctx.booking.Id);
    }

    @IsTest
    static void testTriggerTopUpAddsAdditionalEntries() {
        System.debug('===WaiverLogs=== START testTriggerTopUpAddsAdditionalEntries');
        TestContext ctx = createContext();

        Interest_Waiver_Request__c req = new Interest_Waiver_Request__c(
            Booking__c = ctx.booking.Id, Waiver_Amount__c = 100, Status__c = 'Draft'
        );
        insert req;

        Test.startTest();
        req.Status__c = 'Approved'; update req;          // 100 → all to s1
        req.Waiver_Amount__c = 300; update req;          // top-up → +50 to s1, +150 to s2
        Test.stopTest();

        assertPostedWaivers(ctx.booking.Id, ctx.s1.Id, ctx.s2.Id, 6);

        Map<Id, Booking_Payment_Schedule__c> sch = new Map<Id, Booking_Payment_Schedule__c>([
            SELECT Id, Interest_Waived__c
            FROM Booking_Payment_Schedule__c
            WHERE Id IN :new List<Id>{ ctx.s1.Id, ctx.s2.Id }
        ]);

        Map<Id, Decimal> waiverSums = postedWaiverInterestBySchedule(new Set<Id>{ ctx.s1.Id, ctx.s2.Id });
        assertFieldEqualsLedger(ctx.s1.Id, sch.get(ctx.s1.Id).Interest_Waived__c, waiverSums);
        assertFieldEqualsLedger(ctx.s2.Id, sch.get(ctx.s2.Id).Interest_Waived__c, waiverSums);

        System.assertEquals(150, sch.get(ctx.s1.Id).Interest_Waived__c);
        System.assertEquals(150, sch.get(ctx.s2.Id).Interest_Waived__c);

        assertNoErrorLogsAndDumpIfAny(ctx.booking.Id);
    }

    @IsTest
    static void testTriggerBookingChangedReprocessesNewBooking() {
        System.debug('===WaiverLogs=== START testTriggerBookingChangedReprocessesNewBooking');
        TestContext oldCtx = createContext();
        TestContext newCtx = createContext();

        Interest_Waiver_Request__c req = new Interest_Waiver_Request__c(
            Booking__c = oldCtx.booking.Id, Waiver_Amount__c = 300, Status__c = 'Draft'
        );
        insert req;

        Test.startTest();
        req.Status__c = 'Approved'; update req;          // apply to old
        req.Booking__c = newCtx.booking.Id; update req;  // move to new
        Test.stopTest();

        assertPostedWaivers(newCtx.booking.Id, newCtx.s1.Id, newCtx.s2.Id, 4);

        Map<Id, Booking_Payment_Schedule__c> newSch = new Map<Id, Booking_Payment_Schedule__c>([
            SELECT Id, Interest_Waived__c
            FROM Booking_Payment_Schedule__c
            WHERE Id IN :new List<Id>{ newCtx.s1.Id, newCtx.s2.Id }
        ]);

        Map<Id, Decimal> waiverSums = postedWaiverInterestBySchedule(new Set<Id>{ newCtx.s1.Id, newCtx.s2.Id });
        assertFieldEqualsLedger(newCtx.s1.Id, newSch.get(newCtx.s1.Id).Interest_Waived__c, waiverSums);
        assertFieldEqualsLedger(newCtx.s2.Id, newSch.get(newCtx.s2.Id).Interest_Waived__c, waiverSums);

        System.assertEquals(150, newSch.get(newCtx.s1.Id).Interest_Waived__c);
        System.assertEquals(150, newSch.get(newCtx.s2.Id).Interest_Waived__c);

        assertNoErrorLogsAndDumpIfAny(newCtx.booking.Id);
    }

    @IsTest
    static void testTriggerSkipsInvalidRows() {
        System.debug('===WaiverLogs=== START testTriggerSkipsInvalidRows');
        TestContext ctx = createContext();

        Interest_Waiver_Request__c noBooking = new Interest_Waiver_Request__c(
            Waiver_Amount__c = 200, Status__c = 'Draft'
        );
        insert noBooking;

        Interest_Waiver_Request__c zeroAmount = new Interest_Waiver_Request__c(
            Booking__c = ctx.booking.Id, Waiver_Amount__c = 0, Status__c = 'Draft'
        );
        insert zeroAmount;

        Test.startTest();
        noBooking.Status__c = 'Approved'; update noBooking;
        zeroAmount.Status__c = 'Approved'; update zeroAmount;
        Test.stopTest();

        List<Ledger_Entry__c> rows = waiverRows(ctx.booking.Id);
        System.assertEquals(0, rows.size(), 'No waiver rows should be created for invalid requests');

        Map<Id, Booking_Payment_Schedule__c> sch = new Map<Id, Booking_Payment_Schedule__c>([
            SELECT Id, Interest_Waived__c
            FROM Booking_Payment_Schedule__c
            WHERE Id IN :new List<Id>{ ctx.s1.Id, ctx.s2.Id }
        ]);
        System.assertEquals(0, sch.get(ctx.s1.Id).Interest_Waived__c);
        System.assertEquals(0, sch.get(ctx.s2.Id).Interest_Waived__c);

        assertNoErrorLogsAndDumpIfAny(ctx.booking.Id);
    }
}