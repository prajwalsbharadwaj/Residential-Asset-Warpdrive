public class AgentBrokerageAfterInsertTriggerHandler extends TriggerHandlerBase {

    public override void mainEntry(TriggerParameters tp) {
        list<Agent_Brokerage__c> newList = (list<Agent_Brokerage__c>)tp.newList;
        
        set<Id> agBrIds = new set<Id>();
        
        for(Agent_Brokerage__c br:newList){
            if(br.Booking__c != null){
                agBrIds.add(br.Id);
            }
        }
        
        If(!agBrIds.isEmpty()){
            AgentBrokerageHelper.createBookConForBrokerage(agBrIds);
        }
    }
}