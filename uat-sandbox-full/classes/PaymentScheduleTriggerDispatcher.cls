public class PaymentScheduleTriggerDispatcher extends TriggerDispatcherBase {

    private static Boolean isBeforeInsertProcessing = false;
    private static Boolean isBeforeUpdateProcessing = false;

    public override void beforeInsert(TriggerParameters tp) {
        if (!isBeforeInsertProcessing) {
            isBeforeInsertProcessing = true;
            execute(new PaymentSchBeforeInsertTriggerHandler(), tp, TriggerParameters.TriggerEvent.beforeInsert);
            isBeforeInsertProcessing = false;
        } else {
            execute(null, tp, TriggerParameters.TriggerEvent.beforeInsert);
        }
    }
    
    public override void beforeUpdate(TriggerParameters tp) {
        if (!isBeforeUpdateProcessing) {
            isBeforeUpdateProcessing = true;
            execute(new PaymentSchBeforeUpdateTriggerHandler(), tp, TriggerParameters.TriggerEvent.beforeUpdate);
            isBeforeUpdateProcessing = false;
        } else {
            execute(null, tp, TriggerParameters.TriggerEvent.beforeUpdate);
        }
    }
}