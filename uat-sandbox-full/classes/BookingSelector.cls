public class BookingSelector {
	
    public list<Booking__c> getBookingByIds(set<Id> bookingIds){
        List<Booking__c> bookingList = [
      SELECT
        Id,
        Booking_Date__c,
        SAP_External_Id__c,
        Account_Id__r.SAP_External_Id__c,
        Co_Applicant_1__r.SAP_External_Id__c,
        Co_Applicant_2__r.SAP_External_Id__c,
        Co_Applicant_3__r.SAP_External_Id__c,
        Co_Applicant_4__r.SAP_External_Id__c,
        Co_Applicant_5__r.SAP_External_Id__c,
        Broker_agreement_condition__c,
        SFDC_Booking_Reference_No__c,
        Payment_Plan_Id__r.Name,
        Sales_Organization__c,
        Division__c,
        Distribution_Channel__c,
        Document_Type__c,
        Order_Qty__c,
        Unit_Id__r.Property__r.SAP_External_Id__c,
        Unit_Id__r.SAP_External_Id__c,
        Unit_Id__r.Tower__r.SAP_External_Id__c,
        Unit_Id__r.Tower__r.ZWBS_Structure__c,
        Opportunity_Id__r.OtherCharges__c,
        Opportunity_Id__r.TaxOnOtherCharges__c,
        (
          SELECT
            Id,
            Installment_Number__c,
            Payment_Due_Date__c,
            Payment_Schedule_Id__r.Payment_Percentage__c,
            Adjusted_Amount__c,
            Installment_Amount__c,
            Payment_Schedule_Id__r.Billing_Rule__c,
            Bill_Block__c,
            Payment_Schedule_Id__r.Milestone_Code__c,
            Milestone_Code__c
          FROM Booking_Payment_Schedules__r ORDER BY Installment_Number__c ASC
        ),
        (
          SELECT Id, Name, Amount__c, UOM__c, Condition_Type__c, Quantity__c, Amount_By_Type__c
          FROM Booking_Conditions__r
        )
      FROM Booking__c
      WHERE Id IN :bookingIds
    ];
        return bookingList;
    }

}