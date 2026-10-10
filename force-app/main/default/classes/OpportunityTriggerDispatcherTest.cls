@isTest
private class OpportunityTriggerDispatcherTest {

    @isTest
    static void testOpportunityTriggerDispatcherAndSiteVisits() {
        // Create Property
        Property__c prop = new Property__c(
            Name = 'Nikoo Homes IV'
        );
        insert prop;

        // Create Lead
        Lead ld = new Lead(
            FirstName = 'Vikram',
            LastName = 'Malhotra',
            Company = 'Self',
            Status = 'New',
            MobilePhone = '9876543210'
        );
        insert ld;

        // Create Site Visit pointing to Lead
        Site_Visit__c sv = new Site_Visit__c(
            Lead__c = ld.Id,
            Project__c = prop.Id,
            Status__c = 'Completed',
            Visit_DateTime__c = System.now()
        );
        insert sv;

        // Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Vikram Malhotra Opportunity',
            StageName = 'Negotiation',
            CloseDate = Date.today().addDays(30)
        );

        Test.startTest();
        insert opp;

        // Test RoundRobinLeadQueueable execution
        RoundRobinLeadQueueable queueable = new RoundRobinLeadQueueable(new List<Id>{ ld.Id });
        System.enqueueJob(queueable);
        Test.stopTest();

        // Verify OpportunityTriggerDispatcher handled insertion gracefully
        System.assertNotEquals(null, opp.Id, 'Opportunity should insert successfully');
    }
}
