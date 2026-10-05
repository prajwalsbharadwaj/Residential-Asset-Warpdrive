trigger AgentBrokerageTrigger on Agent_brokerage__c (After insert) {
    if (!UtilityClass.isTriggerGloballyDisabled()) {
         TriggerFactory.createTriggerDispatcher(Agent_brokerage__c.SObjectType);
    }
}