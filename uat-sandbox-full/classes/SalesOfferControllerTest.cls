@isTest
public class SalesOfferControllerTest {

    @testSetup
    static void setupData() {
        System.debug('==== Entering @testSetup: setupData ====');

        // Create core inventory data
        Account acc = ResidentialTestDataFactory.createAccount();
        System.debug('Created Account: ' + acc);

        Property__c project = ResidentialTestDataFactory.createProject();
        System.debug('Created Project: ' + project);

        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        System.debug('Created Tower: ' + tower);

        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        System.debug('Created Floor: ' + floor);

        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
        System.debug('Created Unit: ' + unit);

        // Create Opportunity linked to unit + account
        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        System.debug('Created Opportunity: ' + opp);

        // Create Quote linked to Opportunity
        Quote q = ResidentialTestDataFactory.createQuote(opp.Id, acc.Id);
        System.debug('Created Quote Chargeable area: ' + q.Chargeable_Area__c);
        System.debug('Created Quote: ' + q);

        // Create Payment Plan + Schedules
        Payment_Plan__c pp = ResidentialTestDataFactory.createPaymentPlan();
        System.debug('Created Payment Plan: ' + pp);

        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(pp.Id);
        System.debug('Created Payment Schedules: ' + schedules);

        System.debug('==== Exiting @testSetup: setupData ====');
    }

    @isTest
    static void testControllerInitialization() {
        // Fetch test data
        Quote q = [SELECT Id, Opportunity.Interested_Unit__c FROM Quote LIMIT 1];
        Payment_Plan__c pp = [SELECT Id FROM Payment_Plan__c LIMIT 1];
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        // Set page params
        Test.setCurrentPage(new PageReference('/apex/SalesOffer'));
        ApexPages.currentPage().getParameters().put('recordId', q.Id);
        ApexPages.currentPage().getParameters().put('paymentPlanId', pp.Id);
        // Instantiate controller
        ApexPages.StandardController sc = new ApexPages.StandardController(unit);
        SalesOfferController ctrl = new SalesOfferController(sc);

        System.assertNotEquals(null, ctrl.unitDetails, 'Unit details should be populated');
        System.assertNotEquals(null, ctrl.quoteDetails, 'Quote should be fetched');
        System.assert(ctrl.grandTotal > 0, 'Grand total should be calculated');
        System.assert(ctrl.otherChargesTotal > 0, 'Other charges should be calculated');
        System.assertEquals(2, ctrl.paymentPlanDetailList.size(), 'Should fetch payment schedules');
        System.assertEquals(2, ctrl.countOfPaymentSchedule, 'Count should match schedule size');
    }

    @isTest
    static void testWithMissingRecordId() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Test.setCurrentPage(new PageReference('/apex/SalesOffer'));
        // No recordId set
        ApexPages.StandardController sc = new ApexPages.StandardController(unit);
        SalesOfferController ctrl = new SalesOfferController(sc);
    }

    @isTest
    static void testErrorHandling() {

        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Payment_Plan__c pp = [SELECT Id FROM Payment_Plan__c];
        delete pp;
        Quote q = [SELECT Id FROM Quote];
        delete q;
        Test.setCurrentPage(new PageReference('/apex/SalesOffer'));
        // Pass invalid recordId + paymentPlanId
        ApexPages.currentPage().getParameters().put('recordId', q.Id);
        ApexPages.currentPage().getParameters().put('paymentPlanId', pp.Id);

        ApexPages.StandardController sc = new ApexPages.StandardController(unit);
        SalesOfferController ctrl = new SalesOfferController(sc);

        // Even in error case, object should be initialized
        System.assertNotEquals(null, ctrl.unitDetails, 'UnitDetails should be initialized in error case');

    }
}