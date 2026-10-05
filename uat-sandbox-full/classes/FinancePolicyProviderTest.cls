@IsTest
private class FinancePolicyProviderTest {

    @testSetup
    static void resetProvider() {
        FinancePolicyProvider.reset();
    }

    @IsTest
    static void testDefaultGettersViaOverride() {
        FinancePolicyProvider.reset();
        FinancePolicyProvider.setTestPolicy(new FinancePolicyProvider.Policy(9, 10, 5));

        System.assertEquals(10, FinancePolicyProvider.graceDays());
        System.assertEquals(9, FinancePolicyProvider.annualRatePct());
        System.assertEquals(5, FinancePolicyProvider.interestTaxPct());

        System.assertEquals(0, FinancePolicyProvider.daysNonNeg(null, Date.today()));
        System.assertEquals(0, FinancePolicyProvider.daysNonNeg(Date.today(), Date.today().addDays(-1)));
        System.assertEquals(3, FinancePolicyProvider.daysNonNeg(Date.today(), Date.today().addDays(2)));
    }

    @IsTest
    static void testForOpportunityAndBookingWithOverride() {
        FinancePolicyProvider.reset();
        FinancePolicyProvider.setTestPolicy(new FinancePolicyProvider.Policy(12, 20, 18));

        Account acc = ResidentialTestDataFactory.createAccount();
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, project.Id);

        Opportunity oppWithRelations = [
            SELECT Id, Interested_Unit__r.Property__r.Name
            FROM Opportunity
            WHERE Id = :opp.Id
        ];
        Booking__c bookingWithRelations = [
            SELECT Id, Unit_Id__r.Property__r.Name
            FROM Booking__c
            WHERE Id = :booking.Id
        ];

        FinancePolicyProvider.Policy policyFromOpp = FinancePolicyProvider.forOpportunity(oppWithRelations);
        System.assertEquals(12, policyFromOpp.annualRate);
        System.assertEquals(20, policyFromOpp.graceDays);
        System.assertEquals(18, policyFromOpp.taxRate);

        FinancePolicyProvider.Policy policyFromBooking = FinancePolicyProvider.forBooking(bookingWithRelations);
        System.assertEquals(12, policyFromBooking.annualRate);
        System.assertEquals(20, policyFromBooking.graceDays);
        System.assertEquals(18, policyFromBooking.taxRate);

        FinancePolicyProvider.Policy policyFromGeneric = FinancePolicyProvider.forOpportunity(new Opportunity());
        System.assertEquals(12, policyFromGeneric.annualRate);
        System.assertEquals(20, policyFromGeneric.graceDays);
        System.assertEquals(18, policyFromGeneric.taxRate);
    }

    @IsTest
    static void testTestOverrideLifecycle() {
        FinancePolicyProvider.reset();

        FinancePolicyProvider.setTestPolicy(new FinancePolicyProvider.Policy(7, 3, 2));
        FinancePolicyProvider.Policy overridePolicy = FinancePolicyProvider.get();
        System.assertEquals(7, overridePolicy.annualRate);
        System.assertEquals(3, overridePolicy.graceDays);
        System.assertEquals(2, overridePolicy.taxRate);

        FinancePolicyProvider.clearTestOverride();
        FinancePolicyProvider.clearCache();
        FinancePolicyProvider.Policy defaultPolicy = FinancePolicyProvider.get();

    }
}