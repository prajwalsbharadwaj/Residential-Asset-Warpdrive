public class PaymentReceiptBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {
    
    private Set<Id> receiptIds;
    
    public PaymentReceiptBatch(Set<Id> receiptIds) {
        this.receiptIds = receiptIds;
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT 
            ChequeNumber__c,
            Date_Of_Payment__c,
            Demand__r.SAP_External_Id__c,
            Booking_Payment_Schedule__r.Milestone_Code__c,
            Booking_Payment_Schedule__r.Booking__r.SAP_External_Id__c, 
            Booking_Payment_Schedule__r.Booking__r.Project__r.SAP_External_Id__c,
            Booking_Payment_Schedule__r.Booking__r.Token_Amount__c,
            Booking_Payment_Schedule__r.Booking__r.Account_Id__r.SAP_External_Id__c, 
            Booking_Payment_Schedule__r.Booking__r.Account_Id__r.Company_Code__c
            FROM Payment_Receipt__c WHERE SAP_Sync_Status__c = 'Pending'
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<Payment_Receipt__c> paymentReceipts) {
        
        for(Payment_Receipt__c receipt:paymentReceipts){
            //Build Payload for single receipt record.
           // SAPReceiptHelper.ReceiptPayload payload = SAPReceiptHelper.buildPayload(receipt);
            
            // Send callout for single payload.
           // SAPReceiptHelper.sendPayload(payload);
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('Batch finished for receipts: ' + receiptIds);
    }
}