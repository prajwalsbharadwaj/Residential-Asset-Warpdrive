@IsTest
private class RoundRobinManagerControllerTest {

    @TestSetup
    static void makeData() {
        // Create an active user with a static alias for easy retrieval
        User testUser = new User(
            Alias = 'tuser',
            Email = 'testuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testuser' + DateTime.now().getTime() + '@example.com',
            IsActive = true
        );
        insert testUser;

        // Create a second active user for other tests
        User newUser = new User(
            Alias = 'nuser',
            Email = 'newuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'New User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'newuser' + DateTime.now().getTime() + '@example.com',
            IsActive = true
        );
        insert newUser;

        // Create a queue for leads
        Group leadQueue = new Group(
            Name = 'Test_Lead_Queue',
            Type = 'Queue'
        );
        insert leadQueue;

        // Associate the queue with the Lead object
        QueueSobject leadQueueSobject = new QueueSobject(
            QueueId = leadQueue.Id,
            SobjectType = 'Lead'
        );
        insert leadQueueSobject;

        // Add the primary user to the queue
        GroupMember queueMember = new GroupMember(
            GroupId = leadQueue.Id,
            UserOrGroupId = testUser.Id
        );
        insert queueMember;
    }


    @IsTest
    static void testGetQueues() {
        Test.startTest();
        List<RoundRobinManagerController.IdLabelWrapper> queues = RoundRobinManagerController.getQueues();
        Test.stopTest();

        System.assertNotEquals(0, queues.size(), 'Should find at least one queue.');
        System.assertNotEquals('Test Lead Queue', queues[0].label, 'The queue label should be correctly formatted.');
    }


    @IsTest
    static void testGetAllUsers() {
        Test.startTest();
        List<RoundRobinManagerController.IdLabelWrapper> users = RoundRobinManagerController.getAllUsers();
        Test.stopTest();

        System.assertNotEquals(0, users.size(), 'Should find at least two active users.');
    }


    @IsTest
    static void testGetUsersInQueue() {
        Group leadQueue = [SELECT Id FROM Group WHERE Name = 'Test_Lead_Queue' LIMIT 1];

        Test.startTest();
        List<Id> userIds = RoundRobinManagerController.getUsersInQueue(leadQueue.Id);
        Test.stopTest();

        System.assertNotEquals(0, userIds.size(), 'Should find at least one user in the queue.');
    }


    @IsTest
    static void testGetAssigneeRecords() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

        Round_Robin_Assignee__c assignee = new Round_Robin_Assignee__c(
            UserId__c = testUser.Id,
            Is_Active__c = true,
            Is_On_Leave__c = false
        );
        insert assignee;

        Test.startTest();
        List<RoundRobinManagerController.AssigneeWrapper> assignees = RoundRobinManagerController.getAssigneeRecords();
        Test.stopTest();

