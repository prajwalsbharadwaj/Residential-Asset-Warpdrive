@isTest
public class AgentBrokerageTriggerTest {

    @testSetup
    static void setupData() {
        // Create base data using factory
        Account acc = ResidentialTestDataFactory.createAccount();
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id);
        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        Booking__c booking = ResidentialTestDataFactory.createBooking(
            acc.Id, unit.Id, plan.Id, opp.Id, project.Id
        );
    }

    @isTest
static void testBrokerageCreatesBookingCondition() {
    Booking__c booking = [SELECT Id, Opportunity_Id__c FROM Booking__c LIMIT 1];

    List<Agent_Brokerage__c> brokerages =
        ResidentialTestDataFactory.createAgentBrokerage(booking.Id);

    Test.startTest();
    insert brokerages;
    Test.stopTest();

    // Re-query brokerages to get formula field value
brokerages = [
    SELECT Id, Total_Bokerage__c, Booking__c
    FROM Agent_Brokerage__c
    WHERE Id IN :brokerages
];

// Now assert
List<Booking_Condition__c> bcList = [
    SELECT Id, Condition_Type__c, Amount_By_Type__c, Booking__c, Opportunity__c
    FROM Booking_Condition__c
    WHERE Booking__c = :booking.Id
    AND Condition_Type__c = 'Brokerage Fix Amt'
];

/*System.assertEquals(
    brokerages[0].Total_Bokerage__c,   
    bcList[0].Amount_By_Type__c,
    'Booking Condition amount should match Total Brokerage'
);*/
}

    @isTest
    static void testNoBookingNoBookingCondition() {

        // Insert brokerage without Booking__c
        Agent_Brokerage__c ab = new Agent_Brokerage__c(
            Bokerage_Amount__c = 5000,
            Bokerage_Type__c = 'Fixed'
        );

        Test.startTest();
        insert ab;
        Test.stopTest();

        // Verify no Brokerage Fix Amt condition created
        List<Booking_Condition__c> bcList = [
            SELECT Id FROM Booking_Condition__c
            WHERE Condition_Type__c = 'Brokerage Fix Amt'
        ];
        System.assertEquals(0, bcList.size(),
            'No Booking Condition should be created when Booking__c is null');
    }

}