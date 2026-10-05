public with sharing class BookingInterestService {

    // ===== DTOs =====
    public class SnapshotDTO {
        @AuraEnabled public Id bookingId;
        @AuraEnabled public Decimal totalInstallmentAmount;
        @AuraEnabled public Decimal totalOutstandingPrincipal;
        @AuraEnabled public Decimal totalPrincipalReceived;
        @AuraEnabled public Decimal totalAdvanceApplied;
        @AuraEnabled public Decimal totalInterestTillToday;
        @AuraEnabled public Decimal totalInterestReceivedAllocated;
        @AuraEnabled public Decimal totalInterestOutstanding;
        @AuraEnabled public Decimal totalInterestWaived;
        @AuraEnabled public Decimal totalTaxOnInterestTillToday;
        @AuraEnabled public Decimal totalTaxOnInterestReceived;
        @AuraEnabled public Decimal totalTaxOnInterestOutstanding;
        @AuraEnabled public Integer scheduleCount;
        @AuraEnabled public Date nextDueDate;
        @AuraEnabled public Datetime asOfTimestamp;
        @AuraEnabled public Map<String, Decimal> debugRates;
        @AuraEnabled public List<ScheduleDTO> schedules;

        public SnapshotDTO() {
            schedules = new List<ScheduleDTO>();
            debugRates = new Map<String, Decimal>();
            asOfTimestamp = System.now();
        }
    }

    public class ScheduleDTO {
        @AuraEnabled public Id scheduleId;
        @AuraEnabled public Integer installmentNumber;
        @AuraEnabled public String milestoneCode;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public Decimal installmentAmount;
        @AuraEnabled public Decimal outstandingPrincipal;
        @AuraEnabled public Decimal principalReceived;
        @AuraEnabled public Decimal advanceApplied;
        @AuraEnabled public Decimal interestTillToday;
        @AuraEnabled public Decimal interestWaived;
        @AuraEnabled public Decimal interestReceivedAllocated;
        @AuraEnabled public Decimal interestOutstanding;
        @AuraEnabled public Decimal taxTillToday;
        @AuraEnabled public Decimal taxReceivedAllocated;
        @AuraEnabled public Decimal taxOutstanding;
        @AuraEnabled public Decimal otherCharges;
        @AuraEnabled public Decimal taxOnOtherCharges;
    }

    // ===== Public entrypoint =====
    @AuraEnabled(cacheable=true)
    public static SnapshotDTO calculateAsOf(Id bookingId) {
        if (bookingId == null) throw new AuraHandledException('bookingId is required');

        Date asOfDate = Date.today();
        String cacheKey = buildCacheKey(bookingId, asOfDate);
        SnapshotDTO cached = fetchFromCache(cacheKey);
        if (cached != null) return cached;

        SnapshotDTO snapshot = buildSnapshot(bookingId, asOfDate);
        storeInCache(cacheKey, snapshot);
        return snapshot;
    }

    public static SnapshotDTO snapshotFor(Id bookingId, Date asOfDate) {
        if (bookingId == null) throw new AuraHandledException('bookingId is required');
        Date effectiveDate = asOfDate == null ? Date.today() : asOfDate;
        return buildSnapshot(bookingId, effectiveDate);
    }

    // ===== Core: ledger totals + preview of unposted accrual to "today" =====
    private class Agg {
        Decimal prinSum = 0;   // sum of Principal_Amount__c (receipts negative; reversals positive)
        Decimal intAcc  = 0;   // posted interest accruals
        Decimal intRcv  = 0;   // posted interest receipts (negative) + reversals (positive)
        Decimal taxAcc  = 0;   // posted tax accruals
        Decimal taxRcv  = 0;   // posted tax receipts (negative) + reversals (positive)
    }

    private static SnapshotDTO buildSnapshot(Id bookingId, Date asOfDate) {
        Booking__c booking = [
            SELECT Id
            FROM Booking__c
            WHERE Id = :bookingId
            LIMIT 1
        ];
        SnapshotDTO snapshot = computeSnapshotFromLedgerWithPreview(booking.Id, asOfDate);
        snapshot.bookingId = booking.Id;
        snapshot.asOfTimestamp = System.now();
        return snapshot;
    }

    private static SnapshotDTO computeSnapshotFromLedgerWithPreview(Id bookingId, Date asOfDate) {
        SnapshotDTO dto = new SnapshotDTO();

        // 1) Schedules (finance fields needed for preview)
        List<Booking_Payment_Schedule__c> schedules = [
            SELECT Id,
                   Booking__c,
                   Installment_Number__c,
                   Milestone_Code__c,
                   Payment_Due_Date__c,
                   Installment_Amount__c,
                   Interest_Waived__c,
                   Annual_Interest_Rate__c,
                   Grace_Period_Days__c,
                   GST_VAT_Rate_On_Interest__c
            FROM Booking_Payment_Schedule__c
            WHERE Booking__c = :bookingId
            ORDER BY Payment_Due_Date__c ASC, Installment_Number__c ASC, Id ASC
        ];
        if (schedules.isEmpty()) { dto.scheduleCount = 0; return dto; }

        Set<Id> schedIds = new Set<Id>();
        for (Booking_Payment_Schedule__c s : schedules) if (s.Id != null) schedIds.add(s.Id);

        // Waivers from ledger (interest/tax waiver rows are stored as NEGATIVE; we convert to positive magnitudes)
        Map<Id, Map<String, Decimal>> waiverBySched = fetchWaiversBySchedule(schedIds);

        // 2) Posted ledger up to asOfDate (all sources)
        Map<Id, Agg> aggBySchedule = new Map<Id, Agg>();
        for (Ledger_Entry__c le : [
            SELECT Schedule__c,
                   Type__c,
                   Source__c,
                   Principal_Amount__c,
                   Interest_Amount__c,
                   Tax_Amount__c,
                   Entry_Date__c,
                   Status__c
            FROM Ledger_Entry__c
            WHERE Booking__c = :bookingId
              AND Status__c IN (:LedgerConst.STATUS_POSTED,:LedgerConst.STATUS_REVERSED)
              AND Entry_Date__c <= :asOfDate
        ]) {
            if (le.Schedule__c == null) continue;
            if (!aggBySchedule.containsKey(le.Schedule__c)) aggBySchedule.put(le.Schedule__c, new Agg());
            Agg a = aggBySchedule.get(le.Schedule__c);

            // Principal: include all principal amounts (receipts negative, reversals positive)
            a.prinSum = toMoney(a.prinSum + nz(le.Principal_Amount__c));

            // Accruals vs receipts/reversals
            if (LedgerConst.SOURCE_ACCRUAL.equalsIgnoreCase(le.Source__c)) {
                a.intAcc = toMoney(a.intAcc + nz(le.Interest_Amount__c));
                a.taxAcc = toMoney(a.taxAcc + nz(le.Tax_Amount__c));
            } else {
                // CHANGED: include REVERSAL to offset earlier receipts when bounced
                if (le.Type__c == LedgerConst.TYPE_INTEREST_RECEIPT || le.Type__c == LedgerConst.TYPE_REVERSAL) {
                    a.intRcv = toMoney(a.intRcv + nz(le.Interest_Amount__c));
                }
                if (le.Type__c == LedgerConst.TYPE_INTEREST_TAX_RECEIPT || le.Type__c == LedgerConst.TYPE_REVERSAL) {
                    a.taxRcv = toMoney(a.taxRcv + nz(le.Tax_Amount__c));
                }
            }
        }

        // 3) Latest posted accrual end per schedule (to know where preview should start)
        Map<Id, Date> lastAccrualEndBySchedule = new Map<Id, Date>();
        for (AggregateResult ar : [
            SELECT Schedule__c sid, MAX(Period_End__c) pe
            FROM Ledger_Entry__c
            WHERE Booking__c = :bookingId
              AND Status__c   = :LedgerConst.STATUS_POSTED
              AND Source__c   = :LedgerConst.SOURCE_ACCRUAL
            GROUP BY Schedule__c
        ]) {
            lastAccrualEndBySchedule.put((Id)ar.get('sid'), (Date)ar.get('pe'));
        }

        // 4) Rows + totals (add preview when needed)
        Decimal totInstallment = 0, totOutstandingPrincipal = 0,
                totPrincipalReceived = 0, totAdvance = 0,
                totInterestTillToday = 0, totInterestReceived = 0,
                totInterestWaived = 0, totTaxTillToday = 0, totTaxReceived = 0;

        Date nextDue = null;

        for (Booking_Payment_Schedule__c s : schedules) {
            Agg a = aggBySchedule.containsKey(s.Id) ? aggBySchedule.get(s.Id) : new Agg();

            ScheduleDTO row = new ScheduleDTO();
            row.scheduleId = s.Id;
            row.installmentNumber = toInteger(s.Installment_Number__c);
            row.milestoneCode = s.Milestone_Code__c;
            row.dueDate = s.Payment_Due_Date__c;
            row.installmentAmount = toMoney(s.Installment_Amount__c);

            // Principal: show received as positive; outstanding = base + net ledger principal (never < 0)
            row.principalReceived = toMoney(a.prinSum < 0 ? (a.prinSum * -1) : 0);
            Decimal principalOutstanding = toMoney(row.installmentAmount + a.prinSum);
            if (principalOutstanding < 0) principalOutstanding = 0;
            row.outstandingPrincipal = principalOutstanding;

            row.advanceApplied = 0; // not ledger-driven here

            // Posted accruals
            Decimal postedInterest = toMoney(a.intAcc);
            Decimal postedTax      = toMoney(a.taxAcc);

            // ---- Preview delta (unposted accrual to "today") ----
            Integer g = s.Grace_Period_Days__c == null ? 0 : Integer.valueOf(s.Grace_Period_Days__c);
            Date due = s.Payment_Due_Date__c;
            Date naturalStart = (due == null) ? asOfDate : due.addDays(Math.max(0, g) + 1);
            Date lastEnd = lastAccrualEndBySchedule.get(s.Id);
            Date startPreview = (lastEnd == null) ? naturalStart : lastEnd.addDays(1);

            Decimal previewInterest = 0, previewTax = 0;
            if (principalOutstanding > 0 &&
                startPreview != null &&
                asOfDate >= startPreview &&
                (due == null || asOfDate > due.addDays(Math.max(0, g)))) {

                Integer days = startPreview.daysBetween(asOfDate) + 1; // inclusive
                if (days > 0) {
                    Decimal annual = s.Annual_Interest_Rate__c == null ? 0 : s.Annual_Interest_Rate__c;
                    Decimal daily  = (annual / 100) / 365;
                    if (daily > 0) {
                        previewInterest = (principalOutstanding * daily * days).setScale(2, RoundingMode.HALF_UP);
                        Decimal taxRate = s.GST_VAT_Rate_On_Interest__c == null ? 0 : s.GST_VAT_Rate_On_Interest__c;
                        previewTax = (previewInterest * (taxRate / 100)).setScale(2, RoundingMode.HALF_UP);
                    }
                }
            }

            // Interest (posted + preview)
            row.interestTillToday = toMoney(postedInterest + previewInterest);
            row.interestReceivedAllocated = toMoney(a.intRcv < 0 ? (a.intRcv * -1) : 0);

            // Waivers (from ledger waiver rows; positive magnitudes for reporting)
            Map<String, Decimal> wz = waiverBySched.containsKey(s.Id) ? waiverBySched.get(s.Id) : new Map<String, Decimal>();
            Decimal waivedInterest = (wz.containsKey('interestWaived') ? wz.get('interestWaived') : 0);
            Decimal waivedTax      = (wz.containsKey('taxWaived')      ? wz.get('taxWaived')      : 0);
            row.interestWaived = toMoney(waivedInterest);

            row.interestOutstanding = toMoney(
                Math.max(0,
                    row.interestTillToday
                  - row.interestReceivedAllocated
                  - row.interestWaived
                )
            );

            // Tax (posted + preview − waivedTax)
            row.taxTillToday = toMoney(postedTax + previewTax - waivedTax);
            row.taxReceivedAllocated = toMoney(a.taxRcv < 0 ? (a.taxRcv * -1) : 0);
            row.taxOutstanding = toMoney(
                Math.max(0, row.taxTillToday - row.taxReceivedAllocated)
            );

            // Other charges placeholders
            row.otherCharges = 0;
            row.taxOnOtherCharges = 0;

            dto.schedules.add(row);

            // Totals
            totInstallment         += row.installmentAmount;
            totOutstandingPrincipal += row.outstandingPrincipal;
            totPrincipalReceived   += row.principalReceived;
            totAdvance             += row.advanceApplied;
            totInterestTillToday   += row.interestTillToday;
            totInterestReceived    += row.interestReceivedAllocated;
            totInterestWaived      += row.interestWaived;
            totTaxTillToday        += row.taxTillToday;
            totTaxReceived         += row.taxReceivedAllocated;

            nextDue = resolveNextDue(nextDue, s.Payment_Due_Date__c, asOfDate);
        }

        dto.totalInstallmentAmount           = toMoney(totInstallment);
        dto.totalOutstandingPrincipal        = toMoney(totOutstandingPrincipal);
        dto.totalPrincipalReceived           = toMoney(totPrincipalReceived);
        dto.totalAdvanceApplied              = toMoney(totAdvance);

        dto.totalInterestTillToday           = toMoney(totInterestTillToday);
        dto.totalInterestReceivedAllocated   = toMoney(totInterestReceived);
        dto.totalInterestWaived              = toMoney(totInterestWaived);
        dto.totalInterestOutstanding         = toMoney(
            Math.max(0,
                dto.totalInterestTillToday
              - dto.totalInterestReceivedAllocated
              - dto.totalInterestWaived
            )
        );

        dto.totalTaxOnInterestTillToday      = toMoney(totTaxTillToday);
        dto.totalTaxOnInterestReceived       = toMoney(totTaxReceived);
        dto.totalTaxOnInterestOutstanding    = toMoney(
            Math.max(0, dto.totalTaxOnInterestTillToday - dto.totalTaxOnInterestReceived)
        );

        dto.scheduleCount = dto.schedules.size();
        dto.nextDueDate   = nextDue;
        return dto;
    }

    // ===== Waivers from ledger =====
    // Returns total waived interest and tax per schedule (positive numbers)
    private static Map<Id, Map<String, Decimal>> fetchWaiversBySchedule(Set<Id> scheduleIds) {
        Map<Id, Map<String, Decimal>> out = new Map<Id, Map<String, Decimal>>();
        if (scheduleIds == null || scheduleIds.isEmpty()) return out;

        Set<String> waiverTypes = new Set<String>{
            LedgerConst.TYPE_INTEREST_WAIVER,
            LedgerConst.TYPE_INTEREST_TAX_WAIVER
        };

        for (AggregateResult ar : [
            SELECT Schedule__c sid,
                   Type__c t,
                   SUM(Interest_Amount__c) si,
                   SUM(Tax_Amount__c) st
            FROM Ledger_Entry__c
            WHERE Schedule__c IN :scheduleIds
              AND Status__c   = :LedgerConst.STATUS_POSTED
              AND Type__c     IN :waiverTypes
            GROUP BY Schedule__c, Type__c
        ]) {
            Id sid     = (Id) ar.get('sid');
            String t   = (String) ar.get('t');
            Decimal si = (Decimal) ar.get('si');
            Decimal st = (Decimal) ar.get('st');

            if (!out.containsKey(sid)) {
                out.put(sid, new Map<String, Decimal>{
                    'interestWaived' => 0,
                    'taxWaived'      => 0
                });
            }
            Map<String, Decimal> bucket = out.get(sid);

            // Waivers are stored as NEGATIVE amounts; convert to positive magnitudes
            if (t == LedgerConst.TYPE_INTEREST_WAIVER) {
                Decimal add = (si == null) ? 0 : (si < 0 ? -si : 0);
                bucket.put('interestWaived',
                    (bucket.get('interestWaived') + add).setScale(2, RoundingMode.HALF_UP));
            } else if (t == LedgerConst.TYPE_INTEREST_TAX_WAIVER) {
                Decimal add = (st == null) ? 0 : (st < 0 ? -st : 0);
                bucket.put('taxWaived',
                    (bucket.get('taxWaived') + add).setScale(2, RoundingMode.HALF_UP));
            }
        }
        return out;
    }

    // ===== Small helpers =====
    private static Date resolveNextDue(Date currentNext, Date candidate, Date asOf) {
        if (candidate == null) return currentNext;
        if (currentNext == null) return candidate;
        Boolean candFuture = candidate >= asOf;
        Boolean currFuture = currentNext >= asOf;
        if (candFuture && !currFuture) return candidate;
        if (!candFuture && currFuture) return currentNext;
        return candidate < currentNext ? candidate : currentNext;
    }

    private static SnapshotDTO fetchFromCache(String key) {
        try {
            Object raw = Cache.Org.get(key);
            if (raw == null) return null;
            return (SnapshotDTO)JSON.deserialize(JSON.serialize(raw), SnapshotDTO.class);
        } catch (Exception e) { return null; }
    }

    private static void storeInCache(String key, SnapshotDTO dto) {
        try { Cache.Org.put(key, dto, 120); } catch (Exception e) {}
    }

    private static String buildCacheKey(Id bookingId, Date asOfDate) {
        return 'BookingInterestService:' + String.valueOf(bookingId) + ':' + String.valueOf(asOfDate);
    }

    private static Decimal toMoney(Decimal v)   { return v == null ? 0 : v.setScale(2, RoundingMode.HALF_UP); }
    private static Integer toInteger(Decimal v) { return v == null ? null : Integer.valueOf(v); }
    private static Decimal nz(Decimal v)        { return v == null ? 0 : v; }
}