/**
 * InterestWaiverTrigger
 * ------------------------------------------------------------------
 * PURPOSE
 *  - As soon as a waiver row is Approved (or its Approved amount increases),
 *    apply/top-up the booking’s approved waiver pool across its schedules.
 *  - No "effective from/to" date windows are used.
 *
 * WHEN
 *  - AFTER INSERT
 *  - AFTER UPDATE
 *
 * WHAT IT DOES
 *  - Collects the set of Booking__c ids whose waiver state requires (re)allocation:
 *      * Newly Approved rows
 *      * Still Approved but Waiver_Amount__c increased
 *      * Still Approved but Booking__c changed
 *  - Calls WaiverApplyService.applyForBookings(bookingIds)
 *
 * NOTES
 *  - Idempotent behavior is in the service:
 *      Total Approved (sum of Approved rows) minus Already Used (sum of schedules.Interest_Waived__c)
 *      = Remaining pool to allocate now.
 *  - Keep Validation Rules to ensure Approved rows have a Booking and a positive Amount.
 */
trigger InterestWaiverTrigger on Interest_Waiver_Request__c (after update) {
    Set<Id> bookingIds = new Set<Id>();

    // ---- AFTER UPDATE: detect transitions or increases while staying Approved ----
    if (Trigger.isUpdate) {
        for (Integer i = 0; i < Trigger.new.size(); i++) {
            Interest_Waiver_Request__c nw = Trigger.new[i];
            Interest_Waiver_Request__c ow = Trigger.old[i];
            if (nw == null) continue;

            // Skip if no booking or non-positive amount (VR should already prevent this when Approved)
            if (nw.Booking__c == null) continue;

            Boolean nowApproved   = (nw.Status__c == 'Approved');
            Boolean wasApproved   = (ow != null && ow.Status__c == 'Approved');

            // Case 1: became Approved now
            if (nowApproved && !wasApproved && (nw.Waiver_Amount__c != null && nw.Waiver_Amount__c > 0)) {
                bookingIds.add(nw.Booking__c);
                continue;
            }

            // Case 2: still Approved, and amount increased
            if (nowApproved && wasApproved) {
                Decimal newAmt = (nw.Waiver_Amount__c == null ? 0 : nw.Waiver_Amount__c);
                Decimal oldAmt = (ow.Waiver_Amount__c == null ? 0 : ow.Waiver_Amount__c);
                if (newAmt > oldAmt) {
                    bookingIds.add(nw.Booking__c);
                    continue;
                }
                // Case 3: still Approved, and Booking changed (rare but possible)
                if (nw.Booking__c != ow.Booking__c) {
                    // Re-apply for both old and new bookings to keep pools consistent
                    if (ow.Booking__c != null) bookingIds.add(ow.Booking__c);
                    bookingIds.add(nw.Booking__c);
                }
            }
        }
    }

    // ---- Apply/Top-up waiver across schedules for the impacted bookings ----
    if (!bookingIds.isEmpty()) {
        WaiverApplyService.applyForBookings(bookingIds);
    }
}