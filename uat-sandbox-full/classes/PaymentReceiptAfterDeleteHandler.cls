public class PaymentReceiptAfterDeleteHandler extends TriggerHandlerBase {
    public override void mainEntry(TriggerParameters tp) {
        
        ManualReceiptAccrualService.process(tp.newList, null, false, false);
    }
}