/**
 * Routes trigger events for Opportunities with the Resale_Assistance record type.
 */
public with sharing class ResaleOpportunityTriggerDispatcher extends TriggerDispatcherBase {

    public override void beforeInsert(TriggerParameters tp)  { }

    public override void afterInsert(TriggerParameters tp) {
        // Run buyer account/contact creation in a Queueable so any failure
        // does not roll back the Opportunity itself.
        List<Id> oppIds = new List<Id>();
        for (Opportunity opp : (List<Opportunity>) tp.newList) {
            if (String.isNotBlank(opp.Buyer_Name__c)) {
                oppIds.add(opp.Id);
            }
        }
        if (!oppIds.isEmpty() && !System.isFuture() && !System.isBatch()) {
            System.enqueueJob(new ResaleBuyerCreationQueueable(oppIds));
        }
    }

    public override void beforeUpdate(TriggerParameters tp)  { }
    public override void afterUpdate(TriggerParameters tp)   { }
    public override void beforeDelete(TriggerParameters tp)  { }
}