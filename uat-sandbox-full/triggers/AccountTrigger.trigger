trigger AccountTrigger on Account (after insert, after update) {

    if (!UtilityClass.isTriggerGloballyDisabled()) {
        TriggerFactory.createTriggerDispatcher(Account.sObjectType);
    }
    
}