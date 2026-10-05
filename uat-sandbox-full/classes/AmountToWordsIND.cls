public class AmountToWordsIND {

    // Arrays for words
    private static final String[] units = new String[]{
        '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
        'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen',
        'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'
    };

    private static final String[] tens = new String[]{
        '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
    };

    // Convert numbers < 100
    private static String convertTwoDigits(Integer num) {
        if (num < 20) {
            return units[num];
        }
        Integer t = num / 10;
        Integer u = Math.mod(num, 10);
        return tens[t] + (u > 0 ? ' ' + units[u] : '');
    }

    // Convert numbers < 1000
    private static String convertThreeDigits(Integer num) {
        String word = '';
        if (num > 99) {
            word += units[num / 100] + ' Hundred';
            num = Math.mod(num, 100);
            if (num > 0) word += ' ';
        }
        if (num > 0) {
            word += convertTwoDigits(num);
        }
        return word;
    }

    // Main method: accepts Decimal and returns in Indian Currency Words
    public static String convertToIndianCurrency(Decimal amount) {
        if (amount == null) return '';

        // Round to 2 decimals (like currency)
        amount = amount.setScale(2);

        Long rupees = (Long)Math.floor(amount);
        Integer paise = Integer.valueOf(((amount - rupees) * 100).setScale(0));

        if (rupees == 0 && paise == 0) {
            return 'Zero Rupees';
        }

        String result = '';

        // Break rupees into Indian numbering system
        Integer crore = (Integer)(rupees / 10000000);
        rupees = Math.mod(rupees, 10000000);

        Integer lakh = (Integer)(rupees / 100000);
        rupees = Math.mod(rupees, 100000);

        Integer thousand = (Integer)(rupees / 1000);
        rupees = Math.mod(rupees, 1000);

        Integer hundredAndBelow = (Integer)rupees;

        if (crore > 0) result += convertTwoDigits(crore) + ' Crore ';
        if (lakh > 0) result += convertTwoDigits(lakh) + ' Lakh ';
        if (thousand > 0) result += convertTwoDigits(thousand) + ' Thousand ';
        if (hundredAndBelow > 0) result += convertThreeDigits(hundredAndBelow) + ' ';

        result = result.trim();

        // Add currency suffix
        if (result != '') {
            result += (result == 'One' ? ' Rupee' : ' Rupees');
        }

        if (paise > 0) {
            result += ' and ' + convertTwoDigits(paise) + (paise == 1 ? ' Paisa' : ' Paise');
        }

        return result.trim();
    }
}