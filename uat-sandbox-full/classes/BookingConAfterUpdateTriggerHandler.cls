public class BookingConAfterUpdateTriggerHandler extends TriggerHandlerBase {

    private static Boolean isProcessing = false;

    public override void mainEntry(TriggerParameters tp) {
        if (isProcessing) {
            return; 
        }
        isProcessing = true;

        List<Booking_Condition__c> newList = (List<Booking_Condition__c>) tp.newList;
        Map<Id, Booking_Condition__c> oldMap = (Map<Id, Booking_Condition__c>) tp.oldMap;

        Set<Id> bookingIds = new Set<Id>();
        Set<Id> bookingConditionIds = new Set<Id>();

        Map<Id, Booking__c> bookingSyncStatusToUpdate = new Map<Id, Booking__c>();
        set<Id> oppIdsForOthrChrgs = new set<Id>(); 
        
        for (Booking_Condition__c bc : newList) {
            Booking_Condition__c oldBc = oldMap.get(bc.Id);

            if (oldBc != null && bc.Booking__c != null && (
                oldBc.Amount__c != bc.Amount__c ||
                oldBc.Quantity__c != bc.Quantity__c ||
                oldBc.Condition_Type__c != bc.Condition_Type__c
            )) {
                bookingIds.add(bc.Booking__c);
                bookingConditionIds.add(bc.Id);

                bookingSyncStatusToUpdate.put(bc.Booking__c, new Booking__c(
                    Id = bc.Booking__c,
                    SAP_Sync_Status__c = 'Pending update'
                ));
            }
            
            //Opportunity check on Booking Conditions
            if(bc.Opportunity__c != null){
                oppIdsForOthrChrgs.add(bc.Opportunity__c);
            }
        }

        if (!bookingSyncStatusToUpdate.isEmpty()) {
            update bookingSyncStatusToUpdate.values();
        }

        if (!bookingIds.isEmpty()) {
            SAPBookingIntegrationHandler.sendBookingConUpdatedData(bookingIds, bookingConditionIds);
        }

        isProcessing = false;
        
        BookingConditionHelper.recalcSiblingsIfBaseChanged((list<Booking_Condition__c>)tp.newList, tp.oldMap);
    }
}