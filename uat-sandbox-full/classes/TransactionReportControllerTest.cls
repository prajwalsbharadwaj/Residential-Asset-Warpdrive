@isTest
private class TransactionReportControllerTest {

    @testSetup
    static void setupData() {
        Account primaryAccount = ResidentialTestDataFactory.createAccount();
        primaryAccount.PersonEmail = 'primary@example.com';
        primaryAccount.PersonBirthdate = Date.newInstance(1990, 5, 20);
        primaryAccount.PersonMailingStreet = '221 Baker Street';
        primaryAccount.PersonMailingCity = 'Mumbai';
        primaryAccount.PersonMailingState = 'Maharashtra';
        primaryAccount.PersonMailingPostalCode = '400001';
        primaryAccount.PersonMailingCountry = 'India';
        primaryAccount.Phone = '+91-9988776655';
        primaryAccount.PAN_Number__c = 'ABCDE1234F';
        update primaryAccount;

        Account coApplicantOne = ResidentialTestDataFactory.createAccount();
        coApplicantOne.PersonEmail = 'coapp1@example.com';
        update coApplicantOne;

        Account coApplicantTwo = ResidentialTestDataFactory.createAccount();
        coApplicantTwo.PersonEmail = 'coapp2@example.com';
        update coApplicantTwo;

        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
        unit.BHK_Configuration__c = '3 BHK';
        unit.Built_Up_Area_SBA__c = 1450;
        unit.Terrace_Area__c = 120;
        unit.SAP_External_Id__c ='UNIT-01';
        unit.Status__c = 'Available';
        update unit;

        Opportunity opportunity = ResidentialTestDataFactory.createOpportunity(primaryAccount.Id, unit.Id);

        Booking_Condition__c basePrice= new Booking_Condition__c(
            Opportunity__c = opportunity.Id,
            Condition_Type__c = 'Base Price',
            Amount__c = 10000
        );

        Booking_Condition__c basePriceDiscount = new Booking_Condition__c(
            Opportunity__c = opportunity.Id,
            Condition_Type__c = 'Base Price Discount',
            Percentage__c = 5
        );
        insert new List<Booking_Condition__c>{ basePrice, basePriceDiscount };

        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);

        Booking__c booking = ResidentialTestDataFactory.createBooking(primaryAccount.Id, unit.Id, plan.Id, opportunity.Id, project.Id);
        booking.Booking_Date__c = Date.today();
        booking.Remarks__c = 'Customer prefers corner unit';
        booking.Co_Applicant_1__c = coApplicantOne.Id;
        booking.Co_Applicant_2__c = coApplicantTwo.Id;
        update booking;

        List<Booking_Payment_Schedule__c> bookingSchedules = ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, schedules);

        List<Booking_Condition__c> conditions = ResidentialTestDataFactory.createBookingCondition(booking.Id, opportunity.Id);
        for (Booking_Condition__c condition : conditions) {
            if (condition.Condition_Type__c == 'Base Price') {
                condition.Amount__c = 5200;
                condition.Quantity__c = 2;
            }
            if (condition.Condition_Type__c == 'Club House Membershi') {
                condition.Amount__c = 75000;
            }
        }
        update conditions;

        Booking_Condition__c gstOnConstruction = new Booking_Condition__c(
            Booking__c = booking.Id,
            Opportunity__c = opportunity.Id,
            Condition_Type__c = 'IN: 2/3 CGST Tax',
            Percentage__c = 9
        );
        insert new List<Booking_Condition__c>{ gstOnConstruction };

        Account brokerAccount = ResidentialTestDataFactory.createAccount();
        brokerAccount.Phone = '080-12345678';
        brokerAccount.CP_Approval_Status__c = 'Approved';
        brokerAccount.Vendor_Name__c = 'Reliable Realty';
        brokerAccount.RecordTypeId = ResidentialTestDataFactory.RT_ID_ACCOUNT_CHANNEL_PARTNER_RESIDENTIAL;
        update brokerAccount;

        List<Agent_Brokerage__c> brokerages = ResidentialTestDataFactory.createAgentBrokerage(booking.Id);
        for (Agent_Brokerage__c brokerage : brokerages) {
            brokerage.Account__c = brokerAccount.Id;
        }
        insert brokerages;
    }

    /**
     * @description Validates wrapper data when a booking id is provided.
     * GIVEN: A booking with related opportunity, co-applicants, and brokerage exists.
     * WHEN: The TransactionReportController is instantiated with the booking id.
     * THEN: The wrapper is populated with booking, financial, and brokerage details.
     */
    @isTest
    static void givenBookingIdWhenControllerInitialisesThenWrapperPopulated() {
        // Arrange: Re-query key records to use in assertions
        Booking__c booking = [
            SELECT Id, Project__r.Name, Account_Id__r.Name, Payment_Plan_Id__r.Name
            FROM Booking__c
            LIMIT 1
        ];

        ApexPages.currentPage().getParameters().put('bookingId', booking.Id);

        // Act: Instantiate the controller to build the report wrapper
        TransactionReportController controller = new TransactionReportController();

        // Assert: Confirm wrapper is populated with key information
        System.assert.areEqual(
            booking.Project__r.Name,
            controller.wrapper.project,
            'Project name should match the booking project'
        );
        System.assert.areEqual(
            booking.Account_Id__r.Name,
            controller.wrapper.customerName,
            'Customer name should match the primary account'
        );
        System.assert.isTrue(
            controller.wrapper.coApplicants.size() >= 2,
            'At least two co-applicants should be listed'
        );
        System.assert.isTrue(
            controller.wrapper.saleConsideration.size() > 0,
            'Sale consideration rows should be generated'
        );
        System.assert.isTrue(
            controller.wrapper.isBrokerage,
            'Brokerage information should be marked as available'
        );
        System.assert.areEqual(
            booking.Payment_Plan_Id__r.Name,
            controller.wrapper.paymentPlan,
            'Payment plan should match the booking payment plan'
        );
        System.assert.isTrue(
            controller.wrapper.totalBrokerage > 0,
            'Total brokerage should capture the inserted brokerage amount'
        );

        ApexPages.currentPage().getParameters().clear();
    }

}