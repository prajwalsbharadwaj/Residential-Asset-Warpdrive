public class BookingPaymentScheduleTriggerDispatcher extends TriggerDispatcherBase {

    private static Boolean isAfterInsertProcessing = false;
    private static Boolean isAfterUpdateProcessing = false;
    private static Boolean isAfterDeleteProcessing = false;
    private static Boolean isAfterUndeleteProcessing = false;
    private static Boolean isBeforeInsertProcessing = false;

     
    /**
     * Called by the trigger framework to carry out the actions before the Booking_Payment_Schedule__c record(s) are inserted.
     */
    public override void beforeInsert(TriggerParameters tp) {
        if (!isBeforeInsertProcessing) {
            isBeforeInsertProcessing = true;
            execute(new bookingPaySchBeforeInsertTriggerHandler(), tp, TriggerParameters.TriggerEvent.beforeInsert);
            isBeforeInsertProcessing = false;
        } else {
            execute(null, tp, TriggerParameters.TriggerEvent.beforeInsert);
        }
    }
    
    /**
     * Called by the trigger framework to carry out the actions after the Booking_Payment_Schedule__c record(s) are inserted.
     */
    public override void afterInsert(TriggerParameters tp) {
        if (!isAfterInsertProcessing) {
            isAfterInsertProcessing = true;
            execute(new BookingPaySchAfterInsertTriggerHandler(), tp, TriggerParameters.TriggerEvent.afterInsert);
            isAfterInsertProcessing = false;
        } else {
            execute(null, tp, TriggerParameters.TriggerEvent.afterInsert);
        }
    }
    
    /**
     * Called by the trigger framework to carry out the actions after the Booking_Payment_Schedule__c record(s) are updated.
     */
    public override void afterUpdate(TriggerParameters tp) {
        if (!isAfterUpdateProcessing) {
            isAfterUpdateProcessing = true;
            execute(new BookingPaySchAfterUpdateTriggerHandler(), tp, TriggerParameters.TriggerEvent.afterUpdate);
            isAfterUpdateProcessing = false;
        } else {
            execute(null, tp, TriggerParameters.TriggerEvent.afterUpdate);
        }
    }
    
    /**
     * Called by the trigger framework to carry out the actions after the Booking_Payment_Schedule__c record(s) are deleted.
     */
    public override void afterDelete(TriggerParameters tp) {
        if (!isAfterDeleteProcessing) {
            isAfterDeleteProcessing = true;
            execute(new BookingPaySchAfterDeleteTriggerHandler(), tp, TriggerParameters.TriggerEvent.afterDelete);
            isAfterDeleteProcessing = false;
        } else {
            execute(null, tp, TriggerParameters.TriggerEvent.afterDelete);
        }
    }
    
    /**
     * Called by the trigger framework to carry out the actions after the Booking_Payment_Schedule__c record(s) are undeleted.
     */
    public override void afterUnDelete(TriggerParameters tp) {
        if (!isAfterUndeleteProcessing) {
            isAfterUndeleteProcessing = true;
            execute(new BookingPaySchAfterUndeleteTriggerHandler(), tp, TriggerParameters.TriggerEvent.afterUnDelete);
            isAfterUndeleteProcessing = false;
        } else {
            execute(null, tp, TriggerParameters.TriggerEvent.afterUnDelete);
        }
    }
}