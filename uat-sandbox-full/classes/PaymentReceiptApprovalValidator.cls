public class PaymentReceiptApprovalValidator {

    public static void validateOnApproval(List<Payment_Receipt__c> newList) {
        if (newList == null || newList.isEmpty()) return;

        // Only rows transitioning Pending Approval -> Approved
        List<Payment_Receipt__c> rows = new List<Payment_Receipt__c>();
        Set<Id> schIds = new Set<Id>();

        for (Payment_Receipt__c r : newList) {            
            if (r.Receipt_Status__c != 'Cancelled' && r.Receipt_Status__c != 'Bounced') {
                rows.add(r);
                if (r.Booking_Payment_Schedule__c != null) schIds.add(r.Booking_Payment_Schedule__c);
            }
        }
        if (rows.isEmpty()) return;

        // Need GST% to validate tax proportionality
        Map<Id, Booking_Payment_Schedule__c> bpsMap = schIds.isEmpty() ? new Map<Id, Booking_Payment_Schedule__c>()
            : new Map<Id, Booking_Payment_Schedule__c>([
                SELECT Id, Booking__c, Payment_Due_Date__c, Installment_Amount__c,
                       Annual_Interest_Rate__c, Grace_Period_Days__c, GST_VAT_Rate_On_Interest__c,
                       Installment_Number__c
                FROM Booking_Payment_Schedule__c
                WHERE Id IN :schIds
            ]);

        // Baseline checks + non-negative + split coverage + schedule tax proportionality
        for (Payment_Receipt__c r : rows) {
            if (r.Demand__c == null)          r.Demand__c.addError('Demand is required.');
            if (r.Date_Of_Payment__c == null) r.Date_Of_Payment__c.addError('Date of Payment is required.');
            if (r.Amount_Paid__c == null)     r.Amount_Paid__c.addError('Amount Paid is required.');

            if (r.Principal_Applied__c == null) r.Principal_Applied__c = 0;
            if (r.Interest_Applied__c  == null) r.Interest_Applied__c  = 0;
            if (r.Tax_on_Interest__c   == null) r.Tax_on_Interest__c   = 0;

            if (nz(r.Principal_Applied__c) < 0) r.Principal_Applied__c.addError('Principal cannot be negative.');
            if (nz(r.Interest_Applied__c)  < 0) r.Interest_Applied__c.addError('Interest cannot be negative.');
            if (nz(r.Tax_on_Interest__c)   < 0) r.Tax_on_Interest__c.addError('Tax on interest cannot be negative.');

            Decimal split = nz(r.Principal_Applied__c) + nz(r.Interest_Applied__c) + nz(r.Tax_on_Interest__c);
            if (r.Amount_Paid__c != null && nz(r.Amount_Paid__c) < split) {
                r.Amount_Paid__c.addError('Amount Paid is less than Principal + Interest + Tax.');
            }

            // Per-schedule proportionality check to avoid mistyped tax
            if (r.Booking_Payment_Schedule__c != null && bpsMap.containsKey(r.Booking_Payment_Schedule__c)) {
                Booking_Payment_Schedule__c s = bpsMap.get(r.Booking_Payment_Schedule__c);
                Decimal rate = nz(s.GST_VAT_Rate_On_Interest__c);
                Decimal expected = (nz(r.Interest_Applied__c) * rate / 100).setScale(2, RoundingMode.HALF_UP);
                if ((nz(r.Interest_Applied__c) > 0 || nz(r.Tax_on_Interest__c) > 0)
                    && Math.abs(nz(r.Tax_on_Interest__c) - expected) > 1) {
                    r.Tax_on_Interest__c.addError('Tax on interest must be ' + rate + '% of Interest Applied (' + String.valueOf(expected) + ').');
                }
            }
        }
        if (hasDmlErrors(rows)) return;

        // Demand -> Schedule
        Set<Id> demandIds = new Set<Id>();
        for (Payment_Receipt__c r : rows) if (r.Demand__c != null) demandIds.add(r.Demand__c);

        Map<Id, Demand__c> demandMap = demandIds.isEmpty()
            ? new Map<Id, Demand__c>()
            : new Map<Id, Demand__c>([
                SELECT Id, Booking_Payment_Schedule_Id__c
                FROM Demand__c
                WHERE Id IN :demandIds
            ]);

        // Resolve schedules and bookings
        Set<Id> scheduleIds = new Set<Id>();
        for (Payment_Receipt__c r : rows) {
            Demand__c d = demandMap.get(r.Demand__c);
            if (d == null || d.Booking_Payment_Schedule_Id__c == null) {
                r.Demand__c.addError('Selected Demand is not linked to a Booking Payment Schedule.');
            } else {
                scheduleIds.add(d.Booking_Payment_Schedule_Id__c);
            }
        }
        if (hasDmlErrors(rows)) return;

        Map<Id, Booking_Payment_Schedule__c> currentSch = scheduleIds.isEmpty()
            ? new Map<Id, Booking_Payment_Schedule__c>()
            : new Map<Id, Booking_Payment_Schedule__c>([
                SELECT Id, Booking__c, Payment_Due_Date__c,
                       Installment_Amount__c, Installment_Number__c,
                       Annual_Interest_Rate__c, Grace_Period_Days__c, GST_VAT_Rate_On_Interest__c
                FROM Booking_Payment_Schedule__c
                WHERE Id IN :scheduleIds
            ]);

        Set<Id> bookingIds = new Set<Id>();
        for (Booking_Payment_Schedule__c s : currentSch.values()) if (s.Booking__c != null) bookingIds.add(s.Booking__c);

        // All schedules per booking for sequencing checks
        Map<Id, List<Booking_Payment_Schedule__c>> schedulesByBooking = new Map<Id, List<Booking_Payment_Schedule__c>>();
        if (!bookingIds.isEmpty()) {
            for (Booking_Payment_Schedule__c s : [
                SELECT Id, Booking__c, Payment_Due_Date__c, Installment_Amount__c,
                       Installment_Number__c
                FROM Booking_Payment_Schedule__c
                WHERE Booking__c IN :bookingIds
                ORDER BY Payment_Due_Date__c NULLS FIRST, Installment_Number__c NULLS FIRST, Id
            ]) {
                if (!schedulesByBooking.containsKey(s.Booking__c)) {
                    schedulesByBooking.put(s.Booking__c, new List<Booking_Payment_Schedule__c>());
                }
                schedulesByBooking.get(s.Booking__c).add(s);
            }
        }

        // Validate each receipt against ledger-based caps
        for (Payment_Receipt__c r : rows) {
            Demand__c dem = demandMap.get(r.Demand__c);
            Booking_Payment_Schedule__c curr = (dem == null) ? null : currentSch.get(dem.Booking_Payment_Schedule_Id__c);
            if (curr == null || curr.Booking__c == null) continue;
            Id bookingId = curr.Booking__c;

            // 1) Principal sequencing: earlier schedules must have zero principal outstanding
            if (nz(r.Principal_Applied__c) > 0) {
                List<Booking_Payment_Schedule__c> all = schedulesByBooking.containsKey(bookingId)
                    ? schedulesByBooking.get(bookingId) : new List<Booking_Payment_Schedule__c>();

                for (Booking_Payment_Schedule__c s : all) {
                    if (isEarlierThan(s, curr)) {
                        // Use field Outstanding_Principal__c if present; otherwise compute from ledger + installment
                        Decimal outPrin = readOutstandingPrincipalFieldSafe(s);
                        if (outPrin == null) {
                            outPrin = principalOutstandingFromLedger(s.Id, s.Installment_Amount__c);
                        }
                        if (nz(outPrin) > 0) {
                            r.Principal_Applied__c.addError('Cannot apply principal to this schedule while earlier schedules still have outstanding principal: ' + outPrin);
                            break;
                        }
                    }
                }
            }
            if (hasDmlErrors(new List<Payment_Receipt__c>{ r })) continue;

            // 2) Booking-wide INTEREST cap from Ledger up to the receipt date
            Date asOf = (r.Date_Of_Payment__c == null) ? Date.today() : r.Date_Of_Payment__c;
            Decimal interestOutstanding = bookingInterestOutstandingFromLedger(bookingId, asOf);
			
            System.debug('Interest_Applied__c: ' + r.Interest_Applied__c);
            System.debug('interestOutstanding: ' + interestOutstanding);
            if (nz(r.Interest_Applied__c) - interestOutstanding > 0.01) {
                r.Interest_Applied__c.addError(
                    'Interest applied exceeds booking-wide interest outstanding as of the payment date (' +
                    String.valueOf(interestOutstanding.setScale(2, RoundingMode.HALF_UP)) + ').'
                );
            }

            // 3) Booking-wide TAX cap from Ledger up to the receipt date
            Decimal taxOutstanding = bookingInterestTaxOutstandingFromLedger(bookingId, asOf);
            if (nz(r.Tax_on_Interest__c) - taxOutstanding > 0.01) {
                r.Tax_on_Interest__c.addError(
                    'Tax on interest exceeds booking-wide tax outstanding as of the payment date (' +
                    String.valueOf(taxOutstanding.setScale(2, RoundingMode.HALF_UP)) + ').'
                );
            }
        }
    }

    // ---------------- Ledger-based caps ----------------

    // Interest Outstanding = max(0, Accruals(interest, <=asOf) + Receipts(interest, <=asOf) + Waivers(interest, <=asOf))
    // Notes: receipt/waiver entries are negative in ledger; adding them reduces the balance.
    private static Decimal bookingInterestOutstandingFromLedger(Id bookingId, Date asOf) {
        if (bookingId == null || asOf == null) return 0;

        Decimal accrued = sumInterest(bookingId, asOf, 'ACCRUAL', null);
        Decimal recvd   = sumInterest(bookingId, asOf, null, new Set<String>{ LedgerConst.TYPE_INTEREST_RECEIPT });
        Decimal waived  = sumInterest(bookingId, asOf, null, new Set<String>{ LedgerConst.TYPE_INTEREST_WAIVER });

        Decimal out = nz(accrued) + nz(recvd) + nz(waived);
        return (out < 0) ? 0 : out.setScale(2, RoundingMode.HALF_UP);
    }

    // Tax Outstanding = max(0, Accruals(tax, <=asOf) + Receipts(tax, <=asOf) + Waivers(tax, <=asOf))
    private static Decimal bookingInterestTaxOutstandingFromLedger(Id bookingId, Date asOf) {
        if (bookingId == null || asOf == null) return 0;

        Decimal accrued = sumTax(bookingId, asOf, 'ACCRUAL', null); // interest tax accrual entries
        Decimal recvd   = sumTax(bookingId, asOf, null, new Set<String>{ LedgerConst.TYPE_INTEREST_TAX_RECEIPT });
        Decimal waived  = sumTax(bookingId, asOf, null, new Set<String>{ LedgerConst.TYPE_INTEREST_TAX_WAIVER });

        Decimal out = nz(accrued) + nz(recvd) + nz(waived);
        return (out < 0) ? 0 : out.setScale(2, RoundingMode.HALF_UP);
    }

    // ---------------- Principal helpers ----------------

    // Try to read BPS.Outstanding_Principal__c if org has it (returns null if missing)
    private static Decimal readOutstandingPrincipalFieldSafe(Booking_Payment_Schedule__c s) {
        try {
            Object raw = s.get('Outstanding_Principal__c');
            return (raw == null) ? null : (Decimal)raw;
        } catch (Exception e) {
            return null;
        }
    }

    // Compute principal outstanding from ledger if no field:
    // outstanding = max(0, Installment_Amount__c + SUM(Ledger.Principal_Amount__c posted for this schedule))
    // (Remember: principal receipts are negative in the ledger.)
    private static Decimal principalOutstandingFromLedger(Id scheduleId, Decimal installmentAmount) {
        if (scheduleId == null) return nz(installmentAmount);
        AggregateResult ar = [
            SELECT SUM(Principal_Amount__c) p
            FROM Ledger_Entry__c
            WHERE Schedule__c = :scheduleId
              AND Status__c IN ('POSTED', 'REVERSED')
        ];
        Decimal sumPrin = (Decimal) (ar.get('p') == null ? 0 : ar.get('p'));
        Decimal raw = nz(installmentAmount) + nz(sumPrin);
        if (raw < 0) raw = 0;
        return raw.setScale(2, RoundingMode.HALF_UP);
    }

    // ---------------- SOQL aggregators ----------------

    private static Decimal sumInterest(Id bookingId, Date asOf, String sourceEquals, Set<String> typeIn) {
        String q = 'SELECT SUM(Interest_Amount__c) i ' +
                   'FROM Ledger_Entry__c ' +
                   'WHERE Booking__c = :bookingId ' +
                   'AND Status__c = \'POSTED\' ';

        if (sourceEquals != null) {
            q += 'AND Source__c = :sourceEquals ';
        }
        if (typeIn != null && !typeIn.isEmpty()) {
            q += 'AND Type__c IN :typeIn ';
        }
        // Use Period_End__c for accrual as-of, Entry_Date__c for others (receipt/waiver)
        if (sourceEquals == 'ACCRUAL') {
            q += 'AND Period_End__c <= :asOf';
        } else {
            q += 'AND Entry_Date__c <= :asOf';
        }

        List<AggregateResult> rs = Database.query(q);
        if (rs.isEmpty()) return 0;
        Decimal s = (Decimal) (rs[0].get('i') == null ? 0 : rs[0].get('i'));
        return s == null ? 0 : s;
    }

    private static Decimal sumTax(Id bookingId, Date asOf, String sourceEquals, Set<String> typeIn) {
        String q = 'SELECT SUM(Tax_Amount__c) t ' +
                   'FROM Ledger_Entry__c ' +
                   'WHERE Booking__c = :bookingId ' +
                   'AND Status__c = \'POSTED\' ';

        if (sourceEquals != null) {
            q += 'AND Source__c = :sourceEquals ';
        }
        if (typeIn != null && !typeIn.isEmpty()) {
            q += 'AND Type__c IN :typeIn ';
        }
        if (sourceEquals == 'ACCRUAL') {
            q += 'AND Period_End__c <= :asOf';
        } else {
            q += 'AND Entry_Date__c <= :asOf';
        }

        List<AggregateResult> rs = Database.query(q);
        if (rs.isEmpty()) return 0;
        Decimal s = (Decimal) (rs[0].get('t') == null ? 0 : rs[0].get('t'));
        return s == null ? 0 : s;
    }

    // ---------------- Utilities ----------------

    private static Decimal nz(Decimal d) { return d == null ? 0 : d; }

    /** Earlier than = smaller Installment_Number__c; ties by Id */
    private static Boolean isEarlierThan(Booking_Payment_Schedule__c a, Booking_Payment_Schedule__c b) {
        if (a == null || b == null) return false;
        if (a.Id == b.Id) return false;

        Decimal an = a.Installment_Number__c, bn = b.Installment_Number__c;
        if (an == null && bn == null) return String.valueOf(a.Id) < String.valueOf(b.Id);
        if (an == null) return true;
        if (bn == null) return false;
        if (an.equals(bn)) return String.valueOf(a.Id) < String.valueOf(b.Id);
        return an < bn;
    }

    // Apex doesn’t expose addError state; SF surfaces errors automatically in the UI.
    private static Boolean hasDmlErrors(List<Payment_Receipt__c> rows) { return false; }
}