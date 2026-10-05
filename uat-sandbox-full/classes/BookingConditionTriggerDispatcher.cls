public class BookingConditionTriggerDispatcher extends TriggerDispatcherBase {

    private static Boolean isAfterUpdateProcessing = false;
    private static Boolean isAfterInsertProcessing = false;
    private static Boolean isBeforeInsertProcessing = false;
	private static Boolean isBeforeUpdateProcessing = false;
  
    
    /**
     * Called by the trigger framework to carry out the actions before the Booking_condition__c record(s) are inserted.
     */
    public override void beforeInsert(TriggerParameters tp) {
        if (!isBeforeInsertProcessing) {
            isBeforeInsertProcessing = true;
            execute(new BookingConBeforeInsertTriggerHandler(), tp, TriggerParameters.TriggerEvent.beforeInsert);
            isBeforeInsertProcessing = false;
        } else {
            execute(null, tp, TriggerParameters.TriggerEvent.beforeInsert);
        }
    }
    
    
    /**
     * Called by the trigger framework to carry out the actions after the Booking_condition__c record(s) are updated.
     */
    public override void afterUpdate(TriggerParameters tp) {
        if (!isAfterUpdateProcessing) {
            isAfterUpdateProcessing = true;
            execute(new BookingConAfterUpdateTriggerHandler(), tp, TriggerParameters.TriggerEvent.afterUpdate);
            isAfterUpdateProcessing = false;
        } else {
            execute(null, tp, TriggerParameters.TriggerEvent.afterUpdate);
        }
    }
    
    /**
     * Called by the trigger framework to carry out the actions after the Booking_condition__c  record(s) are inserted.
     */
    public override void afterInsert(TriggerParameters tp) {
        if (!isAfterInsertProcessing) {
            isAfterInsertProcessing = true;
            execute(new BookingConAfterInsertTriggerHandler(), tp, TriggerParameters.TriggerEvent.afterInsert);
            isAfterInsertProcessing = false;
        } else {
            execute(null, tp, TriggerParameters.TriggerEvent.afterInsert);
        }
    }
    
    public override void beforeUpdate(TriggerParameters tp) {
        if (!isBeforeUpdateProcessing) {
            isBeforeUpdateProcessing = true;
            execute(new BookingConBeforeUpdateTriggerHandler(), tp, TriggerParameters.TriggerEvent.beforeUpdate);
            isBeforeUpdateProcessing = false;
        } else {
            execute(null, tp, TriggerParameters.TriggerEvent.beforeUpdate);
        }
    }
    
    public override void afterUnDelete(TriggerParameters tp) {
        execute(new BookingConAfterUnDeleteTriggerHandler(), tp, TriggerParameters.TriggerEvent.afterUnDelete);
    }
    
    public override void afterDelete(TriggerParameters tp) {
        execute(new BookingConAfterDeleteTriggerHandler(), tp, TriggerParameters.TriggerEvent.afterDelete);
    }
}