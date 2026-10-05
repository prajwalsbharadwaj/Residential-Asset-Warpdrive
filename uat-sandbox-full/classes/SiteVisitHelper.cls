public class SiteVisitHelper {
    
    public void updateNoRecentInteractionFlagOnLead(Set<Id> leadIds) {
        try {
            List<Lead> leads = [SELECT Id FROM Lead WHERE Id IN :leadIds AND No_Recent_Interaction_90_Days__c = true];
            
            for (Lead lead : leads) {
                lead.No_Recent_Interaction_90_Days__c = false;
            }
            
            if (!leads.isEmpty()) {
                update leads;
            }
        } catch (Exception e) {
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload().withComponentName('SiteVisitHelper').withDescription('Failed to update No_Recent_Interaction_90_Days__c field on Lead.' +' '+ e.getMessage()).withClassName('SiteVisitHelper').withMethodName('updateNoRecentInteractionFlagOnLead').withException(e); ExceptionLogger.logException(payload);
        }
    }
}