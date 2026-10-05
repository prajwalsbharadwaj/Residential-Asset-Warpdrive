public class BookingPaymentScheduleSelector {
    
    public list<Booking_Payment_Schedule__c> getBookingPaymentScheduleByBookingIds(set<Id> bookingIds){
        list<Booking_Payment_Schedule__c> bpsList = [
            SELECT
            Id,
            Booking__c,
            Installment_Number__c,
            Payment_Due_Date__c,
            Payment_Schedule_Id__r.Payment_Percentage__c,
            Adjusted_Amount__c,
            Installment_Amount__c,
            Payment_Schedule_Id__r.Billing_Rule__c,
            Bill_Block__c, Payment_Schedule_Id__r.Name,
            Payment_Schedule_Id__r.Milestone_Code__c,
            Milestone_Code__c
            FROM Booking_Payment_Schedule__c WHERE Booking__c in:bookingIds ORDER BY Installment_Number__c ASC
        ];
        
        return bpsList;
    }
}