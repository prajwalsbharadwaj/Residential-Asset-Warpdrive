public class PaymentSchBeforeUpdateTriggerHandler extends TriggerHandlerBase {

    private PaymentScheduleHelper helper = new PaymentScheduleHelper();

    public override void mainEntry(TriggerParameters tp) {
        list<Payment_Schedule__c> newList = (List<Payment_Schedule__c>)tp.newList;
        map<Id,Payment_Schedule__c> oldMap = (map<Id,Payment_Schedule__c>)tp.oldMap;
   
        set<Id> planIds = new set<Id>();
        for(Payment_Schedule__c ps:newList){
            if(ps.payment_plan_Id__c != null && oldMap.get(ps.Id).Milestone_Code__c != ps.Milestone_Code__c ){
                planIds.add(ps.Payment_Plan_Id__c);
            }
        }
        
        if(!planIds.isEmpty()){
            helper.validateMilestoneCodesUnderPaymPlan(newList,planIds);
        }
    }
    
}