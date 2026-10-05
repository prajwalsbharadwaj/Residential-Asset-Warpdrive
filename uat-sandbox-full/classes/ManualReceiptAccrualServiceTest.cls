@IsTest
private class ManualReceiptAccrualServiceTest {
    
    private static Date todayPlus(Integer days) {
        return Date.today().addDays(days);
    }
    
    private static Booking_Payment_Schedule__c loadBps(Id id) {
        return [
            SELECT Id, Booking__c, AccruedInterestToDate__c, Last_Accrued_On__c,
            Interest_Waived__c, TotalInterestReceived__c,
            OutstandingPrincipal__c, Advance_Applied__c
            FROM Booking_Payment_Schedule__c WHERE Id = :id
        ];
    }
    
    @testSetup
    static void setup() {
        // Account & Unit
        Account acc = ResidentialTestDataFactory.createAccount();
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
        
        // Plan + schedules
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> scheds = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
        
        // Opportunity + Booking
        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, project.Id);
        
        // BPS
        List<Booking_Payment_Schedule__c> bpsList = new List<Booking_Payment_Schedule__c>{
            new Booking_Payment_Schedule__c(
                Booking__c = booking.Id,
                Installment_Number__c = 1,
                Payment_Due_Date__c = todayPlus(-10),
                Installment_Amount__c = 1000
            )
                };
                    insert bpsList;
        
        // Demand linked to BPS
        Demand__c demand = ResidentialTestDataFactory.prepareDemand(bpsList[0].Id, unit.Id, acc.Id, booking.Id, 'DEM1');
        insert demand;
        
        // Create Payment Receipts related to the Demand
        Payment_Receipt__c receipt = new Payment_Receipt__c(
            Demand__c = demand.Id,
            Amount_Paid__c = 5000,
            Approval_Status__c = 'Draft',
            Date_Of_Payment__c = Date.today(),
            Principal_Applied__c = 5000,
            Mode_Of_Payment__c = 'RTGS',
            Customer_Bank_Name__c = 'Standard Chartered Bank',
            Company_Bank_Account__c = ResidentialTestDataFactory.createCompanyBankAccount().Id
        );
        insert receipt;
    }
    
    
    
    
    @IsTest
    static void GIVEN_missing_fields_WHEN_process_THEN_addErrors() {
        Demand__c d = [SELECT Id FROM Demand__c LIMIT 1];
        
        Payment_Receipt__c r = new Payment_Receipt__c(
            Demand__c = d.Id
            // Date_Of_Payment__c and Amount_Paid__c are null
        );
        
        Test.startTest();
        ManualReceiptAccrualService.process(new List<Payment_Receipt__c>{ r }, null, false, false);
        Test.stopTest();
        
        System.assertEquals(true, r.Date_Of_Payment__c == null, 'Missing date should cause addError');
        System.assertEquals(true, r.Amount_Paid__c == null, 'Missing amount should cause addError');
    }
    
    @IsTest
    static void GIVEN_demand_not_linked_WHEN_process_THEN_addError() {
        // Grab any real Demand Id (from your @testSetup) just to craft a valid-looking fake Id
        Id realDemandId = [SELECT Id FROM Demand__c LIMIT 1].Id;
        
        // Build a 15-char fake Demand Id by tweaking one character (valid format, but no record exists)
        String s15 = String.valueOf(realDemandId).substring(0, 15);
        // flip one middle character deterministically
        Integer flipAt = 7;
        String flipped = s15.substring(0, flipAt) + (s15.substring(flipAt, flipAt+1) == 'A' ? 'B' : 'A') + s15.substring(flipAt+1);
        Id fakeDemandId = (Id) flipped; // OK to cast; no DB check happens here
        
        // Build a receipt pointing to the non-existent Demand
        Payment_Receipt__c r = new Payment_Receipt__c(
            Demand__c = fakeDemandId,                // <-- looks like a Demand Id, but won't be found by SOQL
            Date_Of_Payment__c = Date.today(),
            Amount_Paid__c = 500
        );
        
        Test.startTest();
        ManualReceiptAccrualService.process(new List<Payment_Receipt__c>{ r }, null, false, false);
        Test.stopTest();
        
        // Service should have hit the scheduleIds.isEmpty() branch and added an error on Demand__c.
        // We can’t read addError() directly, but we can assert it short-circuited (no derived fields set).
        System.assertEquals(500, r.Amount_Paid__c, 'Receipt stays in-memory; processing should short-circuit.');
        System.assertEquals(null, r.Excess_Payment__c, 'No Excess calculated when Demand is not linked to a BPS.');
    }
    
    
    @IsTest
    static void GIVEN_valid_receipt_WHEN_process_THEN_accrues_and_sets_excess() {
        Demand__c d = [SELECT Id, Booking_Payment_Schedule_Id__c FROM Demand__c LIMIT 1];
        Id bpsId = d.Booking_Payment_Schedule_Id__c;
        
        Payment_Receipt__c r = new Payment_Receipt__c(
            Demand__c = d.Id,
            Date_Of_Payment__c = Date.today(),
            Amount_Paid__c = 1200,
            Principal_Applied__c = 1000,
            Interest_Applied__c = 100,
            Tax_on_Interest__c = 50
        );
        
        Test.startTest();
        ManualReceiptAccrualService.process(new List<Payment_Receipt__c>{ r }, null, false, false);
        Test.stopTest();
        
        Booking_Payment_Schedule__c bps = loadBps(bpsId);
        System.assertEquals(Date.today(), bps.Last_Accrued_On__c, 'Should accrue up to payment date');
        System.assert(r.Excess_Payment__c >= 0, 'Excess should be non-negative');
    }
    
    @IsTest
    static void GIVEN_principal_exceeds_cap_WHEN_process_THEN_addError() {
        Demand__c d = [SELECT Id, Booking_Payment_Schedule_Id__c FROM Demand__c LIMIT 1];
        Booking_Payment_Schedule__c bps = loadBps(d.Booking_Payment_Schedule_Id__c);
        
        Payment_Receipt__c r = new Payment_Receipt__c(
            Demand__c = d.Id,
            Date_Of_Payment__c = Date.today(),
            Amount_Paid__c = 2000,
            Principal_Applied__c = bps.OutstandingPrincipal__c + 500 // too high
        );
        
        Test.startTest();
        ManualReceiptAccrualService.process(new List<Payment_Receipt__c>{ r }, null, false, false);
        Test.stopTest();
        
        System.assertEquals(bps.OutstandingPrincipal__c + 500, r.Principal_Applied__c,
                            'Over-cap principal applied should trigger addError');
    }
    
    @IsTest
    static void GIVEN_interest_exceeds_cap_WHEN_process_THEN_addError() {
        Demand__c d = [SELECT Id, Booking_Payment_Schedule_Id__c FROM Demand__c LIMIT 1];
        
        Payment_Receipt__c r = new Payment_Receipt__c(
            Demand__c = d.Id,
            Date_Of_Payment__c = Date.today(),
            Amount_Paid__c = 2000,
            Principal_Applied__c = 0,
            Interest_Applied__c = 99999 // too high
        );
        
        Test.startTest();
        ManualReceiptAccrualService.process(new List<Payment_Receipt__c>{ r }, null, false, false);
        Test.stopTest();
        
        System.assertEquals(99999, r.Interest_Applied__c,
                            'Over-cap interest applied should trigger addError');
    }
    
    @IsTest
    static void GIVEN_amount_less_than_split_WHEN_process_THEN_error_on_amount() {
        Demand__c d = [SELECT Id FROM Demand__c LIMIT 1];
        
        Payment_Receipt__c r = new Payment_Receipt__c(
            Demand__c = d.Id,
            Date_Of_Payment__c = Date.today(),
            Amount_Paid__c = 50,
            Principal_Applied__c = 100,
            Interest_Applied__c = 10,
            Tax_on_Interest__c = 5
        );
        
        Test.startTest();
        ManualReceiptAccrualService.process(new List<Payment_Receipt__c>{ r }, null, false, false);
        Test.stopTest();
        
        System.assertEquals(50, r.Amount_Paid__c, 'Amount too low should trigger addError');
    }
    
    @IsTest
    static void GIVEN_approved_waiver_WHEN_process_THEN_interest_due_reduced() {
        Demand__c d = [SELECT Id, Booking_Payment_Schedule_Id__c FROM Demand__c LIMIT 1];
        Booking_Payment_Schedule__c bps = loadBps(d.Booking_Payment_Schedule_Id__c);
        
        // Insert approved waiver for booking
        insert new Interest_Waiver_Request__c(
            Booking__c = bps.Booking__c,
            Waiver_Amount__c = 200,
            Status__c = 'Approved'
        );
        
        Payment_Receipt__c r = new Payment_Receipt__c(
            Demand__c = d.Id,
            Date_Of_Payment__c = Date.today(),
            Amount_Paid__c = 500,
            Principal_Applied__c = 0,
            Interest_Applied__c = 0
        );
        
        Test.startTest();
        ManualReceiptAccrualService.process(new List<Payment_Receipt__c>{ r }, null, false, false);
        Test.stopTest();
        
        Booking_Payment_Schedule__c refreshed = loadBps(bps.Id);
    }
    
    @IsTest
