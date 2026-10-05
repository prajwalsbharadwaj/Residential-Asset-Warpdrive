trigger BookingPaymentScheduleTrigger on Booking_Payment_Schedule__c (before insert, After Insert, After update, After delete, After undelete) {
    if (!UtilityClass.isTriggerGloballyDisabled()) {
        System.debug(Trigger.isUndelete);
         TriggerFactory.createTriggerDispatcher(Booking_Payment_Schedule__c.SObjectType);
    }
}