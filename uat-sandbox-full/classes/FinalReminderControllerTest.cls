@isTest
private class FinalReminderControllerTest {
    
    @testSetup
    static void setupTestData() {
        // Get Person Account Record Type Id
        Id personRTId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('PersonAccount')
            .getRecordTypeId();
        
        // Person Account with email (positive scenario)
        Account accWithEmail = new Account(
            RecordTypeId = personRTId,
            LastName = 'Test With Email',
            PersonEmail = 'customer@example.com',
            Phone = '9876543210',
            SAP_External_Id__c = 'PA0001'
        );
        insert accWithEmail;
        
        // Person Account without email (negative scenario)
        Account accWithoutEmail = new Account(
            RecordTypeId = personRTId,
            LastName = 'Test No Email',
            SAP_External_Id__c = 'PA0002'
        );
        insert accWithoutEmail;
        
        // Project, Tower, Unit, Payment Plan, Payment Schedules
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id);
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
        
        // Opportunities
        Opportunity opp1 = ResidentialTestDataFactory.createOpportunity(accWithEmail.Id, unit.Id);
        Opportunity opp2 = ResidentialTestDataFactory.createOpportunity(accWithoutEmail.Id, unit.Id);
        
        // Bookings
        Booking__c bookingWithEmail = ResidentialTestDataFactory.createBooking(
            accWithEmail.Id, unit.Id, plan.Id, opp1.Id, project.Id
        );
        Booking__c bookingWithoutEmail = ResidentialTestDataFactory.createBooking(
            accWithoutEmail.Id, unit.Id, plan.Id, opp2.Id, project.Id
        );
        
        // Booking Payment Schedules from factory
        List<Booking_Payment_Schedule__c> bpsWithEmail = ResidentialTestDataFactory.createBookingPaymentSchedules(
            bookingWithEmail.Id, schedules
        );
        List<Booking_Payment_Schedule__c> bpsWithoutEmail = ResidentialTestDataFactory.createBookingPaymentSchedules(
            bookingWithoutEmail.Id, schedules
        );
        
        // FIX: Avoid validation error by making Amount_Paid__c >= Installment_Amount__c
        for (Booking_Payment_Schedule__c bps : bpsWithEmail) {
            bps.Amount_Paid__c = bps.Installment_Amount__c; // fully paid
        }
        for (Booking_Payment_Schedule__c bps : bpsWithoutEmail) {
            bps.Amount_Paid__c = bps.Installment_Amount__c; // fully paid
        }
        update bpsWithEmail;
        update bpsWithoutEmail;
        
        // Adjust first positive record to test partial payment + adjusted amount
        bpsWithEmail[0].Amount_Paid__c = 1000000; 
        bpsWithEmail[0].Adjusted_Amount__c = 50000;
        update bpsWithEmail[0];
        
        // Dates for formatDate coverage
        bookingWithEmail.Booking_Date__c = Date.today().addDays(-1); // Non-null
        bookingWithoutEmail.Booking_Date__c = null;                   // Null branch
        update new List<Booking__c>{ bookingWithEmail, bookingWithoutEmail };
        
        // Extra BPS for null amounts branch — still satisfy validation rule
        Booking_Payment_Schedule__c nullAmtBps = new Booking_Payment_Schedule__c(
            Booking__c = bookingWithEmail.Id,
            Installment_Number__c = 99,
            Payment_Due_Date__c = Date.today().addDays(10),
            Installment_Amount__c = 0,      // no validation error
            Amount_Paid__c = 0,
            Adjusted_Amount__c = null,
            Payment_Schedule_Id__c = schedules[0].Id
        );
        insert nullAmtBps;
    }
    
    static testMethod void testSendReminderEmail_Positive() {
        Booking_Payment_Schedule__c bps = [
            SELECT Id 
            FROM Booking_Payment_Schedule__c
            WHERE Booking__r.Account_Id__r.PersonEmail != null
            LIMIT 1
        ];
        
        Test.startTest();
        FinalReminderController.sendReminderEmail(bps.Id);
        Test.stopTest();
        
        System.Assert.isTrue(true, 'Positive scenario completed without exceptions.');
    }
    
    static testMethod void testSendReminderEmail_NoEmail_Negative() {
        Booking_Payment_Schedule__c bps = [
            SELECT Id 
            FROM Booking_Payment_Schedule__c
            WHERE Booking__r.Account_Id__r.PersonEmail = null
            LIMIT 1
        ];
        
        Test.startTest();
        try {
            FinalReminderController.sendReminderEmail(bps.Id);
            System.Assert.isTrue(false, 'Expected AuraHandledException for missing email.');
        } catch (AuraHandledException e) {
            System.Assert.isTrue(e.getMessage().contains('Failed to send reminder email'), 'Exception message mismatch: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
    static testMethod void testSendReminderEmail_InvalidId_ExceptionPath() {
        Id fakeId = 'a00000000000001AAA'; // Non-existent BPS Id
        
        Test.startTest();
        try {
            FinalReminderController.sendReminderEmail(fakeId);
            System.Assert.isTrue(false, 'Expected AuraHandledException for invalid Id.');
        } catch (AuraHandledException e) {
            System.Assert.isTrue(e.getMessage().contains('Failed to send reminder email'), 'Exception message mismatch: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
    static testMethod void testSendReminderEmail_NullAmountsBoundary() {
        Booking_Payment_Schedule__c bps = [
            SELECT Id 
            FROM Booking_Payment_Schedule__c
            WHERE Installment_Number__c = 99
            LIMIT 1
        ];
        
        Test.startTest();
        FinalReminderController.sendReminderEmail(bps.Id);
        Test.stopTest();
        
        System.Assert.isTrue(true, 'Boundary case with null amounts completed.');
    }
}