public class QuoteTriggerDispatcher extends TriggerDispatcherBase {

    private static Boolean isbeforeInsertProcessing = false;
    
    /**
     * Called by the trigger framework to carry out the actions before the Quote  record(s) are inserted.
     */
    public override void beforeInsert(TriggerParameters tp) {
        if (!isbeforeInsertProcessing) {
            isbeforeInsertProcessing = true;
            execute(new QuoteBeforeInsertTriggerhandler(), tp, TriggerParameters.TriggerEvent.beforeInsert);
            isbeforeInsertProcessing = false;
        } else {
            execute(null, tp, TriggerParameters.TriggerEvent.beforeInsert);
        }
    }
}