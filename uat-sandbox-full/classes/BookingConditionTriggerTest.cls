@IsTest
private class BookingConditionTriggerTest {

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('[]');
            return res;
        }
    }

    @testSetup
    static void setupData() {
        Account account = ResidentialTestDataFactory.createAccount();
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);
        Unit__c unit = ResidentialTestDataFactory.createUnit(project.Id, tower.Id, floor.Id);
        Opportunity opportunity = ResidentialTestDataFactory.createOpportunity(account.Id, unit.Id);
        Payment_Plan__c plan = ResidentialTestDataFactory.createPaymentPlan();

        Booking__c booking = ResidentialTestDataFactory.createBooking(
            account.Id,
            unit.Id,
            plan.Id,
            opportunity.Id,
            project.Id
        );
        booking.Order_Qty__c = 1;
        update booking;
    }

    private static Booking__c getBookingWithOpportunity() {
        return [
            SELECT Id, Opportunity_Id__c
            FROM Booking__c
            LIMIT 1
        ];
    }

    private static Booking_Condition__c prepareCondition(
        String conditionType,
        Decimal amount,
        Decimal quantity,
        Decimal percentage,
        String typeValue
    ) {
        Booking__c booking = getBookingWithOpportunity();
        return ResidentialTestDataFactory.prepareBookingCondition(
            booking.Id,
            booking.Opportunity_Id__c,
            conditionType,
            amount,
            quantity,
            percentage,
            typeValue
        );
    }

    private static Booking_Condition__c createCondition(
        String conditionType,
        Decimal amount,
        Decimal quantity,
        Decimal percentage,
        String typeValue
    ) {
        Booking__c booking = getBookingWithOpportunity();
        return ResidentialTestDataFactory.createBookingCondition(
            booking.Id,
            booking.Opportunity_Id__c,
            conditionType,
            amount,
            quantity,
            percentage,
            typeValue
        );
    }

    @IsTest
    static void beforeInsertPopulatesCalculatedFields() {
        Booking_Condition__c baseRow = prepareCondition('Base Price', 5000, 1, null, 'Fixed Amount');
        Booking_Condition__c otherRow = prepareCondition('Club House Membershi', 250, null, null, 'Fixed Amount');

        Test.startTest();
        insert new List<Booking_Condition__c>{ baseRow, otherRow };
        Test.stopTest();

        Map<String, Booking_Condition__c> inserted = new Map<String, Booking_Condition__c>();
        for (Booking_Condition__c row : [
            SELECT Id, Condition_Type__c, Amount_By_Type__c, Item_Number__c, Type__c
            FROM Booking_Condition__c
            WHERE Id IN :new List<Id>{ baseRow.Id, otherRow.Id }
        ]) {
            inserted.put(row.Condition_Type__c, row);
        }

        System.assertEquals(5000, inserted.get('Base Price').Amount_By_Type__c);
        System.assertEquals(1, inserted.get('Base Price').Item_Number__c);
        System.assertNotEquals(null, inserted.get('Club House Membershi').Item_Number__c);
        System.assertEquals('Fixed Amount', inserted.get('Club House Membershi').Type__c);
    }

    @IsTest
    static void afterInsertRecalculatesSiblingRows() {
        Booking_Condition__c discount = createCondition('Base Price Discount', null, null, 10, 'Percentage');
        Decimal before = [
            SELECT Amount_By_Type__c FROM Booking_Condition__c WHERE Id = :discount.Id
        ].Amount_By_Type__c;

        Booking_Condition__c baseRow = prepareCondition('Base Price', 6000, 1, null, 'Fixed Amount');
        insert baseRow;

        Decimal after = [
            SELECT Amount_By_Type__c FROM Booking_Condition__c WHERE Id = :discount.Id
        ].Amount_By_Type__c;

        System.assertNotEquals(before, after);
        System.assert(after > 0, 'Discount row should reflect recalculated base value.');
    }

    @IsTest
    static void beforeUpdateRecalculatesAmounts() {
        Booking_Condition__c baseRow = prepareCondition('Base Price', 1200, 2, null, 'Fixed Amount');
        Booking_Condition__c rateRow = prepareCondition('BESCOM & BWSSB', 200, null, null, 'Rate');
        insert new List<Booking_Condition__c>{ baseRow, rateRow };

        Decimal original = [
            SELECT Amount_By_Type__c FROM Booking_Condition__c WHERE Id = :rateRow.Id
        ].Amount_By_Type__c;

        rateRow.Amount__c = (rateRow.Amount__c == null ? 0 : rateRow.Amount__c) + 50;

        Test.startTest();
        update rateRow;
        Test.stopTest();

        Decimal recalculated = [
            SELECT Amount_By_Type__c FROM Booking_Condition__c WHERE Id = :rateRow.Id
        ].Amount_By_Type__c;

        System.assertNotEquals(original, recalculated);
    }

    @IsTest
    static void afterUpdateFlagsBookingForSync() {
        Booking_Condition__c baseRow = prepareCondition('Base Price', 8000, 1, null, 'Fixed Amount');
        Booking_Condition__c rateRow = prepareCondition('BESCOM & BWSSB', 150, null, null, 'Rate');
        insert new List<Booking_Condition__c>{ baseRow, rateRow };

        Booking__c booking = getBookingWithOpportunity();
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        rateRow.Amount__c = (rateRow.Amount__c == null ? 0 : rateRow.Amount__c) + 25;

        Test.startTest();
        update rateRow;
        Test.stopTest();

        Booking__c refreshed = [
            SELECT SAP_Sync_Status__c
            FROM Booking__c
            WHERE Id = :booking.Id
        ];
        System.assertEquals('Pending update', refreshed.SAP_Sync_Status__c);
    }

    @IsTest
    static void afterDeleteRecalculatesDependentRows() {
        Booking_Condition__c baseRow = prepareCondition('Base Price', 6000, 1, null, 'Fixed Amount');
        Booking_Condition__c discountRow = prepareCondition('Base Price Discount', 500, null, null, 'Fixed Amount');
        Booking_Condition__c landRow = prepareCondition('1/3 Agreement Value', null, null, null, null);
        insert new List<Booking_Condition__c>{ baseRow, discountRow, landRow };

        Decimal beforeDelete = [
            SELECT Amount_By_Type__c FROM Booking_Condition__c WHERE Id = :landRow.Id
        ].Amount_By_Type__c;

        delete discountRow;

        Booking_Condition__c recalculated = [
            SELECT Id, Opportunity__c, Amount__c, Percentage__c, Quantity__c,
                   Type__c, Condition_Type__c, Amount_By_Type__c
            FROM Booking_Condition__c
            WHERE Id = :landRow.Id
        ];

        Decimal actualAfterDelete = recalculated.Amount_By_Type__c;
        BookingConditionHelper helper = new BookingConditionHelper();
        helper.calculateLineAmounts(new List<Booking_Condition__c>{ recalculated });
        Decimal expectedAfterDelete = recalculated.Amount_By_Type__c;

        System.assertEquals(expectedAfterDelete, actualAfterDelete,
            'After delete, Amount_By_Type__c should match helper recalculation.');
        System.assert(actualAfterDelete > beforeDelete,
            'Land cost should increase once the discount row is removed.');
    }

    @IsTest
    static void afterUndeleteRestoresDependentRows() {
        Booking_Condition__c baseRow = prepareCondition('Base Price', 6000, 1, null, 'Fixed Amount');
        Booking_Condition__c discountRow = prepareCondition('Base Price Discount', 500, null, null, 'Fixed Amount');
        Booking_Condition__c landRow = prepareCondition('1/3 Agreement Value', null, null, null, null);
        insert new List<Booking_Condition__c>{ baseRow, discountRow, landRow };

        Decimal original = [
            SELECT Amount_By_Type__c FROM Booking_Condition__c WHERE Id = :landRow.Id
        ].Amount_By_Type__c;

        delete discountRow;

        Test.startTest();
        undelete new List<Booking_Condition__c>{ new Booking_Condition__c(Id = discountRow.Id) };
        Test.stopTest();

        Booking_Condition__c recalculated = [
            SELECT Id, Opportunity__c, Amount__c, Percentage__c, Quantity__c,
                   Type__c, Condition_Type__c, Amount_By_Type__c
            FROM Booking_Condition__c
            WHERE Id = :landRow.Id
        ];

        Decimal actualAfterUndelete = recalculated.Amount_By_Type__c;
        BookingConditionHelper helper = new BookingConditionHelper();
        helper.calculateLineAmounts(new List<Booking_Condition__c>{ recalculated });
        Decimal expectedAfterUndelete = recalculated.Amount_By_Type__c;

        System.assertEquals(expectedAfterUndelete, actualAfterUndelete,
            'After undelete, Amount_By_Type__c should match helper recalculation.');
        System.assertEquals(original, actualAfterUndelete,
            'Land cost should revert to the discounted amount when discount row returns.');
    }
}