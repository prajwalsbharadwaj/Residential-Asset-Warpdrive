@IsTest
public class BookingPaymentSchHelperTest {
    
    @testSetup
    static void setupData() {
        // Create base data using factory
        Account acc = ResidentialTestDataFactory.createAccount();
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        
        // Create a booking
        Booking__c booking1 = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, project.Id);
        
        // Create Booking Payment Schedules with outstanding values
        List<Booking_Payment_Schedule__c> bpsList = new List<Booking_Payment_Schedule__c>{
            new Booking_Payment_Schedule__c(
                Booking__c = booking1.Id,
                Installment_Number__c = 1,
                Payment_Due_Date__c = Date.today(),
                Installment_Amount__c = 50000,
                //TotalInterestOutstandingnet__c = 1000,
                //OutstandingPrincipal__c = 40000,
                AccruedInterestToDate__c = 1000,
                Payment_Schedule_Id__c = schedules[0].Id
            ),
            new Booking_Payment_Schedule__c(
                Booking__c = booking1.Id,
                Installment_Number__c = 2,
                Payment_Due_Date__c = Date.today().addDays(30),
                Installment_Amount__c = 70000,
                AccruedInterestToDate__c = 1000,
                Payment_Schedule_Id__c = schedules[1].Id
            )
        };
        insert bpsList;

        // Create another booking for bulk test
        Booking__c booking2 = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, project.Id);
        Booking_Payment_Schedule__c bps2 = new Booking_Payment_Schedule__c(
            Booking__c = booking2.Id,
            Installment_Number__c = 1,
            Payment_Due_Date__c = Date.today(),
            Installment_Amount__c = 80000,
            AccruedInterestToDate__c = 1000,
            Payment_Schedule_Id__c = schedules[0].Id
        );
        insert bps2;
    }
    
    
    // From here new test methods added.
    @IsTest
    static void testAssignFinanceDetails_WithMatchingPolicy() {
        opportunity opp = [SELECT id, Interested_unit__c, Interested_Unit__r.property__c FROM Opportunity LIMIT 1];
        Property__c project = [SELECT Name FROM Property__c WHERE Id =: opp.Interested_Unit__r.property__c];
        project.name = 'Kessaku';
        update project;

        // Create CMDT test record (simulate Finance Policy for Kessaku)
        Finance_Policy__mdt kessakuPolicy = [SELECT DeveloperName, MasterLabel, Default_Annual_Interest_Rate__c,Grace_Period_Days__c, GSTVATRateOnInterest__c FROM Finance_Policy__mdt WHERE MasterLabel = 'Kessaku' LIMIT 1];
        // Create booking schedule (before insert simulation)
        Booking_Payment_Schedule__c bps = new Booking_Payment_Schedule__c(
            Opportunity__c = opp.Id,
            Booking__c = null, // Not needed for this method
            Installment_Number__c = 1,
            Payment_Due_Date__c = Date.today(),
            Installment_Amount__c = 100000
        );

        Test.startTest();
        List<Booking_Payment_Schedule__c> newList = new List<Booking_Payment_Schedule__c>{bps};
        BookingPaymentSchHelper.assignFinanceDetails(newList);
        Test.stopTest();
        System.assertEquals(kessakuPolicy.Default_Annual_Interest_Rate__c, newList[0].Annual_Interest_Rate__c,
            'Annual interest rate should be assigned from CMDT');
        System.assertEquals(kessakuPolicy.Grace_Period_Days__c, newList[0].Grace_Period_Days__c,
            'Grace period should be assigned from CMDT');
        System.assertEquals(kessakuPolicy.GSTVATRateOnInterest__c, newList[0].GST_VAT_Rate_On_Interest__c,
            'GST/VAT Rate should be assigned from CMDT');
    }


    @IsTest
    static void testAssignFinanceDetails_DefaultPolicyApplied() {
        opportunity opp = [SELECT id, Interested_unit__c, Interested_Unit__r.property__c FROM Opportunity LIMIT 1];
        Property__c project = [SELECT Name FROM Property__c WHERE Id =: opp.Interested_Unit__r.property__c];
        project.name = 'Some Other 123';
        update project;

        // Insert a default CMDT record
        Finance_Policy__mdt defaultPolicy = [SELECT DeveloperName, MasterLabel, Default_Annual_Interest_Rate__c,Grace_Period_Days__c, GSTVATRateOnInterest__c FROM Finance_Policy__mdt WHERE MasterLabel = 'Default' LIMIT 1];

        // Create booking schedule
        Booking_Payment_Schedule__c bps = new Booking_Payment_Schedule__c(
            Opportunity__c = opp.Id,
            Installment_Number__c = 1,
            Payment_Due_Date__c = Date.today(),
            Installment_Amount__c = 200000
        );

        Test.startTest();
        List<Booking_Payment_Schedule__c> newList = new List<Booking_Payment_Schedule__c>{bps};
        BookingPaymentSchHelper.assignFinanceDetails(newList);
        Test.stopTest();

        // Verify default policy applied
        System.assertEquals(defaultPolicy.Default_Annual_Interest_Rate__c, newList[0].Annual_Interest_Rate__c,
            'Default Annual interest rate should be applied');
        System.assertEquals(defaultPolicy.Grace_Period_Days__c, newList[0].Grace_Period_Days__c,
            'Default Grace period should be applied');
        System.assertEquals(defaultPolicy.GSTVATRateOnInterest__c, newList[0].GST_VAT_Rate_On_Interest__c,
            'Default GST/VAT Rate should be applied');
    }

    @IsTest
    static void testAssignFinanceDetails_ExceptionHandled() {
        // Pass an invalid Opportunity Id to simulate exception
        Booking_Payment_Schedule__c bps = new Booking_Payment_Schedule__c(
            Opportunity__c = '006000000000000AAA', // fake Id
            Installment_Number__c = 1,
            Payment_Due_Date__c = Date.today(),
            Installment_Amount__c = 50000
        );

        Test.startTest();
        BookingPaymentSchHelper.assignFinanceDetails(new List<Booking_Payment_Schedule__c>{bps});
        Test.stopTest();

        // No exception should propagate
        System.assert(true, 'Exception should be caught gracefully');
    }
}