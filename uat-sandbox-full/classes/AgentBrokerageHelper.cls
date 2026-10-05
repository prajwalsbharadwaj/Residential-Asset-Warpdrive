public class AgentBrokerageHelper {
    //Create Booking Condition record for 'Brokerage Fix Amt' whenever a Agent Brokerage record is created.
    public static void createBookConForBrokerage(set<Id> agentbrIds){
        try{
            list<Agent_Brokerage__c> AgentBrokerageList = [SELECT Id, Bokerage_Amount__c, Total_Bokerage__c,
                                               Booking__r.Opportunity_Id__c FROM Agent_Brokerage__c WHERE Id in:agentbrIds];
        list<booking_condition__c> bcToInsert = new list<booking_condition__c>();
        for(Agent_Brokerage__c br:AgentBrokerageList){
            if(br.Booking__r.Opportunity_Id__c != null && br.Total_Bokerage__c > 0){
                Booking_Condition__c bc = new Booking_Condition__c();
                bc.Amount__c = br.Total_Bokerage__c;
                bc.Condition_Type__c = 'Brokerage Fix Amt';
                bc.Booking__c = br.Booking__c;
                bc.Opportunity__c = br.Booking__r.Opportunity_Id__c;
                bcToInsert.add(bc);
            }
        }
        if(!bcToInsert.isEmpty()){
            insert bcToInsert;
        }
        }catch(Exception ex){
            ExceptionLogger.logException(new ExceptionLogger.ExceptionLogPayload().withComponentName('Agent Brokerage After Insert Trigger').withClassName('AgentBrokerageHelper').withMethodName('createBookConForBrokerage').withDescription('Failed to Create Booking Condition record for Brokerage Fix Amt whenever a Agent Brokerage record is created.').withException(ex)
            );
        }
}
}