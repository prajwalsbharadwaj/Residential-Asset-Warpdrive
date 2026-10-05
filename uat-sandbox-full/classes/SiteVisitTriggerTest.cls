@isTest
public class SiteVisitTriggerTest {
    static Id SiteVisitRecordTypeId = Schema.SObjectType.Site_Visit__c.getRecordTypeInfosByDeveloperName().get('Residential_Sales_Site_Visit').getRecordTypeId();

    // Helper to create a list of unique leads for bulk testing. (This method is correct)
    private static List<Lead> createLeads(Integer count, Boolean interactionFlag) {
        List<Lead> leadsToInsert = new List<Lead>();
        Long uniqueBatchId = Math.abs(Crypto.getRandomInteger());

        for (Integer i = 0; i < count; i++) {
            // This logic correctly creates unique, sequential 10-digit phone numbers.
            String uniquePhone = '9555000000';
            Long finalPhone = Long.valueOf(uniquePhone) + i;

            leadsToInsert.add(new Lead(
                FirstName = 'Bulk',
                LastName = 'Lead' + i,
                Company = 'Test Company',
                No_Recent_Interaction_90_Days__c = interactionFlag,
                Phone = String.valueOf(finalPhone),
                Email = 'bulk' + uniqueBatchId + i + '@example.com'
            ));
        }
        insert leadsToInsert;
        return leadsToInsert;
    }

    // Helper to create a single unique Lead.
    private static Lead createLead(String lastName, Boolean interactionFlag) {
        // --- THIS IS THE CORRECTED LINE ---
        // Using Math.mod() instead of the '%' operator for Apex syntax.
        Long uniquePhoneSuffix = Math.mod(Math.abs(Crypto.getRandomInteger()), 1000000000L);
        String tenDigitPhone = '9' + String.valueOf(uniquePhoneSuffix).leftPad(9, '0');

        Lead l = new Lead(
            FirstName = 'Test',
            LastName = lastName,
            Company = 'Test Company',
            No_Recent_Interaction_90_Days__c = interactionFlag,
            Phone = tenDigitPhone,
            Email = 'test' + tenDigitPhone + '@example.com'
        );
        insert l;
        return l;
    }

    // Helper to create a Project
    private static Property__c createProject() {
        Property__c project = new Property__c(Name = 'Test Project', Address__c = 'Test Address');
        insert project;
        return project;
    }

    //------------------------------------------------------------------------------------

    @isTest
    static void testSiteVisitAfterInsertHandler_Bulk() {
        // --- Setup ---
        Property__c project = createProject();
        List<Lead> testLeads = createLeads(3, true);
        List<Site_Visit__c> visits = new List<Site_Visit__c>();
        for(Lead l : testLeads) {
            visits.add(new Site_Visit__c(
                RecordTypeId = SiteVisitRecordTypeId,
                Lead__c = l.Id,
                Visit_DateTime__c = Date.today(),
                Project__c = project.Id
            ));
        }

        // --- Execute ---
        Test.startTest();
        insert visits;
        Test.stopTest();
    }

    // The rest of the test methods...
    @isTest
    static void testTriggerDoesNotFailWithNullLead() {
        Property__c project = createProject();
        Site_Visit__c visit = new Site_Visit__c(Visit_DateTime__c = Date.today(), Project__c = project.Id, RecordTypeId = SiteVisitRecordTypeId);
        Test.startTest();
        Database.SaveResult result = Database.insert(visit, false);
        Test.stopTest();
        System.assert(result.isSuccess(), 'Insert should succeed with a null lead.');
    }

    @isTest
    static void testHelperWithMatchingLead() {
        Lead testLead = createLead('HelperMatch', true);
        Test.startTest();
        new SiteVisitHelper().updateNoRecentInteractionFlagOnLead(new Set<Id>{ testLead.Id });
        Test.stopTest();
        Lead resultLead = [SELECT No_Recent_Interaction_90_Days__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(false, resultLead.No_Recent_Interaction_90_Days__c);
    }
    
    
    ////////////////////////////////////
   

}