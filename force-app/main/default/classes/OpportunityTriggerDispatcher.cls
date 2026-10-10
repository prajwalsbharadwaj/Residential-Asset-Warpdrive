/**
 * @description Master trigger dispatcher for Opportunity.
 * Automatically links Site Visits from originating Leads to new Opportunities,
 * and processes resale queueables.
 */
public with sharing class OpportunityTriggerDispatcher extends TriggerDispatcherBase {

    public override void beforeInsert(TriggerParameters tp) { }

    public override void afterInsert(TriggerParameters tp) {
        Set<Id> oppIds = new Set<Id>();
        List<Id> resaleOppIds = new List<Id>();

        for (Opportunity opp : (List<Opportunity>) tp.newList) {
            oppIds.add(opp.Id);
            if (String.isNotBlank(opp.Buyer_Name__c)) {
                resaleOppIds.add(opp.Id);
            }
        }

        // 1. Fetch site visits tagged to opportunity's lead and show on opp
        if (!oppIds.isEmpty()) {
            List<Lead> convertedLeads = [
                SELECT Id, ConvertedOpportunityId 
                FROM Lead 
                WHERE ConvertedOpportunityId IN :oppIds
            ];
            if (!convertedLeads.isEmpty()) {
                Map<Id, Id> leadIdToOppId = new Map<Id, Id>();
                for (Lead ld : convertedLeads) {
                    leadIdToOppId.put(ld.Id, ld.ConvertedOpportunityId);
                }
                ResLeadTriggerDispatcher.repointSiteVisitsOnConversion(leadIdToOppId);
            }
        }

        // 2. Enqueue Resale Buyer account creation if needed
        if (!resaleOppIds.isEmpty() && !System.isFuture() && !System.isBatch() && !System.isQueueable()) {
            System.enqueueJob(new ResaleBuyerCreationQueueable(resaleOppIds));
        }
    }

    public override void beforeUpdate(TriggerParameters tp) { }
    public override void afterUpdate(TriggerParameters tp) { }
    public override void beforeDelete(TriggerParameters tp) { }
}
