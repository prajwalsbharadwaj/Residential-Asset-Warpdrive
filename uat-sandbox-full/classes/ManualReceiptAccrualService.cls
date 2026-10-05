public with sharing class ManualReceiptAccrualService {

    /**
     * BEFORE trigger entry.
     * @param recs   Trigger.new
     * @param oldMap Trigger.oldMap (null on insert)
     * @param isUpdate Trigger.isUpdate
     * @param enforceTotalEqualsSplit usually false (we allow Excess)
     */
    public static void process(List<Payment_Receipt__c> recs,
                               Map<Id, Payment_Receipt__c> oldMap,
                               Boolean isUpdate,
                               Boolean enforceTotalEqualsSplit) {
        if (recs == null || recs.isEmpty()) return;

        // 0) Filter actionable rows & null-safe defaults (unchanged)
        List<Payment_Receipt__c> work = new List<Payment_Receipt__c>();
        for (Payment_Receipt__c r : recs) {
            if (r == null) continue;

            if (r.Demand__c == null) { r.Demand__c.addError('Demand is required.'); continue; }
            if (r.Date_Of_Payment__c == null) { r.Date_Of_Payment__c.addError('Date of Payment is required.'); continue; }
            if (r.Amount_Paid__c == null) { r.Amount_Paid__c.addError('Amount Paid is required.'); continue; }

            if (r.Principal_Applied__c == null) r.Principal_Applied__c = 0;
            if (r.Interest_Applied__c  == null) r.Interest_Applied__c  = 0;
            if (r.Tax_on_Interest__c   == null) r.Tax_on_Interest__c   = 0;

            work.add(r);
        }
        if (work.isEmpty()) return;

        // 1) Demands → Schedules (unchanged)
        Set<Id> demandIds = new Set<Id>();
        for (Payment_Receipt__c r : work) demandIds.add(r.Demand__c);

        Map<Id, Demand__c> demandMap = new Map<Id, Demand__c>([
            SELECT Id, Booking_Payment_Schedule_Id__c
            FROM Demand__c
            WHERE Id IN :demandIds
        ]);

        Set<Id> scheduleIds = new Set<Id>();
        for (Demand__c d : demandMap.values())
            if (d.Booking_Payment_Schedule_Id__c != null) scheduleIds.add(d.Booking_Payment_Schedule_Id__c);

        if (scheduleIds.isEmpty()) {
            for (Payment_Receipt__c r : work) {
                Demand__c dem = demandMap.get(r.Demand__c);
                if (dem == null || dem.Booking_Payment_Schedule_Id__c == null) {
                    r.Demand__c.addError('Selected Demand is not linked to a Booking Payment Schedule.');
                }
            }
            return;
        }

        Map<Id, Booking_Payment_Schedule__c> schMap = new Map<Id, Booking_Payment_Schedule__c>([
            SELECT Id, Booking__c, Payment_Due_Date__c,
                   Installment_Amount__c,
                   Last_Accrued_On__c, AccruedInterestToDate__c,
                   TotalPrincipalReceived__c, TotalInterestReceived__c, Interest_Waived__c,
                   Advance_Applied__c
            FROM Booking_Payment_Schedule__c
            WHERE Id IN :scheduleIds
            FOR UPDATE
        ]);

        // 2) Policy (unchanged)
        Policy pol = loadPolicy();

        // 3) Waiver pools (unchanged)
        Set<Id> bookingIds = new Set<Id>();
        for (Booking_Payment_Schedule__c s : schMap.values()) if (s.Booking__c != null) bookingIds.add(s.Booking__c);

        Map<Id, Decimal> approvedWaiverByBooking = fetchApprovedTotals(bookingIds);
        Map<Id, Decimal> alreadyWaivedByBooking = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Booking__c b, SUM(Interest_Waived__c) w
            FROM Booking_Payment_Schedule__c
            WHERE Booking__c IN :bookingIds
            GROUP BY Booking__c
        ]) {
            alreadyWaivedByBooking.put((Id) ar.get('b'), (Decimal) (ar.get('w') == null ? 0 : ar.get('w')));
        }

        // 4) Per-receipt processing
        for (Payment_Receipt__c rec : work) {
            Demand__c dem = demandMap.get(rec.Demand__c);
            Booking_Payment_Schedule__c sch = (dem != null) ? schMap.get(dem.Booking_Payment_Schedule_Id__c) : null;
            if (sch == null) { rec.Demand__c.addError('Selected Demand is not linked to a valid Booking Payment Schedule.'); continue; }

            // --- 4.1 Accrue to payment date (unchanged) ---
            Date interestStart = (sch.Payment_Due_Date__c == null)
                ? rec.Date_Of_Payment__c
                : sch.Payment_Due_Date__c.addDays(pol.graceDays + 1);

            Date accrualStart = (sch.Last_Accrued_On__c == null)
                ? interestStart
                : sch.Last_Accrued_On__c.addDays(1);

            Date beginDate = (accrualStart > interestStart ? accrualStart : interestStart);
            Integer days = daysNonNeg(beginDate, rec.Date_Of_Payment__c);

            Decimal baseOutstanding =
                  nz(sch.Installment_Amount__c)
                - nz(sch.TotalPrincipalReceived__c)
                - nz(sch.Advance_Applied__c);
            if (baseOutstanding < 0) baseOutstanding = 0;

            Decimal dailyRate = nz(pol.defaultAnnualRate) / 365;
            Decimal delta = (baseOutstanding * dailyRate * days).setScale(2, RoundingMode.HALF_UP);

            sch.AccruedInterestToDate__c = nz(sch.AccruedInterestToDate__c) + delta;
            sch.Last_Accrued_On__c = rec.Date_Of_Payment__c;

            // --- 4.2 Interest due now (gross - received - waived) ---
            Decimal interestDueNow =
                  nz(sch.AccruedInterestToDate__c)
                - nz(sch.TotalInterestReceived__c)
                - nz(sch.Interest_Waived__c);
            if (interestDueNow < 0) interestDueNow = 0;

            // --- 4.3 Apply booking waiver cap (unchanged) ---
            Decimal approved = (sch.Booking__c != null && approvedWaiverByBooking.containsKey(sch.Booking__c))
                             ? nz(approvedWaiverByBooking.get(sch.Booking__c)) : 0;
            Decimal used     = (sch.Booking__c != null && alreadyWaivedByBooking.containsKey(sch.Booking__c))
                             ? nz(alreadyWaivedByBooking.get(sch.Booking__c)) : 0;

            Decimal remainingWaiver = approved - used;
            if (remainingWaiver < 0) remainingWaiver = 0;

            Decimal waiverHit = Math.min(remainingWaiver, interestDueNow);
            if (waiverHit > 0) {
                sch.Interest_Waived__c = nz(sch.Interest_Waived__c) + waiverHit;
                alreadyWaivedByBooking.put(sch.Booking__c, used + waiverHit);
                interestDueNow -= waiverHit;
            }

            // -----------------------------
            // 4.4 EFFECTIVE CAPS FOR UPDATES
            // -----------------------------
            Decimal priorPrincipal = 0, priorInterest = 0;
            if (isUpdate == true && oldMap != null && oldMap.containsKey(rec.Id)) {
                Payment_Receipt__c oldRec = oldMap.get(rec.Id);
                priorPrincipal = nz(oldRec.Principal_Applied__c);
                priorInterest  = nz(oldRec.Interest_Applied__c);
            }

            // If the schedule rollups already include the OLD values from this receipt,
            // then the "baseOutstanding" we computed is AFTER subtracting prior principal.
            // So allow the user to increase up to (baseOutstanding + priorPrincipal).
            Decimal principalCap = baseOutstanding + priorPrincipal;

            // Same logic for interest: allow up to (interestDueNow + priorInterest)
            Decimal interestCap  = interestDueNow + priorInterest;

            // --- Field-level validations using EFFECTIVE caps ---
            if (rec.Principal_Applied__c > principalCap) {
                rec.Principal_Applied__c.addError(
                    'Principal applied exceeds allowed maximum for this schedule. ' +
                    'Enter up to ' + String.valueOf(principalCap.setScale(2)) + '. ' +
                    'Extra should remain as Excess.'
                );
            }

            if (rec.Interest_Applied__c > interestCap) {
                rec.Interest_Applied__c.addError(
                    'Interest applied exceeds current payable interest. ' +
                    'Enter up to ' + String.valueOf(interestCap.setScale(2)) + '.'
                );
            }

            // --- 4.5 Derive Excess (must be ≥ 0) ---
            Decimal splitSum = ( nz(rec.Principal_Applied__c)
                               + nz(rec.Interest_Applied__c)
                               + nz(rec.Tax_on_Interest__c) ).setScale(2, RoundingMode.HALF_UP);

            Decimal excess = ( nz(rec.Amount_Paid__c).setScale(2, RoundingMode.HALF_UP) - splitSum )
                             .setScale(2, RoundingMode.HALF_UP);

            if (excess < 0) {
                rec.Amount_Paid__c.addError('Amount Paid is less than Principal + Interest + Tax on Interest.');
            } else {
                rec.Excess_Payment__c = excess; // 0 or positive
            }

        }

        // 5) Persist schedule updates (accrual & waiver)
        if (!schMap.isEmpty()) update schMap.values();
    }

    // --- Policy / Waiver / Helpers (unchanged) ---
    public class Policy { public Integer graceDays = 0; public Decimal defaultAnnualRate = 0; }
    public static Policy loadPolicy() {
        Policy p = new Policy();
        Finance_Policy__mdt m = Finance_Policy__mdt.getInstance('Default');
        if (m != null) {
            if (m.Grace_Period_Days__c != null) p.graceDays = Integer.valueOf(m.Grace_Period_Days__c);
            if (m.Default_Annual_Interest_Rate__c != null) p.defaultAnnualRate = m.Default_Annual_Interest_Rate__c; 
            else {
                throw new TriggerException('Finance policy interest rate is not configured.');
            }
        }
        return p;
    }
    public static Map<Id, Decimal> fetchApprovedTotals(Set<Id> bookingIds) {
        Map<Id, Decimal> res = new Map<Id, Decimal>();
        if (bookingIds == null || bookingIds.isEmpty()) return res;
        for (AggregateResult ar : [
            SELECT Booking__c b, SUM(Waiver_Amount__c) t
            FROM Interest_Waiver_Request__c
            WHERE Booking__c IN :bookingIds AND Status__c = 'Approved'
            GROUP BY Booking__c
        ]) {
            res.put((Id) ar.get('b'), (Decimal) (ar.get('t') == null ? 0 : ar.get('t')));
        }
        return res;
    }
    @TestVisible private static Decimal nz(Decimal d) { return d == null ? 0 : d; }
    @TestVisible private static Integer daysNonNeg(Date startIncl, Date endIncl) {
        // Accrue from start (inclusive) up to end (inclusive logic via date math).
        // Use start.daysBetween(end) so result is positive when end >= start.
        if (startIncl == null || endIncl == null) return 0;
        Integer d = startIncl.daysBetween(endIncl);  // positive if end >= start
        return (d < 0) ? 0 : d;
    }
}