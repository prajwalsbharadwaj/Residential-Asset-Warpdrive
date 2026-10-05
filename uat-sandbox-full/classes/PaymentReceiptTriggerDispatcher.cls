public class PaymentReceiptTriggerDispatcher extends TriggerDispatcherBase {

    private static Boolean isAfterInsertProcessing = false;

    public override void afterUpdate(TriggerParameters tp) {
        execute(new PaymentReceiptAfterUpdateHandler(), tp, TriggerParameters.TriggerEvent.afterUpdate);
    }
    
    public override void beforeDelete(TriggerParameters tp){
        execute(new PaymentReceiptBeforeDeleteHandler(), tp, TriggerParameters.TriggerEvent.beforeDelete);
    }
    
    public override void afterInsert(TriggerParameters tp){
        execute(new PaymentReceiptAfterInsertHandler(), tp, TriggerParameters.TriggerEvent.afterInsert);
    }
    
    public override void beforeInsert(TriggerParameters tp){
        execute(new PaymentReceiptBeforeInsertHandler(), tp, TriggerParameters.TriggerEvent.beforeInsert);
    }
    
    public override void beforeUpdate(TriggerParameters tp){
        execute(new PaymentReceiptBeforeUpdateHandler(), tp, TriggerParameters.TriggerEvent.beforeUpdate);
    }
}