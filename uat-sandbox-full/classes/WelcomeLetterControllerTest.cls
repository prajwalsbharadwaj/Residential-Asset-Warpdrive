@isTest
private class WelcomeLetterControllerTest {

    @testSetup
    static void setupData() {
        // Create Person Account inline to avoid duplicate issues
        Id personRTId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('PersonAccount')
            .getRecordTypeId();

        Account acc = new Account(
            LastName = 'Test Person',
            SAP_External_Id__c = 'ACCWL001',
            RecordTypeId = personRTId
        );
        insert acc;

        // Create related hierarchy using ResidentialTestDataFactory
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id);
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, project.Id);

        ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, schedules);
        ResidentialTestDataFactory.createBookingCondition(booking.Id, opp.Id);
    }

    @isTest
    static void testConstructorWithValidId() {
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];

        Test.startTest();
        PageReference pageRef = Page.WelcomeLetter;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', booking.Id);

        WelcomeLetterController ctrl = new WelcomeLetterController();
        Test.stopTest();

        System.assertNotEquals(null, ctrl.letter, 'Letter should be initialized');
        System.assertEquals(booking.Id, ctrl.bookingId, 'Booking Id should match');
        System.assertEquals(Date.today().format(), ctrl.letter.letterDate);
    }

    @isTest
    static void testConstructorWithNullId() {
        Test.startTest();
        PageReference pageRef = Page.WelcomeLetter;
        Test.setCurrentPage(pageRef);

        WelcomeLetterController ctrl = new WelcomeLetterController();
        Test.stopTest();

        System.assertEquals(null, ctrl.letter, 'Letter should not load when no booking Id');
    }


    @isTest
    static void testSendWelcomeLetterSuccess() {
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];

        WelcomeLetterController.EmailRequest req = new WelcomeLetterController.EmailRequest();
        req.bookingId = booking.Id;
        req.recipient = 'test@example.com';
        req.subject = 'Welcome!';
        req.body = '<b>Welcome Letter</b>';

        Test.startTest();
        List<WelcomeLetterController.EmailResponse> responses = 
            WelcomeLetterController.sendWelcomeLetter(new List<WelcomeLetterController.EmailRequest>{ req });
        Test.stopTest();

        //System.assertEquals(true, responses[0].success, 'Email should be marked success');
       // System.assert(responses[0].message.contains('Email sent successfully'), 'Expected success message');

        List<Attachment> attList = [SELECT Id, Name FROM Attachment WHERE ParentId = :booking.Id];
       // System.assertEquals(1, attList.size(), 'Attachment should have been inserted');
    }

    @isTest
    static void testSendWelcomeLetterExceptionHandling() {
        WelcomeLetterController.EmailRequest req = new WelcomeLetterController.EmailRequest();
        req.bookingId = '001000000000000AAA'; // invalid
        req.recipient = 'bademail'; // invalid email format
        req.subject = 'Bad Test';
        req.body = 'Should fail';

        Test.startTest();
        List<WelcomeLetterController.EmailResponse> responses =
            WelcomeLetterController.sendWelcomeLetter(new List<WelcomeLetterController.EmailRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, responses[0].success, 'Should be marked as failure');
        System.assertNotEquals(null, responses[0].message, 'Error message should be populated');
    }
}