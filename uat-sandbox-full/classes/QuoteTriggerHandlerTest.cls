@isTest
public class QuoteTriggerHandlerTest {

    @testSetup
    static void setupData() {
        // Create base data for all tests
        Account acc = ResidentialTestDataFactory.createAccount();
        Property__c proj = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(proj.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(proj.Id, tower.Id);
        ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
    }

    @isTest
    static void testHelperWithNoOpportunityId() {
        // Covers the branch where oppIds.isEmpty() = true
        Quote q = new Quote(Name = 'No OppId Quote');
        
        Test.startTest();
        ResQuoteTriggerHelper.markPrimaryQuote(new List<Quote>{ q });
        Test.stopTest();
        
        System.assertEquals(false, q.Primary__c, 
            'Quote without OpportunityId should remain unchanged');
    }

    @isTest
    static void testFirstQuoteMarkedPrimary() {
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];

        Test.startTest();
        Quote q1 = ResidentialTestDataFactory.createQuote(opp.Id, opp.AccountId);
        Test.stopTest();

        // Requery to confirm trigger logic applied
        Quote inserted = [SELECT Id, Primary__c FROM Quote WHERE Id = :q1.Id];
        System.debug('Inserted Quote Primary__c: ' + inserted.Primary__c);

        System.assertEquals(true, inserted.Primary__c,
            'First quote linked to an Opportunity should be marked primary');
    }

    @isTest
    static void testNewQuoteBecomesPrimaryAndOldUnmarked() {
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];
        
        // Insert first quote (should be primary)
        Quote q1 = ResidentialTestDataFactory.createQuote(opp.Id, opp.AccountId);
        System.assertEquals(true, 
            [SELECT Primary__c FROM Quote WHERE Id = :q1.Id].Primary__c,
            'First quote should be primary initially');

        Test.startTest();
        // Insert second quote for same opportunity
        Quote q2 = new Quote(
            Name = 'Second Quote',
            OpportunityId = opp.Id
        );
        insert q2;
        Test.stopTest();

        // Reload all quotes for this opp
        List<Quote> quotes = [
            SELECT Id, Primary__c 
            FROM Quote 
            WHERE OpportunityId = :opp.Id
        ];

        System.assertEquals(2, quotes.size(), 
            'Should have two quotes for the same Opportunity');
        
        Integer primaryCount = 0;
        for (Quote q : quotes) {
            if (q.Primary__c) primaryCount++;
        }
        System.assertEquals(1, primaryCount, 
            'Only one quote should remain primary after inserting a second one');
    }
}