trigger ResQuoteTrigger on Quote (before insert) {
    if (!UtilityClass.isTriggerGloballyDisabled()) {
        TriggerFactory.createTriggerDispatcher(Quote.SObjectType);
    }
}