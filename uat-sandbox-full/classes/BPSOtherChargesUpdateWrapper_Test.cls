@IsTest
private class BPSOtherChargesUpdateWrapper_Test {

    @IsTest
    static void testWrapperStructure() {
        // 1. Setup Inner Class: BillWrapper
        BookingPaySchedOtherChargesUpdateWrapper.BillWrapper bill = new BookingPaySchedOtherChargesUpdateWrapper.BillWrapper();
        bill.ITEM_NO = '000003';
        bill.MILESTONE_CODE = 'Z0010';
        bill.MILESTONE_DES = 'PS-0003';
        bill.BILLING_DATE = '2026-01-12';
        bill.INV_PER = '80.00';
        bill.BILL_VAL = '44716000.00';
        bill.BILL_RULE = '2';
        bill.BILL_BLOCK = '';

        // 2. Setup Inner Class: ItemWrapper
        BookingPaySchedOtherChargesUpdateWrapper.ItemWrapper item = new BookingPaySchedOtherChargesUpdateWrapper.ItemWrapper();
        item.itm_number = '10';
        item.plant = '2063';
        item.material = 'R001-6281';
        item.division = '10';
        item.reason_rej = '';
        item.cond = '';
        item.bill = new List<BookingPaySchedOtherChargesUpdateWrapper.BillWrapper>{ bill };

        // 3. Setup Inner Class: OtherItemWrapper
        BookingPaySchedOtherChargesUpdateWrapper.OtherItemWrapper other = new BookingPaySchedOtherChargesUpdateWrapper.OtherItemWrapper();
        other.itm_number = '20';
        other.plant = '2063';
        other.material = 'BESCOMANDBWSSB';
        other.bill_block = '';
        other.billing_date = '2026-01-12';

        // 4. Setup Main Wrapper Class
        BookingPaySchedOtherChargesUpdateWrapper mainWrapper = new BookingPaySchedOtherChargesUpdateWrapper();
        
        // Assigning a fake Id to the transient field
        Id fakeId = Id.valueOf('a01000000000001');
        mainWrapper.BOOKING_ID = fakeId;
        
        mainWrapper.booking = '2010000076';
        mainWrapper.sales_grp = 'GRP1';
        mainWrapper.sales_off = 'OFF1';
        mainWrapper.sales_dist = 'DIST1';
        mainWrapper.purch_no_c = 'P123';
        mainWrapper.purch_date = '2026-01-01';
        mainWrapper.price_grp = 'PG1';
        mainWrapper.incoterms1 = 'INC1';
        mainWrapper.incoterms2 = 'INC2';
        mainWrapper.co_applicant1 = 'APP1';
        mainWrapper.co_applicant2 = 'APP2';
        mainWrapper.co_applicant3 = 'APP3';
        mainWrapper.co_applicant4 = 'APP4';
        mainWrapper.co_applicant5 = 'APP5';
        
        // Assign lists
        mainWrapper.item = new List<BookingPaySchedOtherChargesUpdateWrapper.ItemWrapper>{ item };
        mainWrapper.otheritem = new List<BookingPaySchedOtherChargesUpdateWrapper.OtherItemWrapper>{ other };

        // 5. Execution & Verification
        Test.startTest();
        String jsonString = JSON.serialize(mainWrapper);
        BookingPaySchedOtherChargesUpdateWrapper deserialized = (BookingPaySchedOtherChargesUpdateWrapper)JSON.deserialize(jsonString, BookingPaySchedOtherChargesUpdateWrapper.class);
        Test.stopTest();

        // 6. Assertions
        System.assertNotEquals(null, jsonString, 'Serialization should produce a string');
        System.assertEquals('2010000076', deserialized.booking, 'Data should persist through serialization');
        System.assertEquals('20', deserialized.otheritem[0].itm_number, 'Nested data should persist');
        
        // Verify transient field behavior (transient fields are not serialized)
        System.assertEquals(fakeId, mainWrapper.BOOKING_ID);
        System.assert(!jsonString.contains(String.valueOf(fakeId)), 'Transient field should not be in JSON');
    }
}