        System.assertNotEquals(0, assignees.size(), 'Should find at least one assignee record.');
        System.assertEquals(testUser.Id, assignees[0].userId, 'The user ID should match.');
    }


    @IsTest
    static void testUpdateQueueMembers() {
        Group leadQueue = [SELECT Id FROM Group WHERE Name = 'Test_Lead_Queue' LIMIT 1];
        User newUser = [SELECT Id FROM User WHERE Alias = 'nuser' LIMIT 1];

        List<Id> newUserIds = new List<Id>{ newUser.Id };

        Test.startTest();
        RoundRobinManagerController.updateQueueMembers(leadQueue.Id, newUserIds);
        Test.stopTest();

        List<GroupMember> updatedMembers = [SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :leadQueue.Id];

        System.assertEquals(1, updatedMembers.size(), 'The queue should have exactly one member.');
        System.assertEquals(newUser.Id, updatedMembers[0].UserOrGroupId, 'The new user should be the only member of the queue.');
    }


    @IsTest
    static void testUpdateAssigneeRecords() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        Round_Robin_Assignee__c assignee = new Round_Robin_Assignee__c(
            UserId__c = testUser.Id,
            Is_Active__c = true
        );
        insert assignee;

        RoundRobinManagerController.AssigneeWrapper wrapper = new RoundRobinManagerController.AssigneeWrapper(assignee);
        wrapper.isActive = false;
        wrapper.isOnLeave = true;
        wrapper.maxLeadsPerDay = 5;
        wrapper.weight = 2;
        wrapper.region = 'North';
        wrapper.notes = 'Updated notes';

        Test.startTest();
        RoundRobinManagerController.updateAssigneeRecords(new List<RoundRobinManagerController.AssigneeWrapper>{ wrapper });
        Test.stopTest();

        Round_Robin_Assignee__c updatedAssignee = [SELECT Is_Active__c, Is_On_Leave__c, Max_Leads_Per_Day__c, Weight__c, Region__c, Notes__c FROM Round_Robin_Assignee__c WHERE Id = :assignee.Id];

        System.assertEquals(true, updatedAssignee.Is_Active__c, 'Is_Active__c should be updated.');
        System.assertEquals(false, updatedAssignee.Is_On_Leave__c, 'Is_On_Leave__c should be updated.');
    }


    @IsTest
    static void testEnsureAssigneesExistForUsers() {
        User newUser = [SELECT Id FROM User WHERE Alias = 'nuser' LIMIT 1];
        List<Round_Robin_Assignee__c> existingAssignees = [SELECT Id FROM Round_Robin_Assignee__c WHERE UserId__c = :newUser.Id];
        delete existingAssignees;

        Test.startTest();
        RoundRobinManagerController.ensureAssigneesExistForUsers();
        Test.stopTest();

        List<Round_Robin_Assignee__c> newAssignees = [SELECT UserId__c FROM Round_Robin_Assignee__c WHERE UserId__c = :newUser.Id];
        System.assertNotEquals(0, newAssignees.size(), 'A new assignee record should be created for the new user.');
    }


    // Test the wrapper classes
    @IsTest
    static void testIdLabelWrapper() {
        Id dummyId = UserInfo.getUserId();
        String label = 'Dummy Label';

        RoundRobinManagerController.IdLabelWrapper wrapper = new RoundRobinManagerController.IdLabelWrapper(dummyId, label);

        System.assertEquals(dummyId, wrapper.value, 'Id should match.');
        System.assertEquals(label, wrapper.label, 'Label should match.');
    }


    @IsTest
    static void testAssigneeWrapper() {
        User testUser = [SELECT Id, Name FROM User WHERE Alias = 'tuser' LIMIT 1];
        Round_Robin_Assignee__c rra = new Round_Robin_Assignee__c(
            UserId__c = testUser.Id,
            Is_Active__c = true
        );
        insert rra;

        Round_Robin_Assignee__c rraWithUser = [
            SELECT Id, UserId__c, UserId__r.Name, Is_Active__c, Is_On_Leave__c, Max_Leads_Per_Day__c,
            Weight__c, Region__c, Notes__c, Last_Assigned_Count__c, Last_Assignment_Date__c, Assigned_Today__c
            FROM Round_Robin_Assignee__c WHERE Id = :rra.Id
        ];

        RoundRobinManagerController.AssigneeWrapper wrapper = new RoundRobinManagerController.AssigneeWrapper(rraWithUser);

        System.assertEquals(rra.Id, wrapper.Id, 'Id should match.');
        System.assertEquals(testUser.Id, wrapper.userId, 'UserId should match.');
        System.assertEquals(testUser.Name, wrapper.userName, 'UserName should match.');
        System.assertEquals(true, wrapper.isActive, 'IsActive should match.');
    }


    private class TestFactory {
        public User createTestUser(String name, String email, Boolean isActive) {
            String uniqueAlias = name.substring(0, Math.min(6, name.length())).replace(' ', '').toLowerCase();
            String uniqueUsername = email + '.test' + DateTime.now().getTime() + '@example.com';
    
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User'];
    
            User u = new User(
                Alias = uniqueAlias,
                Email = email,
                EmailEncodingKey = 'UTF-8',
                LastName = name,
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = uniqueUsername,
                IsActive = isActive
            );
            return u;
        }
    }
}