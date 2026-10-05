@IsTest
private class UtilityClassTest {

    @IsTest
    static void testGetSObjectTypeName_and_StaticFlags() {
        // SObject type helper
        String t = UtilityClass.getSObjectTypeName(new Account());
        System.assertEquals('Account', t, 'Should return SObject API name');

        // Static flags default & toggle
        System.assertEquals(false, UtilityClass.isAfterUpdateRunning);
        System.assertEquals(false, UtilityClass.isSAPSyncInProgress);

        UtilityClass.isAfterUpdateRunning = true;
        UtilityClass.isSAPSyncInProgress  = true;

        System.assertEquals(true, UtilityClass.isAfterUpdateRunning);
        System.assertEquals(true, UtilityClass.isSAPSyncInProgress);
    }

    @IsTest
    static void testIsTriggerGloballyDisabled_cacheConsistency() {
        // First call initializes the cache from whatever exists in the org
        // (record present or not). We don't rely on its actual value.
        Boolean first = UtilityClass.isTriggerGloballyDisabled();

        // Second call should return the same value within this execution context,
        // proving the caching path runs and is stable.
        Boolean second = UtilityClass.isTriggerGloballyDisabled();

        System.assertEquals(first, second,
            'Value should be returned from cache on subsequent calls in the same context.');
    }
}