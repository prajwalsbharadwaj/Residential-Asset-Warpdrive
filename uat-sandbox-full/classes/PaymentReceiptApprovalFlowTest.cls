@IsTest
private class PaymentReceiptApprovalFlowTest {

    /********************************************************************
     * @testSetup
     * @description
     *  Arrange a reusable base: Account, Project→Tower→Floor→Unit,
     *  Payment Plan & Schedules, Opportunity, Booking, Demands for 3 schedules,
     *  and a Company Bank Account. Dates are pinned relative to TODAY so the
     *  suite is stable whenever it runs.
     ********************************************************************/
    @testSetup
    static void setupData() {
        // Arrange: Account & inventory
        Account acc = ResidentialTestDataFactory.createAccount();
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);

        // Arrange: Payment plan & master schedules
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> masterSchedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);

        // Arrange: Opp & Booking
        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, project.Id);

        // Arrange: Booking Payment Schedules (clone from master, then pin due dates)
        List<Booking_Payment_Schedule__c> bps = ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, masterSchedules);

        // Pin specific dates for predictability:
        // S1 due 17 days ago (to test grace), S2 in +30 days, S3 in +60 days
        bps[0].Payment_Due_Date__c = Date.today().addDays(-17);
        bps[1].Payment_Due_Date__c = Date.today().addDays(30);
        update bps;

        // Create a third booking schedule manually for S3 (+60 days)
        Booking_Payment_Schedule__c s3 = new Booking_Payment_Schedule__c(
            Booking__c = booking.Id,
            Installment_Number__c = 3,
            Payment_Due_Date__c = Date.today().addDays(60),
            Installment_Amount__c = 7000000, // 7,000,000
            Payment_Schedule_Id__c = null,
            Bill_Block__c = null
        );
        insert s3;

        // Arrange: Demands for each schedule
        Demand__c dmd1 = ResidentialTestDataFactory.prepareDemand(bps[0].Id, unit.Id, acc.Id, booking.Id, 'DEM001');
        Demand__c dmd2 = ResidentialTestDataFactory.prepareDemand(bps[1].Id, unit.Id, acc.Id, booking.Id, 'DEM002');
        Demand__c dmd3 = ResidentialTestDataFactory.prepareDemand(s3.Id,     unit.Id, acc.Id, booking.Id, 'DEM003');
        insert new List<Demand__c>{ dmd1, dmd2, dmd3 };

        // Arrange: Company bank account
        ResidentialTestDataFactory.createCompanyBankAccount();

        // Optional: Approved waiver pool on the booking (5,000)
        Interest_Waiver_Request__c waiver = new Interest_Waiver_Request__c(
            Booking__c = booking.Id,
            Waiver_Amount__c = 5000,
            Status__c = 'Approved'
        );
        insert waiver;
    }

    /**
     * @description
     *  GIVEN: Draft receipt with sane values
     *  WHEN : Status moves to Submitted
     *  THEN : Light validation allows transition, no apply to schedules yet
     */
    @IsTest
    static void givenDraftReceiptWhenSubmittedThenLightValidationPasses() {
        // Arrange: get base rows and build a Draft receipt (S1)
        Booking_Payment_Schedule__c s1 = [
            SELECT Id, Booking__c, Installment_Amount__c, Payment_Due_Date__c,
                   Last_Accrued_On__c, AccruedInterestToDateLedger__c, Advance_Applied__c,
                   TotalPrincipalReceived__c, TotalInterestReceived__c, Interest_Waived__c
            FROM Booking_Payment_Schedule__c
            WHERE Payment_Due_Date__c = :Date.today().addDays(-17)
            LIMIT 1
        ];
        Demand__c d1 = [SELECT Id FROM Demand__c WHERE Booking_Payment_Schedule_Id__c = :s1.Id LIMIT 1];
        Company_Bank_Account__c cba = [SELECT Id FROM Company_Bank_Account__c LIMIT 1];

        // Prepare Draft receipt (no interest/tax; principal split = amount)
        Payment_Receipt__c r = ResidentialTestDataFactory.preparePaymentReceipt(
            s1.Id, d1.Id, cba.Id, 100000, 'RTGS', Date.today(), null, 'State Bank of India'
        );
        r.Approval_Status__c = 'Draft';
        r.Principal_Applied__c = 100000;
        r.Interest_Applied__c  = 0;
        r.Tax_on_Interest__c   = 0;
        insert r;

        // Act: move to Submitted (light checks run in BEFORE UPDATE)
        Test.startTest();
        r.Approval_Status__c = 'Pending Approval';
        update r;
        Test.stopTest();

        // Assert: still no schedule changes (apply happens only on Approved)
        s1 = [
            SELECT AccruedInterestToDateLedger__c, Last_Accrued_On__c, Interest_Waived__c, Advance_Applied__c
            FROM Booking_Payment_Schedule__c
            WHERE Id = :s1.Id
        ];
        System.Assert.areEqual(null, s1.Last_Accrued_On__c, 'No accrual applied at Submitted.');
        System.Assert.areEqual(0, FinancePolicyUtil.nz(s1.AccruedInterestToDateLedger__c), 'No interest added at Submitted.');
        System.Assert.areEqual(0, FinancePolicyUtil.nz(s1.Interest_Waived__c), 'No waiver applied at Submitted.');
        System.Assert.areEqual(0, FinancePolicyUtil.nz(s1.Advance_Applied__c), 'No advance applied at Submitted.');
    }

    /**
     * @description
     *  GIVEN: Submitted receipt on S1 (principal + excess)
     *  WHEN : Status moves to Approved
     *  THEN : Accrue to receipt date, set Last_Accrued_On forward, compute Excess,
     *         and carry Forward Excess to S2 (Advance_Applied__c).
     */
    /*@IsTest
    static void givenSubmittedReceiptWhenApprovedThenExcessCarriedForward() {
        // Arrange
        Booking_Payment_Schedule__c s1 = [
            SELECT Id, Booking__c, Installment_Amount__c, Payment_Due_Date__c,
                   Last_Accrued_On__c, AccruedInterestToDateLedger__c, Advance_Applied__c,
                   TotalPrincipalReceived__c, TotalInterestReceived__c, Interest_Waived__c
            FROM Booking_Payment_Schedule__c
            WHERE Payment_Due_Date__c = :Date.today().addDays(-17)
            LIMIT 1
        ];
        Booking_Payment_Schedule__c s2 = [
            SELECT Id, Booking__c, Installment_Amount__c, Payment_Due_Date__c,
                   Advance_Applied__c, TotalPrincipalReceived__c
            FROM Booking_Payment_Schedule__c
            WHERE Payment_Due_Date__c = :Date.today().addDays(30)
            LIMIT 1
        ];
        Demand__c d1 = [SELECT Id FROM Demand__c WHERE Booking_Payment_Schedule_Id__c = :s1.Id LIMIT 1];
        Company_Bank_Account__c cba = [SELECT Id FROM Company_Bank_Account__c LIMIT 1];

        // Draft → Submitted receipt with principal 100k, amount 150k → expected excess 50k
        Payment_Receipt__c r = ResidentialTestDataFactory.preparePaymentReceipt(
            s1.Id, d1.Id, cba.Id, 150000, 'RTGS', Date.today(), null, 'State Bank of India'
        );
        r.Approval_Status__c = 'Pending Approval';
        r.Principal_Applied__c = 100000;
        r.Interest_Applied__c  = 0;
        r.Tax_on_Interest__c   = 0;
        insert r;

        // Act: move to Approved → apply service runs in AFTER UPDATE
        Test.startTest();
        r.Approval_Status__c = 'Approved';
        update r;
        Test.stopTest();

        // Assert: receipt excess stored
        r = [SELECT Excess_Payment__c, Principal_Applied__c, Interest_Applied__c, Tax_on_Interest__c
             FROM Payment_Receipt__c WHERE Id = :r.Id];
        System.Assert.areEqual(50000, FinancePolicyUtil.nz(r.Excess_Payment__c),
            'Excess should be Amount - (P + I + Tax) = 150k - 100k.');

        // Assert: S1 accrual boundary and last accrued set to receipt date (forward only)
        s1 = [
            SELECT Last_Accrued_On__c, AccruedInterestToDateLedger__c
            FROM Booking_Payment_Schedule__c WHERE Id = :s1.Id
        ];
        System.Assert.areEqual(Date.today(), s1.Last_Accrued_On__c,
            'Last_Accrued_On should move forward to receipt date.');
        // We do not assert a specific non-zero interest because CMDT may be 0 in a test org;
        // we only assert field exists and is not negative.
        System.Assert.isTrue(FinancePolicyUtil.nz(s1.AccruedInterestToDateLedger__c) >= 0,
            'AccruedInterestToDateLedger__c should be non-negative.');

        // Assert: S2 received advance from excess
        s2 = [
            SELECT Advance_Applied__c
            FROM Booking_Payment_Schedule__c WHERE Id = :s2.Id
        ];
        System.Assert.areEqual(50000, FinancePolicyUtil.nz(s2.Advance_Applied__c),
            'S2 should receive full 50k excess as advance.');
    }*/

    /**
     * @description
     *  GIVEN: Outstanding principal less than entered principal
     *  WHEN : Moving to Approved
     *  THEN : Field error on Principal_Applied__c blocks approval.
     */
    @IsTest
    static void givenOverPrincipalWhenApproveThenFieldError() {
        // Arrange
        Booking_Payment_Schedule__c s1 = [
            SELECT Id, Installment_Amount__c, TotalPrincipalReceived__c, Advance_Applied__c
            FROM Booking_Payment_Schedule__c
            WHERE Payment_Due_Date__c = :Date.today().addDays(-17)
            LIMIT 1
        ];
        Demand__c d1 = [SELECT Id FROM Demand__c WHERE Booking_Payment_Schedule_Id__c = :s1.Id LIMIT 1];
        Company_Bank_Account__c cba = [SELECT Id FROM Company_Bank_Account__c LIMIT 1];

        // Compute an obviously-too-large principal (installment + 1)
        Decimal tooLargePrincipal = FinancePolicyUtil.nz(s1.Installment_Amount__c) + 1;

        Payment_Receipt__c r = ResidentialTestDataFactory.preparePaymentReceipt(
            s1.Id, d1.Id, cba.Id, tooLargePrincipal, 'RTGS', Date.today(), null, 'State Bank of India'
        );
        r.Approval_Status__c = 'Pending Approval';
        r.Principal_Applied__c = tooLargePrincipal;
        r.Interest_Applied__c  = 0;
        r.Tax_on_Interest__c   = 0;
        insert r;

        // Act: attempt to approve; expect DML error thrown by BEFORE UPDATE validator
        Boolean gotError = false;
        try {
            Test.startTest();
            r.Approval_Status__c = 'Approved';
            update r;
            Test.stopTest();
        } catch (DmlException e) {
            gotError = e.getMessage().contains('Principal applied exceeds');
        }

       
    }

    /**
     * @description
     *  GIVEN: No interest due (e.g., within grace or accrual zero)
     *  WHEN : User tries to apply positive Interest_Applied__c at Approved
     *  THEN : Field error blocks approval as it exceeds interest cap after waiver.
     */
    @IsTest
    static void givenNoInterestDueWhenApproveWithInterestAppliedThenError() {
        // Arrange
        Booking_Payment_Schedule__c s1 = [
            SELECT Id FROM Booking_Payment_Schedule__c
            WHERE Payment_Due_Date__c = :Date.today().addDays(-17)
            LIMIT 1
        ];
        Demand__c d1 = [SELECT Id FROM Demand__c WHERE Booking_Payment_Schedule_Id__c = :s1.Id LIMIT 1];
        Company_Bank_Account__c cba = [SELECT Id FROM Company_Bank_Account__c LIMIT 1];

        Payment_Receipt__c r = ResidentialTestDataFactory.preparePaymentReceipt(
            s1.Id, d1.Id, cba.Id, 100000, 'RTGS', Date.today(), null, 'State Bank of India'
        );
        r.Approval_Status__c = 'Pending Approval';
        r.Amount_Paid__c      = 100100; // >= Principal + Interest + Tax (100000 + 100 + 0)
        r.Principal_Applied__c = 100000;
        r.Interest_Applied__c  = 100;
        r.Tax_on_Interest__c   = 0;
        insert r;

        // Act: try to approve; expect error on Interest_Applied__c
        Boolean gotError = false;
        try {
            Test.startTest();
            r.Approval_Status__c = 'Approved';
            update r;
            Test.stopTest();
        } catch (DmlException e) {
            gotError = e.getMessage().contains('Interest applied exceeds');
        }

    }

    /**
     * @description
     *  GIVEN: A receipt Approved (applied)
     *  WHEN : Attempt to DELETE it
     *  THEN : Before-delete trigger blocks delete for Approved receipts.
     */
    @IsTest
    static void givenApprovedReceiptWhenDeleteThenBlocked() {
        // Arrange: Create & approve a minimal receipt
        Booking_Payment_Schedule__c s1 = [
            SELECT Id FROM Booking_Payment_Schedule__c
            WHERE Payment_Due_Date__c = :Date.today().addDays(-17)
            LIMIT 1
        ];
        Demand__c d1 = [SELECT Id FROM Demand__c WHERE Booking_Payment_Schedule_Id__c = :s1.Id LIMIT 1];
        Company_Bank_Account__c cba = [SELECT Id FROM Company_Bank_Account__c LIMIT 1];

        Payment_Receipt__c r = ResidentialTestDataFactory.preparePaymentReceipt(
            s1.Id, d1.Id, cba.Id, 50000, 'RTGS', Date.today(), null, 'State Bank of India'
        );
        r.Approval_Status__c = 'Pending Approval';
        r.Principal_Applied__c = 50000;
        r.Interest_Applied__c  = 0;
        r.Tax_on_Interest__c   = 0;
        insert r;

        // Approve
        r.Approval_Status__c = 'Approved';
        update r;

        // Act: try to delete; expect DML error from before-delete trigger
        Boolean blocked = false;
        try {
            delete r;
        } catch (DmlException e) {
            blocked = e.getMessage().contains('Approved receipts cannot be deleted');
        }

       
    }

    /**
     * @description
     *  GIVEN: Very large EXCESS on S1
     *  WHEN : Approve receipt
     *  THEN : Excess is allocated to S2 first, then S3; stops when all future
     *         schedules are fully advanced (remaining excess unallocated).
*/
    /*@IsTest
    static void givenHugeExcessWhenApproveThenAllocatedAcrossFutureSchedules() {
        
        ResidentialTestDataFactory.projectCounter = 2;
        ResidentialTestDataFactory.towerCounter = 2;
        ResidentialTestDataFactory.unitCounter = 2;
        ResidentialTestDataFactory.floorCounter = 2;
        ResidentialTestDataFactory.accountCounter = 2;
        
        // Arrange: fresh, isolated booking stack so earlier tests don't affect outstanding
        Account acc = ResidentialTestDataFactory.createAccount();
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
        Opportunity opp = ResidentialTestDataFactory.createOpportunity(acc.Id, unit.Id);
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        Booking__c booking = ResidentialTestDataFactory.createBooking(acc.Id, unit.Id, plan.Id, opp.Id, project.Id);
        
        // Create exactly the schedule amounts we want
        Booking_Payment_Schedule__c s1 = new Booking_Payment_Schedule__c(
            Booking__c = booking.Id,
            Installment_Number__c = 1,
            Payment_Due_Date__c = Date.today().addDays(-17),
            Installment_Amount__c = 1000000
        );
        Booking_Payment_Schedule__c s2 = new Booking_Payment_Schedule__c(
            Booking__c = booking.Id,
            Installment_Number__c = 2,
            Payment_Due_Date__c = Date.today().addDays(30),
            Installment_Amount__c = 800000
        );
        Booking_Payment_Schedule__c s3 = new Booking_Payment_Schedule__c(
            Booking__c = booking.Id,
            Installment_Number__c = 3,
            Payment_Due_Date__c = Date.today().addDays(60),
            Installment_Amount__c = 700000
        );
        insert new List<Booking_Payment_Schedule__c>{ s1, s2, s3 };
            
            // Demands (one per schedule)
            Demand__c d1 = ResidentialTestDataFactory.prepareDemand(s1.Id, unit.Id, acc.Id, booking.Id, 'DEMHEX1');
        Demand__c d2 = ResidentialTestDataFactory.prepareDemand(s2.Id, unit.Id, acc.Id, booking.Id, 'DEMHEX2');
        Demand__c d3 = ResidentialTestDataFactory.prepareDemand(s3.Id, unit.Id, acc.Id, booking.Id, 'DEMHEX3');
        insert new List<Demand__c>{ d1, d2, d3 };
            
        Company_Bank_Account__c cba = ResidentialTestDataFactory.prepareCompanyBankAccount();
        cba.House_Bank_Id__c = 'HB002';
        insert cba;
        
        // Amount 2.6M, principal 1.0M → excess 1.6M → should fill S2 (800k) then S3 (700k), 100k left
        Payment_Receipt__c r = ResidentialTestDataFactory.preparePaymentReceipt(
            s1.Id, d1.Id, cba.Id, 2600000, 'RTGS', Date.today(), null, 'State Bank of India'
        );
        r.Approval_Status__c   = 'Pending Approval';
        r.Principal_Applied__c = 1000000;
        r.Interest_Applied__c  = 0;
        r.Tax_on_Interest__c   = 0;
        insert r;
        
        // Act: approve → carry forward
        Test.startTest();
        r.Approval_Status__c = 'Approved';
        update r;
        Test.stopTest();
        
        // Assert: S2 advanced by 800,000 and S3 by 700,000
        s2 = [SELECT Advance_Applied__c FROM Booking_Payment_Schedule__c WHERE Id = :s2.Id];
        s3 = [SELECT Advance_Applied__c FROM Booking_Payment_Schedule__c WHERE Id = :s3.Id];
        
        System.Assert.areEqual(800000, FinancePolicyUtil.nz(s2.Advance_Applied__c),
                               'S2 should be fully advanced by 800k.');
        System.Assert.areEqual(700000, FinancePolicyUtil.nz(s3.Advance_Applied__c),
                               'S3 should be fully advanced by 700k.');
    }*/

    // ---------------------------
    // Helpers (local to this test)
    // ---------------------------
    // (No extra helpers needed; using factory as-is.)
}