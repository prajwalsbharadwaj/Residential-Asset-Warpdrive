@isTest
private class PaymentPlanControllerTest {

    @isTest
    static void testSearchPaymentPlans() {
        // Prepare test data using factory
        Payment_Plan__c plan1 = ResidentialTestDataFactory.createPaymentPlan();
        Payment_Plan__c plan2 = new Payment_Plan__c(Name = 'Plan Beta', Active__c = true, Use_in_Quotation__c = true);
        insert plan2;

        Test.startTest();
        // Match one record
        List<Payment_Plan__c> results = PaymentPlanController.searchPaymentPlans('Standard');
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(1, results.size(), 'Only Standard Plan should match');
        System.assertEquals('Standard Plan', results[0].Name);
    }

    @isTest
    static void testNoMatchFound() {
        // Prepare data
        ResidentialTestDataFactory.createPaymentPlan();

        Test.startTest();
        List<Payment_Plan__c> results = PaymentPlanController.searchPaymentPlans('NonExisting');
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Should return no records');
    }

    @isTest
    static void testGetUnitIdFromOpportunity_success() {
        // Create related records
        Account acc = ResidentialTestDataFactory.createAccount();
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id);

        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);

        Test.startTest();
        Id returnedUnitId = PaymentPlanController.getUnitIdFromOpportunity(opp.Id);
        Test.stopTest();

        System.assertEquals(unit.Id, returnedUnitId, 'Returned Unit Id should match the one linked to Opportunity');
    }

    @isTest
    static void testGetUnitIdFromOpportunity_withException() {
        // Pass an invalid Opportunity Id to trigger exception
        Test.startTest();
        Id returnedUnitId = PaymentPlanController.getUnitIdFromOpportunity('006000000000001AAA');
        Test.stopTest();

        System.assertEquals(null, returnedUnitId, 'Should return null when Opportunity not found');
    }
}