@isTest
private class LedgerStatementTest {

    @isTest
    static void testLedgerStatement_DefaultConstructor() {
        // Act
        LedgerStatement ls = new LedgerStatement();

        // Assert default values
        System.Assert.isTrue(ls.content != null, 'Content map should be initialized');
        System.Assert.areEqual(0, ls.content.size(), 'Content map should start empty');

        System.Assert.isTrue(ls.entry != null, 'Entry list should be initialized');
        System.Assert.areEqual(0, ls.entry.size(), 'Entry list should start empty');

        System.assertEquals(0, ls.totalInterest, 'Default totalInterest should be zero');
        System.assertEquals(0, ls.totalDebits, 'Default totalDebits should be zero');
        System.assertEquals(0, ls.totalCredits, 'Default totalCredits should be zero');
        System.assertEquals(0, ls.totalBalance, 'Default totalBalance should be zero');
        System.assertEquals(ls.closingDate, ls.closingDate, 'Closing date should remain null by default');
    }

    @isTest
    static void testLedgerStatement_WithEntriesAndValues() {
        // Arrange
        LedgerStatement ls = new LedgerStatement();
        ls.content.put('Key1', 'Value1');
        ls.totalInterest = 100.50;
        ls.totalDebits = 200.75;
        ls.totalCredits = 150.25;
        ls.totalBalance = 50.50;
        ls.closingDate = Date.today();

        // Create entries
        LedgerStatement.Entry entry1 = new LedgerStatement.Entry(
            1,
            Date.today().addDays(-5),
            Date.today().addDays(5),
            'Demand: First',
            500.00,
            0,
            500.00
        );

        LedgerStatement.Entry entry2 = new LedgerStatement.Entry(
            2,
            Date.today(),
            null,
            'Payment: First',
            0,
            200.00,
            300.00
        );

        // Act
        ls.entry.add(entry1);
        ls.entry.add(entry2);

        // Assert
        System.assertEquals(1, entry1.sortOrder);
        System.assertEquals('Demand: First', entry1.particulars);
        System.assertEquals(500.00, entry1.debit);
        System.assertEquals(0, entry1.credit);
        System.assertEquals(500.00, entry1.balance);

        System.assertEquals(2, entry2.sortOrder);
        System.assertEquals('Payment: First', entry2.particulars);
        System.assertEquals(0, entry2.debit);
        System.assertEquals(200.00, entry2.credit);
        System.assertEquals(300.00, entry2.balance);

        System.assertEquals(2, ls.entry.size(), 'Should have 2 entries added');
        System.assertEquals('Value1', ls.content.get('Key1'));
        System.assertEquals(100.50, ls.totalInterest);
        System.assertEquals(200.75, ls.totalDebits);
        System.assertEquals(150.25, ls.totalCredits);
        System.assertEquals(50.50, ls.totalBalance);
        System.assertEquals(Date.today(), ls.closingDate);
    }

    @isTest
    static void testLedgerStatement_BoundaryValues() {
        // Arrange: Test with zero and negative values
        LedgerStatement.Entry entry = new LedgerStatement.Entry(
            3,
            Date.today(),
            Date.today().addDays(1),
            'Boundary Test',
            -100.00,
            -50.00,
            0
        );

        // Assert
        System.assertEquals(-100.00, entry.debit, 'Debit should allow negative value');
        System.assertEquals(-50.00, entry.credit, 'Credit should allow negative value');
        System.assertEquals(0, entry.balance, 'Balance can be zero');
    }
}