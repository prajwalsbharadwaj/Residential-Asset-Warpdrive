public with sharing class BookingLedgerRecalcController {
    @TestVisible private static Boolean bypassAccessCheck = false;
    public class StartResult {
        @AuraEnabled public List<Id> receiptIds;
        public StartResult(List<Id> receiptIds) {
            this.receiptIds = receiptIds == null ? new List<Id>() : receiptIds;
        }
    }

    @AuraEnabled
    public static StartResult startRecalculation(Id bookingId) {
        if (bookingId == null) {
            throw new AuraHandledException('Booking Id is required.');
        }
        assertAccess();
        assertNoInterestWaiver(bookingId);

        Integer entryCount = [
            SELECT COUNT()
            FROM Ledger_Entry__c
            WHERE Booking__c = :bookingId
        ];
        if (entryCount > 10000) {
            throw new AuraHandledException('Too many ledger entries to recalculate in a single action. Please contact your system administrator.');
        }
        if (entryCount > 0) {
            List<Ledger_Entry__c> toDelete = [
                SELECT Id
                FROM Ledger_Entry__c
                WHERE Booking__c = :bookingId
            ];
            delete toDelete;
        }

        List<Payment_Receipt__c> receipts = [
            SELECT Id
            FROM Payment_Receipt__c
            WHERE (Booking_Payment_Schedule__r.Booking__c = :bookingId
                   OR Demand__r.Booking_Id__c = :bookingId)
              AND Receipt_Status__c NOT IN ('Cancelled', 'Bounced')
            ORDER BY Date_Of_Payment__c ASC, CreatedDate ASC
        ];
        List<Id> receiptIds = new List<Id>();
        for (Payment_Receipt__c r : receipts) receiptIds.add(r.Id);
        return new StartResult(receiptIds);
    }

    @AuraEnabled
    public static void processReceipt(Id bookingId, Id receiptId) {
        if (bookingId == null || receiptId == null) {
            throw new AuraHandledException('Booking Id and Receipt Id are required.');
        }
        assertAccess();

        List<Payment_Receipt__c> receiptRows = [
            SELECT Id, Booking_Payment_Schedule__c, Demand__c, Receipt_Status__c,
                   Date_Of_Payment__c, Interest_Applied__c, Tax_on_Interest__c, Principal_Applied__c, Excess_Payment__c
            FROM Payment_Receipt__c
            WHERE Id = :receiptId
            LIMIT 1
        ];
        if (receiptRows.isEmpty()) return;
        Payment_Receipt__c receipt = receiptRows[0];

        if (receipt.Receipt_Status__c == 'Cancelled' || receipt.Receipt_Status__c == 'Bounced') {
            return;
        }

        Id resolvedBookingId = resolveBookingId(bookingId, receipt);
        if (resolvedBookingId == null) {
            throw new AuraHandledException('Unable to resolve booking for receipt.');
        }
        if (resolvedBookingId != bookingId) {
            throw new AuraHandledException('Receipt does not belong to the selected booking.');
        }

        List<Booking_Payment_Schedule__c> schedules = [
            SELECT Id, Booking__c, Installment_Amount__c, Installment_Number__c, Payment_Due_Date__c,
                   Milestone_Code__c, Annual_Interest_Rate__c, Grace_Period_Days__c, GST_VAT_Rate_On_Interest__c
            FROM Booking_Payment_Schedule__c
            WHERE Booking__c = :resolvedBookingId
            ORDER BY Payment_Due_Date__c, Installment_Number__c, Id
        ];

        LedgerEntryService.postReceipt(new Booking__c(Id = resolvedBookingId), receipt, schedules);

        try {
            update new Payment_Receipt__c(Id = receipt.Id, Receipt_Status__c = 'Posted');
        } catch (Exception e) {
            // Ignore status update failure to keep ledger rebuild moving.
        }
    }

    private static void assertAccess() {
        if (Test.isRunningTest() && bypassAccessCheck) {
            return;
        }
        // if (!FeatureManagement.checkPermission('RecalculateLedgerEnteriesAccess')) {
        //     throw new AuraHandledException('You do not have access to recalculate ledger entries. Please contact your system administrator.');
        // }
    }

    private static void assertNoInterestWaiver(Id bookingId) {
        List<Ledger_Entry__c> waived = [
            SELECT Id
            FROM Ledger_Entry__c
            WHERE Booking__c = :bookingId
              AND Type__c = :LedgerConst.TYPE_INTEREST_WAIVER
            LIMIT 1
        ];
        if (!waived.isEmpty()) {
            throw new AuraHandledException('Ledger entries cannot be recalculated because interest is waived off. Please contact your system administrator.');
        }
    }

    private static Id resolveBookingId(Id bookingId, Payment_Receipt__c receipt) {
        Id resolved = bookingId;
        Id scheduleId = receipt.Booking_Payment_Schedule__c;
        Id demandId = receipt.Demand__c;

        if (scheduleId == null && demandId != null) {
            Demand__c d = [
                SELECT Id, Booking_Payment_Schedule_Id__c, Booking_Id__c
                FROM Demand__c
                WHERE Id = :demandId
                LIMIT 1
            ];
            if (d.Booking_Id__c != null) resolved = d.Booking_Id__c;
            if (scheduleId == null) scheduleId = d.Booking_Payment_Schedule_Id__c;
        }

        if (scheduleId != null) {
            List<Booking_Payment_Schedule__c> scheds = [
                SELECT Id, Booking__c
                FROM Booking_Payment_Schedule__c
                WHERE Id = :scheduleId
                LIMIT 1
            ];
            if (!scheds.isEmpty() && scheds[0].Booking__c != null) {
                resolved = scheds[0].Booking__c;
            }
        }

        return resolved;
    }
}