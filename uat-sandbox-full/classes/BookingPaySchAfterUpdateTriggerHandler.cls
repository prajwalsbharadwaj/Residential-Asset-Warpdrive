public class BookingPaySchAfterUpdateTriggerHandler extends TriggerHandlerBase {
    public override void mainEntry(TriggerParameters tp) {
        
        list<Booking_Payment_Schedule__c> newList = (list<Booking_Payment_Schedule__c>)tp.newList;
        map<Id, Booking_Payment_Schedule__c> oldMap = (map<Id, Booking_Payment_Schedule__c>)tp.oldMap;
        
        set<Id> bookingPaymentSchIds = new set<Id>();
        set<Id> otherChargesBookingPaymentSchIds = new set<Id>();
        Map<Id, booking__c> bookingSyncStatusToUpdate = new Map<Id, Booking__c>();
        Map<Id, booking__c> bookingSyncStatusOtherChargesToUpdate = new Map<Id, Booking__c>();
        for(Booking_Payment_Schedule__c BPS:newList){
            if(oldMap.get(BPS.Id).Bill_Block__c != BPS.Bill_Block__c && BPS.Booking__c != null && bps.Bill_Block__c == null){
                
                if(BPS.Milestone_Code__c == 'Other Charges'){
                    bookingSyncStatusOtherChargesToUpdate.put(
                        BPS.Booking__c,
                        new Booking__c(
                            Id = BPS.Booking__c,
                            SAP_Sync_Status__c = 'Pending update'
                        )
                    );
                    otherChargesBookingPaymentSchIds.add(BPS.Id);
                }
                else if(!bookingSyncStatusToUpdate.containsKey(BPS.Booking__c)){
                    bookingSyncStatusToUpdate.put(BPS.Booking__c, new Booking__c(
                        Id = BPS.Booking__c,
                        SAP_Sync_Status__c = 'Pending update'
                    ));
                    bookingPaymentSchIds.add(BPS.Id);
                }
                
            }
            
        }
        
        if(!bookingSyncStatusToUpdate.isEmpty()){
            BookingAdminService.updateRecords(bookingSyncStatusToUpdate.values());
        }
        
        if(!bookingSyncStatusToUpdate.isEmpty()){
            SAPBookingIntegrationHandler.sendBookingPaymentSchUpdatedData(bookingSyncStatusToUpdate.keySet(), bookingPaymentSchIds);
        }

        System.debug('bookingSyncStatusOtherChargesToUpdate: ' + bookingSyncStatusOtherChargesToUpdate);
        if(!bookingSyncStatusOtherChargesToUpdate.isEmpty()){
            SAPBookingIntegrationHandler.sendBookingPaymentSchUpdatedOtherChargesData(bookingSyncStatusOtherChargesToUpdate.keySet(), otherChargesBookingPaymentSchIds);
        }
        
    }
}