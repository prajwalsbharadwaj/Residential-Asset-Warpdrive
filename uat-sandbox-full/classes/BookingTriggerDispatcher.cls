public class BookingTriggerDispatcher extends TriggerDispatcherBase {

    private static Boolean isAfterInsertProcessing = false;
    private static Boolean isAfterUpdateProcessing = false;

    /**
     * Called by the trigger framework to carry out the actions after the Booking__c record(s) are inserted.
     */
    public override void afterInsert(TriggerParameters tp) {
        if (!isAfterInsertProcessing) {
            isAfterInsertProcessing = true;
            execute(new BookingAfterInsertTriggerHandler(), tp, TriggerParameters.TriggerEvent.afterInsert);
            isAfterInsertProcessing = false;
        } else {
            execute(null, tp, TriggerParameters.TriggerEvent.afterInsert);
        }
    }

    /**
     * Called by the trigger framework to carry out the actions after the Booking__c record(s) are updated.
     */
    public override void afterUpdate(TriggerParameters tp) {
        if (!isAfterUpdateProcessing) {
            isAfterUpdateProcessing = true;
            execute(new BookingAfterUpdateTriggerHandler(), tp, TriggerParameters.TriggerEvent.afterUpdate);
            isAfterUpdateProcessing = false;
        } else {
            execute(null, tp, TriggerParameters.TriggerEvent.afterUpdate);
        }
    }
}