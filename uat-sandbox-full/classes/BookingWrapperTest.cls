@isTest
private class BookingWrapperTest {

    /**
     * @description Verifies the compareTo logic prioritises ZPR0 condition codes.
     * GIVEN: Two item wrappers with different COND1 values.
     * WHEN: compareTo is invoked.
     * THEN: Items with COND1 = 'ZPR0' sort ahead of others.
     */
    @isTest
    static void givenZpr0ConditionWhenComparedThenReturnsHigherPriority() {
        BookingWrapper.ItemWrapper zprItem = new BookingWrapper.ItemWrapper();
        zprItem.COND1 = 'ZPR0';

        BookingWrapper.ItemWrapper otherItem = new BookingWrapper.ItemWrapper();
        otherItem.COND1 = 'ZDIS';

        System.assertEquals(-1, zprItem.compareTo(otherItem), 'ZPR0 item should be ordered before other conditions.');
        System.assertEquals(1, otherItem.compareTo(zprItem), 'Non-ZPR0 item should be ordered after ZPR0.');
        System.assertEquals(0, zprItem.compareTo(zprItem), 'Comparing identical items should result in equality.');
    }

    /**
     * @description Ensures BookingWrapper integrates with BookingSapPayloadBuilder.
     * GIVEN: A fully populated booking.
     * WHEN: prepareJSONBodyForBooking is invoked.
     * THEN: At least one BookingWrapper is returned with bill entries populated.
     */
    @isTest
    static void givenBookingWhenPayloadPreparedThenBookingWrapperReturned() {
        Account account = ResidentialTestDataFactory.createAccount();
        account.PersonMailingState = 'Karnataka';
        account.PersonMailingCountry = 'India';
        update account;

        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id);

        Opportunity opportunity = ResidentialTestDataFactory.createOpportunity(account.Id, unit.Id);
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();
        List<Payment_Schedule__c> schedules = ResidentialTestDataFactory.createPaymentSchedules(plan.Id);
        Booking__c booking = ResidentialTestDataFactory.createBooking(account.Id, unit.Id, plan.Id, opportunity.Id, project.Id);

        ResidentialTestDataFactory.createBookingCondition(booking.Id, opportunity.Id);
        ResidentialTestDataFactory.createBookingPaymentSchedules(booking.Id, schedules);

        BookingSapPayloadBuilder builder = new BookingSapPayloadBuilder();
        List<BookingWrapper> wrappers = builder.prepareJSONBodyForBooking(new Set<Id>{ booking.Id });

        System.assertEquals(1, wrappers.size(), 'Expected one wrapper per booking.');
        System.assertNotEquals(null, wrappers[0].ITEM, 'Item list should be initialised.');
        System.assert(wrappers[0].ITEM.isEmpty() == false, 'At least one item should be generated for the booking.');
        System.assertNotEquals(null, wrappers[0].ITEM[0].BILL, 'Billing schedule should populate the bill collection.');
    }
}