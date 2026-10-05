public class AgentBrokerageTriggerDispatcher extends TriggerDispatcherBase {
    private static boolean isAfterInsertProcessing = false;
    
    /**
     * Called by the trigger framework to carry out the actions before the Agent_Brokerage__c record(s) are inserted.
     */
    public override void afterInsert(TriggerParameters tp) {
        if (!isAfterInsertProcessing) {
            isAfterInsertProcessing = true;
            execute(new AgentBrokerageAfterInsertTriggerHandler(), tp, TriggerParameters.TriggerEvent.afterInsert);
            isAfterInsertProcessing = false;
        }
    }
}