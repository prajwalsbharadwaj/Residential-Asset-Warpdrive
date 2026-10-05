public class BookingConBeforeInsertTriggerHandler extends TriggerHandlerBase {
    
    BookingConditionHelper helper = new BookingConditionHelper();
    
    public override void mainEntry(TriggerParameters tp) {
        list<Booking_Condition__c> newList = (list<Booking_Condition__c>)tp.newList;
        
        helper.calculateLineAmounts(tp.newList);
        BookingConditionHelper.updateTypeInBookCond(newList);
        BookingConditionHelper.assignItemNumbers(newList);
        
    }
}