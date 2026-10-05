/**
 * PaymentReceiptApplyService
 * AFTER UPDATE for Payment_Receipt__c rows transitioning to Approved.
 *
 * Bulk-safe & grouped by Booking_Payment_Schedule__c:
 * - Accrues once per schedule (uses PreviewInterestToday__c when present).
 * - No duplicate Ids in update lists.
 * - Waiver applied once per schedule.
 * - AccruedInterestToDate__c floored to recognized interest (others + this batch + waived).
 */
public class PaymentReceiptApplyService {

    private static Boolean reentry = false;

    public static void applyOnApproved(List<Payment_Receipt__c> newList,
                                       Map<Id, Payment_Receipt__c> oldMap) {
        if (reentry) return;
        reentry = true;
        try {
            if (newList == null || newList.isEmpty()) return;

            // 1) Filter: rows that just turned Approved in THIS DML
            List<Payment_Receipt__c> toApply = new List<Payment_Receipt__c>();
            for (Payment_Receipt__c r : newList) {
                if (r == null) continue;
                Boolean nowApproved = (r.Approval_Status__c == 'Approved');
                Boolean wasApproved = (oldMap != null && oldMap.containsKey(r.Id))
                                      ? (oldMap.get(r.Id).Approval_Status__c == 'Approved')
                                      : false;
                if (nowApproved && !wasApproved) toApply.add(r);
            }
            if (toApply.isEmpty()) return;

            // 2) Gather Demands & map to Schedules
            Set<Id> demandIds = new Set<Id>();
            Set<Id> toApplyIds = new Set<Id>();
            for (Payment_Receipt__c r : toApply) {
                if (r.Demand__c != null) demandIds.add(r.Demand__c);
                toApplyIds.add(r.Id);
            }

            Map<Id, Demand__c> demandMap = new Map<Id, Demand__c>([
                SELECT Id, Booking_Payment_Schedule_Id__c
                FROM Demand__c
                WHERE Id IN :demandIds
            ]);

            Set<Id> schIds = new Set<Id>();
            for (Payment_Receipt__c r : toApply) {
                Demand__c d = demandMap.get(r.Demand__c);
                if (d != null && d.Booking_Payment_Schedule_Id__c != null) {
                    schIds.add(d.Booking_Payment_Schedule_Id__c);
                }
            }
            if (schIds.isEmpty()) return;

            // 3) Lock schedules (we also read PreviewInterestToday__c to match the UI)
            Map<Id, Booking_Payment_Schedule__c> schMap = new Map<Id, Booking_Payment_Schedule__c>([
                SELECT Id, Booking__c, Payment_Due_Date__c,
                       Installment_Amount__c,
                       Last_Accrued_On__c, AccruedInterestToDate__c,
                       TotalPrincipalReceived__c, TotalInterestReceived__c, Interest_Waived__c,
                       Advance_Applied__c,
                       PreviewInterestToday__c,
                       Annual_Interest_Rate__c,
                       Grace_Period_Days__c
                FROM Booking_Payment_Schedule__c
                WHERE Id IN :schIds
                FOR UPDATE
            ]);

            // 4) Rates will be derived per schedule from its own fields

            // 5) Waiver pools per booking
            Set<Id> bookingIds = new Set<Id>();
            for (Booking_Payment_Schedule__c s : schMap.values()) if (s.Booking__c != null) bookingIds.add(s.Booking__c);

            Map<Id, Decimal> approvedWaiverByBooking = WaiverUtil.fetchApprovedTotals(bookingIds);

            Map<Id, Decimal> alreadyWaivedByBooking = new Map<Id, Decimal>();
            if (!bookingIds.isEmpty()) {
                for (AggregateResult ar : [
                    SELECT Booking__c b, SUM(Interest_Waived__c) w
                    FROM Booking_Payment_Schedule__c
                    WHERE Booking__c IN :bookingIds
                    GROUP BY Booking__c
                ]) {
                    alreadyWaivedByBooking.put(
                        (Id) ar.get('b'),
                        (Decimal) (ar.get('w') == null ? 0 : ar.get('w'))
                    );
                }
            }

            // 6) PRE-RECEIPT totals from OTHER Approved receipts (exclude current batch)
            Map<Id, Decimal> prinApprovedBySch = new Map<Id, Decimal>();
            Map<Id, Decimal> intApprovedBySch  = new Map<Id, Decimal>();

            List<Payment_Receipt__c> otherApproved = [
                SELECT Id, Demand__c, Booking_Payment_Schedule__c,
                       Principal_Applied__c, Interest_Applied__c
                FROM Payment_Receipt__c
                WHERE Approval_Status__c = 'Approved'
                  AND Id NOT IN :toApplyIds
                  AND (Demand__c IN :demandIds OR Booking_Payment_Schedule__c IN :schIds)
            ];
            for (Payment_Receipt__c pr : otherApproved) {
                Id sid = pr.Booking_Payment_Schedule__c;
                if (sid == null && pr.Demand__c != null) {
                    Demand__c dm = demandMap.get(pr.Demand__c);
                    if (dm != null) sid = dm.Booking_Payment_Schedule_Id__c;
                }
                if (sid == null) continue;
                prinApprovedBySch.put(sid, (prinApprovedBySch.containsKey(sid) ? prinApprovedBySch.get(sid) : 0)
                                            + (pr.Principal_Applied__c == null ? 0 : pr.Principal_Applied__c));
                intApprovedBySch.put (sid, (intApprovedBySch.containsKey(sid)  ? intApprovedBySch.get(sid)  : 0)
                                            + (pr.Interest_Applied__c  == null ? 0 : pr.Interest_Applied__c));
            }

            // 7) Group receipts by schedule
            Map<Id, List<Payment_Receipt__c>> receiptsBySch = new Map<Id, List<Payment_Receipt__c>>();
            for (Payment_Receipt__c r : toApply) {
                Demand__c d = demandMap.get(r.Demand__c);
                if (d == null || d.Booking_Payment_Schedule_Id__c == null) continue;
                Id sid = d.Booking_Payment_Schedule_Id__c;
                if (!receiptsBySch.containsKey(sid)) receiptsBySch.put(sid, new List<Payment_Receipt__c>());
                receiptsBySch.get(sid).add(r);
            }

            // 8) Stage updates (deduped)
            Map<Id, Booking_Payment_Schedule__c> scheduleUpdates = new Map<Id, Booking_Payment_Schedule__c>();
            List<Payment_Receipt__c>             receiptUpdates  = new List<Payment_Receipt__c>();
            List<Payment_Receipt__c>             newForCarry     = new List<Payment_Receipt__c>();
            Map<Id, Payment_Receipt__c>          fakeOldMap      = new Map<Id, Payment_Receipt__c>();

            // Process per-schedule
            for (Id sid : receiptsBySch.keySet()) {
                Booking_Payment_Schedule__c sch = schMap.get(sid);
                if (sch == null) continue;

                List<Payment_Receipt__c> paymentReceipts = receiptsBySch.get(sid);

                // A) Accrual delta ONCE per schedule (prefer PreviewInterestToday__c)
                Decimal interestDelta = (sch.PreviewInterestToday__c == null) ? 0 : sch.PreviewInterestToday__c;

                if (interestDelta == 0) {
                    // Fallback compute
                    // Use payment date = max date in group (accrue up to the latest one)
                    Date maxPayDate = null;
                    for (Payment_Receipt__c r : paymentReceipts) {
                        if (r.Date_Of_Payment__c != null && (maxPayDate == null || r.Date_Of_Payment__c > maxPayDate)) {
                            maxPayDate = r.Date_Of_Payment__c;
                        }
                    }
                    if (maxPayDate != null) {
                        Integer graceDays = (sch.Grace_Period_Days__c == null) ? 0 : Integer.valueOf(sch.Grace_Period_Days__c);
                        Date nominalStart = (sch.Payment_Due_Date__c == null)
                            ? maxPayDate
                            : sch.Payment_Due_Date__c.addDays(graceDays + 1);

                        Date boundaryNext = (sch.Last_Accrued_On__c == null) ? null : sch.Last_Accrued_On__c.addDays(1);
                        Date beginDate = (boundaryNext == null)
                            ? nominalStart
                            : (nominalStart > boundaryNext ? nominalStart : boundaryNext);

                        Integer days = daysNonNeg(beginDate, maxPayDate);

                        Decimal prePrinReceived = (prinApprovedBySch.containsKey(sid) ? prinApprovedBySch.get(sid) : 0);
                        Decimal outstanding = nz(sch.Installment_Amount__c) - prePrinReceived - nz(sch.Advance_Applied__c);
                        if (outstanding < 0) outstanding = 0;

                        Decimal dailyRate = (((sch.Annual_Interest_Rate__c == null) ? 0 : sch.Annual_Interest_Rate__c) / 100) / 365;
                        interestDelta = (outstanding * dailyRate * days).setScale(2, RoundingMode.HALF_UP);

                        // Also advance boundary to max receipt date
                        if (sch.Last_Accrued_On__c == null || maxPayDate > sch.Last_Accrued_On__c) {
                            sch.Last_Accrued_On__c = maxPayDate;
                        }
                    }
                }

                sch.AccruedInterestToDate__c = nz(sch.AccruedInterestToDate__c) + interestDelta;

                // If we used preview, still advance boundary to the latest receipt date
                Date latest = sch.Last_Accrued_On__c;
                for (Payment_Receipt__c r : paymentReceipts) {
                    if (latest == null || (r.Date_Of_Payment__c != null && r.Date_Of_Payment__c > latest)) {
                        latest = r.Date_Of_Payment__c;
                    }
                }
                if (latest != null && (sch.Last_Accrued_On__c == null || latest > sch.Last_Accrued_On__c)) {
                    sch.Last_Accrued_On__c = latest;
                }

                // B) Waiver once per schedule
                Decimal preIntReceived = (intApprovedBySch.containsKey(sid) ? intApprovedBySch.get(sid) : 0);
                Decimal interestDueNow = nz(sch.AccruedInterestToDate__c) - preIntReceived - nz(sch.Interest_Waived__c);
                if (interestDueNow < 0) interestDueNow = 0;

                Decimal approved = (sch.Booking__c != null && approvedWaiverByBooking.containsKey(sch.Booking__c))
                    ? nz(approvedWaiverByBooking.get(sch.Booking__c)) : 0;
                Decimal used     = (sch.Booking__c != null && alreadyWaivedByBooking.containsKey(sch.Booking__c))
                    ? nz(alreadyWaivedByBooking.get(sch.Booking__c)) : 0;
                Decimal remainWaiver = approved - used;
                if (remainWaiver < 0) remainWaiver = 0;

                Decimal waiverHit = (remainWaiver < interestDueNow ? remainWaiver : interestDueNow);
                if (waiverHit > 0) {
                    sch.Interest_Waived__c = nz(sch.Interest_Waived__c) + waiverHit;
                    alreadyWaivedByBooking.put(sch.Booking__c, used + waiverHit);
                }

                // C) Receipt-level updates (excess etc.)
                Decimal batchInterestApplied = 0;
                for (Payment_Receipt__c r : paymentReceipts) {
                    batchInterestApplied += nz(r.Interest_Applied__c);

                    Decimal split = ( nz(r.Principal_Applied__c)
                                    + nz(r.Interest_Applied__c)
                                    + nz(r.Tax_on_Interest__c) ).setScale(2, RoundingMode.HALF_UP);
                    Decimal excess = ( nz(r.Amount_Paid__c).setScale(2, RoundingMode.HALF_UP) - split )
                                     .setScale(2, RoundingMode.HALF_UP);
                    if (excess < 0) excess = 0;

                    receiptUpdates.add(new Payment_Receipt__c(
                        Id = r.Id,
                        Excess_Payment__c = excess
                    ));

                    Payment_Receipt__c rForCarry = new Payment_Receipt__c(
                        Id = r.Id,
                        Demand__c = r.Demand__c,
                        Excess_Payment__c = excess
                    );
                    newForCarry.add(rForCarry);
                    fakeOldMap.put(r.Id, new Payment_Receipt__c(Id = r.Id, Excess_Payment__c = 0));
                }

                // D) Floor persisted accrual to recognized interest across the whole group
                Decimal minAccrued = preIntReceived + nz(sch.Interest_Waived__c) + batchInterestApplied;
                if (nz(sch.AccruedInterestToDate__c) < minAccrued) {
                    sch.AccruedInterestToDate__c = minAccrued;
                }

                // Stage this schedule ONCE
                scheduleUpdates.put(sch.Id, sch);
            }

            // 9) DML (deduped schedules)
            if (!scheduleUpdates.isEmpty()) update scheduleUpdates.values();
            if (!receiptUpdates.isEmpty())  update receiptUpdates;

            //10) Carry forward excess
            if (!newForCarry.isEmpty()) {
                AdvanceCarryForwardService.carryForward(newForCarry, fakeOldMap);
            }

            //  // 10) Carry forward excess
            // if (!newForCarry.isEmpty()) {
            //     AdvanceCarryForwardService.carryForward(newForCarry, null);
            // }

        } finally {
            reentry = false;
        }
    }

    private static Decimal nz(Decimal d) { return (d == null) ? 0 : d; }
    private static Integer daysNonNeg(Date startIncl, Date endIncl) {
        if (startIncl == null || endIncl == null) return 0;
        Integer diff = startIncl.daysBetween(endIncl);
        return (diff < 0) ? 0 : diff + 1;
    }
}