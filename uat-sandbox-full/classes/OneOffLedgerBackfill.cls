public with sharing class OneOffLedgerBackfill {
    private class BucketTotals {
        Decimal principal = 0;
        Decimal interest = 0;
        Decimal tax = 0;

        void addPrincipal(Decimal amount) { principal = add(principal, amount); }
        void addInterest(Decimal amount) { interest = add(interest, amount); }
        void addTax(Decimal amount)       { tax = add(tax, amount); }

        Boolean hasValue() {
            return principal != 0 || interest != 0 || tax != 0;
        }

        private Decimal add(Decimal left, Decimal right) {
            Decimal l = left == null ? 0 : left;
            Decimal r = right == null ? 0 : right;
            return (l + r).setScale(2, RoundingMode.HALF_UP);
        }
    }

    public static void run() {
        Date entryDate = Date.today().addDays(-1);
        List<Booking__c> bookings = [
            SELECT Id, OC_Received__c, Project__r.Name
            FROM Booking__c
            WHERE Status__c != 'Cancelled'
        ];
        if (bookings.isEmpty()) {
            return;
        }
        Set<Id> bookingIds = new Set<Id>();
        for (Booking__c booking : bookings) {
            bookingIds.add(booking.Id);
        }

        Map<Id, List<Booking_Payment_Schedule__c>> schedulesByBooking = new Map<Id, List<Booking_Payment_Schedule__c>>();
        for (Booking_Payment_Schedule__c sched : [
            SELECT Id, Booking__c, Installment_Amount__c,
                   Installment_Number__c, Payment_Due_Date__c,
                   TotalPrincipalReceived__c, AccruedInterestToDateLedger__c,
                   TotalInterestReceived__c, Interest_Waived__c
            FROM Booking_Payment_Schedule__c
            WHERE Booking__c IN :bookingIds
            ORDER BY Payment_Due_Date__c, Installment_Number__c
        ]) {
            if (!schedulesByBooking.containsKey(sched.Booking__c)) {
                schedulesByBooking.put(sched.Booking__c, new List<Booking_Payment_Schedule__c>());
            }
            schedulesByBooking.get(sched.Booking__c).add(sched);
        }

        Set<Id> bookingsWithOpening = new Set<Id>();
        for (AggregateResult ar : [
            SELECT Booking__c b
            FROM Ledger_Entry__c
            WHERE Booking__c IN :bookingIds
              AND Type__c = :LedgerConst.TYPE_MANUAL_ADJUSTMENT
              AND Source__c = :LedgerConst.SOURCE_ADJUSTMENT
              AND Description__c = 'Opening balance'
            GROUP BY Booking__c
        ]) {
            bookingsWithOpening.add((Id)ar.get('b'));
        }

        List<Ledger_Entry__c> entriesToInsert = new List<Ledger_Entry__c>();
        for (Booking__c booking : bookings) {
            if (bookingsWithOpening.contains(booking.Id)) {
                continue;
            }
            List<Booking_Payment_Schedule__c> schedules = schedulesByBooking.get(booking.Id);
            if (schedules == null || schedules.isEmpty()) {
                continue;
            }
            Map<String, BucketTotals> totalsByBucket = new Map<String, BucketTotals>{
                LedgerConst.BUCKET_BASIC => new BucketTotals(),
                LedgerConst.BUCKET_OTHER => new BucketTotals()
            };

            for (Booking_Payment_Schedule__c sched : schedules) {
                Decimal principalOutstanding = calcOutstanding(
                    sched.Installment_Amount__c,
                    sched.TotalPrincipalReceived__c
                );
                Decimal interestOutstanding = calcOutstanding(
                    sched.AccruedInterestToDateLedger__c,
                    sched.TotalInterestReceived__c,
                    sched.Interest_Waived__c
                );
                if (principalOutstanding == 0 && interestOutstanding == 0) {
                    continue;
                }
                String bucket = isPossessionMilestone(sched)
                    ? LedgerConst.BUCKET_OTHER
                    : LedgerConst.BUCKET_BASIC;
                BucketTotals bucketTotals = totalsByBucket.get(bucket);
                if (principalOutstanding > 0) {
                    bucketTotals.addPrincipal(principalOutstanding);
                }
                if (interestOutstanding > 0) {
                    bucketTotals.addInterest(interestOutstanding);
                    Decimal taxPct = sched.GST_VAT_Rate_On_Interest__c;
                    if (taxPct == null) {
                        String scheduleRef = sched.Id == null ? '(unsaved schedule)' : String.valueOf(sched.Id);
                        throw new LedgerEntryService.MissingFinanceDataException(
                            'Booking_Payment_Schedule__c ' + scheduleRef + ' missing required finance data: GST_VAT_Rate_On_Interest__c'
                        );
                    }
                    Decimal taxOutstanding = (interestOutstanding * (taxPct / 100)).setScale(2, RoundingMode.HALF_UP);
                    if (taxOutstanding > 0) {
                        bucketTotals.addTax(taxOutstanding);
                    }
                }
            }

            LedgerEntryService.Balances current = LedgerEntryService.getBalances(booking.Id);
            Decimal runningPrin = current.prin;
            Decimal runningIntr = current.intr;
            Decimal runningTax = current.tax;

            for (String bucket : totalsByBucket.keySet()) {
                BucketTotals totals = totalsByBucket.get(bucket);
                if (totals == null || !totals.hasValue()) {
                    continue;
                }
                Ledger_Entry__c entry = new Ledger_Entry__c();
                entry.Booking__c = booking.Id;
                entry.Entry_Date__c = entryDate;
                entry.Type__c = LedgerConst.TYPE_MANUAL_ADJUSTMENT;
                entry.Bucket__c = bucket;
                entry.Source__c = LedgerConst.SOURCE_ADJUSTMENT;
                entry.Status__c = LedgerConst.STATUS_POSTED;
                entry.Principal_Amount__c = totals.principal;
                entry.Interest_Amount__c = totals.interest;
                entry.Tax_Amount__c = totals.tax;
                entry.Description__c = 'Opening balance';

                runningPrin = (runningPrin + totals.principal).setScale(2, RoundingMode.HALF_UP);
                runningIntr = (runningIntr + totals.interest).setScale(2, RoundingMode.HALF_UP);
                runningTax = (runningTax + totals.tax).setScale(2, RoundingMode.HALF_UP);

                entry.Running_Principal_Outstanding__c = runningPrin;
                entry.Running_Interest_Outstanding__c = runningIntr;
                entry.Running_Tax_Outstanding__c = runningTax;
                entriesToInsert.add(entry);
            }
        }

        if (!entriesToInsert.isEmpty()) {
            insert entriesToInsert;
        }
    }

    private static Boolean isPossessionMilestone(Booking_Payment_Schedule__c sched) {
        return sched != null
            && !String.isBlank(sched.Milestone_Code__c)
            && 'on possession'.equalsIgnoreCase(sched.Milestone_Code__c.trim());
    }

    private static Decimal calcOutstanding(Decimal baseValue, Decimal received) {
        return calcOutstanding(baseValue, received, 0);
    }

    private static Decimal calcOutstanding(Decimal baseValue, Decimal received, Decimal waived) {
        Decimal base = baseValue == null ? 0 : baseValue;
        Decimal rec = received == null ? 0 : received;
        Decimal wav = waived == null ? 0 : waived;
        Decimal outstanding = (base - rec - wav).setScale(2, RoundingMode.HALF_UP);
        return outstanding < 0 ? 0 : outstanding;
    }
}