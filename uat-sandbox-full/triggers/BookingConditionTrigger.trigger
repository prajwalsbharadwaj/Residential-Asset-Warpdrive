trigger BookingConditionTrigger on Booking_Condition__c (Before Insert, After Insert,After update, before update, after delete, after undelete) {
    if (!UtilityClass.isTriggerGloballyDisabled()) {
         TriggerFactory.createTriggerDispatcher(Booking_Condition__c.SObjectType);
    }
}