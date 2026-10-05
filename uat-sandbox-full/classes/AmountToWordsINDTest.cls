@IsTest
private class AmountToWordsINDTest {

    // Helper to format assertion messages
    private static String nf(Decimal d) {
        return d == null ? 'null' : String.valueOf(d.setScale(2));
    }

    @IsTest
    static void GIVEN_nullAmount_WHEN_convertToIndianCurrency_THEN_returnsEmptyString() {
        Test.startTest();
        String result = AmountToWordsIND.convertToIndianCurrency(null);
        Test.stopTest();

        System.assertEquals('', result, 'Null amount should return empty string');
    }

    @IsTest
    static void GIVEN_zeroAmount_WHEN_convertToIndianCurrency_THEN_returnsZeroRupees() {
        Test.startTest();
        String result = AmountToWordsIND.convertToIndianCurrency(0);
        Test.stopTest();

        System.assertEquals('Zero Rupees', result, 'Zero amount should return "Zero Rupees"');
    }

    @IsTest
    static void GIVEN_smallWholeNumber_WHEN_convertToIndianCurrency_THEN_returnsWords() {
        Test.startTest();
        String result = AmountToWordsIND.convertToIndianCurrency(15);
        Test.stopTest();

        System.assert(result.contains('Fifteen'), 'Expected "Fifteen", got: ' + result);
    }

    @IsTest
    static void GIVEN_numberWithPaise_WHEN_convertToIndianCurrency_THEN_includesPaiseInWords() {
        Test.startTest();
        String result = AmountToWordsIND.convertToIndianCurrency(123.45);
        Test.stopTest();

        System.assert(result.contains('Rupees'), 'Should mention Rupees');
        System.assert(result.contains('Paise'), 'Should mention Paise for decimals');
    }

    @IsTest
    static void GIVEN_threeDigitNumber_WHEN_convertToIndianCurrency_THEN_includesHundredInWords() {
        Test.startTest();
        String result = AmountToWordsIND.convertToIndianCurrency(512);
        Test.stopTest();

        System.assert(result.contains('Hundred'), 'Hundreds should be included');
        System.assert(result.contains('Twelve') || result.contains('Twelve Paise') || result.contains('Twelve Rupees'),
            'Should include the last digits as words, got: ' + result);
    }

    @IsTest
    static void GIVEN_lakhNumber_WHEN_convertToIndianCurrency_THEN_includesLakhInWords() {
        Test.startTest();
        String result = AmountToWordsIND.convertToIndianCurrency(150000);
        Test.stopTest();

        System.assert(result.contains('Lakh'), 'Should contain "Lakh" for 1,50,000');
    }

    @IsTest
    static void GIVEN_croreNumber_WHEN_convertToIndianCurrency_THEN_includesCroreInWords() {
        Test.startTest();
        String result = AmountToWordsIND.convertToIndianCurrency(25000000);
        Test.stopTest();

        System.assert(result.contains('Crore'), 'Should contain "Crore" for 2.5 Crores');
    }

    @IsTest
    static void GIVEN_largeNumberWithAllParts_WHEN_convertToIndianCurrency_THEN_coversAllBranches() {
        Test.startTest();
        Decimal amount = 987654321.99;
        String result = AmountToWordsIND.convertToIndianCurrency(amount);
        Test.stopTest();

        System.debug('Result for ' + nf(amount) + ' = ' + result);

        System.assert(result.contains('Crore'), 'Should include Crore part');
        System.assert(result.contains('Lakh'), 'Should include Lakh part');
        System.assert(result.contains('Thousand'), 'Should include Thousand part');
        System.assert(result.contains('Hundred'), 'Should include Hundred part');
        System.assert(result.contains('Paise'), 'Should include Paise part');
    }

    @IsTest
    static void GIVEN_amountWithExactPaiseZero_WHEN_convertToIndianCurrency_THEN_noPaiseMentioned() {
        Test.startTest();
        String result = AmountToWordsIND.convertToIndianCurrency(2500.00);
        Test.stopTest();

        System.assert(result.endsWith('Rupees'), 'Should only mention Rupees if Paise is zero, got: ' + result);
    }
}