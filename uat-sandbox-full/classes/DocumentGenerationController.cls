public with sharing class DocumentGenerationController {
    public Id bookingId { get; set; }
    public Id bpsId { get; set; }
    public String docType { get; set; }
    
    public Booking__c booking { get; set; }
    public Booking_Payment_Schedule__c bps { get; set; }
    public List<Opportunity_Parking__c> parkings { get; set; }
    
    public String parkingsDetails {get {
        List<String> parkingStrings = new List<String>();
        if(parkings != null) {
            for(Opportunity_Parking__c park : parkings){
                parkingStrings.add('<strong>' + park.Name + '</strong> in the basement level <strong>' + park.Basement_Level__c + '</strong>');
            }
        }
        return String.join(parkingStrings, ', ');
    }}
    //public Opportunity_Parking__c parkings { get; set; }
    
    // Variables to hold data for VF pages
    public CancellationWrapper cancellationData { get; set; }
    public CarParkWrapper carParkData { get; set; }
    public ReminderWrapper reminderData { get; set; }
    
    public DocumentGenerationController() {
        bookingId = ApexPages.currentPage().getParameters().get('bookingId');
        bpsId     = ApexPages.currentPage().getParameters().get('bpsId');
        docType   = ApexPages.currentPage().getParameters().get('docType');
        
        if (bookingId != null) {
            booking = [
                SELECT Id, Name, Final_Reminder_Letter_Date__c, Pre_Cancellation_Date__c, Booking_Cancellation_Date__c, Booking_Date__c, Sale_Deed_Executed_Date__c, Project__r.Name, Project__r.Address__c, Unit_Id__r.Name, Unit_Id__r.Tower__r.Name, Unit_Id__r.Floor__r.Name,
                Account_Id__r.Salutation, Account_Id__c, Account_Id__r.Name, Account_Id__r.BillingStreet, Account_Id__r.BillingCity,Agreement_Registered_Date__c,
                Account_Id__r.BillingState, Account_Id__r.BillingPostalCode, Account_Id__r.Phone,Total_Interest_Outstanding__c, Agreement_Executed_Date__c
                FROM Booking__c
                WHERE Id = :bookingId
                LIMIT 1
            ];
            
            parkings = [
                SELECT Id, Name, Basement_Level__c  FROM Opportunity_Parking__c where Booking__r.Id = :bookingId
            ];            
        }
        
        if (bpsId != null) {
            bps = [
                SELECT Id, Name, Booking__r.Booking_Date__c, Installment_Amount__c,Payment_Due_Date__c, opportunity__r.TaxOnOtherCharges__c,
                Interest_Start_Date__c,Installment_Number__c,Booking__r.TotalInterestOutstandingFromLedger__c,
                Booking__r.Account_Id__r.Salutation, Booking__r.Account_Id__r.Name, Booking__r.Account_Id__r.BillingStreet, 
                Booking__r.Account_Id__r.BillingCity,booking__r.Agreement_Registered_Date__c,
                Booking__r.Account_Id__r.BillingState, Booking__r.Account_Id__r.BillingPostalCode, Booking__r.Account_Id__r.Phone, 
                Booking__r.Project__r.Name,  Booking__r.Project__r.Address__c, Booking__r.Unit_Id__r.Name, Booking__r.Unit_Id__r.Tower__r.Name, Booking__r.Unit_Id__r.Floor__r.Name
                FROM Booking_Payment_Schedule__c
                WHERE Id = :bpsId
                LIMIT 1
            ];
        }
        
        if (docType != null) {
            switch on docType {
                // Booking-level docs
                when 'PreCancellation' {
                    cancellationData = getPreCancellationData(bookingId);
                }
                when 'CancellationRefund' {
                    cancellationData = getRefundData(bookingId);
                }
                when 'FinalCancellation' {
                    cancellationData = getFinalCancellationData(bookingId);
                }
                when 'CarParkAllotment' {
                    carParkData = getCarParkData(bookingId);
                }
                
                // BPS-level docs
                when 'Reminder1' {
                    reminderData = getReminderData(bps, 1);
                }
                when 'Reminder2' {
                    reminderData = getReminderData(bps, 2);
                }
                when 'Reminder3' {
                    reminderData = getReminderData(bps, 3);
                }
                when 'FinalReminder' {
                    reminderData = getReminderData(bps, 4);
                }
            }
        }
    }
    
    //-------------------------------------
    // All Service Methods consolidated
    //-------------------------------------
    private static CancellationWrapper getPreCancellationData(Id bookingId) {
        // TODO: Add logic to query and populate the wrapper
        return new CancellationWrapper();
    }
    
    private static CancellationWrapper getRefundData(Id bookingId) {
        // TODO: Add logic to query and populate the wrapper
        return new CancellationWrapper();
    }
    
    private static CancellationWrapper getFinalCancellationData(Id bookingId) {
        // TODO: Add logic to query and populate the wrapper
        return new CancellationWrapper();
    }
    
    private static CarParkWrapper getCarParkData(Id bookingId) {
        // TODO: Add logic to query and populate the wrapper
        return new CarParkWrapper();
    }
    
    private static ReminderWrapper getReminderData(Booking_Payment_Schedule__c bps, Integer reminderNumber) {
        
        
        // TODO: Add logic to query and populate the wrapper
        ReminderWrapper remWrap = new ReminderWrapper();
        //Set CGST & SGST On other charges.
        Decimal taxOnOtherCharges = 0;
        if(reminderNumber == 3){
            remWrap.cgstOnOtherChrg = bps.Opportunity__r.TaxOnOtherCharges__c != null ? bps.Opportunity__r.TaxOnOtherCharges__c/2 : 0;
            remWrap.sgstOnOtherChrg = bps.Opportunity__r.TaxOnOtherCharges__c != null ? bps.Opportunity__r.TaxOnOtherCharges__c/2 : 0;
            taxOnOtherCharges = remWrap.cgstOnOtherChrg + remWrap.sgstOnOtherChrg;
        }
        
        list<Booking_payment_Schedule__c> prevBps = [SELECT Id, Installment_Amount__c, Installment_Number__c, OutstandingPrincipal__c,Booking__c,Milestone_Code__c
                                                     FROM Booking_Payment_Schedule__c WHERE Booking__c =: bps.Booking__c AND Installment_Number__c <: bps.Installment_Number__c 
                                                     ORDER BY Installment_Number__c ASC];
        remWrap.previousOutstanding = 0;
        remWrap.TotalamountOverDue = 0;
        Booking_Payment_Schedule__c exactOnePrevBps;
        Map<Id,String> milestoneMap = new map<Id,string>();
        for(Booking_Payment_Schedule__c bp:prevBps){
            remWrap.previousOutstanding += bp.OutstandingPrincipal__c ?? 0;
            //Capture just exact One previous BPS record
            if(bp.Installment_Number__c < bps.Installment_Number__c){
                exactOnePrevBps = bp;
            }
            //Capture all the outstanding Milestones
            if(milestoneMap.containsKey(bp.Booking__c)){
                milestoneMap.put(bp.Booking__c, (milestoneMap.get(bp.Booking__c) + ', '+bp.Milestone_Code__c));
            }else{
                milestoneMap.put(bp.Booking__c, bp.Milestone_Code__c);
            }
        }
        Decimal totalInterestOustanding = bps.Booking__r.TotalInterestOutstandingFromLedger__c != null ? bps.Booking__r.TotalInterestOutstandingFromLedger__c : 0;
        Decimal currentInstallment = bps.Installment_Amount__c != null ? bps.Installment_Amount__c : 0;
        remWrap.TotalamountOverDue = remWrap.previousOutstanding + currentInstallment + totalInterestOustanding + taxOnOtherCharges;
        //Convert amount in words.
        remWrap.amountInwords = AmountToWordsIND.convertToIndianCurrency(remWrap.TotalamountOverDue);
        
        // Pick last demand letter sent date from just previous demand.
        /*if(exactOnePrevBps != null){
Demand__c prevDemand = [SELECT Id, DemandLetterSentDate__c FROM Demand__c WHERE Booking_Id__c =:exactOnePrevBps.Booking__c 
ORDER BY DemandLetterSentDate__c DESC LIMIT 1];
remWrap.lastDemandLetterSentDate = prevDemand.DemandLetterSentDate__c ?? null;

}*/
        if (exactOnePrevBps != null) {
            List<Demand__c> prevDemands = [
                SELECT Id, DemandLetterSentDate__c 
                FROM Demand__c 
                WHERE Booking_Id__c = :exactOnePrevBps.Booking__c 
                ORDER BY DemandLetterSentDate__c DESC 
                LIMIT 1
            ];
            
            if (!prevDemands.isEmpty()) {
                remWrap.lastDemandLetterSentDate = prevDemands[0].DemandLetterSentDate__c;
            } else {
                remWrap.lastDemandLetterSentDate = null;
            }
        }
        
        remWrap.bps = bps;
        remWrap.reminderNumber = reminderNumber;
        // Pick all outstanding milestones
        remWrap.outstandingMilestones = milestoneMap.get(bps.Booking__c);
        return remWrap;
    }
    
    //Update reminder dates on Booking Payment Schedule Record.
    public void updateReminderDates(){
        if(reminderData.bps != null && reminderData.reminderNumber != null){
            Booking_Payment_Schedule__c bps = reminderData.bps;
            if(reminderData.reminderNumber < 4){
                string dynamicErpDateField = 'ERPReminder'+ reminderData.reminderNumber +'Date__c';
                bps.put(dynamicErpDateField, date.Today());
            }else{
                bps.FinalERPReminderDate__c = date.today();
            }
            update bps;
        }
    }
    
    //------------------------------
    // Wrapper classes
    //------------------------------
    public class CancellationWrapper {
        public String customerName;
        public Date cancellationDate;
        public Decimal refundAmount;
    }
    
    public class CarParkWrapper {
        public String slotNumber;
        public String location;
    }
    
    public class ReminderWrapper {
        public String scheduleName {get;set;}
        public Booking_Payment_Schedule__c bps {get;set;}
        public decimal previousOutstanding {get;set;}
        public string outstandingMilestones {get;set;}
        public Date dueDate {get;set;}
        public Date lastDemandLetterSentDate {get;set;}
        public Decimal TotalamountOverDue {get;set;}
        public string amountInwords {get;set;}
        public Integer reminderNumber {get;set;}
        public decimal cgstOnOtherChrg {get;set;}
        public decimal sgstOnOtherChrg {get;set;}
    }
}