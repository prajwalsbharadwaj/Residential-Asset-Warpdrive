public class ReportSelector {
    
    public static list<payment_receipt__c> getPaymentReceipt(Date startDate, Date endDate, Integer pageNumber, Integer pageSize){
        if (pageNumber == null || pageNumber < 1) pageNumber = 1;
        if (pageSize == null || pageSize < 1) pageSize = 10;
        
        Integer offsetVal = (pageNumber - 1) * pageSize;
        
        list<Payment_Receipt__c> receipts = new list<payment_receipt__c>();
        receipts = [SELECT Id, Demand__r.Unit__r.Property__r.Name, Demand__r.Unit__r.Tower__r.Name, Account__r.Name,
                    Demand__r.Unit__r.Name, Booking_Payment_Schedule__r.Opportunity__r.BasePrice__c, 
                    Demand__r.Unit__r.Built_Up_Area_SBA__c, Account__r.Company_Code__c,
                    Account__r.BillingAddress, Account__r.Pan_Number__c, Demand__r.createdDate, Date_Of_Payment__c, Name,
                    Demand__r.SAP_External_Id__c, Receipt_Status__c, Booking_Payment_Schedule__r.installment_amount__c,
                    Amount_Paid__c, Booking_Payment_Schedule__r.Booking__r.Total_Interest_Outstanding__c, 
                    Booking_Payment_Schedule__r.Booking__r.InterestReceivedFromLedger__c, Booking_Payment_Schedule__r.Installment_Number__c,
                    Booking_Payment_Schedule__r.Opportunity__r.Construction_Cost__c, Booking_Payment_Schedule__r.Opportunity__r.Land_Cost__c,
                    Demand__r.Unit__r.Tower__r.BESCOM_BWSSB_Charges__c, Demand__r.Unit__r.Tower__r.Club_Membership_Fees__c,
                    Demand__r.Unit__r.Tower__r.Legal_Fees__c, Demand__r.Unit__r.Tower__r.Maintenance_Deposit_Corpus_Fund__c,
                    Booking_Payment_Schedule__r.Opportunity__r.Taxable_Other_Charges__c, Booking_Payment_Schedule__r.Opportunity__r.TaxOnOtherCharges__c,
                    Booking_Payment_Schedule__r.Opportunity__r.Chargeable_Area__c
                    FROM Payment_Receipt__c WHERE 
                    Date_Of_Payment__c >= :startDate AND Date_Of_Payment__c <= :endDate 
                    ORDER BY Date_Of_Payment__c DESC LIMIT :pageSize OFFSET :offsetVal];
        
        return receipts;
    }
    
    public static Decimal getPrevDues(Id bookingId){
        
        list<Booking_Payment_Schedule__c> bpsList = [SELECT Id, Outstanding_Principal__c FROM Booking_Payment_Schedule__c WHERE 
                                                     Booking__c =: bookingId AND Payment_Due_Date__c < TODAY];
        decimal outstandingPrincipal = 0;
        for(Booking_Payment_Schedule__c bps:bpsList){
            outstandingPrincipal += bps.Outstanding_Principal__c;
        }
        return outstandingPrincipal;
    }
    
    // Get paginated booking records
    public static List<Booking__c> getBooking(string towerName, Integer pageNumber, Integer pageSize) {
        Integer offsetVal = (pageNumber - 1) * pageSize;
        
        List<Booking__c> bookings = [
            SELECT Id,
            Account_Id__r.Company_Code__c,
            Account_Id__r.Name,
            Account_Id__r.Phone,
            Account_Id__r.Other_Phone_2__c,
            Account_Id__r.Other_Phone_3__c,
            Account_Id__r.Other_Phone_4__c,
            Account_Id__r.Sales_Group__c,
            Unit_Id__r.Name, (SELECT Id, Account__r.Name FROM Agent_Brokerages__r),
            Booking_Date__c, Unit_Id__r.Built_Up_Area_SBA__c, 
            opportunity_Id__r.owner.Name,
            opportunity_Id__r.Total_Amount__c,
            opportunity_Id__r.BaseCostAfterDiscount__c, opportunity_Id__r.OtherCharges__c,
            opportunity_Id__r.TaxOnConstructionCost__c, opportunity_Id__r.Tax_on_Land_Cost__c,
            opportunity_Id__r.TaxOnOtherCharges__c,
            Account_Id__r.TotalCreditNoteAmt__c,
            Account_Id__r.TotalTaxOnCreditNote__c,
            (SELECT Id, Invoice_Value__c FROM Credit_Notes__r),
            (SELECT Id, Installment_Amount__c,Payment_Due_Date__c, Outstanding_Principal__c FROM Booking_Payment_Schedules__r),
            Total_Principal_Received__c
            FROM Booking__c WHERE Tower__c = :towerName ORDER BY CreatedDate DESC LIMIT :pageSize OFFSET :offsetVal
        ];

        return bookings;
    }

    // Get total count (for pagination)
    public static Integer getBookingCount(string towerName) {
        return [SELECT COUNT() FROM Booking__c WHERE Tower__c =: towerName];
    }
}