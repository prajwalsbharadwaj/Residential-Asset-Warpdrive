@isTest
private class PaymentReceiptPDFExtTest {

    @testSetup
    static void setupData() {
        Account account = ResidentialTestDataFactory.createAccount();
        account.PersonMailingStreet = '123 Residency Road';
        account.PersonMailingCity = 'Bengaluru';
        account.PersonMailingState = 'Karnataka';
        account.PersonMailingPostalCode = '560001';
        account.PersonMailingCountry = 'India';
        account.Phone = '9988776655';
        update account;

        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);

        Opportunity opportunity = ResidentialTestDataFactory.createOpportunity(account.Id, unit.Id);
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);

        Booking__c booking = ResidentialTestDataFactory.createBooking(account.Id, unit.Id, plan.Id, opportunity.Id, project.Id);
        booking.SAP_External_Id__c = 'BOOK-001';
        update booking;

        List<Booking_Payment_Schedule__c> schedulesToInsert = ResidentialTestDataFactory.prepareBookingPaymentSchedules(booking.Id, schedules);
        insert schedulesToInsert;

        Demand__c demand = ResidentialTestDataFactory.prepareDemand(schedulesToInsert[0].Id, unit.Id, account.Id, booking.Id, 'DEM-001');
        insert demand;

        Company_Bank_Account__c companyBank = ResidentialTestDataFactory.createCompanyBankAccount();

        Payment_Receipt__c receiptWithAmount = ResidentialTestDataFactory.preparePaymentReceipt(
            schedulesToInsert[0].Id,
            demand.Id,
            companyBank.Id,
            10250.75,
            'RTGS',
            Date.today(),
            987654,
            'State Bank of India'
        );
        receiptWithAmount.SAP_External_Id__c = 'PR-001';
        insert receiptWithAmount;

    }

    /**
     * @description Verifies the extension loads the receipt and computes amount words.
     * GIVEN: A payment receipt with amount and related booking data exists.
     * WHEN: The PaymentReceiptPDFExt controller is constructed.
     * THEN: The header and amount in words are populated correctly.
     */
    @isTest
    static void givenPaymentReceiptWhenExtensionConstructedThenHeaderAndAmountWordsSet() {
        // Arrange: Re-query the prepared payment receipt with populated amount
        Payment_Receipt__c queriedReceipt = [
            SELECT Id, SAP_External_Id__c
            FROM Payment_Receipt__c
            WHERE SAP_External_Id__c = 'PR-001'
            LIMIT 1
        ];

        ApexPages.StandardController stdController = new ApexPages.StandardController(queriedReceipt);

        // Act: Construct the extension and compute amount words
        PaymentReceiptPDFExt extension = new PaymentReceiptPDFExt(stdController);
        String amountWords = extension.getAmountInWords();
        String headerValue = ApexPages.currentPage().getHeaders().get('content-disposition');

        // Assert: Verify amount words and response header
        System.assert.areEqual(
            'Ten Thousand Two Hundred Fifty Rupees and Seventy Five Paise Only',
            amountWords,
            'Amount in words should match the expected Indian currency format'
        );
        System.assert.isTrue(
            headerValue.contains('Payment Receipt - PR-001.pdf'),
            'Header should include the receipt file name'
        );
    }


}