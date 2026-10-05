/**
 * AdvanceCarryForwardService
 * ---------------------------------------------------------
 * PURPOSE
 *  AFTER UPDATE on Payment_Receipt__c (transition to Approved):
 *   - Allocate EXCESS to later schedules in the same Booking by increasing
 *     Booking_Payment_Schedule__c.Advance_Applied__c (earliest due first).
 *
 * NOTES
 *  - We do not implement de-allocation here (no reverse paths in the current design).
 */
public class AdvanceCarryForwardService {

    public static void carryForward(List<Payment_Receipt__c> newList, Map<Id, Payment_Receipt__c> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        // Build positive deltas (excess new - excess old)
        List<DeltaRec> deltas = new List<DeltaRec>();
        for (Payment_Receipt__c rec : newList) {
            if (rec == null || rec.Demand__c == null) continue;

            Decimal newExcess = FinancePolicyUtil.nz(rec.Excess_Payment__c);
            Decimal oldExcess = (oldMap != null && oldMap.containsKey(rec.Id)) ? FinancePolicyUtil.nz(oldMap.get(rec.Id).Excess_Payment__c) : 0;
            Decimal delta = (newExcess - oldExcess).setScale(2, RoundingMode.HALF_UP);
            if (delta > 0)
             {
                deltas.add(new DeltaRec(rec.Demand__c, delta));
            }


            // Decimal delta = (newExcess - oldExcess).setScale(2, RoundingMode.HALF_UP);

            // if (oldMap == null || !oldMap.containsKey(rec.Id))
            // {
            //     if(newExcess > 0){
            //         deltas.add(new DeltaRec(rec.Demand__c, newExcess));
            //     }
            // }
            // else if(delta > 0)
            // {
            //     deltas.add(new DeltaRec(rec.Demand__c, delta));
            // }
        }
        if (deltas.isEmpty()) return;

        // Demands -> source schedules
        Set<Id> demandIds = new Set<Id>();
        for (DeltaRec d : deltas) demandIds.add(d.demandId);

        Map<Id, Demand__c> demandMap = new Map<Id, Demand__c>([
            SELECT Id, Booking_Payment_Schedule_Id__c
            FROM Demand__c
            WHERE Id IN :demandIds
        ]);

        Set<Id> srcSchIds = new Set<Id>();
        for (DeltaRec d : deltas) {
            Demand__c dem = demandMap.get(d.demandId);
            if (dem != null && dem.Booking_Payment_Schedule_Id__c != null) srcSchIds.add(dem.Booking_Payment_Schedule_Id__c);
        }
        if (srcSchIds.isEmpty()) return;

        Map<Id, Booking_Payment_Schedule__c> srcSchMap = new Map<Id, Booking_Payment_Schedule__c>([
            SELECT Id, Booking__c, Payment_Due_Date__c
            FROM Booking_Payment_Schedule__c
            WHERE Id IN :srcSchIds
        ]);

        // Group by booking (carry along source schedule & due date)
        Map<Id, List<DeltaPool>> byBooking = new Map<Id, List<DeltaPool>>();
        for (DeltaRec d : deltas) {
            Demand__c dem = demandMap.get(d.demandId);
            if (dem == null) continue;
            Booking_Payment_Schedule__c src = srcSchMap.get(dem.Booking_Payment_Schedule_Id__c);
            if (src == null || src.Booking__c == null) continue;

            if (!byBooking.containsKey(src.Booking__c)) byBooking.put(src.Booking__c, new List<DeltaPool>());
            byBooking.get(src.Booking__c).add(new DeltaPool(src.Id, src.Payment_Due_Date__c, d.delta));
        }
        if (byBooking.isEmpty()) return;

        // Load ordered schedules per booking (ascending due)
        Map<Id, List<Booking_Payment_Schedule__c>> targetsByBooking = new Map<Id, List<Booking_Payment_Schedule__c>>();
        for (Id bookingId : byBooking.keySet()) {
            List<Booking_Payment_Schedule__c> ordered = [
                SELECT Id, Booking__c, Payment_Due_Date__c,
                       Installment_Amount__c, TotalPrincipalReceived__c, Advance_Applied__c
                FROM Booking_Payment_Schedule__c
                WHERE Booking__c = :bookingId
                ORDER BY Payment_Due_Date__c ASC, Id ASC
            ];
            targetsByBooking.put(bookingId, ordered);
        }

        List<Booking_Payment_Schedule__c> updates = new List<Booking_Payment_Schedule__c>();

        for (Id bookingId : byBooking.keySet()) {
            List<Booking_Payment_Schedule__c> targetList = targetsByBooking.get(bookingId);
            for (DeltaPool pool : byBooking.get(bookingId)) {
                Decimal remaining = pool.delta;
                for (Booking_Payment_Schedule__c t : targetList) {
                    if (t.Id == pool.sourceScheduleId) continue; // skip source
                    if (t.Payment_Due_Date__c != null && pool.sourceDueDate != null &&
                        t.Payment_Due_Date__c < pool.sourceDueDate) continue; // only same/after source date

                    Decimal outstanding = FinancePolicyUtil.nz(t.Installment_Amount__c)
                                          - FinancePolicyUtil.nz(t.TotalPrincipalReceived__c)
                                          - FinancePolicyUtil.nz(t.Advance_Applied__c);
                    if (outstanding <= 0) continue;

                    Decimal hit = (remaining <= outstanding) ? remaining : outstanding;
                    if (hit <= 0) continue;

                    t.Advance_Applied__c = FinancePolicyUtil.nz(t.Advance_Applied__c) + hit;
                    remaining -= hit;

                    updates.add(t);
                    if (remaining <= 0) break;
                }
            }
        }

        if (!updates.isEmpty()) {
            // De-dup small chance of repeats
            Map<Id, Booking_Payment_Schedule__c> uniq = new Map<Id, Booking_Payment_Schedule__c>();
            for (Booking_Payment_Schedule__c s : updates) uniq.put(s.Id, s);
            update uniq.values();
        }
    }

    // ----- DTOs -----
    private class DeltaRec {
        Id demandId; Decimal delta;
        DeltaRec(Id demandId, Decimal delta) { this.demandId = demandId; this.delta = delta; }
    }
    private class DeltaPool {
        Id sourceScheduleId; Date sourceDueDate; Decimal delta;
        DeltaPool(Id sourceScheduleId, Date sourceDueDate, Decimal delta) {
            this.sourceScheduleId = sourceScheduleId; this.sourceDueDate = sourceDueDate; this.delta = delta;
        }
    }
}