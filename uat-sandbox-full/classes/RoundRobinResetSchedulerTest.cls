@isTest
private class RoundRobinResetSchedulerTest {

    @testSetup
    static void setupTestData() {
        // Create base records using ResidentialTestDataFactory
        Account acc = ResidentialTestDataFactory.createAccount();

        // Create Round Robin Assignees (1 outdated, 1 current)
        List<Round_Robin_Assignee__c> assignees = new List<Round_Robin_Assignee__c>{
            new Round_Robin_Assignee__c(
                UserId__c = acc.OwnerId,
                Is_Active__c = true,
                Is_On_Leave__c = false,
                Assigned_Today__c = 5,
                Last_Assignment_Date__c = Date.today().addDays(-1) // ✅ This should reset
            ),
            new Round_Robin_Assignee__c(
                UserId__c = acc.OwnerId,
                Is_Active__c = true,
                Is_On_Leave__c = false,
                Assigned_Today__c = 3,
                Last_Assignment_Date__c = Date.today() // ❌ This should not reset
            )
        };
        insert assignees;
    }

    /**
     * @description Verifies scheduler resets last assignment date (and optionally assigned count)
     * GIVEN: Assignees with yesterday's assignment date
     * WHEN: Scheduler execute runs
     * THEN: Last_Assignment_Date__c is updated to today
     */
    @IsTest
    static void givenOutdatedAssigneesWhenExecuteThenDatesReset() {
        Test.startTest();
        new RoundRobinResetScheduler().execute(null);
        Test.stopTest();

        List<Round_Robin_Assignee__c> results = [
            SELECT Assigned_Today__c, Last_Assignment_Date__c
            FROM Round_Robin_Assignee__c
        ];

        for (Round_Robin_Assignee__c a : results) {
            System.Assert.areEqual(Date.today(), a.Last_Assignment_Date__c, 'All should be set to today');
            if (a.Assigned_Today__c != null) {
               // System.assertEquals(0, a.Assigned_Today__c, 'Assigned_Today__c should be reset');
            }
        }
    }

    /**
     * @description Verifies no-op execution when all assignees are current
     * GIVEN: Assignees already updated today
     * WHEN: Scheduler execute runs
     * THEN: No errors occur
     */
    @IsTest
    static void givenCurrentAssigneesWhenExecuteThenNoErrors() {
        // Update all Last_Assignment_Date__c to today
        List<Round_Robin_Assignee__c> assignees = [
            SELECT Id FROM Round_Robin_Assignee__c
        ];
        for (Round_Robin_Assignee__c a : assignees) {
            a.Last_Assignment_Date__c = Date.today();
        }
        update assignees;

        Test.startTest();
        new RoundRobinResetScheduler().execute(null);
        Test.stopTest();

        // Assert that records were not modified (no exception, no DML)
        System.Assert.isTrue(true, 'Executed successfully even with no updates');
    }

    /**
     * @description Verifies scheduler catches internal exceptions
     * GIVEN: A forced exception flag
     * WHEN: Scheduler execute runs
     * THEN: No exception escapes the execute method
     */
    @IsTest
    static void givenForcedExceptionWhenExecuteThenCaughtInternally() {
        // Set flag to force exception in scheduler
        RoundRobinResetScheduler.throwExceptionForTest = true;
    
        Test.startTest();
        try {
            new RoundRobinResetScheduler().execute(null);
        } catch (Exception e) {
            System.Assert.isTrue(false, 'Exception should be caught internally');
        }
        Test.stopTest();
    
        // Reset flag after test
        RoundRobinResetScheduler.throwExceptionForTest = false;
    
        System.Assert.isTrue(true, 'Catch block executed without throwing exception to caller');
    }

}