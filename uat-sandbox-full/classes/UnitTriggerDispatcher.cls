public class UnitTriggerDispatcher extends TriggerDispatcherBase {
	private static Boolean isBeforeUpdateProcessing = false;
    private static Boolean isAfterUpdateProcessing = false;

    /**
     * Called by the trigger framework to carry out the actions after the Booking__c record(s) are inserted.
     */
    /*
	public override void beforeUpdate(TriggerParameters tp) {
        if (!isBeforeUpdateProcessing) {
            isBeforeUpdateProcessing = true;
            execute(new UnitBeforeUpdateTriggerHandler(), tp, TriggerParameters.TriggerEvent.beforeUpdate);
            isBeforeUpdateProcessing = false;
        } else {
            execute(null, tp, TriggerParameters.TriggerEvent.beforeUpdate);
        }
    }
	*/

    /**
     * Called by the trigger framework to carry out the actions after the Booking__c record(s) are updated.
     */
    public override void afterUpdate(TriggerParameters tp) {
        if (!isAfterUpdateProcessing) {
            isAfterUpdateProcessing = true;
            execute(new UnitAfterUpdateTriggerHandler(), tp, TriggerParameters.TriggerEvent.afterUpdate);
            isAfterUpdateProcessing = false;
        } else {
            execute(null, tp, TriggerParameters.TriggerEvent.afterUpdate);
        }
    }
}