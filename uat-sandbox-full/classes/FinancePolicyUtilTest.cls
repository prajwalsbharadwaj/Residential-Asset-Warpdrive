@IsTest
private class FinancePolicyUtilTest {
    @IsTest
    static void testNzDelegatesToProvider() {
        Test.startTest();
        // explicitly set a test policy so provider is initialised predictably
        FinancePolicyProvider.setTestPolicy(new FinancePolicyProvider.Policy(9, 10, 5));
        Decimal fromNull = FinancePolicyUtil.nz(null);
        Decimal fromValue = FinancePolicyUtil.nz(5.1234);
        Test.stopTest();

        System.assertEquals(0, fromNull, 'nz should convert null to zero');
        System.assertEquals(5.1234, fromValue, 'nz should return the original decimal when not null');

        FinancePolicyProvider.clearTestOverride();
        FinancePolicyProvider.clearCache();
    }
}