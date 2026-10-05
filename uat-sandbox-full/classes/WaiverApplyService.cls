/**
 * WaiverApplyService (NO effective date logic)
 * ------------------------------------------------------------------
 * PURPOSE
 *  When one or more Interest_Waiver_Request__c rows are Approved, immediately
 *  apply (or top-up) the booking's TOTAL approved waiver across its
 *  Booking_Payment_Schedule__c rows (oldest due first), by increasing
 *  Interest_Waived__c up to each schedule's CURRENT interest due.
 *
 * CURRENT INTEREST DUE (per schedule)
 *   dueNow = AccruedInterestToDateLedger__c
 *          - Interest_Received__c
 *          - Interest_Waived__c
 *   (never negative)
 *
 * HOW IT WORKS
 *  - Query the latest TOTAL Approved amount per booking (sum of all Approved rows).
 *  - Query how much is ALREADY used (sum of schedules.Interest_Waived__c).
 *  - remaining = approvedTotal - alreadyUsed
 *  - Allocate remaining across schedules in Payment_Due_Date__c order.
 *
 * NOTES
 *  - Idempotent: calling this repeatedly will never double-apply, because we always
 *    compute "remaining" from the database each time.
 *  - This class does not accrue interest; accrual happens in your receipt BEFORE logic.
 *  - This class does not touch receipts; it only updates schedules.Interest_Waived__c.
 */
