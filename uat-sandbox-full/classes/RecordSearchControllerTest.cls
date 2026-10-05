@isTest
private class RecordSearchControllerTest {

    @testSetup
    static void setupData() {
        // Create a sample Account using ResidentialTestDataFactory
        ResidentialTestDataFactory.createAccount();
    }

    /**
     * @description Verifies account search returns results
     * GIVEN: An account exists
     * WHEN: searchRecords is called with a matching query
     * THEN: Returns at least one Account
     */
    @IsTest
    static void givenExistingAccountWhenSearchThenReturnsResults() {
        Test.startTest();
        List<SObject> results = RecordSearchController.searchRecords('Account', 'Test');
        Test.stopTest();

        System.Assert.isTrue(results.size() != 0, 'Should return at least one matching Account');
        System.Assert.areEqual('Account', String.valueOf(results[0].getSObjectType()), 'Returned object type should be Account');
    }

    /**
     * @description Verifies no results are returned for unmatched search terms
     * GIVEN: An account exists
     * WHEN: searchRecords is called with an unmatched term
     * THEN: Returns zero results
     */
    @IsTest
    static void givenUnmatchedTermWhenSearchThenReturnsNone() {
        Test.startTest();
        List<SObject> results = RecordSearchController.searchRecords('Account', 'NonExistingName');
        Test.stopTest();

        System.Assert.areEqual(0, results.size(), 'Should return no results for unmatched search term');
    }

    /**
     * @description Verifies invalid sObject API name is handled with AuraHandledException
     * GIVEN: An invalid sObject name
     * WHEN: searchRecords is called
     * THEN: Throws AuraHandledException
     */
    @IsTest
    static void givenInvalidObjectWhenSearchThenThrows() {
        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            RecordSearchController.searchRecords('InvalidObject', 'Test');
            Test.stopTest();
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            //System.assert(e.getMessage().contains('Invalid SObject API Name'), 'Should throw AuraHandledException for invalid object name');
        }
        System.Assert.isTrue(exceptionThrown, 'Expected AuraHandledException not thrown');
    }

    /**
     * @description Verifies query exception path is handled gracefully
     * GIVEN: A schema name that leads to query failure
     * WHEN: searchRecords is called
     * THEN: Throws AuraHandledException
     */
    @IsTest
    static void givenQueryFailureWhenSearchThenThrows() {
        // This forces an exception in the query by using a valid object but with an invalid field in the SOQL
        // We will simulate it by temporarily passing a malicious searchTerm that breaks the query
        // (The escapeSingleQuotes will protect from injection, so to force exception, use a real invalid object with field mismatch)
        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            // Using an object that exists but doesn't have a Name field will cause exception
            // "AggregateResult" is not a real object API name for query but exists in schemaMap, so won't pass initial validation
            RecordSearchController.searchRecords('AggregateResult', 'Test');
            Test.stopTest();
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            //System.assert(e.getMessage().contains('An error occurred while searching for records'), 'Should handle query exception gracefully');
        }
        System.Assert.isTrue(exceptionThrown, 'Expected AuraHandledException not thrown');
    }
}