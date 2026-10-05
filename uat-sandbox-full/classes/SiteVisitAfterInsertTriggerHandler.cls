public class SiteVisitAfterInsertTriggerHandler extends TriggerHandlerBase {
    
    private SiteVisitHelper helper = new SiteVisitHelper();
    
	public override void mainEntry(TriggerParameters tp) {
		process((List<Site_Visit__c>)tp.newList);
	}
    
    private void process(List<Site_Visit__c> records) {
    Set<Id> leadIds = new Set<Id>();
    Set<Id> recordTypeIds = new Set<Id>();
    
    // Collect RecordTypeIds from incoming records
    for (Site_Visit__c sv : records) {
        if (sv.RecordTypeId != null) {
            recordTypeIds.add(sv.RecordTypeId);
        }
    }
    
    // Query RecordType to get DeveloperName
    Map<Id, RecordType> rtMap = new Map<Id, RecordType>(
        [SELECT Id, DeveloperName FROM RecordType WHERE Id IN :recordTypeIds]
    );
        system.debug('Record Type Map---> '+rtMap);
    
    // Filter Site Visits by RecordType = 'Standard_Lead_Residential'
    for (Site_Visit__c sv : records) {
        if (sv.Lead__c != null && rtMap.get(sv.RecordTypeId)?.DeveloperName == 'Residential_Sales_Site_Visit') {
            system.debug('Record Type---> '+rtMap.get(sv.RecordTypeId).DeveloperName);
            leadIds.add(sv.Lead__c);
        }
    }
    
    if (!leadIds.isEmpty()) {
        helper.updateNoRecentInteractionFlagOnLead(leadIds);
    }
}

}