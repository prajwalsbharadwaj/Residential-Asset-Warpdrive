@IsTest
private class SiteVisitControllerTest {

    @TestSetup
    static void setupData() {
        Property__c prop = new Property__c(
            Name = 'Grand Heights Residency'
        );
        insert prop;

        Tower__c tow = new Tower__c(
            Name = 'Tower Alpha',
            Property__c = prop.Id
        );
        insert tow;

        Floor__c flr = new Floor__c(
            Name = 'Floor 5',
            Tower__c = tow.Id
        );
        insert flr;

        Unit__c u = new Unit__c(
            Name = 'Unit 501',
            Floor__c = flr.Id,
            Tower__c = tow.Id,
            Property__c = prop.Id,
            BHK_Configuration__c = '3 BHK',
            Status__c = 'Available',
            Base_Price__c = 15000000
        );
        insert u;

        Lead ld = new Lead(
            FirstName = 'Test',
            LastName = 'Buyer',
            Company = 'Self Employed',
            MobilePhone = '9876543210',
            Phone = '0801234567',
            Status = 'New',
            ProjectL__c = prop.Id
        );
        insert ld;
    }

    @IsTest
    static void testLeadDetailsAndProjects() {
        Lead ld = [SELECT Id FROM Lead LIMIT 1];
        Property__c prop = [SELECT Id FROM Property__c LIMIT 1];

        Test.startTest();
        SiteVisitController.LeadDetailWrapper details = SiteVisitController.getLeadDetails(ld.Id);
        List<Property__c> projects = SiteVisitController.getProjects();
        List<SiteVisitController.UnitOptionWrapper> units = SiteVisitController.getUnitsForProject(prop.Id);
        SiteVisitController.OtpResultWrapper otpRes = SiteVisitController.generateOtp('9876543210');
        Test.stopTest();

        System.assertNotEquals(null, details, 'Lead details should not be null');
        System.assertEquals('Test Buyer', details.name);
        System.assertEquals(false, details.hasSiteVisit);
        System.assert(projects.size() > 0, 'Should return at least one project');
        System.assert(units.size() > 0, 'Should return units for project');
        System.assertNotEquals(null, otpRes.otpCode, 'OTP should be generated');
        System.assertEquals(6, otpRes.otpCode.length(), 'OTP should be 6 digits');
    }

    @IsTest
    static void testLogSiteVisitSuccess() {
        Lead ld = [SELECT Id FROM Lead LIMIT 1];
        Property__c prop = [SELECT Id FROM Property__c LIMIT 1];
        Unit__c u = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        SiteVisitController.SiteVisitSaveResult res = SiteVisitController.logSiteVisit(
            ld.Id,
            prop.Id,
            u.Id,
            '9876543210',
            '123456',
            'Hot',
            'Client loved the living room balcony and floor view.',
            System.now()
        );
        Test.stopTest();

        System.assert(res.success, 'Save should succeed');
        System.assertNotEquals(null, res.siteVisitId, 'Site Visit Id should be created');

        Lead updatedLead = [SELECT Id, Status FROM Lead WHERE Id = :ld.Id];
        System.assertEquals('Site Visit', updatedLead.Status, 'Status must be updated to Site Visit');

        Site_Visit__c sv = [SELECT Id, Lead__c, Project__c, Unit__c, Rating__c, OTP_Verified__c, Visitor_Mobile__c, OTP_Code__c FROM Site_Visit__c WHERE Id = :res.siteVisitId];
        System.assertEquals(ld.Id, sv.Lead__c);
        System.assertEquals(prop.Id, sv.Project__c);
        System.assertEquals(u.Id, sv.Unit__c);
        System.assertEquals('Hot', sv.Rating__c);
        System.assertEquals(true, sv.OTP_Verified__c);
        System.assertEquals('9876543210', sv.Visitor_Mobile__c);
        System.assertEquals('123456', sv.OTP_Code__c);
    }

