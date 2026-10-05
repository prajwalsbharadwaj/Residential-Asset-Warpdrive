public class bookingPaySchBeforeInsertTriggerHandler extends TriggerHandlerBase {
    
    public override void mainEntry(TriggerParameters tp) {
        
        BookingPaymentSchHelper.assignFinanceDetails(tp.newList);
        
    }
    
}