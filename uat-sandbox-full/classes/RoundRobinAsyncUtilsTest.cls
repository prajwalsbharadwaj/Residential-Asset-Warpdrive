@IsTest
private class RoundRobinAsyncUtilsTest {

    @TestSetup
    static void setupTestData() {
        // Get Standard User profile
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];

        // Create 3 test users
        List<User> users = new List<User>();
        Long timestamp = Datetime.now().getTime();
        for (Integer i = 0; i < 3; i++) {
            users.add(new User(
                Alias = 'user' + i,
                Email = 'user' + i + '@test.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'TestUser' + i,
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'testuser' + i + timestamp + '@test.com',
                IsActive = true
            ));
        }
        insert users;

        // Create 2 Round Robin assignees so reassignment is possible
        List<Round_Robin_Assignee__c> assignees = new List<Round_Robin_Assignee__c>{
            new Round_Robin_Assignee__c(
                UserId__c = users[0].Id,
                Is_Active__c = true,
                Last_Assigned_Count__c = 5,
                Assigned_Today__c = 2,
                Weight__c = 1,
                Max_Leads_Per_Day__c = 10
            ),
            new Round_Robin_Assignee__c(
                UserId__c = users[1].Id,
                Is_Active__c = true,
                Last_Assigned_Count__c = 0,
                Assigned_Today__c = 0,
                Weight__c = 1,
                Max_Leads_Per_Day__c = 10
            )
        };
        insert assignees;
    }

    @IsTest
    static void testCreateMissingAssignees() {
        List<User> users = [SELECT Id FROM User WHERE Alias LIKE 'user%'];
        List<Id> usersToAdd = new List<Id>{ users[2].Id }; // user[2] not an assignee yet

        Test.startTest();
        RoundRobinAsyncUtils.createMissingAssignees(usersToAdd);
        Test.stopTest();

        List<Round_Robin_Assignee__c> newAssignees = [
            SELECT Id, UserId__c, Is_Active__c, Weight__c, Max_Leads_Per_Day__c
            FROM Round_Robin_Assignee__c
            WHERE UserId__c IN :usersToAdd
        ];
        System.assertEquals(1, newAssignees.size(), 'One new assignee should have been created.');
        System.Assert.isTrue(newAssignees[0].Is_Active__c, 'New assignee should be active.');
    }

    @IsTest
    static void testRoundRobinResetScheduler() {
        Round_Robin_Assignee__c assignee = [SELECT Id, Assigned_Today__c, Last_Assignment_Date__c FROM Round_Robin_Assignee__c LIMIT 1];
        assignee.Assigned_Today__c = 5;
        assignee.Last_Assignment_Date__c = Date.today().addDays(-1);
        update assignee;

        Test.startTest();
        // Execute scheduler directly
        new RoundRobinAsyncUtils.RoundRobinResetScheduler().execute(null);
        Test.stopTest();

        Round_Robin_Assignee__c updatedAssignee = [SELECT Assigned_Today__c, Last_Assignment_Date__c FROM Round_Robin_Assignee__c WHERE Id = :assignee.Id];
        System.assertEquals(0, updatedAssignee.Assigned_Today__c, 'Assigned_Today__c should be reset to 0.');
    }

    @IsTest
    static void testRoundRobinInactiveLeadReassignmentJob_Assignment() {
        List<User> users = [SELECT Id FROM User WHERE Alias LIKE 'user%'];
        Lead testLead = new Lead(
            LastName = 'TestLead',
            Company = 'TestCompany',
            Status = 'New',
            OwnerId = users[0].Id
        );
        insert testLead;

        Test.startTest();
        // Call TestVisible execute() to bypass LastModifiedDate restriction
        new RoundRobinAsyncUtils.RoundRobinInactiveLeadReassignmentJob(testLead.Id).execute(null, true);
        Test.stopTest();

        Lead updatedLead = [SELECT OwnerId FROM Lead WHERE Id = :testLead.Id];
        System.assertNotEquals(users[0].Id, updatedLead.OwnerId, 'Owner should be reassigned to a different assignee.');
    }

    @IsTest
    static void testRoundRobinInactiveLeadReassignmentJob_NoReassignment() {
        List<User> users = [SELECT Id FROM User WHERE Alias LIKE 'user%'];
        Lead testLead = new Lead(
            LastName = 'TestLead2',
            Company = 'TestCompany2',
            Status = 'Converted',
            OwnerId = users[0].Id
        );
        insert testLead;

        Test.startTest();
        System.schedule('Inactive Lead No Reassignment', '0 0 0 * * ?', new RoundRobinAsyncUtils.RoundRobinInactiveLeadReassignmentJob(testLead.Id));
        Test.stopTest();

        Lead updatedLead = [SELECT OwnerId FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(users[0].Id, updatedLead.OwnerId, 'Owner should not be reassigned if lead is Converted.');
    }

    @IsTest
    static void testExceptionHandling() {
        // Pass null to trigger exception in createMissingAssignees
        Test.startTest();
        RoundRobinAsyncUtils.createMissingAssignees(null);
        Test.stopTest();
    }
}