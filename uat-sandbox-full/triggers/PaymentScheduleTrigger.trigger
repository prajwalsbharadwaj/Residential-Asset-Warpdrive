trigger PaymentScheduleTrigger on Payment_Schedule__c (before insert, before update) {
    if (!UtilityClass.isTriggerGloballyDisabled()) {
        TriggerFactory.CreateTriggerDispatcher(Payment_Schedule__c.SObjectType);
    }
}