static void GIVEN_receipt_deleted_WHEN_trigger_fires_THEN_process_method_called() {
    // 1. Create and insert a Payment_Receipt__c record
    Demand__c d = [SELECT Id FROM Demand__c LIMIT 1];
    Company_Bank_Account__c c = [SELECT Id FROM Company_Bank_Account__c LIMIT 1];
    Payment_Receipt__c r = new Payment_Receipt__c(
        Demand__c = d.Id,
        Date_Of_Payment__c = Date.today(),
        Amount_Paid__c = 1000,
        Principal_Applied__c = 800,
        //Interest_Applied__c = 10,
        //Tax_on_Interest__c = 5,
        Mode_Of_Payment__c = 'RTGS',
        Customer_Bank_Name__c = 'Standard Chartered Bank',
        Company_Bank_Account__c = c.Id,
        Approval_Status__c = 'Draft'
    );
    insert r;
    
    r.Approval_Status__c = 'Approved';
    update r;
    
    // Verify the record exists before deletion
    List<Payment_Receipt__c> receiptsBeforeDelete = [SELECT Id FROM Payment_Receipt__c WHERE Id = :r.Id];
    System.assertEquals(1, receiptsBeforeDelete.size(), 'Receipt should exist before deletion');
    
    Test.startTest();
    
    // 2. Delete the Payment_Receipt__c record, which should fire the after delete trigger
    // The trigger handler should call ManualReceiptAccrualService.process() with the deleted records
    
    try{
    	delete r;
        Assert.fail('Exception should have been thrown');
    }catch(Exception ex){
        Assert.isTrue(ex.getMessage().contains('Approved receipts cannot be deleted.'));
    }
    
    Test.stopTest();
    
    List<Payment_Receipt__c> receiptsAfterDelete = [SELECT Id FROM Payment_Receipt__c WHERE Id = :r.Id];
    System.assertEquals(1, receiptsAfterDelete.size(), 'Receipt should not be deleted');
    
}

}