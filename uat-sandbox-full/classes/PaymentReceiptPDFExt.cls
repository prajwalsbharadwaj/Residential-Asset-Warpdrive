// file: PaymentReceiptPDFExt.cls
public with sharing class PaymentReceiptPDFExt {
    public Payment_Receipt__c rec { get; private set; }

    public PaymentReceiptPDFExt(ApexPages.StandardController std) {
        rec = (Payment_Receipt__c) std.getRecord();
        // Query any fields not in the layout token
        rec = [
            SELECT Name, Booking_Payment_Schedule__c, CreatedDate,
            		Demand__r.Booking_Id__r.Account_Id__r.Name, Demand__r.Booking_Id__r.Account_Id__r.PersonMailingStreet, Demand__r.Booking_Id__r.Account_Id__r.PersonMailingCity, 
            		Demand__r.Booking_Id__r.Account_Id__r.PersonMailingPostalCode, Demand__r.Booking_Id__r.Account_Id__r.Salutation,
            
            		Account__r.Name, Account__r.Salutation, Account__r.PersonMailingStreet, Account__r.PersonMailingCity, Account__r.PersonMailingPostalCode,
            		Demand__r.Booking_Id__r.Account_Id__r.Phone, SAP_External_Id__c, Demand__r.Booking_Id__r.Unit_Id__r.Name, Demand__r.Booking_Id__r.Unit_Id__r.Property__r.Name,
            		Amount_Paid__c, Mode_Of_Payment__c, Date_Of_Payment__c, Demand__c, ChequeNumber__c, 
            		Transaction_Reference__c, Challan_Number__c, Certificate_Number__c, SAP_Sync_Status__c, Company_Bank_Account__c, Customer_Bank_Name__c, CustomerAccountNumber__c 
            FROM Payment_Receipt__c WHERE Id = :rec.Id
        ];
        
        ApexPages.currentPage().getHeaders().put('content-disposition', 'inline; filename=Payment Receipt - ' + rec.SAP_External_Id__c + '.pdf');
    }

    /** “Rupees One Lakh Twenty Three Thousand … Only” (Indian system) */
    public String getAmountInWords() {
        if (rec.Amount_Paid__c == null) return '';
        Long rupees = (Long)Math.floor(rec.Amount_Paid__c);
        Integer paise = Integer.valueOf( Math.round( (rec.Amount_Paid__c - rupees) * 100 ) );
        String words = numberToIndianWords(rupees) + ' Rupees';
        if (paise > 0) words += ' and ' + numberToIndianWords(paise) + ' Paise';
        return words + ' Only';
    }

    private static final List<String> ONES = new List<String>{
        '', 'One','Two','Three','Four','Five','Six','Seven','Eight','Nine','Ten',
        'Eleven','Twelve','Thirteen','Fourteen','Fifteen','Sixteen','Seventeen','Eighteen','Nineteen'
    };
    private static final List<String> TENS = new List<String>{
        '', '', 'Twenty','Thirty','Forty','Fifty','Sixty','Seventy','Eighty','Ninety'
    };

    private static String twoDigits(Integer n) {
        if (n < 20) return ONES[n];
        Integer t = n/10, o = Math.Mod(n, 10);
        return TENS[t] + (o > 0 ? ' ' + ONES[o] : '');
    }
    private static String threeDigits(Integer n) {
        Integer h = n/100, r = Math.Mod(n, 100);
        String s = (h > 0 ? ONES[h] + ' Hundred' : '');
        if (r > 0) s += (s=='' ? '' : ' ') + twoDigits(r);
        return s;
    }
    private static String numberToIndianWords(Long n) {
        if (n == 0) return 'Zero';
        Integer crore = Integer.valueOf(Math.Mod((n/10000000L), 100));
        Integer lakh  = Integer.valueOf(Math.Mod((n/100000L), 100));
        Integer thousand = Integer.valueOf(Math.Mod((n/1000L), 100));
        Integer hundred  = Integer.valueOf(Math.Mod(n, 1000));

        List<String> parts = new List<String>();
        if (crore   > 0) parts.add(twoDigits(crore)   + ' Crore');
        if (lakh    > 0) parts.add(twoDigits(lakh)    + ' Lakh');
        if (thousand> 0) parts.add(twoDigits(thousand)+ ' Thousand');
        if (hundred > 0) parts.add(threeDigits(hundred));
        return String.join(parts, ' ');
    }
}