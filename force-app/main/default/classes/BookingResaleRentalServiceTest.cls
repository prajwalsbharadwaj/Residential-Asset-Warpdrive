@isTest
private class BookingResaleRentalServiceTest {

    @isTest
    static void testResaleAndRentalInitiationFromBooking() {
        Handover__c ho = HandoverTestDataFactory.createHandoverTestData();
        Booking__c b = [SELECT Id, Account_Id__c, Unit_Id__c, Project__c FROM Booking__c WHERE Id = :ho.Booking__c LIMIT 1];

        Test.startTest();

        // 1. Test Resale Opportunity Creation
        BookingResaleRentalService.ResaleInitiationResult resaleRes = BookingResaleRentalService.createResaleOpportunityFromBooking(
            b.Id, 15000000, 'Customer requesting resale disposition at market price.'
        );
        System.assertNotEquals(null, resaleRes.opportunityId);
        System.assertEquals('Success', resaleRes.status);

        Opportunity oppResale = [
            SELECT Id, Name, Booking__c, AccountId, interested_unit__c, Amount, StageName, Description,
                   Expected_Resale_Price__c, Resale_Approval_Status__c, Buyer_KYC_Status__c
            FROM Opportunity
            WHERE Id = :resaleRes.opportunityId
        ];
        System.assertEquals(b.Id, oppResale.Booking__c);
        System.assertEquals(b.Account_Id__c, oppResale.AccountId);
        System.assertEquals(b.Unit_Id__c, oppResale.interested_unit__c);
        System.assertEquals(15000000, oppResale.Amount);
        System.assertEquals(15000000, oppResale.Expected_Resale_Price__c);
        System.assertEquals('Resale Initiation', oppResale.StageName);
        System.assertEquals('Not Submitted', oppResale.Resale_Approval_Status__c);
        System.assertEquals('Pending', oppResale.Buyer_KYC_Status__c);

        // 2. Test Rental Opportunity Creation
        BookingResaleRentalService.ResaleInitiationResult rentalRes = BookingResaleRentalService.createRentalOpportunityFromBooking(
            b.Id, 65000, Date.today().addDays(30), 'Customer requesting leasing assistance with corporate tenants.'
        );
        System.assertNotEquals(null, rentalRes.opportunityId);
        System.assertEquals('Success', rentalRes.status);

        Opportunity oppRental = [
            SELECT Id, Name, Booking__c, AccountId, interested_unit__c, Amount, StageName, Description,
                   Expected_Rent__c, Rental_Approval_Status__c, Tenant_KYC_Status__c
            FROM Opportunity
            WHERE Id = :rentalRes.opportunityId
        ];
        System.assertEquals(b.Id, oppRental.Booking__c);
        System.assertEquals(b.Account_Id__c, oppRental.AccountId);
        System.assertEquals(b.Unit_Id__c, oppRental.interested_unit__c);
        System.assertEquals(65000 * 12, oppRental.Amount);
        System.assertEquals(65000, oppRental.Expected_Rent__c);
        System.assertEquals('Rental Initiation', oppRental.StageName);
        System.assertEquals('Not Submitted', oppRental.Rental_Approval_Status__c);
        System.assertEquals('Pending', oppRental.Tenant_KYC_Status__c);

        // 3. Test Negative / Validation Paths
        Boolean nullBookingCaught = false;
        try {
            BookingResaleRentalService.createResaleOpportunityFromBooking(null, 1000, 'Test');
        } catch (Exception ex) {
            nullBookingCaught = true;
        }
        System.assertEquals(true, nullBookingCaught);

        Boolean nullRentalBookingCaught = false;
        try {
            BookingResaleRentalService.createRentalOpportunityFromBooking(null, 1000, Date.today(), 'Test');
        } catch (Exception ex) {
            nullRentalBookingCaught = true;
        }
        System.assertEquals(true, nullRentalBookingCaught);

        Test.stopTest();
    }
}