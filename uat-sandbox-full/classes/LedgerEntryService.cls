/**
 * Ledger entry posting service for booking schedules.
 *
 * What this class does:
 * - Posts accrual entries (interest and tax) on overdue schedules.
 * - Posts receipt entries (principal, interest, tax) allocated in schedule order.
 * - Handles excess receipts as advance principal carry-forward across future schedules.
 * - Reverses previously posted receipt/accrual entries through balancing reversal rows.
 * - Maintains running outstanding balances on each inserted ledger row.
 *
 * Allocation and scenario handling:
 * - Interest/tax/principal from a receipt are allocated left-to-right on ordered schedules.
 * - If a receipt touches an overdue schedule and accrual is missing for that date,
 *   accrual is created first, then receipt is posted.
 * - Excess payment is distributed sequentially by remaining principal due on each schedule.
 *   If all schedules are fully covered, leftover excess is carried as advance on last schedule.
 * - "On possession" milestone can split base principal vs other charges for accrual/tax treatment.
 *
 * Example:
 * - S1 due principal: 3,00,000; S2 due principal: 4,00,000.
 * - Receipt principal applied: 3,00,000; Excess_Payment__c: 5,00,000.
 * - Result:
 *   1) Normal principal allocation clears S1 for 3,00,000.
 *   2) Excess allocation applies 4,00,000 to S2.
 *   3) Remaining 1,00,000 is posted as advance on the last ordered schedule.
 */
