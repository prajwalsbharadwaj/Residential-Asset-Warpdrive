public class BookingPaySchAfterInsertTriggerHandler extends TriggerHandlerBase {
    
    public override void mainEntry(TriggerParameters tp) {
        
        list<Booking_Payment_Schedule__c> newList = (list<Booking_Payment_Schedule__c>)tp.newList;
        
        
    }
}