trigger SiteVisitTrigger on Site_Visit__c (after insert) {
	TriggerFactory.createTriggerDispatcher(Site_Visit__c.sObjectType); 
}