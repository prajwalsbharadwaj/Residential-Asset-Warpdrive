public class BookingConAfterInsertTriggerHandler extends TriggerHandlerBase {
    
    public override void mainEntry(TriggerParameters tp) {
        BookingConditionHelper.recalcSiblingsIfBaseChanged((list<Booking_Condition__c>)tp.newList, tp.oldMap);
    }
}