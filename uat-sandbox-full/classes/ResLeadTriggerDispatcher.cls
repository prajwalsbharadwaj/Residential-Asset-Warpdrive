public class ResLeadTriggerDispatcher extends TriggerDispatcherBase {

    // Cache the Residential Lead RecordType Id (safe even in tests)
    public static Id RT_ID_LEAD_RESIDENTIAL;
    static {
        Map<String, Schema.RecordTypeInfo> recordTypeInfoByDevName = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName();
        RT_ID_LEAD_RESIDENTIAL = recordTypeInfoByDevName.get('Standard_Lead_Residential').getRecordTypeId();
    }

    /**
     * After update: when a Lead is just converted, relink its Site Visits to the new Opportunity.
     */
    public override void afterUpdate(TriggerParameters tp) {
        // Build a map of {LeadId -> ConvertedOpportunityId} only for newly-converted leads.
        Map<Id, Id> leadIdToOppId = new Map<Id, Id>();
        Map<Id, SObject> oldMap = tp.oldMap;

        for (SObject sobj : tp.newList) {
            Lead newLead = (Lead) sobj;
            Lead oldLead = oldMap != null ? (Lead) oldMap.get(newLead.Id) : null;
            if (oldLead == null) continue;

            // Converted now (true) but not earlier (false)
            if (newLead.IsConverted == true && oldLead.IsConverted == false) {
                // Optional: limit to Residential lead RT if available
                if (newLead.RecordTypeId == RT_ID_LEAD_RESIDENTIAL) {
                    // Only useful if an Opportunity was created
                    if (newLead.ConvertedOpportunityId != null) {
                        leadIdToOppId.put(newLead.Id, newLead.ConvertedOpportunityId);
                    }
                }
            }
        }

        if (leadIdToOppId.isEmpty()) return;

        // Single SOQL to fetch all Site Visits pointing to those Leads
        List<Site_Visit__c> visits = [
            SELECT Id, Lead__c, Opportunity__c
            FROM Site_Visit__c
            WHERE Lead__c IN :leadIdToOppId.keySet()
        ];

        if (visits.isEmpty()) return;

        for (Site_Visit__c v : visits) {
            v.Opportunity__c = leadIdToOppId.get(v.Lead__c);
            v.Lead__c       = null;
        }

        // Partial success to avoid hard failure on occasional row locks/validation
        Database.Update(visits, /*allOrNone*/ true);
    }
}