    @IsTest
    static void testPublicGuestPortalMethods() {
        Property__c prop = [SELECT Id FROM Property__c LIMIT 1];
        Tower__c tow = [SELECT Id FROM Tower__c LIMIT 1];
        Unit__c u = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        List<Property__c> propList = SiteVisitController.getProperties();
        List<Tower__c> towerList = SiteVisitController.getTowers(prop.Id);
        List<Unit__c> unitList = SiteVisitController.getUnits(tow.Id);
        Lead foundLead = SiteVisitController.findExistingLead('9876543210', null);

        SiteVisitController.SiteVisitWrapper info = new SiteVisitController.SiteVisitWrapper();
        info.firstName = 'Anita';
        info.lastName = 'Rao';
        info.mobile = '9876543299';
        info.email = 'anita.rao@example.com';
        info.propertyId = prop.Id;
        info.towerId = tow.Id;
        info.unitId = u.Id;
        info.interactionRating = 'Good';
        info.overallExperience = 'Superior';
        info.waitingTime = '5';

        String submitResult = SiteVisitController.submitData(info, 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==', null);
        Test.stopTest();

        System.assert(propList.size() > 0);
        System.assert(towerList.size() > 0);
        System.assert(unitList.size() > 0);
        System.assertNotEquals(null, foundLead);
        System.assertEquals('Success', submitResult);
    }

    @IsTest
    static void testLogSiteVisitWithCustomerAndExecutiveFeedback() {
        Lead ld = [SELECT Id FROM Lead LIMIT 1];
        Property__c prop = [SELECT Id FROM Property__c LIMIT 1];
        Unit__c u = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        SiteVisitController.SiteVisitSaveResult res = SiteVisitController.logSiteVisitWithDetails(
            ld.Id,
            prop.Id,
            u.Id,
            '9876543210',
            '123456',
            'Hot',
            'Negotiating on floor rise',
            System.now(),
            'Yes',
            'Project',
            'Yes',
            'Superior',
            'Questions about handover timeline and car parking',
            'High',
            'Week',
            'Offered floor-rise discount, customer ready to sign booking form'
        );
        Test.stopTest();

        System.assert(res.success);
        Site_Visit__c sv = [
            SELECT Id, Did_the_guest_visit_the_show_flat__c, Did_the_guest_like_the_project_or_produc__c,
                   Has_the_Guest_Visited_with_Family__c, Your_Overall_Experience__c,
                   Suggestions_to_improve_your_experience__c, Interest_Level__c,
                   Next_Follow_up_After__c, Sales_Manager_Remarks__c
            FROM Site_Visit__c 
            WHERE Id = :res.siteVisitId
        ];
        System.assertEquals('Yes', sv.Did_the_guest_visit_the_show_flat__c);
        System.assertEquals('Project', sv.Did_the_guest_like_the_project_or_produc__c);
        System.assertEquals('Yes', sv.Has_the_Guest_Visited_with_Family__c);
        System.assertEquals('Superior', sv.Your_Overall_Experience__c);
        System.assertEquals('High', sv.Interest_Level__c);
        System.assertEquals('Next_Follow_up_After__c', 'Next_Follow_up_After__c');
    }

    @IsTest
    static void testGREFormData() {
        Test.startTest();
        SiteVisitController.GREFormData formData = SiteVisitController.getGREFormData();
        Test.stopTest();

        System.assertNotEquals(null, formData, 'Form data should not be null');
        System.assert(formData.projects.size() > 0, 'Projects should be returned');
        System.assert(formData.configurations.size() > 0, 'Configurations should be returned');
    }

    @IsTest
    static void testSearchVisitorByPhone() {
        Test.startTest();
        // Unknown phone
        SiteVisitController.WalkinLookupResult notFound = SiteVisitController.searchVisitorByPhone('9999999999');
        System.assertEquals(false, notFound.isExistingLead, 'Unknown phone should return false');

        // Existing lead phone
        SiteVisitController.WalkinLookupResult found = SiteVisitController.searchVisitorByPhone('+91 98765 43210');
        Test.stopTest();

        System.assertEquals(true, found.isExistingLead, 'Existing lead should be found');
        System.assertEquals('Test Buyer', found.fullName);
    }

    @IsTest
    static void testRegisterWalkinGuestNew() {
        Property__c prop = [SELECT Id FROM Property__c LIMIT 1];
        Unit__c u = [SELECT Id FROM Unit__c LIMIT 1];

        SiteVisitController.WalkinIntakePayload payload = new SiteVisitController.WalkinIntakePayload();
        payload.firstName = 'Rohit';
        payload.lastName = 'Verma';
        payload.mobilePhone = '9888877771';
        payload.email = 'rohit.verma@example.com';
        payload.projectId = prop.Id;
        payload.configuration = '3BHK';
        payload.unitId = u.Id;
        payload.visitedWithFamily = 'No';
        payload.notes = 'First walk-in at reception';
        payload.isChannelPartner = false;

        Test.startTest();
        SiteVisitController.WalkinCheckinResult res = SiteVisitController.registerWalkinGuest(payload);
        Test.stopTest();

        System.assert(res.success, 'Registration should succeed');
        System.assertNotEquals(null, res.siteVisitId, 'Site Visit ID should be generated');
        System.assertEquals(false, res.isRepeatVisit, 'Should be flagged as first-time visit');

        Lead newLd = [SELECT Id, Status, MobilePhone FROM Lead WHERE Id = :res.leadId];
        System.assertEquals('Site Visit', newLd.Status);
        System.assertEquals('9888877771', newLd.MobilePhone);

        Site_Visit__c sv = [SELECT Id, OTP_Verified__c, Has_the_Guest_Visited_with_Family__c, Remarks__c FROM Site_Visit__c WHERE Id = :res.siteVisitId];
        System.assertEquals(true, sv.OTP_Verified__c, 'Walk-in at desk must bypass OTP qualification gate');
        System.assertEquals('No', sv.Has_the_Guest_Visited_with_Family__c);
    }

    @IsTest
    static void testRegisterWalkinGuestRepeatFamilyVisit() {
        Lead existingLd = [SELECT Id, MobilePhone FROM Lead LIMIT 1];
        Property__c prop = [SELECT Id FROM Property__c LIMIT 1];

        Integer initialLeadCount = [SELECT count() FROM Lead];

        // First visit for this lead
        SiteVisitController.WalkinIntakePayload payload1 = new SiteVisitController.WalkinIntakePayload();
        payload1.leadId = existingLd.Id;
        payload1.mobilePhone = existingLd.MobilePhone;
        payload1.projectId = prop.Id;
        payload1.configuration = '3BHK';
        payload1.visitedWithFamily = 'No';
        payload1.visitorName = 'Test Buyer';
        payload1.notes = 'Husband visiting on Saturday';

        SiteVisitController.registerWalkinGuest(payload1);

        // Second visit: Spouse visiting on Wednesday with SAME phone number
        SiteVisitController.WalkinIntakePayload payload2 = new SiteVisitController.WalkinIntakePayload();
        payload2.leadId = null; // Even if desk doesn't prefill leadId, deduplication finds it
        payload2.mobilePhone = existingLd.MobilePhone;
        payload2.projectId = prop.Id;
        payload2.configuration = '3BHK';
        payload2.visitedWithFamily = 'Yes';
        payload2.visitorName = 'Priya Buyer (Spouse)';
        payload2.notes = 'Spouse visiting to inspect balcony and kitchen';

        Test.startTest();
        SiteVisitController.WalkinCheckinResult res2 = SiteVisitController.registerWalkinGuest(payload2);
        Test.stopTest();

        System.assert(res2.success, 'Second visit checkin should succeed');
        System.assertEquals(true, res2.isRepeatVisit, 'Must be identified as returning lead');
        System.assertEquals(existingLd.Id, res2.leadId, 'Must tag to existing lead');

        // Zero duplicate leads created!
        Integer finalLeadCount = [SELECT count() FROM Lead];
        System.assertEquals(initialLeadCount, finalLeadCount, 'Zero duplicate leads should be created for family repeat visits');

        // Verify Site Visit #2 fields
        Site_Visit__c sv2 = [
            SELECT Id, Lead__c, Has_the_Guest_Visited_with_Family__c, Remarks__c, Comments__c, OTP_Verified__c
            FROM Site_Visit__c
            WHERE Id = :res2.siteVisitId
        ];
        System.assertEquals(existingLd.Id, sv2.Lead__c);
        System.assertEquals('Yes', sv2.Has_the_Guest_Visited_with_Family__c);
        System.assert(sv2.Remarks__c.contains('Priya Buyer (Spouse)'), 'Visitor name must capture spouse details');
        System.assertEquals(true, sv2.OTP_Verified__c);
    }
}
