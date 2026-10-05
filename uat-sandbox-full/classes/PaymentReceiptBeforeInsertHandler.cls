public class PaymentReceiptBeforeInsertHandler extends TriggerHandlerBase {
    public override void mainEntry(TriggerParameters tp) {
        
        PaymentReceiptValidator.validateOnStatusChange(tp.newList);
        PaymentReceiptApprovalValidator.validateOnApproval(tp.newList);
    }
}