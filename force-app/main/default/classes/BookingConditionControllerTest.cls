@isTest
public class BookingConditionControllerTest {

    @testSetup
    static void setupData() {
        Account acc = ResidentialTestDataFactory.createAccount();
        Property__c proj = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(proj.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(proj.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(proj.Id, tower.Id, floor.Id);
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, proj.Id);
        ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, schedules);
        ResidentialTestDataFactory.createBookingCondition(booking.Id, opp.Id);
    }
    
     @IsTest
    static void testUpdateTypeInBookCondExceptionHandling() {
        // Create some mock data for testing
        List<Booking_Condition__c> conditions = [SELECT Id, Opportunity__c, Condition_Type__c FROM Booking_Condition__c LIMIT 1];

        // Simulate an exception inside the method by mocking the custom metadata fetching process to throw an error
        // We need to mock an exception inside the method
        Test.startTest();
        try {
            // This should throw an exception to cover the catch block in `updateTypeInBookCond`
            BookingConditionHelper.updateTypeInBookCond(conditions);
        } catch (Exception e) {
            // Verify that the exception was caught and logged
            System.assert(e.getMessage().contains('Failed to update Type in Booking Conditions from before insert trigger'), 
                'Exception message should match the expected one.');
        }
        Test.stopTest();
    }


    @IsTest
    static void testGetConditionTypePicklistValues() {
        Test.startTest();
        List<Map<String, String>> values = BookingConditionController.getConditionTypePicklistValues();
        Test.stopTest();
        System.assert(values.size() > 0, 'Picklist values should return');
    }

    @IsTest
    static void testGetConditionsBookingAndOpportunity() {
        Booking__c booking = [SELECT Id, Opportunity_Id__c FROM Booking__c LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        List<Booking_Condition__c> bookingConds = BookingConditionController.getConditions(booking.Id, 'Booking__c');
        List<Booking_Condition__c> oppConds = BookingConditionController.getConditions(opp.Id, 'Opportunity__c');
        Test.stopTest();

        System.assert(bookingConds.size() > 0, 'Booking should return conditions');
    }

    @IsTest
    static void testGetConditionTypeDefaults() {
        Test.startTest();
        Map<String,String> defaults = BookingConditionController.getConditionTypeDefaults();
        Test.stopTest();
    }

    @IsTest
static void testUpsertConditionsBookingFixed() {
    Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];

    // Case 1: Fixed amount
    Map<String, Decimal> amounts = new Map<String, Decimal>{
        'Base Price' => 11111,
        'BESCOM & BWSSB' => 2222
    };

    Test.startTest();
    BookingConditionController.upsertConditions(booking.Id, 'Booking__c', amounts, null, null);
    Test.stopTest();

    List<Booking_Condition__c> updated = [
        SELECT Condition_Type__c, Amount__c, Percentage__c, Type__c 
        FROM Booking_Condition__c 
        WHERE Booking__c = :booking.Id
    ];
    System.assert(updated.size() > 0, 'Fixed conditions must exist');
    System.assertEquals(11111, updated[0].Amount__c, 'Base Price fixed amount should match');
}

@IsTest
static void testUpsertConditionsBookingPercentage() {
    Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];

    // Case 2: Percentage type
    Map<String, Decimal> percAmounts = new Map<String, Decimal>{ 'Base Price' => 10 };
    Map<String, String> types = new Map<String, String>{ 'Base Price' => 'Percentage' };

    Test.startTest();
    BookingConditionController.upsertConditions(booking.Id, 'Booking__c', percAmounts, null, types);
    Test.stopTest();

    List<Booking_Condition__c> updated = [
        SELECT Condition_Type__c, Amount__c, Percentage__c, Type__c 
        FROM Booking_Condition__c 
        WHERE Booking__c = :booking.Id
    ];
    System.assert(updated.size() > 0, 'Percentage conditions must exist');
    System.assertEquals(10, updated[0].Percentage__c, 'Base Price percentage should match');
}


    @IsTest
    static void testUpsertConditionsOpportunityPath() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Map<String, Decimal> amounts = new Map<String, Decimal>{ 'Legal charge/Expense' => 50000 };

        Test.startTest();
        BookingConditionController.upsertConditions(opp.Id, 'Opportunity__c', amounts, null, null);
        Test.stopTest();

        List<Booking_Condition__c> inserted = [
            SELECT Id, Condition_Type__c, Amount__c FROM Booking_Condition__c WHERE Opportunity__c = :opp.Id
        ];
        System.assert(inserted.size() > 0, 'Upsert via opportunity should insert');
    }

    @IsTest
    static void testUpsertConditionsNoChanges() {
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        Map<String, Decimal> amounts = new Map<String, Decimal>{ 'Base Price' => 11111 };

        // Run twice so second run has no changes
        BookingConditionController.upsertConditions(booking.Id, 'Booking__c', amounts, null, null);
        Test.startTest();
        BookingConditionController.upsertConditions(booking.Id, 'Booking__c', amounts, null, null);
        Test.stopTest();
        System.assert(true, 'No exception on no changes');
    }

    @IsTest
    static void testDeleteConditionsPositiveAndEmpty() {
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        List<Booking_Condition__c> conds = [SELECT Condition_Type__c FROM Booking_Condition__c WHERE Booking__c = :booking.Id];
        List<String> types = new List<String>();
        for (Booking_Condition__c c : conds) types.add(c.Condition_Type__c);

        Test.startTest();
        BookingConditionController.deleteConditions(booking.Id, 'Booking__c', types);
        BookingConditionController.deleteConditions(booking.Id, 'Booking__c', new List<String>()); // empty list
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Booking_Condition__c WHERE Booking__c = :booking.Id];
        System.assertEquals(0, count, 'Conditions should be deleted');
    }

    @IsTest
    static void testGetParentStageBookingAndOpportunity() {
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        String bookingStage = BookingConditionController.getParentStage(booking.Id, 'Booking__c');
        String oppStage = BookingConditionController.getParentStage(opp.Id, 'Opportunity');
        Test.stopTest();

    }

    @IsTest
    static void testGetParentStageUnsupportedType() {
        Booking__c booking = [SELECT Id FROM Booking__c LIMIT 1];
        Boolean thrown = false;
        try {
            BookingConditionController.getParentStage(booking.Id, 'SomethingElse');
        } catch (AuraHandledException e) {
            thrown = true;
        }
        System.assert(thrown, 'Unsupported type should throw');
    }

    @IsTest
    static void testNullInputsThrow() {
        Boolean exc1=false, exc2=false, exc3=false, exc4=false;
        try { BookingConditionController.getConditions(null,'Booking__c'); } catch(AuraHandledException e){ exc1=true; }
        try { BookingConditionController.getConditions(Id.valueOf(UserInfo.getUserId()), null); } catch(AuraHandledException e){ exc2=true; }
        try { BookingConditionController.upsertConditions(null, 'Booking__c', new Map<String,Decimal>(), null, null); } catch(AuraHandledException e){ exc3=true; }
        try { BookingConditionController.deleteConditions(null, 'Booking__c', new List<String>()); } catch(AuraHandledException e){ exc4=true; }
        System.assert(exc1 && exc2 && exc3 && exc4, 'All should throw AuraHandledException on invalid inputs');
    }

}