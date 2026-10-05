@isTest
private class OwnershipTransferControllerTest {

    @testSetup
    static void setupData() {
        // Account (Person) via factory
        Account acc = ResidentialTestDataFactory.preparePersonAccount();
        acc.LastName = 'Test Account';
        insert acc;
        
        // Account
        Account custacc = new Account(
            Name = 'Customer Account'
        );
        insert custacc;
        
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.prepareUnit(project.Id, tower.Id, floor.Id);
        unit.Name = 'Test Unit';
        unit.Status__c = 'Available';
        unit.SAP_External_Id__c = 'UNIT123';
        insert unit;

        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);

        // Opportunity via factory
        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        opp.StageName = 'Closed Won';
        opp.Payment_Plan__c = plan.Id;
        opp.Token_Amount__c = 50000;
        update opp;

        // Lead via factory
        Lead lead = ResidentialTestDataFactory.createLead();

        // Payment Plan via factory
        Payment_Plan__c paymentPlan = ResidentialTestDataFactory.createPaymentPlan();

        // Booking via factory and adjust specifics
        Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, paymentPlan.Id, opp.Id, project.Id);
        booking.Funding_Method__c = 'Self-Funded';
        booking.Booking_Date__c = Date.today();
        update booking;
    }

    static Map<String, Id> getIds() {
        return new Map<String, Id>{
            'AccountId' => [SELECT Id FROM Account LIMIT 1].Id,
            'CustomerAccountId' => [SELECT Id FROM Account WHERE Name = 'Customer Account' LIMIT 1].Id,
            'LeadId'    => [SELECT Id FROM Lead LIMIT 1].Id,
            'BookingId' => [SELECT Id FROM Booking__c LIMIT 1].Id
        };
    }

    @isTest
    static void testCreateOwnershipTransferForAccount() {
        Map<String, Id> ids = getIds();

        String payload = JSON.serialize(new Map<String, Object>{
            'transferReason'       => 'Ownership change due to resale',
            'transferDate'         => String.valueOf(Date.today()),
            'parentRecordId'       => ids.get('BookingId'),
            'parentObjectApiName'  => 'Booking__c',
            'transferType'         => 'Account',
            'newAccountId'         => ids.get('CustomerAccountId')
        });

        Test.startTest();
        OwnershipTransferController.createOwnershipTransfer(payload);
        Test.stopTest();

        List<Ownership_Transfer__c> transfers = [
            SELECT Id, New_Account_Id__c, Status__c
            FROM Ownership_Transfer__c
            WHERE Booking_Id__c = :ids.get('BookingId')
        ];

        System.assertEquals(1, transfers.size(), 'One ownership transfer should be created');
        System.assertEquals('Submitted', transfers[0].Status__c);
    }

    @isTest
    static void testCreateOwnershipTransferMissingBooking() {
        String payload = JSON.serialize(new Map<String, Object>{
            'transferReason'       => 'No booking test',
            'transferDate'         => String.valueOf(Date.today()),
            'parentRecordId'       => null,
            'parentObjectApiName'  => null,
            'transferType'         => 'Account',
            'newAccountId'         => UserInfo.getUserId()
        });

        Test.startTest();
        try {
            OwnershipTransferController.createOwnershipTransfer(payload);
            System.Assert.isTrue(false, 'Expected AuraHandledException not thrown');
        } catch (AuraHandledException ex) {
            System.Assert.isTrue(true, 'Caught expected AuraHandledException');
        }
        Test.stopTest();
    }
    
    // approval process test class
    private static String getPayload(Id bookingId, String newAccountId) {
        Map<String, Object> data = new Map<String, Object>{
            'transferReason' => 'Test reason',
            'transferDate' => String.valueOf(Date.today()),
            'parentRecordId' => bookingId,
            'parentObjectApiName' => 'Booking__c',
            'transferType' => 'Account',
            'newAccountId' => newAccountId
        };
        return JSON.serialize(data);
    }

    // Test for exception in Booking query (simulate by passing invalid booking Id)
    @isTest static void testBookingQueryException() {
        // Pass an invalid Booking Id to force query to fail
        String badBookingId = 'a0B000000000000AAA'; // fake Booking Id
        String payload = getPayload(badBookingId, UserInfo.getUserId());

        Test.startTest();
        try {
            OwnershipTransferController.createOwnershipTransfer(payload);
            System.Assert.isTrue(false, 'Expected AuraHandledException was not thrown');
        } catch (AuraHandledException e) {
            System.assertEquals('Script-thrown exception', e.getMessage());
        }
        Test.stopTest();
    }
}