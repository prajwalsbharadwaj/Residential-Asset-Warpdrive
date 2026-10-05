public class WaiverUtil {
    /** Returns total Approved waiver per booking (BookingId -> Decimal). */
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
}