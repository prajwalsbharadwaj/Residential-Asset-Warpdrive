@IsTest
private class RoundRobinLeadReassignmentJobTest {

    @TestSetup
    static void setupTestData() {
        // Standard profile
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];

        // Create 3 users
        List<User> users = new List<User>();
        Long ts = Datetime.now().getTime();
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
                UserName = 'testuser' + i + ts + '@test.com',
                IsActive = true
            ));
        }
        insert users;

        // Create Channel Partner Queue
        Group channelQueue = new Group(Name = 'Channel Partner Queue', Type = 'Queue');
        insert channelQueue;

        // Add users to Channel Queue
        List<GroupMember> members = new List<GroupMember>{
            new GroupMember(GroupId = channelQueue.Id, UserOrGroupId = users[0].Id),
            new GroupMember(GroupId = channelQueue.Id, UserOrGroupId = users[1].Id)
        };
        insert members;

        // Create Project Queues
        Group bangaloreQueue = new Group(Name = 'Bangalore', Type = 'Queue');
        Group kolkataQueue = new Group(Name = 'Kolkata', Type = 'Queue');
        insert new List<Group>{bangaloreQueue, kolkataQueue};

        // Add users to Bangalore Queue
        insert new GroupMember(GroupId = bangaloreQueue.Id, UserOrGroupId = users[2].Id);
    }

    @IsTest
    static void testChannelPartnerLeadAssignment() {
        User ownerUser = [SELECT Id FROM User WHERE Alias='user0' LIMIT 1];

        Lead lead = new Lead(
            LastName = 'ChannelLead',
            Company = 'TestCompany',
            Status = 'New',
            OwnerId = ownerUser.Id,
            LeadSource = 'Channel Partner'
        );
        insert lead;

        Test.startTest();
        new RoundRobinInactiveLeadReassignmentJob(lead.Id).execute(null, true);
        Test.stopTest();

        Lead updatedLead = [SELECT OwnerId FROM Lead WHERE Id = :lead.Id];
        System.Assert.areEqual(ownerUser.Id, updatedLead.OwnerId, 'Owner should be reassigned to a queue member.');
    }

    @IsTest
    static void testProjectBasedLeadAssignment() {
        User ownerUser = [SELECT Id FROM User WHERE Alias='user0' LIMIT 1];

        Lead lead = new Lead(
            LastName = 'ProjectLead',
            Company = 'TestCompany',
            Status = 'New',
            OwnerId = ownerUser.Id,
            Projects__c = 'Kessaku'
        );
        insert lead;

        Test.startTest();
        new RoundRobinInactiveLeadReassignmentJob(lead.Id).execute(null, true);
        Test.stopTest();

        Lead updatedLead = [SELECT OwnerId FROM Lead WHERE Id = :lead.Id];
        System.Assert.areEqual(ownerUser.Id, updatedLead.OwnerId, 'Owner should be reassigned based on project queue.');
    }

    @IsTest
    static void testConvertedLeadNoReassignment() {
        User ownerUser = [SELECT Id FROM User WHERE Alias='user0' LIMIT 1];

        Lead lead = new Lead(
            LastName = 'ConvertedLead',
            Company = 'TestCompany',
            Status = 'Converted',
            OwnerId = ownerUser.Id
        );
        insert lead;

        Test.startTest();
        new RoundRobinInactiveLeadReassignmentJob(lead.Id).execute(null, true);
        Test.stopTest();

        Lead updatedLead = [SELECT OwnerId FROM Lead WHERE Id = :lead.Id];
        System.Assert.areEqual(ownerUser.Id, updatedLead.OwnerId, 'Owner should not be reassigned if lead is Converted.');
    }
}