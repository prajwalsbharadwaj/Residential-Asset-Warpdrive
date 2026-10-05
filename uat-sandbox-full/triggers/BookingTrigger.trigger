trigger BookingTrigger on Booking__c (after update, After Insert) {
    if (!UtilityClass.isTriggerGloballyDisabled()) {
        TriggerFactory.createTriggerDispatcher(Booking__c.SObjectType);
    }
}