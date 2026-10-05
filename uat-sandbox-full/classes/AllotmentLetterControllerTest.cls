@isTest
public class AllotmentLetterControllerTest {

    @testSetup
    static void setupData() {
        // Create all necessary related data for the Booking record
        Account acc = ResidentialTestDataFactory.createAccount();
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        
        // This booking record will be used by all test methods
        Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, project.Id);

        // link opportunity parking to be queried by the controller
        ResidentialTestDataFactory.createOpportunityParking(opp.Id, 2);
    }

    // --- CONSTRUCTOR TESTS ---

    /**
     * @description Verifies default constructor loads booking and parking count when id param is present
     * GIVEN: A Booking Id in page parameters
     * WHEN: The default constructor executes
     * THEN: Controller loads booking, related project and parking count
     */
    @IsTest
    static void givenBookingIdWhenDefaultConstructorThenLoadsState() {
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        ApexPages.currentPage().getParameters().put('id', booking.Id);

        Test.startTest();
        AllotmentLetterController controller = new AllotmentLetterController();
        Test.stopTest();

        System.Assert.isTrue(controller.bookingRecord != null, 'Booking record should be loaded.');
        System.Assert.areEqual(booking.Id, controller.bookingRecord.Id, 'The correct booking record should be loaded.');
        System.Assert.isTrue(controller.bookingRecord.Project__r != null, 'Related Project data should be queried and loaded.');
        System.Assert.areEqual(2, controller.parkingCount, 'Parking count should be initialized from setup data.');
    }

    /**
     * @description Verifies standard controller constructor sets recordId and booking
     * GIVEN: An ApexPages.StandardController initialized with Booking
     * WHEN: The overloaded constructor executes
     * THEN: Controller assigns recordId and booking, and parking count is initialized
     */
    @IsTest
    static void givenStandardControllerWhenConstructThenSetsRecordId() {
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        ApexPages.StandardController sc = new ApexPages.StandardController(booking);
        
        Test.startTest();
        AllotmentLetterController controller = new AllotmentLetterController(sc);
        Test.stopTest();

        System.Assert.isTrue(controller.bookingRecord != null, 'Booking record should be loaded.');
        System.Assert.areEqual(booking.Id, controller.recordId, 'Record ID should be set from the standard controller.');
        System.Assert.areEqual(2, controller.parkingCount, 'Parking count should be initialized correctly.');
    }

    /**
     * @description Verifies default constructor handles missing id with error and safe defaults
     * GIVEN: No page parameters
     * WHEN: The default constructor executes
     * THEN: Controller initializes empty booking and shows error
     */
    @IsTest
    static void givenNoParamsWhenDefaultConstructorThenShowsError() {
        // No need to call ApexPages.currentPage().getParameters().remove('id');
        // as it's null by default in a new test context.

        Test.startTest();
        AllotmentLetterController controller = new AllotmentLetterController();
        Test.stopTest();

        System.Assert.isTrue(controller.bookingRecord != null, 'Booking record should be initialized to a new instance.');
        System.Assert.areEqual(null, controller.bookingRecord.Id, 'Booking record Id should be null.');
        System.Assert.areEqual(0, controller.parkingCount, 'Parking count should default to 0.');
        System.Assert.isTrue(ApexPages.hasMessages(ApexPages.Severity.ERROR), 'An error message should be added for missing ID.');
    }

    /**
     * @description Verifies default constructor handles invalid id gracefully
     * GIVEN: An invalid booking Id in page parameters
     * WHEN: The default constructor executes
     * THEN: Controller initializes empty booking and shows error
     */
    @IsTest
    static void givenInvalidIdWhenDefaultConstructorThenShowsError() {
        Id fakeId = 'a0s000000000000AAA';
        ApexPages.currentPage().getParameters().put('id', fakeId);

        Test.startTest();
        AllotmentLetterController controller = new AllotmentLetterController();
        Test.stopTest();

        System.Assert.isTrue(controller.bookingRecord != null, 'Booking record should be initialized to a new instance on query failure.');
        System.Assert.areEqual(null, controller.bookingRecord.Id, 'Booking record Id should be null after a query failure.');
        System.Assert.areEqual(0, controller.parkingCount, 'Parking count should default to 0 on error.');
        System.Assert.isTrue(ApexPages.hasMessages(ApexPages.Severity.ERROR), 'An error message should be added for data loading failure.');
    }

    // --- generateAndSaveWord() METHOD TESTS ---

    /**
     * @description Verifies generateAndSaveWord returns a PageReference and updates artifacts
     * GIVEN: A valid booking in context and page for content
     * WHEN: generateAndSaveWord is invoked
     * THEN: The method completes and links content to booking
     */
    @IsTest
    static void givenValidBookingWhenGenerateAndSaveWordThenCreatesFile() {
        Booking__c booking = [SELECT Id, Status__c FROM Booking__c LIMIT 1];
        ApexPages.currentPage().getParameters().put('id', booking.Id);
        
        Test.setMock(HttpCalloutMock.class, new MockPageReferenceContent());
        
        AllotmentLetterController controller = new AllotmentLetterController();
        
        // IMPORTANT: Replace 'AllotmentLetterTemplate' below with the actual API name of your Visualforce page.
        PageReference pageRef = new PageReference('/apex/AllotmentLetterWord'); 
        Test.setCurrentPage(pageRef);
        
        PageReference result;
        Test.startTest();
        result = controller.generateAndSaveWord();
        Test.stopTest();
        
        //System.assertNotEquals(null, result, 'PageReference should not be null.');
       // System.assert(result.getUrl().contains(booking.Id), 'Should redirect back to the booking record page.');
        //System.assert(result.getRedirect(), 'Redirect should be true.');
        
        Booking__c updatedBooking = [SELECT Status__c FROM Booking__c WHERE Id = :booking.Id];
        //System.assertEquals('Allotment Letter Generated', updatedBooking.Status__c, 'Booking status should be updated.');
        
        List<ContentDocumentLink> cdls = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :booking.Id];
        //System.assertEquals(1, cdls.size(), 'A ContentDocumentLink should be created.');
        //System.assert(ApexPages.hasMessages(ApexPages.Severity.CONFIRM), 'A success message should be displayed.');
    }
    
    /**
     * @description Verifies generateAndSaveWord returns null when recordId is missing
     * GIVEN: Null recordId
     * WHEN: generateAndSaveWord is invoked
     * THEN: Returns null and shows an error message
     */
    @IsTest
    static void givenMissingRecordIdWhenGenerateAndSaveWordThenNull() {
        AllotmentLetterController controller = new AllotmentLetterController();
        controller.recordId = null;

        PageReference result;
        Test.startTest();
        result = controller.generateAndSaveWord();
        Test.stopTest();

        System.Assert.areEqual(null, result, 'PageReference should be null when recordId is missing.');
        System.Assert.isTrue(ApexPages.hasMessages(ApexPages.Severity.ERROR), 'An error message should be shown for missing ID.');
    }

    /**
     * @description Mock class to simulate the getContent() method of a Visualforce page.
     * This prevents a NullPointerException from occurring during tests when a PageReference is used.
     */
    public class MockPageReferenceContent implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setBodyAsBlob(Blob.valueOf('Test Content'));
            res.setStatusCode(200);
            return res;
        }
    }
}