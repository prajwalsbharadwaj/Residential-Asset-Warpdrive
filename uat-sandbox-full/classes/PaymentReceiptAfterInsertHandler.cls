public class PaymentReceiptAfterInsertHandler extends TriggerHandlerBase {
    private static Boolean isProcessing = false;
    
    public override void mainEntry(TriggerParameters tp) {
        if (isProcessing) {
            return;
        }
        isProcessing = true;
        
        try{
            List<Payment_Receipt__c> newReceipts = (List<Payment_Receipt__c>) tp.newList;
            if (newReceipts == null || newReceipts.isEmpty()) {
                return;
            }
            
            handleLedgerActions(newReceipts);
            
        }finally{
            isProcessing = false;
        }
        
    }
    
    private static void handleLedgerActions(List<Payment_Receipt__c> newReceipts) {
        List<Payment_Receipt__c> toPost = new List<Payment_Receipt__c>();
        for (Payment_Receipt__c receipt : newReceipts) {
            if (receipt == null) {
                continue;
            }
            
            if (receipt.Receipt_Status__c != 'Cancelled' && receipt.Receipt_Status__c != 'Bounced') {
                toPost.add(receipt);
            }
        }
        
        System.debug('Topost: ' + toPost.isEMpty());
        if (!toPost.isEmpty()) {
            postReceipts(toPost);
        }
    }
    
    private static void postReceipts(List<Payment_Receipt__c> receipts) {
        system.debug('reached in postReceipts method');
        // collect IDs we need
        Set<Id> demandIds = new Set<Id>();
        Set<Id> scheduleIds = new Set<Id>();
        for (Payment_Receipt__c receipt : receipts) {
            if (receipt == null) continue;
            if (receipt.Demand__c != null) {
                demandIds.add(receipt.Demand__c);
            }
            if (receipt.Booking_Payment_Schedule__c != null) {
                scheduleIds.add(receipt.Booking_Payment_Schedule__c);
            }
        }

        // Demand → Schedule
        Map<Id, Demand__c> demandMap = demandIds.isEmpty()
            ? new Map<Id, Demand__c>()
            : new Map<Id, Demand__c>([
                SELECT Id, Booking_Payment_Schedule_Id__c, Booking_Id__c
                FROM Demand__c
                WHERE Id IN :demandIds
            ]);
        for (Demand__c demand : demandMap.values()) {
            if (demand.Booking_Payment_Schedule_Id__c != null) {
                scheduleIds.add(demand.Booking_Payment_Schedule_Id__c);
            }
        }

        // Fetch referenced schedules
        Map<Id, Booking_Payment_Schedule__c> scheduleMap = scheduleIds.isEmpty()
            ? new Map<Id, Booking_Payment_Schedule__c>()
            : new Map<Id, Booking_Payment_Schedule__c>([
                SELECT Id, Booking__c, Installment_Amount__c, Milestone_Code__c,
                    Installment_Number__c, Payment_Due_Date__c
                FROM Booking_Payment_Schedule__c
                WHERE Id IN :scheduleIds
            ]);

        // Resolve bookings
        Set<Id> bookingIds = new Set<Id>();
        for (Booking_Payment_Schedule__c sched : scheduleMap.values()) {
            if (sched.Booking__c != null) bookingIds.add(sched.Booking__c);
        }
        for (Demand__c demand : demandMap.values()) {
            if (demand.Booking_Id__c != null) bookingIds.add(demand.Booking_Id__c);
        }

        Map<Id, Booking__c> bookingMap = bookingIds.isEmpty()
            ? new Map<Id, Booking__c>()
            : new Map<Id, Booking__c>([
                SELECT Id, OC_Received__c, Project__r.Name
                FROM Booking__c
                WHERE Id IN :bookingIds
            ]);

        // Preload all schedules per booking (for allocation across open schedules)
        Map<Id, List<Booking_Payment_Schedule__c>> schedulesByBooking = new Map<Id, List<Booking_Payment_Schedule__c>>();
        if (!bookingIds.isEmpty()) {
            for (Booking_Payment_Schedule__c sched : [
                SELECT Id, Booking__c, Installment_Amount__c, Installment_Number__c, Payment_Due_Date__c, Milestone_Code__c
                FROM Booking_Payment_Schedule__c
                WHERE Booking__c IN :bookingIds
                ORDER BY Payment_Due_Date__c, Installment_Number__c
            ]) {
                if (!schedulesByBooking.containsKey(sched.Booking__c)) {
                    schedulesByBooking.put(sched.Booking__c, new List<Booking_Payment_Schedule__c>());
                }
                schedulesByBooking.get(sched.Booking__c).add(sched);
            }
        }

        // Prepare to mark receipts as Posted after successful ledger post
        List<Payment_Receipt__c> markPosted = new List<Payment_Receipt__c>();

        // Post each receipt
        for (Payment_Receipt__c receipt : receipts) {
            if (receipt == null) continue;

            Booking_Payment_Schedule__c schedule = scheduleMap.get(receipt.Booking_Payment_Schedule__c);
            if (schedule == null && receipt.Demand__c != null) {
                Demand__c demand = demandMap.get(receipt.Demand__c);
                if (demand != null && demand.Booking_Payment_Schedule_Id__c != null) {
                    schedule = scheduleMap.get(demand.Booking_Payment_Schedule_Id__c);
                }
            }

            Booking__c booking = null;
            if (schedule != null) {
                booking = bookingMap.get(schedule.Booking__c);
            }
            if (booking == null && receipt.Demand__c != null) {
                Demand__c demand = demandMap.get(receipt.Demand__c);
                if (demand != null && demand.Booking_Id__c != null) {
                    booking = bookingMap.get(demand.Booking_Id__c);
                }
            }
            if (booking == null) {
                // nothing to post
                continue;
            }

            List<Booking_Payment_Schedule__c> openSchedules = schedulesByBooking.get(booking.Id);

            // Call into ledger service (now accrues then posts the receipt)
            LedgerEntryService.postReceipt(booking, receipt, openSchedules);

            // Mark lifecycle as Posted (do not fail the whole op if this update fails)
            markPosted.add(new Payment_Receipt__c(Id = receipt.Id, Receipt_Status__c = 'Posted'));
        }

        if (!markPosted.isEmpty()) {
            try { update markPosted; } catch (Exception e) { /* ignore */ }
        }
    }
}