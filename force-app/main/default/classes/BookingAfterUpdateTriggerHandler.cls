public class BookingAfterUpdateTriggerHandler extends TriggerHandlerBase {
    
    public override void mainEntry(TriggerParameters tp) {
        Set<Id> BookingIds = new Set<Id>();
        Set<Id> cancelledIds = new Set<Id>();
        Set<Id> changedAccountBookingIds = new set<Id>();
        Set<Id> tokenAmountChangedBookingIds = new set<Id>();
        set<Id> changedCoApplicantBookIds = new set<Id>();
        
        List<Booking__c> newList = (List<Booking__c>) tp.newList;
        Map<Id, Booking__c> oldMap = (Map<Id, Booking__c>) tp.oldMap;
        
        list<booking__c> bookingSyncStatusToUpdate = new list<Booking__c>();
        Map<Id, Booking__c> oldAccountOnBookingMap = new Map<Id,Booking__c>();
        for (Booking__c newBooking : newList) {
            Booking__c oldBooking = oldMap.get(newBooking.Id);
            
            // Check if approval status has changed and is now "Approved"
            if (newBooking.Approval_Status__c != oldBooking.Approval_Status__c && newBooking.Approval_Status__c == 'Booking Approved'){        
                BookingIds.add(newBooking.Id);
                
            }
            
            if(newBooking.Status__c == 'Cancelled' && newBooking.Status__c != oldBooking.Status__c){
                cancelledIds.add(newBooking.Id);
            }
            
            if(newBooking.Token_Amount__c != oldBooking.Token_Amount__c){
                tokenAmountChangedBookingIds.add(newBooking.Id);
            }
            
            if((oldBooking.Co_Applicant_1__c != newBooking.Co_Applicant_1__c) || 
               (oldBooking.Co_Applicant_2__c != newBooking.Co_Applicant_2__c) || 
               (oldBooking.Co_Applicant_3__c != newBooking.Co_Applicant_3__c ) || 
               (oldBooking.Co_Applicant_4__c != newBooking.Co_Applicant_4__c ) ||
               (oldBooking.Co_Applicant_5__c != newBooking.Co_Applicant_5__c )){
                  changedCoApplicantBookIds.add(newBooking.Id);
            }
        }
        
        if(!bookingSyncStatusToUpdate.isEmpty()){
            update bookingSyncStatusToUpdate;
        }
        
        if (!UtilityClass.isSAPSyncInProgress && !BookingIds.isEmpty()) {
            SAPBookingIntegrationHandler.sendBookingDataAsync(BookingIds);
        }
        
        if(!UtilityClass.isSAPSyncInProgress && !cancelledIds.isEmpty()){
            SAPBookingCancellationHandler.sendBookingCancellationAsync(cancelledIds);
        }
        
        /*if(!UtilityClass.isSAPSyncInProgress && !tokenAmountChangedBookingIds.isEmpty()){
            BookingHelper.sendTokenAmountUpdateToSAP(tokenAmountChangedBookingIds);
        }*/
        
        if(!changedCoApplicantBookIds.isEmpty()){
            SAPBookingIntegrationHandler.sendBookingCoApplicantUpdatedData(changedCoApplicantBookIds);
        }
    }
}