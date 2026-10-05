@isTest
private class StatementDataTest {
    
    @isTest
    static void testStatementDataConstructionAndUsage() {
        Test.startTest();

        // Create main object using default constructor
        StatementData statement = new StatementData();
        
        // ✅ Verify defaults are initialized
        System.assertNotEquals(null, statement.content, 'content map should be initialized');
        System.assertNotEquals(null, statement.schedules, 'schedules list should be initialized');
        System.assertNotEquals(null, statement.receipts, 'receipts list should be initialized');
        System.assertNotEquals(null, statement.summary, 'summary object should be initialized');
        
        // ✅ Test adding values to content map
        statement.content.put('Key1', 'Value1');
        System.assertEquals('Value1', statement.content.get('Key1'));

        // ✅ Test PaymentScheduleEntry
        StatementData.PaymentScheduleEntry scheduleEntry = 
            new StatementData.PaymentScheduleEntry(
                'Milestone 1', 
                '2025-08-05', 
                10000, 
                2000
            );
        scheduleEntry.interest = 250; // test manual setting
        statement.schedules.add(scheduleEntry);
        System.assertEquals(1, statement.schedules.size(), 'One schedule should be added');
        System.assertEquals('Milestone 1', statement.schedules[0].milestone);

        // ✅ Test ReceiptEntry
        StatementData.ReceiptEntry receiptEntry =
            new StatementData.ReceiptEntry(
                'R-001', 
                '2025-08-01', 
                'Cheque', 
                'Test Bank', 
                '2025-07-30', 
                'CHK123', 
                15000
            );
        statement.receipts.add(receiptEntry);
        System.assertEquals(1, statement.receipts.size(), 'One receipt should be added');
        System.assertEquals('Cheque', statement.receipts[0].paymentMode);

        // ✅ Test SummaryInfo values
        statement.summary.totalAmountReceived = 15000;
        statement.summary.balancePayable = 5000;
        statement.summary.totalIncludingExcess = 20000;
        statement.summary.balanceIncludingInterest = 5500;
        statement.summary.totalApartmentCost = 25000;
        
        System.assertEquals(15000, statement.summary.totalAmountReceived);
        System.assertEquals(5000, statement.summary.balancePayable);
        System.assertEquals(25000, statement.summary.totalApartmentCost);

        Test.stopTest();
    }

    @isTest
    static void testMultipleEntriesAndEdgeCases() {
        StatementData statement = new StatementData();

        // Add multiple PaymentScheduleEntries
        for (Integer i = 1; i <= 3; i++) {
            StatementData.PaymentScheduleEntry entry = 
                new StatementData.PaymentScheduleEntry(
                    'Milestone ' + i,
                    '2025-08-0' + i,
                    1000 * i,
                    100 * i
                );
            statement.schedules.add(entry);
        }
        System.assertEquals(3, statement.schedules.size());

        // Add multiple ReceiptEntries
        for (Integer i = 1; i <= 2; i++) {
            StatementData.ReceiptEntry entry =
                new StatementData.ReceiptEntry(
                    'R-00' + i,
                    '2025-07-0' + i,
                    'Online',
                    'Bank ' + i,
                    '2025-07-0' + i,
                    'NUM' + i,
                    500 * i
                );
            statement.receipts.add(entry);
        }
        System.assertEquals(2, statement.receipts.size());
    }
}