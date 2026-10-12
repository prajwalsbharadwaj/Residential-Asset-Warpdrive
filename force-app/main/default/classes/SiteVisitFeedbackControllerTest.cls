@isTest
private class SiteVisitFeedbackControllerTest {

    @testSetup
    static void setupTestData() {
        // 1. Create Property
        Property__c prop = new Property__c(Name = 'Varthur Vista');
        insert prop;

        // 2. Create Tower
        Tower__c tower = new Tower__c(Name = 'Tower 2', Property__c = prop.Id);
        insert tower;

        // 2b. Create Floor
        Floor__c floor = new Floor__c(Name = 'Floor 14', Tower__c = tower.Id);
        insert floor;

        // 3. Create Unit
        Unit__c unit = new Unit__c(
            Name = 'Unit 1404',
            Property__c = prop.Id,
            Tower__c = tower.Id,
            Floor__c = floor.Id,
            BHK_Configuration__c = '3 BHK',
            Status__c = 'Available'
        );
        insert unit;

        // 4. Create Lead
        Lead ld = new Lead(
            FirstName = 'Rahul',
            LastName = 'Sharma',
            Company = 'Rahul Sharma',
            MobilePhone = '9876543210',
            Email = 'rahul.sharma.test@example.com',
            Status = 'New'
        );
        insert ld;

        // 5. Create Site Visit
        Site_Visit__c sv = new Site_Visit__c(
            Lead__c = ld.Id,
            Project__c = prop.Id,
            Unit__c = unit.Id,
            Building__c = tower.Id,
            Status__c = 'Scheduled',
            Visit_DateTime__c = System.now(),
            Visitor_Mobile__c = '9876543210',
            Rating__c = 'Warm',
            Interest_Level__c = 'Medium'
        );
        insert sv;
    }

    @isTest
    static void testGetSiteVisitDetails() {
        Site_Visit__c sv = [SELECT Id FROM Site_Visit__c LIMIT 1];

        Test.startTest();
        SiteVisitFeedbackController.SiteVisitDetailDTO dto = SiteVisitFeedbackController.getSiteVisitDetails(sv.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'DTO should not be null');
        System.assertEquals('Varthur Vista', dto.projectName, 'Project should match');
        System.assertEquals('Tower 2', dto.buildingName, 'Tower/Building should match');
        System.assertEquals('Floor 14', dto.floorName, 'Floor should match');
        System.assertEquals('Unit 1404', dto.unitName, 'Unit should match');
        System.assertEquals('Warm', dto.rating, 'Rating should match');
        System.assert(dto.closingManagers.size() > 0, 'Should load active sales users');
    }

    @isTest
    static void testSaveSiteVisitFeedback() {
        Site_Visit__c sv = [SELECT Id, Lead__c FROM Site_Visit__c LIMIT 1];

        SiteVisitFeedbackController.FeedbackSaveRequest req = new SiteVisitFeedbackController.FeedbackSaveRequest();
        req.siteVisitId = sv.Id;
        req.rating = 'Hot';
        req.interestLevel = 'High';
        req.interestPercent = 85;
        req.overallExperience = 'Superior';
        req.likedProduct = 'Project';
        req.visitedShowFlat = 'Yes';
        req.visitedWithFamily = 'Yes';
        req.recommendFriends = 'Yes';
        req.nextFollowUp = 'Week';
        req.customerComments = 'Loved the master bedroom view and clubhouse amenities.';
        req.executiveRemarks = 'High intent buyer, follow up Saturday for token.';
        req.salesManagerRemarks = 'Approved 1% floor rise discount discussion.';
        req.quickTags = 'Loved Balcony View; Vastu Compliant';
        req.closingManagerId = UserInfo.getUserId();

        Test.startTest();
        SiteVisitFeedbackController.SaveResult res = SiteVisitFeedbackController.saveSiteVisitFeedback(req);
        Test.stopTest();

        System.assert(res.success, 'Save should succeed');
        Site_Visit__c updatedSv = [
            SELECT Status__c, Rating__c, Interest_Level__c, Your_Overall_Experience__c,
                   Did_the_guest_like_the_project_or_produc__c, Did_the_guest_visit_the_show_flat__c,
                   Has_the_Guest_Visited_with_Family__c, Remarks__c, Comments__c
            FROM Site_Visit__c
            WHERE Id = :sv.Id
        ];
        System.assertEquals('Completed', updatedSv.Status__c, 'Status should be Completed');
        System.assertEquals('Hot', updatedSv.Rating__c, 'Rating should be Hot');
        System.assertEquals('High', updatedSv.Interest_Level__c, 'Interest level should be High');
        System.assertEquals('Superior', updatedSv.Your_Overall_Experience__c, 'Overall experience should be Superior');
        System.assert(updatedSv.Comments__c.contains('Loved the master bedroom view'), 'Comments should be populated');

        Lead updatedLead = [SELECT Status, Rating, Projects__c FROM Lead WHERE Id = :sv.Lead__c];
        System.assertEquals('Hot', updatedLead.Rating, 'Lead rating should be updated to Hot');
        System.assertEquals('Site Visit', updatedLead.Status, 'Lead status should be Site Visit');
        System.assertEquals('Varthur Vista', updatedLead.Projects__c, 'Lead Projects__c should be populated from Site Visit');

        List<Task> tasks = [SELECT Subject, Priority, Status, ActivityDate, WhoId FROM Task WHERE WhoId = :sv.Lead__c];
        System.assert(tasks.size() > 0, 'Follow-up task should be auto-created for Closing Manager');
        System.assertEquals('High', tasks[0].Priority, 'Hot lead should generate High priority task');
    }
}