public with sharing class LedgerEntryService {

    // ===== DTOs / helpers =====
    public class Balances {
        public Decimal prin; public Decimal intr; public Decimal tax;
        public Balances() { this(0,0,0); }
        public Balances(Decimal prin, Decimal intr, Decimal tax) {
            this.prin = prin == null ? 0 : prin;
            this.intr = intr == null ? 0 : intr;
            this.tax  = tax  == null ? 0 : tax;
        }
    }
    public class MissingFinanceDataException extends Exception {}
    private class ScheduleSnapshot {
        Id scheduleId; String bucket;
        Decimal principalOutstanding; Decimal interestOutstanding; Decimal taxOutstanding;
    }
    private enum AllocationKind { PRINCIPAL, INTEREST, TAX }
    private class FinanceConfig { Decimal annualRate; Integer graceDays; Decimal taxRate; }
    private class AccrualPreview { Decimal interest; Decimal tax; AccrualPreview(Decimal i, Decimal t){interest=i==null?0:i; tax=t==null?0:t;} }
    private class BookingContext {
        Boolean ocReceived;
        Decimal otherCharges;
        BookingContext(Boolean ocReceived, Decimal otherCharges){
            this.ocReceived = ocReceived == null ? false : ocReceived;
            this.otherCharges = otherCharges == null ? 0 : otherCharges;
        }
    }

    private static Map<Id, List<Booking_Payment_Schedule__c>> scheduleCache = new Map<Id, List<Booking_Payment_Schedule__c>>();
    private static Map<Id, BookingContext> bookingContextCache = new Map<Id, BookingContext>();

    // ===== Balances (single & bulk) =====
    public static Balances getBalances(Id bookingId) {
        // Return current posted outstanding totals for one booking.
        if (bookingId == null) return new Balances();
        AggregateResult agg = [
            SELECT SUM(Principal_Amount__c) prin,
                   SUM(Interest_Amount__c) intr,
                   SUM(Tax_Amount__c)      tax
            FROM Ledger_Entry__c
            WHERE Booking__c = :bookingId
              AND Status__c  = :LedgerConst.STATUS_POSTED
        ];
        return new Balances(
            toMoney((Decimal)agg.get('prin')),
            toMoney((Decimal)agg.get('intr')),
            toMoney((Decimal)agg.get('tax'))
        );
    }
    public static Map<Id, Balances> getBalances(Set<Id> bookingIds) {
        // Bulk variant used to avoid one-query-per-booking.
        Map<Id, Balances> out = new Map<Id, Balances>();
        if (bookingIds == null || bookingIds.isEmpty()) return out;
        for (AggregateResult ar : [
            SELECT Booking__c b,
                   SUM(Principal_Amount__c) prin,
                   SUM(Interest_Amount__c) intr,
                   SUM(Tax_Amount__c)      tax
            FROM Ledger_Entry__c
            WHERE Booking__c IN :bookingIds
              AND Status__c  = :LedgerConst.STATUS_POSTED
            GROUP BY Booking__c
        ]) {
            Id b = (Id)ar.get('b');
            out.put(b, new Balances(
                toMoney((Decimal)ar.get('prin')),
                toMoney((Decimal)ar.get('intr')),
                toMoney((Decimal)ar.get('tax'))
            ));
        }
        for (Id bId : bookingIds) if (!out.containsKey(bId)) out.put(bId, new Balances());
        return out;
    }

    // ===== ACCRUAL (builder + wrapper) =====
    // Wrapper kept for compatibility; uses bulk-safe builder and single insert.
    public static List<Ledger_Entry__c> postAccrual(Booking__c booking,
                                                    Booking_Payment_Schedule__c sched,
                                                    Date fromDate,
                                                    Date toDate) {
        // Guardrails: if required context is missing, no-op.
        if (booking == null || sched == null || toDate == null) return new List<Ledger_Entry__c>();
        FinanceConfig finance = requireFinanceConfig(sched);
        BookingContext ctx = getBookingContext(booking.Id, booking);

        // Compute accrual window from due date/grace and previously accrued end date.
        Integer g = finance.graceDays == null ? 0 : finance.graceDays;
        Date naturalStart = (sched.Payment_Due_Date__c == null)
            ? toDate
            : sched.Payment_Due_Date__c.addDays(Math.max(0, g) + 1);
        Date startDate = fromDate == null ? naturalStart : fromDate.addDays(1);
        if (startDate > toDate) return new List<Ledger_Entry__c>();

        Integer days = startDate.daysBetween(toDate) + 1;
        if (days <= 0) return new List<Ledger_Entry__c>();

        String bucket = bucketFor(sched);
        Decimal dailyRate = (finance.annualRate == null ? 0 : (finance.annualRate / 100) / 365);
        if (dailyRate == 0) return new List<Ledger_Entry__c>();

        // Compute principal outstanding once via aggregate posted principal.
        AggregateResult ar = [
            SELECT SUM(Principal_Amount__c) prin
            FROM Ledger_Entry__c
            WHERE Schedule__c = :sched.Id
              AND Status__c   = :LedgerConst.STATUS_POSTED
        ];
        Decimal basePrin = (sched.Installment_Amount__c == null ? 0 : sched.Installment_Amount__c);
        Decimal prinSum  = toMoney((Decimal)ar.get('prin'));
        Decimal principalOutstanding = toMoney(basePrin + prinSum);
        if (principalOutstanding <= 0) return new List<Ledger_Entry__c>();

        // Split base principal and possession-related other charges for tax treatment.
        Boolean isPossession = isPossessionMilestone(sched);
        Decimal otherOutstanding = resolveOtherChargesOutstanding(
            isPossession, ctx.otherCharges, principalOutstanding
        );
        Decimal baseOutstanding = toMoney(principalOutstanding - otherOutstanding);
        Decimal baseTaxRate = isPossession ? 0 : (ctx.ocReceived ? 0 : 0.5);
        Decimal otherTaxRate = nz(finance.taxRate);
        Boolean splitOtherCharges = isPossession && otherOutstanding > 0;

        List<Ledger_Entry__c> built = buildAccrualEntries(
            booking.Id, sched.Id, bucket,
            startDate, toDate,
            baseOutstanding, otherOutstanding,
            finance.annualRate,
            baseTaxRate, otherTaxRate,
            splitOtherCharges
        );

        // Apply running balances & insert once
        Balances base = getBalances(booking.Id);
        applyRunningBalances(built, base);
        insert built;
        return built;
    }

    // Pure builder (no DML)
    private static List<Ledger_Entry__c> buildAccrualEntries(
        Id bookingId, Id scheduleId, String bucket,
        Date startDate, Date endDate,
        Decimal basePrincipalOutstanding,
        Decimal otherPrincipalOutstanding,
        Decimal annualRate,
        Decimal baseTaxRate,
        Decimal otherTaxRate,
        Boolean splitOtherCharges
    ){
        // Pure builder: creates in-memory accrual/tax rows only, no DML here.
        List<Ledger_Entry__c> out = new List<Ledger_Entry__c>();
        Integer days = startDate.daysBetween(endDate) + 1;
        if (days <= 0) return out;

        Decimal dailyRate = (annualRate == null ? 0 : (annualRate / 100) / 365);
        if (dailyRate == 0) return out;

        Decimal appliedRate = annualRate == null ? 0 : annualRate.setScale(4, RoundingMode.HALF_UP);
        Decimal baseInterest = toMoney(nz(basePrincipalOutstanding) * dailyRate * days);
        Decimal otherInterest = toMoney(nz(otherPrincipalOutstanding) * dailyRate * days);

        // Base-principal interest accrual (+ optional tax accrual).
        if (baseInterest != 0) {
            Ledger_Entry__c i = new Ledger_Entry__c();
            i.Booking__c = bookingId;
            i.Schedule__c = scheduleId;
            i.Entry_Date__c = endDate;
            i.Period_Start__c = startDate;
            i.Period_End__c   = endDate;
            i.Type__c = (bucket == LedgerConst.BUCKET_OTHER)
                ? LedgerConst.TYPE_INTEREST_ACCRUAL_OTHER
                : LedgerConst.TYPE_INTEREST_ACCRUAL_BASIC;
            i.Bucket__c = bucket;
            i.Source__c = LedgerConst.SOURCE_ACCRUAL;
            i.Status__c = LedgerConst.STATUS_POSTED;
            i.Interest_Amount__c = baseInterest;
            i.Applied_Interest_Rate__c = appliedRate;
            if (splitOtherCharges) {
                i.Description__c = 'Interest on principal (excluding other charges)';
            }
            out.add(i);

            if (baseTaxRate != null && baseTaxRate > 0) {
                Decimal taxAmount = toMoney(baseInterest * (baseTaxRate / 100));
                if (taxAmount != 0) {
                    Ledger_Entry__c t = new Ledger_Entry__c();
                    t.Booking__c = bookingId;
                    t.Schedule__c = scheduleId;
                    t.Entry_Date__c = endDate;
                    t.Period_Start__c = startDate;
                    t.Period_End__c   = endDate;
                    t.Type__c = (bucket == LedgerConst.BUCKET_OTHER)
                        ? LedgerConst.TYPE_INTEREST_TAX_ACCRUAL_OTHER
                        : LedgerConst.TYPE_INTEREST_TAX_ACCRUAL_BASIC;
                    t.Bucket__c = bucket;
                    t.Source__c = LedgerConst.SOURCE_ACCRUAL;
                    t.Status__c = LedgerConst.STATUS_POSTED;
                    t.Tax_Amount__c = taxAmount;
                    t.Applied_Interest_Rate__c = appliedRate;
                    t.Applied_Tax_Rate__c = baseTaxRate.setScale(2, RoundingMode.HALF_UP);
                    out.add(t);
                }
            }
        }

        // Other-charges interest accrual (+ optional tax accrual).
        if (otherInterest != 0) {
            Ledger_Entry__c oi = new Ledger_Entry__c();
            oi.Booking__c = bookingId;
            oi.Schedule__c = scheduleId;
            oi.Entry_Date__c = endDate;
            oi.Period_Start__c = startDate;
            oi.Period_End__c   = endDate;
            oi.Type__c = (bucket == LedgerConst.BUCKET_OTHER)
                ? LedgerConst.TYPE_INTEREST_ACCRUAL_OTHER
                : LedgerConst.TYPE_INTEREST_ACCRUAL_BASIC;
            oi.Bucket__c = bucket;
            oi.Source__c = LedgerConst.SOURCE_ACCRUAL;
            oi.Status__c = LedgerConst.STATUS_POSTED;
            oi.Interest_Amount__c = otherInterest;
            oi.Applied_Interest_Rate__c = appliedRate;
            oi.Description__c = 'Interest on other charges';
            out.add(oi);

            if (otherTaxRate != null && otherTaxRate > 0) {
                Decimal otherTaxAmount = toMoney(otherInterest * (otherTaxRate / 100));
                if (otherTaxAmount != 0) {
                    Ledger_Entry__c ot = new Ledger_Entry__c();
                    ot.Booking__c = bookingId;
                    ot.Schedule__c = scheduleId;
                    ot.Entry_Date__c = endDate;
                    ot.Period_Start__c = startDate;
                    ot.Period_End__c   = endDate;
                    ot.Type__c = (bucket == LedgerConst.BUCKET_OTHER)
                        ? LedgerConst.TYPE_INTEREST_TAX_ACCRUAL_OTHER
                        : LedgerConst.TYPE_INTEREST_TAX_ACCRUAL_BASIC;
                    ot.Bucket__c = bucket;
                    ot.Source__c = LedgerConst.SOURCE_ACCRUAL;
                    ot.Status__c = LedgerConst.STATUS_POSTED;
                    ot.Tax_Amount__c = otherTaxAmount;
                    ot.Applied_Interest_Rate__c = appliedRate;
                    ot.Applied_Tax_Rate__c = otherTaxRate.setScale(2, RoundingMode.HALF_UP);
                    ot.Description__c = 'Tax on interest - other charges';
                    out.add(ot);
                }
            }
        }
        return out;
    }

    // ===== RECEIPT (bulk-safe internally) =====
    public static List<Ledger_Entry__c> postReceipt(Booking__c booking,
                                                    Payment_Receipt__c receipt,
                                                    List<Booking_Payment_Schedule__c> openSchedules) {
        // Guardrails: missing booking/receipt means no posting.
        if (booking == null || receipt == null) return new List<Ledger_Entry__c>();
        Id bookingId = booking.Id;
        BookingContext ctx = getBookingContext(bookingId, booking);

        // 1) Resolve ordered schedules for booking (cached)
        List<Booking_Payment_Schedule__c> allSchedules = fetchSchedules(bookingId);
        Set<Id> targetIds = new Set<Id>();
        if (openSchedules != null) for (Booking_Payment_Schedule__c s : openSchedules) if (s != null && s.Id != null) targetIds.add(s.Id);

        List<Booking_Payment_Schedule__c> ordered = new List<Booking_Payment_Schedule__c>();
        for (Booking_Payment_Schedule__c s : allSchedules) if (targetIds.isEmpty() || targetIds.contains(s.Id)) ordered.add(s);
        if (ordered.isEmpty()) ordered = allSchedules;

        if (ordered.isEmpty()) return new List<Ledger_Entry__c>();

        Date receiptDate = (receipt.Date_Of_Payment__c == null) ? Date.today() : receipt.Date_Of_Payment__c;

        // 2) Pre-aggregate current posted principal/interest/tax by schedule.
        Set<Id> ordIds = new Set<Id>(); for (Booking_Payment_Schedule__c s : ordered) ordIds.add(s.Id);
        Map<Id, AggregateResult> postedBySchedule = new Map<Id, AggregateResult>();
        if (!ordIds.isEmpty()){
            for (AggregateResult ar : [
                SELECT Schedule__c sid,
                       SUM(Principal_Amount__c) prin,
                       SUM(Interest_Amount__c) intr,
                       SUM(Tax_Amount__c)      tax
                FROM Ledger_Entry__c
                WHERE Schedule__c IN :ordIds
                  AND Status__c   = :LedgerConst.STATUS_POSTED
                GROUP BY Schedule__c
            ]) {
                postedBySchedule.put((Id)ar.get('sid'), ar);
            }
        }

        // 3) Read accrual state: last accrued date and "already accrued today" marker.
        Map<Id, Date> lastAccrualEndBySchedule = new Map<Id, Date>();
        Set<Id> accrualAlreadyPosted = new Set<Id>();
        if (!ordIds.isEmpty()){
            for (AggregateResult ar : [
                SELECT Schedule__c sid, MAX(Period_End__c) pe
                FROM Ledger_Entry__c
                WHERE Booking__c  = :bookingId
                  AND Source__c   = :LedgerConst.SOURCE_ACCRUAL
                  AND Status__c   = :LedgerConst.STATUS_POSTED
                  AND Schedule__c IN :ordIds
                GROUP BY Schedule__c
            ]) {
                lastAccrualEndBySchedule.put((Id)ar.get('sid'), (Date)ar.get('pe'));
            }
            for (AggregateResult ar2 : [
                SELECT Schedule__c sid
                FROM Ledger_Entry__c
                WHERE Booking__c  = :bookingId
                  AND Source__c   = :LedgerConst.SOURCE_ACCRUAL
                  AND Status__c   = :LedgerConst.STATUS_POSTED
                  AND Entry_Date__c = :receiptDate
                  AND Schedule__c IN :ordIds
                GROUP BY Schedule__c
            ]) {
                accrualAlreadyPosted.add((Id)ar2.get('sid'));
            }
        }

        // 4) For touched overdue schedules, build missing accruals up to receipt date.
        List<Ledger_Entry__c> accrualToInsert = new List<Ledger_Entry__c>();

        Decimal remInterest  = toMoney(receipt.Interest_Applied__c);
        Decimal remTax       = toMoney(receipt.Tax_on_Interest__c);
        Decimal remPrincipal = toMoney(receipt.Principal_Applied__c);

        for (Booking_Payment_Schedule__c sched : ordered) {
            // Stop early when receipt split has no remaining amount to consume.
            if (sched == null || sched.Payment_Due_Date__c == null) continue;
            if (remInterest <= 0 && remTax <= 0 && remPrincipal <= 0) break;

            // Accrual starts only after due date + grace.
            Integer g = (sched.Grace_Period_Days__c == null) ? 0 : Integer.valueOf(sched.Grace_Period_Days__c);
            Date graceEnd = sched.Payment_Due_Date__c.addDays(Math.max(0, g));
            if (receiptDate <= graceEnd) continue;

            AggregateResult ar = postedBySchedule.get(sched.Id);
            Decimal prinDue = toMoney((sched.Installment_Amount__c == null ? 0 : sched.Installment_Amount__c)
                                      + toMoney((Decimal)(ar == null ? 0 : ar.get('prin'))));
            if (prinDue < 0) prinDue = 0;
            Decimal intrDue = toMoney((Decimal)(ar == null ? 0 : ar.get('intr'))); if (intrDue < 0) intrDue = 0;
            Decimal taxDue  = toMoney((Decimal)(ar == null ? 0 : ar.get('tax')));  if (taxDue  < 0) taxDue  = 0;

            // Preview incremental accrual up to receipt date (no additional SOQL).
            Date lastEnd = lastAccrualEndBySchedule.get(sched.Id);
            Decimal basePrin = (sched.Installment_Amount__c == null ? 0 : sched.Installment_Amount__c);
            Decimal prinSum  = toMoney((Decimal)(ar == null ? 0 : ar.get('prin')));
            Decimal principalOutstanding = toMoney(Math.max(0, basePrin + prinSum));

            AccrualPreview prev = previewAccrualToDate_NoSOQL(
                sched, receiptDate, lastEnd, principalOutstanding, ctx.ocReceived, ctx.otherCharges
            );

            Decimal intrDueToReceipt = toMoney(intrDue + prev.interest);
            Decimal taxDueToReceipt  = toMoney(taxDue  + prev.tax);

            Boolean touches = (remInterest > 0 && intrDueToReceipt > 0)
                           || (remTax     > 0 && taxDueToReceipt  > 0)
                           || (remPrincipal > 0 && prinDue > 0);
            if (!touches) continue;

            // Insert accrual only if there is missing period and not already inserted for this date.
            Boolean needAccrual =
                (prev.interest > 0 || prev.tax > 0) &&
                (lastEnd == null || lastEnd < receiptDate) &&
                !accrualAlreadyPosted.contains(sched.Id);

            if (needAccrual) {
                FinanceConfig cfg = requireFinanceConfig(sched);
                String bucket = bucketFor(sched);
                Boolean isPossession = isPossessionMilestone(sched);
                Decimal otherOutstanding = resolveOtherChargesOutstanding(isPossession, ctx.otherCharges, principalOutstanding);
                Decimal baseOutstanding = toMoney(principalOutstanding - otherOutstanding);
                Decimal baseTaxRate = isPossession ? 0 : (ctx.ocReceived ? 0 : 0.5);
                Decimal otherTaxRate = nz(cfg.taxRate);
                Boolean splitOtherCharges = isPossession && otherOutstanding > 0;

                // Start accrual from the next unaccrued day.
                Date naturalStart = sched.Payment_Due_Date__c.addDays((sched.Grace_Period_Days__c == null ? 0 : Integer.valueOf(sched.Grace_Period_Days__c)) + 1);
                Date startDate = (lastEnd == null) ? naturalStart : lastEnd.addDays(1);
                if (startDate <= receiptDate) {
                    accrualToInsert.addAll(
                        buildAccrualEntries(
                            bookingId, sched.Id, bucket,
                            startDate, receiptDate,
                            baseOutstanding,
                            otherOutstanding,
                            cfg.annualRate,
                            baseTaxRate,
                            otherTaxRate,
                            splitOtherCharges
                        )
                    );
                    // mark as posted for this date to avoid duplicates in same pass
                    accrualAlreadyPosted.add(sched.Id);
                }
            }

            // Consume receipt splits in order so downstream schedules only get remaining value.
            Decimal takeIntrIncl = Math.min(remInterest, intrDueToReceipt);
            remInterest = toMoney(remInterest - takeIntrIncl);
            intrDueToReceipt = toMoney(intrDueToReceipt - takeIntrIncl);

            Decimal takeTaxIncl = Math.min(remTax, taxDueToReceipt);
            remTax = toMoney(remTax - takeTaxIncl);
            taxDueToReceipt = toMoney(taxDueToReceipt - takeTaxIncl);

            if (intrDueToReceipt == 0 && taxDueToReceipt == 0) {
                Decimal takePrin = Math.min(remPrincipal, prinDue);
                remPrincipal = toMoney(remPrincipal - takePrin);
                prinDue = toMoney(prinDue - takePrin);
            }
        }

        if (!accrualToInsert.isEmpty()) {
            // Persist all computed accruals in one DML after running-balance enrichment.
            Balances baseForAccrual = getBalances(bookingId);
            applyRunningBalances(accrualToInsert, baseForAccrual);
            insert accrualToInsert;

            // Refresh schedule totals so subsequent receipt posting sees latest state.
            postedBySchedule.clear();
            for (AggregateResult ar2 : [
                SELECT Schedule__c sid,
                       SUM(Principal_Amount__c) prin,
                       SUM(Interest_Amount__c) intr,
                       SUM(Tax_Amount__c)      tax
                FROM Ledger_Entry__c
                WHERE Schedule__c IN :ordIds
                  AND Status__c   = :LedgerConst.STATUS_POSTED
                GROUP BY Schedule__c
            ]) {
                postedBySchedule.put((Id)ar2.get('sid'), ar2);
            }
        }

        // 5) Build schedule snapshots reflecting latest outstanding amounts.
        Map<Id, ScheduleSnapshot> snapshots = buildSnapshots(booking, ordered);
        Map<Id, Booking_Payment_Schedule__c> orderedById = new Map<Id, Booking_Payment_Schedule__c>();
        for (Booking_Payment_Schedule__c s : ordered) orderedById.put(s.Id, s);

        // 6) Allocate user-provided receipt split across schedules in order.
        Map<Id, Decimal> interestAlloc  = allocate(receipt.Interest_Applied__c,  ordered, snapshots, AllocationKind.INTEREST);
        Map<Id, Decimal> taxAlloc       = allocate(receipt.Tax_on_Interest__c,   ordered, snapshots, AllocationKind.TAX);
        Map<Id, Decimal> principalAlloc = allocate(receipt.Principal_Applied__c, ordered, snapshots, AllocationKind.PRINCIPAL);

        // 7) Convert allocations into receipt ledger rows (negative because they reduce dues).
        Date entryDate = receiptDate;
        List<Ledger_Entry__c> receiptEntries = new List<Ledger_Entry__c>();

        for (Id sid : interestAlloc.keySet()) {
            Decimal amt = toMoney(interestAlloc.get(sid)); if (amt <= 0) continue;
            ScheduleSnapshot snap = snapshots.get(sid);
            Ledger_Entry__c e = baseReceiptEntry(bookingId, sid, receipt.Id, entryDate, snap);
            e.Type__c = LedgerConst.TYPE_INTEREST_RECEIPT;
            e.Interest_Amount__c = negate(amt);
            receiptEntries.add(e);
        }
        for (Id sid : taxAlloc.keySet()) {
            Decimal amt = toMoney(taxAlloc.get(sid)); if (amt <= 0) continue;
            ScheduleSnapshot snap = snapshots.get(sid);
            Ledger_Entry__c e = baseReceiptEntry(bookingId, sid, receipt.Id, entryDate, snap);
            e.Type__c = LedgerConst.TYPE_INTEREST_TAX_RECEIPT;
            e.Tax_Amount__c = negate(amt);
            receiptEntries.add(e);
        }
        for (Id sid : principalAlloc.keySet()) {
            Decimal amt = toMoney(principalAlloc.get(sid)); if (amt <= 0) continue;
            ScheduleSnapshot snap = snapshots.get(sid);
            Ledger_Entry__c e = baseReceiptEntry(bookingId, sid, receipt.Id, entryDate, snap);
            e.Type__c = LedgerConst.TYPE_PRINCIPAL_RECEIPT;
            e.Principal_Amount__c = negate(amt);
            receiptEntries.add(e);
        }

        // 8) Allocate excess as additional principal sequentially across remaining due schedules.
        Decimal excess = toMoney(nz(receipt.Excess_Payment__c));
        if (excess > 0) {
            Decimal excessRemaining = excess;
            Map<Id, Decimal> excessAlloc = new Map<Id, Decimal>();

            // First pass: distribute excess only up to remaining due per schedule.
            for (Booking_Payment_Schedule__c s : ordered) {
                if (excessRemaining <= 0) break;
                if (s == null) continue;
                ScheduleSnapshot snap = snapshots.get(s.Id);
                Decimal due = (snap == null) ? 0 : toMoney(snap.principalOutstanding);
                Decimal principalUsed = principalAlloc.containsKey(s.Id) ? toMoney(principalAlloc.get(s.Id)) : 0;
                Decimal alreadyExcess = excessAlloc.containsKey(s.Id) ? toMoney(excessAlloc.get(s.Id)) : 0;
                Decimal remainingDue = toMoney(due - principalUsed - alreadyExcess);
                if (remainingDue <= 0) continue;

                Decimal take = toMoney(Math.min(excessRemaining, remainingDue));
                if (take <= 0) continue;
                excessAlloc.put(s.Id, toMoney(alreadyExcess + take));
                excessRemaining = toMoney(excessRemaining - take);
            }

            // If all schedules are fully covered, keep leftover as advance on the last schedule.
            if (excessRemaining > 0 && !ordered.isEmpty()) {
                Id lastId = ordered[ordered.size()-1].Id;
                Decimal cur = excessAlloc.containsKey(lastId) ? toMoney(excessAlloc.get(lastId)) : 0;
                excessAlloc.put(lastId, toMoney(cur + excessRemaining));
            }

            List<Ledger_Entry__c> excessAccrualToInsert = new List<Ledger_Entry__c>();
            // Ensure overdue schedules receiving excess have accrual posted up to receipt date.
            for (Booking_Payment_Schedule__c s : ordered) {
                if (s == null || !excessAlloc.containsKey(s.Id)) continue;
                Booking_Payment_Schedule__c targetSched = orderedById.get(s.Id);
                if (targetSched == null || targetSched.Payment_Due_Date__c == null || receiptDate == null) continue;

                Integer g = (targetSched.Grace_Period_Days__c == null) ? 0 : Integer.valueOf(targetSched.Grace_Period_Days__c);
                Date graceEnd = targetSched.Payment_Due_Date__c.addDays(Math.max(0, g));
                if (receiptDate <= graceEnd || accrualAlreadyPosted.contains(s.Id)) continue;

                AggregateResult ar = postedBySchedule.get(s.Id);
                Decimal basePrin = (targetSched.Installment_Amount__c == null ? 0 : targetSched.Installment_Amount__c);
                Decimal prinSum  = toMoney((Decimal)(ar == null ? 0 : ar.get('prin')));
                Decimal principalOutstanding = toMoney(Math.max(0, basePrin + prinSum));
                Date lastEnd = lastAccrualEndBySchedule.get(s.Id);
                AccrualPreview prev = previewAccrualToDate_NoSOQL(
                    targetSched, receiptDate, lastEnd, principalOutstanding, ctx.ocReceived, ctx.otherCharges
                );
                Boolean needAccrual =
                    (prev.interest > 0 || prev.tax > 0) &&
                    (lastEnd == null || lastEnd < receiptDate);

                if (!needAccrual) continue;

                FinanceConfig cfg = requireFinanceConfig(targetSched);
                String bucket = bucketFor(targetSched);
                Date naturalStart = targetSched.Payment_Due_Date__c.addDays(
                    (targetSched.Grace_Period_Days__c == null ? 0 : Integer.valueOf(targetSched.Grace_Period_Days__c)) + 1
                );
                Date startDate = (lastEnd == null) ? naturalStart : lastEnd.addDays(1);
                if (startDate > receiptDate) continue;

                Boolean isPossession = isPossessionMilestone(targetSched);
                Decimal otherOutstanding = resolveOtherChargesOutstanding(isPossession, ctx.otherCharges, principalOutstanding);
                Decimal baseOutstanding = toMoney(principalOutstanding - otherOutstanding);
                Decimal baseTaxRate = isPossession ? 0 : (ctx.ocReceived ? 0 : 0.5);
                Decimal otherTaxRate = nz(cfg.taxRate);
                Boolean splitOtherCharges = isPossession && otherOutstanding > 0;

                excessAccrualToInsert.addAll(
                    buildAccrualEntries(
                        bookingId, s.Id, bucket,
                        startDate, receiptDate,
                        baseOutstanding,
                        otherOutstanding,
                        cfg.annualRate,
                        baseTaxRate,
                        otherTaxRate,
                        splitOtherCharges
                    )
                );
                accrualAlreadyPosted.add(s.Id);
            }

            if (!excessAccrualToInsert.isEmpty()) {
                // Persist any additional accruals required by excess allocation.
                Balances baseForExtra = getBalances(bookingId);
                applyRunningBalances(excessAccrualToInsert, baseForExtra);
                insert excessAccrualToInsert;
            }

            // Create principal receipt rows for each excess allocation bucket.
            for (Booking_Payment_Schedule__c s : ordered) {
                if (s == null || !excessAlloc.containsKey(s.Id)) continue;
                Decimal amt = toMoney(excessAlloc.get(s.Id));
                if (amt <= 0) continue;
                ScheduleSnapshot snap = snapshots.get(s.Id);
                Ledger_Entry__c adv = baseReceiptEntry(bookingId, s.Id, receipt.Id, entryDate, snap);
                adv.Type__c = LedgerConst.TYPE_PRINCIPAL_RECEIPT;
                adv.Principal_Amount__c = negate(amt);
                adv.Description__c = 'Excess carry-forward applied as advance to next schedule';
                receiptEntries.add(adv);
            }
        }

        if (receiptEntries.isEmpty()) return receiptEntries;

        // Final insert for receipt-side entries with current running balance baseline.
        Balances baseForReceipt = getBalances(bookingId);
        applyRunningBalances(receiptEntries, baseForReceipt);
        insert receiptEntries;

        return receiptEntries;
    }

    // ===== REVERSAL (bulk) =====
    public static List<Ledger_Entry__c> reverseReceipt(Payment_Receipt__c receipt) {
        // Reverse all posted non-reversal rows linked to this receipt.
        if (receipt == null) return new List<Ledger_Entry__c>();
        List<Ledger_Entry__c> originals = [
            SELECT Id, Booking__c, Schedule__c, Bucket__c,
                   Principal_Amount__c, Interest_Amount__c, Tax_Amount__c,
                   Applied_Interest_Rate__c, Applied_Tax_Rate__c
            FROM Ledger_Entry__c
            WHERE Payment_Receipt__c = :receipt.Id
              AND Status__c          = :LedgerConst.STATUS_POSTED
              AND Type__c           != :LedgerConst.TYPE_REVERSAL
            FOR UPDATE
        ];
        if (originals.isEmpty()) return new List<Ledger_Entry__c>();

        Id bookingId = originals[0].Booking__c;
        Balances base = getBalances(bookingId);
        Date entryDate = Date.today();

        List<Ledger_Entry__c> reversals = new List<Ledger_Entry__c>();
        List<Ledger_Entry__c> updates   = new List<Ledger_Entry__c>();
        for (Ledger_Entry__c o : originals) {
            // Mirror original amounts with opposite sign and mark original as reversed.
            Ledger_Entry__c r = new Ledger_Entry__c();
            r.Booking__c = o.Booking__c;
            r.Schedule__c = o.Schedule__c;
            r.Payment_Receipt__c = receipt.Id;
            r.Entry_Date__c = entryDate;
            r.Type__c   = LedgerConst.TYPE_REVERSAL;
            r.Bucket__c = o.Bucket__c;
            r.Source__c = LedgerConst.SOURCE_REVERSAL;
            r.Status__c = LedgerConst.STATUS_POSTED;
            r.Reverses_Ledger__c = o.Id;
            r.Principal_Amount__c = negate(o.Principal_Amount__c);
            r.Interest_Amount__c  = negate(o.Interest_Amount__c);
            r.Tax_Amount__c       = negate(o.Tax_Amount__c);
            r.Applied_Interest_Rate__c = o.Applied_Interest_Rate__c;
            r.Applied_Tax_Rate__c      = o.Applied_Tax_Rate__c;
            r.Description__c = 'Reversal of entry ' + o.Id;
            reversals.add(r);

            updates.add(new Ledger_Entry__c(Id = o.Id, Status__c = LedgerConst.STATUS_REVERSED));
        }

        // Keep running balance continuity on inserted reversal rows.
        applyRunningBalances(reversals, base);
        insert reversals;
        update updates;
        return reversals;
    }

    // ===== Preview accrual (no SOQL) =====
    private static AccrualPreview previewAccrualToDate_NoSOQL(
        Booking_Payment_Schedule__c sched,
        Date receiptDate,
        Date lastAccrualEnd,
        Decimal principalOutstanding,
        Boolean ocReceived,
        Decimal otherChargesTotal
    ){
        // Lightweight accrual preview for decisioning without extra queries.
        if (sched == null || receiptDate == null || sched.Payment_Due_Date__c == null) return new AccrualPreview(0,0);
        Integer g = (sched.Grace_Period_Days__c == null) ? 0 : Integer.valueOf(sched.Grace_Period_Days__c);
        Date naturalStart = sched.Payment_Due_Date__c.addDays(Math.max(0, g) + 1);
        if (receiptDate < naturalStart) return new AccrualPreview(0,0);

        Date startDate = (lastAccrualEnd == null) ? naturalStart : lastAccrualEnd.addDays(1);
        if (startDate > receiptDate) return new AccrualPreview(0,0);

        Integer days = startDate.daysBetween(receiptDate) + 1;
        if (days <= 0) return new AccrualPreview(0,0);

        Decimal annualRate = nz(sched.Annual_Interest_Rate__c);
        Decimal dailyRate  = (annualRate / 100) / 365;
        if (dailyRate == 0 || principalOutstanding <= 0) return new AccrualPreview(0,0);

        Boolean isPossession = isPossessionMilestone(sched);
        Decimal otherOutstanding = resolveOtherChargesOutstanding(isPossession, otherChargesTotal, principalOutstanding);
        Decimal baseOutstanding = toMoney(principalOutstanding - otherOutstanding);

        Decimal baseInterest = toMoney(baseOutstanding * dailyRate * days);
        Decimal otherInterest = toMoney(otherOutstanding * dailyRate * days);

        Decimal baseTaxRate = isPossession ? 0 : (ocReceived == true ? 0 : 0.5);
        Decimal otherTaxRate = nz(sched.GST_VAT_Rate_On_Interest__c);

        Decimal baseTax = (baseTaxRate > 0 && baseInterest != 0)
            ? toMoney(baseInterest * (baseTaxRate / 100))
            : 0;
        Decimal otherTax = (otherTaxRate > 0 && otherInterest != 0)
            ? toMoney(otherInterest * (otherTaxRate / 100))
            : 0;

        return new AccrualPreview(toMoney(baseInterest + otherInterest), toMoney(baseTax + otherTax));
    }

    // ===== Snapshots / allocation =====
    private static Map<Id, ScheduleSnapshot> buildSnapshots(Booking__c booking,
                                                            List<Booking_Payment_Schedule__c> schedules) {
        // Snapshot = outstanding principal/interest/tax used for allocation decisions.
        Map<Id, ScheduleSnapshot> snapshots = new Map<Id, ScheduleSnapshot>();
        if (schedules == null || schedules.isEmpty()) return snapshots;

        Set<Id> scheduleIds = new Set<Id>(); for (Booking_Payment_Schedule__c s : schedules) scheduleIds.add(s.Id);
        Map<Id, AggregateResult> agg = new Map<Id, AggregateResult>();
        for (AggregateResult ar : [
            SELECT Schedule__c sid,
                   SUM(Principal_Amount__c) prin,
                   SUM(Interest_Amount__c) intr,
                   SUM(Tax_Amount__c)      tax
            FROM Ledger_Entry__c
            WHERE Schedule__c IN :scheduleIds
              AND Status__c   IN (:LedgerConst.STATUS_POSTED, :LedgerConst.STATUS_REVERSED)
            GROUP BY Schedule__c
        ]) {
            agg.put((Id)ar.get('sid'), ar);
        }

        for (Booking_Payment_Schedule__c s : schedules) {
            ScheduleSnapshot snap = new ScheduleSnapshot();
            snap.scheduleId = s.Id;
            snap.bucket = isPossessionMilestone(s) ? LedgerConst.BUCKET_OTHER : LedgerConst.BUCKET_BASIC;

            AggregateResult ar = agg.get(s.Id);
            Decimal prinSum = ar == null ? 0 : (Decimal)ar.get('prin');
            Decimal intrSum = ar == null ? 0 : (Decimal)ar.get('intr');
            Decimal taxSum  = ar == null ? 0 : (Decimal)ar.get('tax');

            Decimal basePrincipal = s.Installment_Amount__c == null ? 0 : s.Installment_Amount__c;
            snap.principalOutstanding = toMoney(basePrincipal + toMoney(prinSum));
            if (snap.principalOutstanding < 0) snap.principalOutstanding = 0;

            snap.interestOutstanding = toMoney(intrSum);
            snap.taxOutstanding      = toMoney(taxSum);

            snapshots.put(s.Id, snap);
        }
        return snapshots;
    }

    private static Map<Id, Decimal> allocate(Decimal amount,
                                             List<Booking_Payment_Schedule__c> ordered,
                                             Map<Id, ScheduleSnapshot> snapshots,
                                             AllocationKind kind) {
        // Allocate amount in schedule order; overflow (if any) goes to last schedule.
        Map<Id, Decimal> out = new Map<Id, Decimal>();
        Decimal remaining = toMoney(amount);
        if (remaining <= 0 || ordered == null || ordered.isEmpty()) return out;

        for (Booking_Payment_Schedule__c s : ordered) {
            if (remaining <= 0) break;
            ScheduleSnapshot snap = snapshots.get(s.Id);
            Decimal available = getOutstanding(snap, kind);
            if (available <= 0) continue;

            Decimal take = Math.min(remaining, available);
            take = toMoney(take);
            if (take <= 0) continue;

            out.put(s.Id, take);
            remaining = toMoney(remaining - take);
        }
        if (remaining > 0) {
            Booking_Payment_Schedule__c last = ordered[ordered.size()-1];
            Decimal cur = out.containsKey(last.Id) ? out.get(last.Id) : 0;
            out.put(last.Id, toMoney(cur + remaining));
        }
        return out;
    }

    private static Decimal getOutstanding(ScheduleSnapshot snap, AllocationKind kind) {
        if (snap == null) return 0;
        if (kind == AllocationKind.PRINCIPAL) return snap.principalOutstanding;
        if (kind == AllocationKind.INTEREST)  return (snap.interestOutstanding > 0 ? snap.interestOutstanding : 0);
        return (snap.taxOutstanding > 0 ? snap.taxOutstanding : 0);
    }

    // ===== Misc helpers =====
    private static Ledger_Entry__c baseReceiptEntry(Id bookingId, Id scheduleId, Id receiptId, Date entryDate, ScheduleSnapshot snap) {
        // Common receipt-row defaults.
        Ledger_Entry__c e = new Ledger_Entry__c();
        e.Booking__c = bookingId;
        e.Schedule__c = scheduleId;
        e.Payment_Receipt__c = receiptId;
        e.Entry_Date__c = entryDate;
        e.Source__c = LedgerConst.SOURCE_RECEIPT;
        e.Status__c = LedgerConst.STATUS_POSTED;
        e.Bucket__c = (snap == null ? LedgerConst.BUCKET_BASIC : snap.bucket);
        return e;
    }
    private static BookingContext getBookingContext(Id bookingId, Booking__c bookingMaybe) {
        // Resolve contextual flags/amounts used in accrual math and cache for this transaction.
        if (bookingId == null) return new BookingContext(false, 0);
        if (bookingContextCache.containsKey(bookingId)) return bookingContextCache.get(bookingId);

        Booking__c b = null;
        List<Booking__c> bookings = [
            SELECT Id, Opportunity_Id__c, OC_Received__c, Project__c, Project__r.OC_Received__c
            FROM Booking__c
            WHERE Id = :bookingId
            LIMIT 1
        ];
        if (!bookings.isEmpty()) {
            b = bookings[0];
        } else {
            BookingContext empty = new BookingContext(false, 0);
            bookingContextCache.put(bookingId, empty);
            return empty;
        }

        Boolean ocReceived = (b.Project__r != null && b.Project__r.OC_Received__c != null)
            ? b.Project__r.OC_Received__c
            : (b.OC_Received__c == null ? false : b.OC_Received__c);

        Decimal otherCharges = 0;
        if (b.Opportunity_Id__c != null) {
            List<Opportunity> opps = [
                SELECT Id, OtherCharges__c, TaxOnOtherCharges__c
                FROM Opportunity
                WHERE Id = :b.Opportunity_Id__c
                LIMIT 1
            ];
            if (!opps.isEmpty()) {
                Opportunity o = opps[0];
                otherCharges = nz(o.OtherCharges__c) + nz(o.TaxOnOtherCharges__c);
            }
        }

        BookingContext ctx = new BookingContext(ocReceived, otherCharges);
        bookingContextCache.put(bookingId, ctx);
        return ctx;
    }
    private static FinanceConfig requireFinanceConfig(Booking_Payment_Schedule__c s) {
        // Fail fast when finance attributes required for accrual are missing.
        if (s == null) throw new MissingFinanceDataException('Booking_Payment_Schedule__c is required');
        List<String> miss = new List<String>();
        Decimal r = s.Annual_Interest_Rate__c;
        Integer g = s.Grace_Period_Days__c == null ? null : Integer.valueOf(s.Grace_Period_Days__c);
        Decimal t = s.GST_VAT_Rate_On_Interest__c;
        if (r == null) miss.add('Annual_Interest_Rate__c');
        if (g == null) miss.add('Grace_Period_Days__c');
        if (t == null) miss.add('GST_VAT_Rate_On_Interest__c');
        if (!miss.isEmpty()) throw new MissingFinanceDataException('Schedule ' + (s.Id==null?'(unsaved)':String.valueOf(s.Id)) + ' missing: ' + String.join(miss, ', '));
        FinanceConfig fc = new FinanceConfig(); fc.annualRate=r; fc.graceDays=g; fc.taxRate=t; return fc;
    }
    private static List<Booking_Payment_Schedule__c> fetchSchedules(Id bookingId) {
        // Ordered schedule fetch (cached) drives deterministic allocation order.
        if (bookingId == null) return new List<Booking_Payment_Schedule__c>();
        if (!scheduleCache.containsKey(bookingId)) {
            scheduleCache.put(bookingId, [
                SELECT Id, Booking__c, Installment_Amount__c, Installment_Number__c, Payment_Due_Date__c,
                       Milestone_Code__c, Annual_Interest_Rate__c, Grace_Period_Days__c, GST_VAT_Rate_On_Interest__c
                FROM Booking_Payment_Schedule__c
                WHERE Booking__c = :bookingId
                ORDER BY Payment_Due_Date__c, Installment_Number__c, Id
            ]);
        }
        return scheduleCache.get(bookingId);
    }
    private static Decimal resolveOtherChargesOutstanding(Boolean isPossession, Decimal otherChargesTotal, Decimal principalOutstanding) {
        // Only possession milestone can split out other-charges component.
        if (!isPossession || otherChargesTotal == null || otherChargesTotal <= 0 || principalOutstanding == null || principalOutstanding <= 0) {
            return 0;
        }
        return toMoney(Math.min(otherChargesTotal, principalOutstanding));
    }
    private static void applyRunningBalances(List<Ledger_Entry__c> entries, Balances base) {
        // Derive per-row running outstanding balances from supplied baseline.
        Decimal rp = base == null ? 0 : base.prin;
        Decimal ri = base == null ? 0 : base.intr;
        Decimal rt = base == null ? 0 : base.tax;
        for (Ledger_Entry__c e : entries) {
            rp = toMoney(rp + nz(e.Principal_Amount__c));
            ri = toMoney(ri + nz(e.Interest_Amount__c));
            rt = toMoney(rt + nz(e.Tax_Amount__c));
            e.Running_Principal_Outstanding__c = rp;
            e.Running_Interest_Outstanding__c  = ri;
            e.Running_Tax_Outstanding__c       = rt;
        }
    }
    private static String bucketFor(Booking_Payment_Schedule__c s) {
        return isPossessionMilestone(s) ? LedgerConst.BUCKET_OTHER : LedgerConst.BUCKET_BASIC;
    }
    private static Boolean isPossessionMilestone(Booking_Payment_Schedule__c s) {
        return s != null && !String.isBlank(s.Milestone_Code__c)
             && 'on possession'.equalsIgnoreCase(s.Milestone_Code__c.trim());
    }

    // ===== math utils =====
    private static Decimal toMoney(Decimal v){ return (v==null?0:v).setScale(2, RoundingMode.HALF_UP); }
    private static Decimal nz(Decimal v){ return v==null?0:v; }
    private static Decimal negate(Decimal v){ return toMoney(nz(v) * -1); }

    @TestVisible static void resetScheduleCache(){
        scheduleCache.clear();
        bookingContextCache.clear();
    }
}