public class PaymentSchBeforeInsertTriggerHandler extends TriggerHandlerBase {
    
    private PaymentScheduleHelper helper = new PaymentScheduleHelper();

    public override void mainEntry(TriggerParameters tp) {
        list<Payment_Schedule__c> newList = (List<Payment_Schedule__c>)tp.newList;
        process((List<Payment_Schedule__c>)tp.newList);
        
   
        set<Id> planIds = new set<Id>();
        for(Payment_Schedule__c ps:newList){
            if(ps.payment_plan_Id__c != null){
                planIds.add(ps.Payment_Plan_Id__c);
            }
        }
        
        if(!planIds.isEmpty()){
            helper.validateMilestoneCodesUnderPaymPlan(newList,planIds);
        }
    }

    private void process(List<Payment_Schedule__c> newRecords) {
        helper.assignInstallmentNumbers(newRecords);
        
    }
}