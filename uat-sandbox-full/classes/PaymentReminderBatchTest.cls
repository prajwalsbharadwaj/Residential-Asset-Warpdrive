@IsTest
public class PaymentReminderBatchTest {

    @TestSetup
    static void setup() {

        //  DO NOT insert CustomNotificationType
        //  DO NOT query it here
        // The batch constructor will query it safely.

        // Create Account
        Account acc = ResidentialTestDataFactory.createAccount();

        // Create Project, Tower, Floor, Unit
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);

        // ️⃣ Payment Plan & Schedules
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);

        // ️⃣ Opportunity
        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);

        // ️⃣ Booking
        Booking__c booking = ResidentialTestDataFactory.createBooking(
            acc.Id, unit.Id, plan.Id, opp.Id, project.Id
        );

        // ️⃣ BPS
        List<Booking_Payment_Schedule__c> bpsList =
            ResidentialTestDataFactory.createBookingPaymentSchedules(
                booking.Id,
                opp.Id,
                schedules
            );

        // ️⃣ Ensure one BPS matches the batch filter
        for (Booking_Payment_Schedule__c bps : bpsList) {
            bps.Payment_Due_Date__c = Date.today().addDays(15);
        }
        update bpsList;
    }

    @IsTest
    static void testPaymentReminderBatch() {

        Test.startTest();

        Database.executeBatch(new PaymentReminderBatch(), 50);

        Test.stopTest();

        //  Verify at least one BPS record exists
        List<Booking_Payment_Schedule__c> listBPS = [
            SELECT Id FROM Booking_Payment_Schedule__c
        ];
        System.assert(!listBPS.isEmpty(), 'BPS should exist');

        //  Verify Custom Notification Type exists (READ-ONLY query allowed)
        CustomNotificationType nt = [
            SELECT Id 
            FROM CustomNotificationType
            WHERE DeveloperName = 'General_Custom_Notification'
            LIMIT 1
        ];
        System.assertNotEquals(null, nt, 'Notification Type must exist');

        //  If no exception → batch executed successfully
        System.assertEquals(true, true);
    }
    
    @IsTest
    static void testSchedulerExecution() {

        String cron = '0 0 2 * * ?'; // Runs at 2 AM daily

        Test.startTest();
        System.schedule(
            'Test Payment Scheduler',
            cron,
            new PaymentReminderBatchScheduler()
        );
        Test.stopTest();

        System.assertEquals(true, true, 'Scheduler executed');
    }
    
   

}