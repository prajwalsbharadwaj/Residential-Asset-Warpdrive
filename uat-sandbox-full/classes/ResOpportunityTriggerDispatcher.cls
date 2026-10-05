public class ResOpportunityTriggerDispatcher extends TriggerDispatcherBase {
	
    private static Boolean isBeforeUpdateProcessing = false;
    private static Boolean isAfterUpdateProcessing = false;

    /**
     * Called by the trigger framework to carry out the actions before the opportunity record(s) are updated.
     */
    public override void beforeUpdate(TriggerParameters tp) {
        if (!isBeforeUpdateProcessing) {
            isBeforeUpdateProcessing = true;
            
            execute(new ResOpportunityBeforeUpdateTriggerHandler(), tp, TriggerParameters.TriggerEvent.beforeUpdate);
            isBeforeUpdateProcessing = false;
        }
    }
    
    /**
     * Called by the trigger framework to carry out the actions after the opportunity record(s) are updated.
     */
    public override void afterUpdate(TriggerParameters tp) {
        if (!isAfterUpdateProcessing) {
            isAfterUpdateProcessing = true;
            execute(new ResOpportunityAfterUpdateTriggerHandler(), tp, TriggerParameters.TriggerEvent.afterUpdate);
            isAfterUpdateProcessing = false;
        }
    }
}