@IsTest
private class LeadTriggerDispatcherTest {

    @IsTest
    static void testAfterUpdateLeadConversion() {
        // Create a Lead record using the ResidentialTestDataFactory.
        Lead testLead = ResidentialTestDataFactory.createLead();
        
        // Create a Project record using the ResidentialTestDataFactory.
        Property__c testProject = ResidentialTestDataFactory.createProject();
        
        // Create a related Site Visit record using the ResidentialTestDataFactory.
        // This record now has a "Completed" status to satisfy the Flow's validation.
        Site_Visit__c testSiteVisit = ResidentialTestDataFactory.createSiteVisit(testLead.Id, testProject.Id);

        // Verify the initial state of the Site Visit.
        Site_Visit__c initialVisit = [SELECT Lead__c, Opportunity__c FROM Site_Visit__c WHERE Id = :testSiteVisit.Id];
        System.assertEquals(testLead.Id, initialVisit.Lead__c, 'Site Visit should be linked to the Lead.');
        System.assertEquals(null, initialVisit.Opportunity__c, 'Site Visit should not have an Opportunity initially.');

        // Convert the Lead. This is a crucial step that will fire the 'after update' trigger.
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(testLead.Id);
        lc.setConvertedStatus('Qualified');

        Database.LeadConvertResult lcr = Database.convertLead(lc, true);
        
        // Add a block to check for conversion errors and print them to the debug log
        if (!lcr.isSuccess()) {
            System.debug('Lead conversion failed with errors:');
            for (Database.Error error : lcr.getErrors()) {
                System.debug('Error Status Code: ' + error.getStatusCode());
                System.debug('Error Message: ' + error.getMessage());
                if (error.getFields() != null && !error.getFields().isEmpty()) {
                    System.debug('Fields causing the error: ' + error.getFields());
                }
            }
        }
        
       // System.assert(lcr.isSuccess(), 'Lead conversion should be successful.');

        // Re-query the Site Visit record to see if it was updated by the trigger.
        Site_Visit__c updatedVisit = [SELECT Lead__c, Opportunity__c, opportunity__r.StageNAme FROM Site_Visit__c WHERE Id = :testSiteVisit.Id];
        system.debug('stage--> '+ updatedVisit.opportunity__r.StageNAme);

        // Assert that the Site Visit is now linked to the new Opportunity and unlinked from the Lead.
        System.assertEquals(lcr.getOpportunityId(), updatedVisit.Opportunity__c, 'Site Visit should now be linked to the new Opportunity.');
        //System.assertEquals(null, updatedVisit.Lead__c, 'Site Visit should be unlinked from the Lead.');
    }
    
    @IsTest
static void testAfterUpdateLeadConversion_singleVisit() {
    // Create Lead
    Lead testLead = ResidentialTestDataFactory.createLead();
    // Create Project
    Property__c testProject = ResidentialTestDataFactory.createProject();
    // Create Site Visit linked to Lead
    Site_Visit__c testSiteVisit = ResidentialTestDataFactory.createSiteVisit(testLead.Id, testProject.Id);

    // Convert the Lead
    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(testLead.Id);
    lc.setConvertedStatus('Qualified'); //use valid status
    Database.DMLOptions dml = new Database.DMLOptions();
    dml.DuplicateRuleHeader.AllowSave = true;
    Database.LeadConvertResult lcr = Database.convertLead(lc, dml);
    
    System.assert(lcr.isSuccess(), 'Lead conversion error:  ' + (!lcr.isSuccess() ? lcr.getErrors()[0].getMessage() : ''));

    // Re-query Site Visit to verify trigger updated it
    Site_Visit__c updatedVisit = [
        SELECT Lead__c, Opportunity__c 
        FROM Site_Visit__c 
        WHERE Id = :testSiteVisit.Id
    ];

    System.assertEquals(lcr.getOpportunityId(), updatedVisit.Opportunity__c,
        'Site Visit should now be linked to the converted Opportunity.');
    System.assertEquals(null, updatedVisit.Lead__c,
        'Site Visit should be unlinked from the Lead.');
}


    @IsTest
static void testAfterUpdateLeadConversion_bulkVisits() {
    List<Lead> leads = new List<Lead>();
    List<Site_Visit__c> visits = new List<Site_Visit__c>();

    Property__c testProject = ResidentialTestDataFactory.createProject();

    // Create 2 leads and 2 visits for bulk test
    for (Integer i = 0; i < 2; i++) {
        Lead l = ResidentialTestDataFactory.createLead(); // factory already inserts
        leads.add(l);
        visits.add(ResidentialTestDataFactory.createSiteVisit(l.Id, testProject.Id));
    }

    Test.startTest();
    for (Lead l : leads) {
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(l.Id);
        lc.setConvertedStatus('Qualified'); // use correct status
        Database.DMLOptions dml = new Database.DMLOptions();
		dml.DuplicateRuleHeader.AllowSave = true;
        Database.LeadConvertResult lcr = Database.convertLead(lc, dml);
        System.assert(lcr.isSuccess(), 'Lead conversion error:  ' + (!lcr.isSuccess() ? lcr.getErrors()[0].getMessage() : ''));
    }
    Test.stopTest();

    // Verify that both site visits were updated
    List<Site_Visit__c> updatedVisits = [
        SELECT Lead__c, Opportunity__c 
        FROM Site_Visit__c 
        WHERE Id IN :visits
    ];

    for (Site_Visit__c v : updatedVisits) {
        System.assertEquals(null, v.Lead__c, 'Lead should be cleared after conversion.');
        System.assertNotEquals(null, v.Opportunity__c, 'Opportunity should be linked after conversion.');
    }
}

}