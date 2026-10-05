public class PaymentScheduleHelper {
    
    public void assignInstallmentNumbers(List<Payment_Schedule__c> newRecords) {
        try {
            Set<Id> paymentPlanIds = new Set<Id>();
            
            for (Payment_Schedule__c ps : newRecords) {
                if (ps.Payment_Plan_Id__c != null) {
                    paymentPlanIds.add(ps.Payment_Plan_Id__c);
                }
            }
            
            if (paymentPlanIds.isEmpty()) return;
            
            // Query existing schedule counts per payment plan
            Map<Id, Integer> planToCountMap = new Map<Id, Integer>();
            for (AggregateResult ar : [
                SELECT Payment_Plan_Id__c planId, COUNT(Id) ct 
                FROM Payment_Schedule__c 
                WHERE Payment_Plan_Id__c IN :paymentPlanIds
                GROUP BY Payment_Plan_Id__c
            ]) {
                planToCountMap.put((Id) ar.get('planId'), (Integer) ar.get('ct'));
            }
            
            // Assign installment numbers
            Map<Id, Integer> runningCounter = new Map<Id, Integer>();
            for (Payment_Schedule__c ps : newRecords) {
                Id planId = ps.Payment_Plan_Id__c;
                if (planId == null) continue;
                
                Integer baseCount = planToCountMap.containsKey(planId) ? planToCountMap.get(planId) : 0;
                Integer offset = runningCounter.containsKey(planId) ? runningCounter.get(planId) : 0;
                Integer newInstallmentNumber = baseCount + offset + 1;
                
                ps.Installment_Number__c = newInstallmentNumber;
                runningCounter.put(planId, offset + 1);
            }
        } catch (Exception e) {
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('PaymentScheduleHelper')
                .withDescription('Failed to assign installment numbers.' + ' ' + e.getMessage())
                .withClassName('PaymentScheduleHelper')
                .withMethodName('assignInstallmentNumbers')
                .withErrorType('DML Operation')
                .withException(e);
            
            ExceptionLogger.logException(payload);
        }
    }
    
    Public void validateMilestoneCodesUnderPaymPlan(list<Payment_Schedule__c> newList, set<Id> planIds){
        
        list<Payment_Schedule__c> existingSchedules = [SELECT Id, Milestone_Code__c, Payment_Plan_Id__c 
                                                       FROM Payment_Schedule__c WHERE Payment_Plan_Id__c IN: planIds];
        system.debug('existingSchedules--> '+existingSchedules);
        if(existingSchedules.isEmpty()) return;
        map<Id, Set<String>> milestoneCodeMap = new map<Id, Set<String>>();
        for(Payment_Schedule__c sch: existingSchedules){
            if (!milestoneCodeMap.containsKey(sch.Payment_Plan_Id__c)) {
                milestoneCodeMap.put(sch.Payment_Plan_Id__c, new Set<String>());
            }
            milestoneCodeMap.get(sch.Payment_Plan_Id__c).add(sch.Milestone_Code__c);
        }
        
        for(Payment_Schedule__c sch: newList){
            if(milestoneCodeMap.containsKey(sch.Payment_Plan_Id__c) && milestoneCodeMap.get(sch.Payment_Plan_Id__c).Contains(sch.Milestone_Code__c)){
                sch.Milestone_Code__c.addError('The milestone code “'+sch.Milestone_Code__c+'” is already used in this Payment Plan. Please choose a different milestone code.');
            }
        }
    }
}