public with sharing class WaiverApplyService {

    
    // Add this helper inside the class
    private class IntAgg { Decimal accr = 0, rcv = 0, wav = 0; }

    // Build a ledger snapshot for interest components per schedule (POSTED rows only)
    private static Map<Id, IntAgg> interestLedgerAgg(Set<Id> scheduleIds) {
        Map<Id, IntAgg> m = new Map<Id, IntAgg>();
        if (scheduleIds.isEmpty()) return m;

        // Posted accruals (+)
        for (AggregateResult ar : [
            SELECT Schedule__c sid, SUM(Interest_Amount__c) s
            FROM Ledger_Entry__c
            WHERE Schedule__c IN :scheduleIds
              AND Status__c = :LedgerConst.STATUS_POSTED
              AND Source__c = :LedgerConst.SOURCE_ACCRUAL
            GROUP BY Schedule__c
        ]) {
            Id sid = (Id)ar.get('sid');
            if (!m.containsKey(sid)) m.put(sid, new IntAgg());
            m.get(sid).accr = (Decimal)ar.get('s');
        }

        // Posted interest receipts (negative)
        for (AggregateResult ar : [
            SELECT Schedule__c sid, SUM(Interest_Amount__c) s
            FROM Ledger_Entry__c
            WHERE Schedule__c IN :scheduleIds
              AND Status__c = :LedgerConst.STATUS_POSTED
              AND Type__c   = :LedgerConst.TYPE_INTEREST_RECEIPT
            GROUP BY Schedule__c
        ]) {
            Id sid = (Id)ar.get('sid');
            if (!m.containsKey(sid)) m.put(sid, new IntAgg());
            m.get(sid).rcv = (Decimal)ar.get('s');
        }

        // Posted interest waivers (negative)
        for (AggregateResult ar : [
            SELECT Schedule__c sid, SUM(Interest_Amount__c) s
            FROM Ledger_Entry__c
            WHERE Schedule__c IN :scheduleIds
              AND Status__c = :LedgerConst.STATUS_POSTED
              AND Type__c   = :LedgerConst.TYPE_INTEREST_WAIVER
            GROUP BY Schedule__c
        ]) {
            Id sid = (Id)ar.get('sid');
            if (!m.containsKey(sid)) m.put(sid, new IntAgg());
            m.get(sid).wav = (Decimal)ar.get('s');
        }

        return m;
    }

    /**
     * Apply or top-up waiver pools for the given bookings.
     * Call this from Interest_Waiver_Request__c AFTER trigger whenever rows are (newly) Approved,
     * Approved amount increases, or Booking changes while remaining Approved.
     *
     * @param bookingIds  Set of Booking__c ids whose waiver pool needs (re)allocation
     */
    public static void applyForBookings(Set<Id> bookingIds) {
        if (bookingIds == null || bookingIds.isEmpty()) return;
        System.debug('===WaiverLogs=== applyForBookings invoked for bookings: ' + bookingIds);

        // 1) TOTAL Approved per booking
        Map<Id, Decimal> approvedByBooking = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Booking__c b, SUM(Waiver_Amount__c) t
            FROM Interest_Waiver_Request__c
            WHERE Booking__c IN :bookingIds AND Status__c = 'Approved'
            GROUP BY Booking__c
        ]) {
            approvedByBooking.put((Id) ar.get('b'), (Decimal) (ar.get('t') == null ? 0 : ar.get('t')));
        }
        System.debug('===WaiverLogs=== approvedByBooking: ' + approvedByBooking);
        if (approvedByBooking.isEmpty()) return;

        // 2) Already used (from schedules field)
        Map<Id, Decimal> usedByBooking = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Booking__c b, SUM(Interest_Waived__c) w
            FROM Booking_Payment_Schedule__c
            WHERE Booking__c IN :approvedByBooking.keySet()
            GROUP BY Booking__c
        ]) {
            usedByBooking.put((Id) ar.get('b'), (Decimal) (ar.get('w') == null ? 0 : ar.get('w')));
        }
        System.debug('===WaiverLogs=== usedByBooking(Interest_Waived__c sum): ' + usedByBooking);

        // 3) remaining
        Map<Id, Decimal> remaining = new Map<Id, Decimal>();
        for (Id bId : approvedByBooking.keySet()) {
            Decimal rem = nz(approvedByBooking.get(bId)) - nz(usedByBooking.get(bId));
            if (rem > 0) remaining.put(bId, rem);
        }
        System.debug('===WaiverLogs=== remaining pool by booking: ' + remaining);
        if (remaining.isEmpty()) return;

        // 4) Load candidate schedules (ordered)
        Map<Id, List<Booking_Payment_Schedule__c>> schedulesByBooking = new Map<Id, List<Booking_Payment_Schedule__c>>();
        Set<Id> allSchedIds = new Set<Id>();
        // for (Booking_Payment_Schedule__c s : [
        //     SELECT Id, Booking__c, Payment_Due_Date__c,
        //            AccruedInterestToDateLedger__c,
        //            Interest_Received__c,
        //            Interest_Waived__c,
        //            Milestone_Code__c,
        //            Annual_Interest_Rate__c,
        //            Grace_Period_Days__c,
        //            GST_VAT_Rate_On_Interest__c
        //     FROM Booking_Payment_Schedule__c
        //     WHERE Booking__c IN :remaining.keySet()
        //     ORDER BY Payment_Due_Date__c ASC, Id ASC
        // ])
        
        for (Booking_Payment_Schedule__c s : [
                SELECT Id, Booking__c, Payment_Due_Date__c,
                    AccruedInterestToDateLedger__c,
                    Interest_Received__c,
                    Interest_Waived__c,
                    Milestone_Code__c,
                    Annual_Interest_Rate__c,
                    Grace_Period_Days__c,
                    GST_VAT_Rate_On_Interest__c,
                    PreviewInterestToday__c, // <-- Add this line
                    Tax_on_Interest_Today__c,  // <-- Add this line
                    Last_Accrued_on__c        // <-- Add this line
                FROM Booking_Payment_Schedule__c
                WHERE Booking__c IN :remaining.keySet()
                ORDER BY Payment_Due_Date__c ASC, Id ASC
            ])
         {
            allSchedIds.add(s.Id);
            if (!schedulesByBooking.containsKey(s.Booking__c)) {
                schedulesByBooking.put(s.Booking__c, new List<Booking_Payment_Schedule__c>());
            }
            schedulesByBooking.get(s.Booking__c).add(s);
        }
        System.debug('===WaiverLogs=== schedulesByBooking sizes: ' + schedulesByBooking.keySet().size() + ' bookings, total schedules=' + allSchedIds.size());

        Map<Id, IntAgg> ledgerAgg = interestLedgerAgg(allSchedIds);
        System.debug('===WaiverLogs=== ledgerAgg keys count: ' + ledgerAgg.keySet().size());

        // 5) Allocate remaining pool across schedules
        List<Ledger_Entry__c> toInsert = new List<Ledger_Entry__c>();
        List<Booking_Payment_Schedule__c> toUpdate = new List<Booking_Payment_Schedule__c>();

        // for (Id bId : remaining.keySet()) {
        //     Decimal pool = remaining.get(bId);
        //     if (pool <= 0) continue;

        //     // running balances (interest/principal/tax) for ledger rows
        //     LedgerEntryService.Balances base = LedgerEntryService.getBalances(bId);
        //     Decimal runPrin = base.prin, runIntr = base.intr, runTax = base.tax;

        //     System.debug('===WaiverLogs=== START booking ' + bId + ' pool=' + pool + ' baseBalances=' + base);

        //     List<Booking_Payment_Schedule__c> bpsList = schedulesByBooking.get(bId);
        //     if (bpsList == null) continue;

        //     for (Booking_Payment_Schedule__c s : bpsList) {
        //         if (pool <= 0) break;

        //         // Compute field rollup based due
        //         Decimal rollAccr = nz(s.AccruedInterestToDateLedger__c);
        //         Decimal rollRcv  = nz(s.Interest_Received__c);
        //         Decimal rollWav  = nz(s.Interest_Waived__c);
        //         Decimal dueRoll  = (rollAccr - rollRcv - rollWav);

        //         // Compute ledger-driven due (receipts/waivers are negative in ledger)
        //         IntAgg la = ledgerAgg.containsKey(s.Id) ? ledgerAgg.get(s.Id) : null;
        //         Boolean hasLedger = (la != null);
        //         Decimal acc = hasLedger ? nz(la.accr) : 0;
        //         Decimal rcv = hasLedger ? nz(la.rcv)  : 0; // negative
        //         Decimal wav = hasLedger ? nz(la.wav)  : 0; // negative
        //         Decimal dueLedger = acc + rcv + wav; // equivalently acc - (-rcv) - (-wav)

        //         // Prefer ledger when available; fall back to rollup if no ledger snapshot
        //         Decimal dueNow = hasLedger ? Math.max(0, dueLedger) : Math.max(0, dueRoll);

        //         System.debug('===WaiverLogs=== schedule ' + s.Id + ' dueRoll=' + dueRoll + ', ledger(accr,rcv,wav)=(' + acc + ',' + rcv + ',' + wav + '), dueLedger=' + dueLedger + ', chosenDue=' + dueNow + ', poolRem=' + pool);

        //         if (dueNow <= 0) continue;

        //         // How much of pool can we apply here?
        //         Decimal hit = (pool <= dueNow) ? pool : dueNow;
        //         pool -= hit;

        //         System.debug('===WaiverLogs=== APPLY booking ' + bId + ' schedule ' + s.Id + ' hit=' + hit + ' pool->' + pool);

        //         // keep schedule field in sync (UI)
        //         s.Interest_Waived__c = nz(s.Interest_Waived__c) + hit;
        //         toUpdate.add(s);

        //         // bucket
        //         String bucket = (s.Milestone_Code__c != null && 'on possession'.equalsIgnoreCase(s.Milestone_Code__c.trim()))
        //             ? LedgerConst.BUCKET_OTHER : LedgerConst.BUCKET_BASIC;

        //         // tax on interest waiver
        //         Decimal taxRate = (s.GST_VAT_Rate_On_Interest__c == null) ? 0 : s.GST_VAT_Rate_On_Interest__c;
        //         Decimal taxHit  = (hit * (taxRate / 100)).setScale(2, RoundingMode.HALF_UP);

        //         Date today = Date.today();

        //         // Interest waiver (negative)
        //         Ledger_Entry__c li = new Ledger_Entry__c();
        //         li.Booking__c = bId;
        //         li.Schedule__c = s.Id;
        //         li.Entry_Date__c = today;
        //         li.Type__c = LedgerConst.TYPE_INTEREST_WAIVER;
        //         li.Source__c = LedgerConst.SOURCE_ADJUSTMENT;
        //         li.Status__c = LedgerConst.STATUS_POSTED;
        //         li.Bucket__c = bucket;
        //         li.Interest_Amount__c = -hit.setScale(2, RoundingMode.HALF_UP);
        //         li.Applied_Interest_Rate__c = (s.Annual_Interest_Rate__c == null ? 0 : s.Annual_Interest_Rate__c.setScale(4, RoundingMode.HALF_UP));
        //         li.Description__c = 'Interest waiver';
        //         runIntr = (runIntr + li.Interest_Amount__c).setScale(2, RoundingMode.HALF_UP);
        //         li.Running_Interest_Outstanding__c = runIntr;
        //         li.Running_Principal_Outstanding__c = runPrin;
        //         li.Running_Tax_Outstanding__c = runTax;
        //         toInsert.add(li);

        //         // Tax waiver (negative)
        //         if (taxHit != 0) {
        //             Ledger_Entry__c lt = new Ledger_Entry__c();
        //             lt.Booking__c = bId;
        //             lt.Schedule__c = s.Id;
        //             lt.Entry_Date__c = today;
        //             lt.Type__c = LedgerConst.TYPE_INTEREST_TAX_WAIVER;
        //             lt.Source__c = LedgerConst.SOURCE_ADJUSTMENT;
        //             lt.Status__c = LedgerConst.STATUS_POSTED;
        //             lt.Bucket__c = bucket;
        //             lt.Tax_Amount__c = -taxHit;
        //             lt.Applied_Tax_Rate__c = taxRate.setScale(2, RoundingMode.HALF_UP);
        //             lt.Description__c = 'Tax waived with interest waiver';
        //             runTax = (runTax + lt.Tax_Amount__c).setScale(2, RoundingMode.HALF_UP);
        //             lt.Running_Interest_Outstanding__c = runIntr;
        //             lt.Running_Principal_Outstanding__c = runPrin;
        //             lt.Running_Tax_Outstanding__c = runTax;
        //             toInsert.add(lt);
        //         }
        //     }
        // }


        // --- THE CONSOLIDATED LOOP STARTS HERE (FIXES DUPLICATE VARIABLE ERROR) ---
        for (Id bId : remaining.keySet()) {
            Decimal pool = remaining.get(bId);
            if (pool <= 0) continue;

            // running balances (interest/principal/tax) for ledger rows
            LedgerEntryService.Balances base = LedgerEntryService.getBalances(bId);
            Decimal runPrin = base.prin, runIntr = base.intr, runTax = base.tax;

            System.debug('===WaiverLogs=== START booking ' + bId + ' pool=' + pool + ' baseBalances=' + base);

            List<Booking_Payment_Schedule__c> bpsList = schedulesByBooking.get(bId);
            if (bpsList == null) continue;

            for (Booking_Payment_Schedule__c s : bpsList) {
                if (pool <= 0) break;

                // --- START NEW SYNC LOGIC (To solve 0 waiver and Sidebar mismatch) ---
                String syncBkt = (s.Milestone_Code__c != null && 'on possession'.equalsIgnoreCase(s.Milestone_Code__c.trim())) ? LedgerConst.BUCKET_OTHER : LedgerConst.BUCKET_BASIC;
                String cpIntrType = (syncBkt == LedgerConst.BUCKET_OTHER) ? LedgerConst.TYPE_INTEREST_ACCRUAL_OTHER : LedgerConst.TYPE_INTEREST_ACCRUAL_BASIC;
                String cpTaxType = (syncBkt == LedgerConst.BUCKET_OTHER) ? LedgerConst.TYPE_INTEREST_TAX_ACCRUAL_OTHER : LedgerConst.TYPE_INTEREST_TAX_ACCRUAL_BASIC;
                Date todaySync = Date.today();

                if (nz(s.AccruedInterestToDateLedger__c) == 0 && nz(s.PreviewInterestToday__c) > 0) {
                    Decimal valInt = s.PreviewInterestToday__c;
                    Decimal valTax = nz(s.Tax_on_Interest_Today__c);
                    
                    toInsert.add(new Ledger_Entry__c(Booking__c=bId, Schedule__c=s.Id, Entry_Date__c=todaySync, Source__c=LedgerConst.SOURCE_ACCRUAL, Status__c=LedgerConst.STATUS_POSTED, Type__c=cpIntrType, Interest_Amount__c=valInt, Bucket__c=syncBkt, Running_Interest_Outstanding__c=(runIntr+valInt), Running_Principal_Outstanding__c=runPrin, Running_Tax_Outstanding__c=runTax, Period_End__c=todaySync));
                    runIntr += valInt;
                    if (valTax > 0) {
                        toInsert.add(new Ledger_Entry__c(Booking__c=bId, Schedule__c=s.Id, Entry_Date__c=todaySync, Source__c=LedgerConst.SOURCE_ACCRUAL, Status__c=LedgerConst.STATUS_POSTED, Type__c=cpTaxType, Tax_Amount__c=valTax, Bucket__c=syncBkt, Running_Tax_Outstanding__c=(runTax+valTax), Running_Interest_Outstanding__c=runIntr, Running_Principal_Outstanding__c=runPrin, Period_End__c=todaySync));
                        runTax += valTax;
                    }
                    
                    IntAgg locAgg = ledgerAgg.containsKey(s.Id) ? ledgerAgg.get(s.Id) : new IntAgg();
                    locAgg.accr += valInt; ledgerAgg.put(s.Id, locAgg);
                    
                    s.Last_Accrued_on__c = todaySync; 
                }
                // --- END NEW SYNC LOGIC ---

                // Compute field rollup based due (ORIGINAL LOGIC)
                Decimal rollAccr = nz(s.AccruedInterestToDateLedger__c);
                Decimal rollRcv  = nz(s.Interest_Received__c);
                Decimal rollWav  = nz(s.Interest_Waived__c);
                Decimal dueRoll  = (rollAccr - rollRcv - rollWav);

                IntAgg la = ledgerAgg.containsKey(s.Id) ? ledgerAgg.get(s.Id) : null;
                Boolean hasLedger = (la != null);
                Decimal acc = hasLedger ? nz(la.accr) : 0;
                Decimal rcv = hasLedger ? nz(la.rcv)  : 0; // negative
                Decimal wav = hasLedger ? nz(la.wav)  : 0; // negative
                Decimal dueLedger = acc + rcv + wav;

                Decimal dueNow = hasLedger ? Math.max(0, dueLedger) : Math.max(0, dueRoll);
                System.debug('===WaiverDebug=== Schedule: ' + s.Id + ' Due: ' + dueNow + ' Pool: ' + pool);

                if (dueNow <= 0) continue;

                Decimal hit = (pool <= dueNow) ? pool : dueNow;
                pool -= hit;

                System.debug('===WaiverLogs=== APPLY booking ' + bId + ' schedule ' + s.Id + ' hit=' + hit + ' pool->' + pool);

                s.Interest_Waived__c = nz(s.Interest_Waived__c) + hit;
                toUpdate.add(s);

                String bucket = (s.Milestone_Code__c != null && 'on possession'.equalsIgnoreCase(s.Milestone_Code__c.trim()))
                    ? LedgerConst.BUCKET_OTHER : LedgerConst.BUCKET_BASIC;

                Decimal taxRate = (s.GST_VAT_Rate_On_Interest__c == null) ? 0 : s.GST_VAT_Rate_On_Interest__c;
                Decimal taxHit  = (hit * (taxRate / 100)).setScale(2, RoundingMode.HALF_UP);

                Date today = Date.today();

                // Interest waiver (negative)
                Ledger_Entry__c li = new Ledger_Entry__c();
                li.Booking__c = bId;
                li.Schedule__c = s.Id;
                li.Entry_Date__c = today;
                li.Type__c = LedgerConst.TYPE_INTEREST_WAIVER;
                li.Source__c = LedgerConst.SOURCE_ADJUSTMENT;
                li.Status__c = LedgerConst.STATUS_POSTED;
                li.Bucket__c = bucket;
                li.Interest_Amount__c = -hit.setScale(2, RoundingMode.HALF_UP);
                li.Applied_Interest_Rate__c = (s.Annual_Interest_Rate__c == null ? 0 : s.Annual_Interest_Rate__c.setScale(4, RoundingMode.HALF_UP));
                li.Description__c = 'Interest waiver';
                runIntr = (runIntr + li.Interest_Amount__c).setScale(2, RoundingMode.HALF_UP);
                li.Running_Interest_Outstanding__c = runIntr;
                li.Running_Principal_Outstanding__c = runPrin;
                li.Running_Tax_Outstanding__c = runTax;
                toInsert.add(li);

                if (taxHit != 0) {
                    Ledger_Entry__c lt = new Ledger_Entry__c();
                    lt.Booking__c = bId;
                    lt.Schedule__c = s.Id;
                    lt.Entry_Date__c = today;
                    lt.Type__c = LedgerConst.TYPE_INTEREST_TAX_WAIVER;
                    lt.Source__c = LedgerConst.SOURCE_ADJUSTMENT;
                    lt.Status__c = LedgerConst.STATUS_POSTED;
                    lt.Bucket__c = bucket;
                    lt.Tax_Amount__c = -taxHit;
                    lt.Applied_Tax_Rate__c = taxRate.setScale(2, RoundingMode.HALF_UP);
                    lt.Description__c = 'Tax waived with interest waiver';
                    runTax = (runTax + lt.Tax_Amount__c).setScale(2, RoundingMode.HALF_UP);
                    lt.Running_Interest_Outstanding__c = runIntr;
                    lt.Running_Principal_Outstanding__c = runPrin;
                    lt.Running_Tax_Outstanding__c = runTax;
                    toInsert.add(lt);
                }
            }
        }

        System.debug('===WaiverLogs=== toUpdate size=' + toUpdate.size() + ', toInsert size=' + toInsert.size());
        if (!toUpdate.isEmpty()) update toUpdate;
        if (!toInsert.isEmpty()) insert toInsert;
        System.debug('===WaiverLogs=== END applyForBookings for bookings: ' + bookingIds);
    }

    private static Decimal nz(Decimal d) { return d == null ? 0 : d; }
}