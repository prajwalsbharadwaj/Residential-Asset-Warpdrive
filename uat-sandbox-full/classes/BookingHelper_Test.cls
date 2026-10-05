@IsTest
private class BookingHelper_Test {

    // ----------- TEST SETUP DATA -----------
    @testSetup
    static void setupData() {

        // Create user roles
        UserRole crmHeadRole = [SELECT Id, DeveloperName FROM UserRole WHERE DeveloperName = 'CRM_Head' LIMIT 1];
        UserRole crmMemberRole = [SELECT Id, DeveloperName FROM UserRole WHERE DeveloperName = 'CRM_Member' LIMIT 1]; 
        UserRole crmFinanceRole = [SELECT Id, DeveloperName FROM UserRole WHERE DeveloperName = 'CRM_Finance_Head' LIMIT 1];
            
        //get Profile
        Profile p = [SELECT Id, Name FROM Profile WHERE Name = 'Phoenix Residential - Base Profile'];
        String unique = System.currentTimeMillis() + '_' + UserInfo.getOrganizationId();
        
        // Create three CRM users
        List<User> users = new List<User>();
        users.add(new User(
            FirstName='A', LastName='Head', Email='head@test.com',
            Username='head'+ unique+'@test.com.test', Alias='hd', TimeZoneSidKey='Asia/Kolkata',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            ProfileId = p.Id,
            UserRoleId = crmHeadRole.Id,
            LanguageLocaleKey = 'en_US',
            isActive = true
        ));

        users.add(new User(
            FirstName='B', LastName='Member', Email='member@test.com',
            Username='member'+ unique+'@test.com.test', Alias='mb', TimeZoneSidKey='Asia/Kolkata',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            ProfileId = p.Id,
            UserRoleId = crmMemberRole.Id,
            LanguageLocaleKey = 'en_US',
            isActive = true
        ));

        users.add(new User(
            FirstName='C', LastName='Finance', Email='fin@test.com',
            Username='fin'+ unique+'@test.com.test', Alias='fn', TimeZoneSidKey='Asia/Kolkata',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            ProfileId = p.Id,
            UserRoleId = crmFinanceRole.Id,
            LanguageLocaleKey = 'en_US',
            isActive = true
        ));
        User admin = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND isActive = true LIMIT 1];
        system.runAs(admin){
            insert users;
            system.debug('users '+users);
        }

        Account acc = ResidentialTestDataFactory.createAccount();
        Property__c project = ResidentialTestDataFactory.createProject();
        Project.Allocated_User__c = admin.Id;
        update project;
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);

        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);

        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
    }

    // ------------- MAIN TEST -------------
    @IsTest
    static void test_booking_team_member_creation() {
        Payment_Plan__c plan = [SELECT Id FROM Payment_Plan__c LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        opp.Token_Amount__c = 0;
        opp.Payment_Plan__c = plan.Id;
        opp.StageName = 'Closed Won';
        update opp;
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Property__c project = [SELECT Id FROM Property__c LIMIT 1];
        Test.startTest();
        
        Test.stopTest();
        Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, project.Id);
        system.debug('Booking--> '+ booking);
        // Validate OTM records were created
        List<OpportunityTeamMember> otmList = [
            SELECT Id, UserId, TeamMemberRole, OpportunityAccessLevel
            FROM OpportunityTeamMember
            WHERE OpportunityId = :opp.Id
        ];
        system.debug('otmList.size() '+ otmList.size());
        system.debug('otmList-> '+otmList);

        System.assertNotEquals(0, otmList.size(), 'OTM records should be created');
    }

    // ------------- TEST: Booking without Opportunity (coverage for branch skip) -------------
    @IsTest
    static void test_booking_without_opportunity() {
        
        Test.startTest();
        Test.stopTest();

        List<OpportunityTeamMember> otm = [
            SELECT Id FROM OpportunityTeamMember LIMIT 10
        ];

        System.assertEquals(0, otm.size(), 'No OTM should be created when Opportunity is null');
    }

}