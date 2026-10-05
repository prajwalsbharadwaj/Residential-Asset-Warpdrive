trigger UnitTrigger on Unit__c (after update, before update) {
	if (!UtilityClass.isTriggerGloballyDisabled()) {
        TriggerFactory.createTriggerDispatcher(Unit__c.SObjectType);
    }
}