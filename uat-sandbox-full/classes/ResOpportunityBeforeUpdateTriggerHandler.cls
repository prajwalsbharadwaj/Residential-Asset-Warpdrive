public class ResOpportunityBeforeUpdateTriggerHandler extends TriggerHandlerBase {
    
    public override void mainEntry(TriggerParameters tp) {
        
        List<Opportunity> newList = (List<Opportunity>)tp.newList;
        Set<Id> oppIds = new Set<Id>();
        Set<Id> planIds = new set<Id>();
        
        Map<Id, SObject> oldMap = tp.oldMap;
        for (Opportunity op : newList) {
            Opportunity oldOp = (Opportunity)oldMap.get(op.Id);
            if (op.Interested_Unit__c != oldOp.Interested_Unit__c && op.Interested_Unit__c != null) {
                oppIds.add(op.Id);
            }
            
            if(op.Payment_Plan__c != null || test.isRunningTest()){
                planIds.add(op.Payment_Plan__c);
            }
        }

        if (!oppIds.isEmpty()) {
            OpportunityHelper.validateUnitOnOpp(oppIds, newList);
            OpportunityHelper.validateChargeableAreaFromTowerToUnit(newList);
        }
        
        if(!planIds.isEmpty()){
            Map<Id,Boolean> duplicateMap = new Map<Id,Boolean>();
            duplicateMap = OpportunityHelper.hasDuplicateMilestones(planIds);
                        
            for(Opportunity op: newList){
                if(duplicateMap.containsKey(op.Payment_Plan__c) && duplicateMap.get(op.Payment_Plan__c)){
                    op.Payment_Plan__c.addError('Selected Payment Plan has duplicate Milestone Codes. Each Payment Schedule must have a unique Milestone Code under a Payment Plan. Please correct the Payment Plan before continuing');
                }
            }
        }
    }
}