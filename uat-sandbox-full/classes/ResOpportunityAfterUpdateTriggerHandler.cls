public class ResOpportunityAfterUpdateTriggerHandler extends TriggerHandlerBase {

    public override void mainEntry(TriggerParameters tp) {
        List<Opportunity> newList = (List<Opportunity>)tp.newList;
        Map<Id, SObject> oldMap = tp.oldMap;
        
        
        Set<Id> oppIds = new Set<Id>();
        Set<Id> tokenOpIds = new Set<Id>();
        set<Id> stageChangeOpIds = new set<Id>();
        //set<Id> discountOnBpOpIds = new set<Id>();
        set<Id> deleteDiscountBookConOpIds = new set<Id>();
        
        // Collect Opportunity Ids where Interested Unit has changed
        for (Opportunity op : newList) {
            Opportunity oldOp = (Opportunity)oldMap.get(op.Id);
            if (op.Interested_Unit__c != oldOp.Interested_Unit__c && op.Interested_Unit__c != null) {
                oppIds.add(op.Id);
            }
            
            // Collect Opportunity Ids where Token Amount has changed
            /*if(oldOp.Token_Amount__c != op.Token_Amount__c){
                tokenOpIds.add(op.Id);
            }*/

            // Collect Opportunity Ids where Discount Percentage has changed
            if(oldop.Actual_Discount_Percentage__c != op.Actual_Discount_Percentage__c 
               && op.Actual_Discount_Percentage__c > 0){
                stageChangeOpIds.add(op.Id);
            }
            
            /*if(oldOp.Actual_Discount_Percentage__c != op.Actual_Discount_Percentage__c && op.Actual_Discount_Percentage__c > 0 &&
              (op.Discount_Approval_Status__c == 'Approved' || op.Discount_Approval_Status__c == 'Approval Not Required')){
                discountOnBpOpIds.add(op.Id);
            }*/
            if(oldOp.Interested_Unit__c != op.Interested_Unit__c && op.Actual_Discount_Percentage__c != null && op.Actual_Discount_Percentage__c > 0){
                deleteDiscountBookConOpIds.add(op.Id);
            }
        }

        if (!oppIds.isEmpty()) {
            OpportunityHelper.upsertBookingCondForBpPrice(oppIds);
            OpportunityHelper.upsertBookCondForOthrChargOnTower(oppIds);
            OpportunityHelper.upsertDefaultCgstSgstBookCon(oppIds);
        }

        /*if (!tokenOpIds.isEmpty()) {
            OpportunityHelper.createBookPaySchForTokenAmount(tokenOpIds);
        }*/
        if(!stageChangeOpIds.isEmpty()){
            OpportunityHelper.updateOppStageDiscountAppr(stageChangeOpIds);
        }
        /*if(!discountOnBpOpIds.isEmpty()){
            OpportunityHelper.createBookCondForDiscountAmount(discountOnBpOpIds);
        }*/
        if(!deleteDiscountBookConOpIds.isEmpty()){
            OpportunityHelper.deleteBookConDiscntRecords(deleteDiscountBookConOpIds);
        }
    }
}