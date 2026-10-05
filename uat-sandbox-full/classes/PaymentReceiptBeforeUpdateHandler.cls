public class PaymentReceiptBeforeUpdateHandler extends TriggerHandlerBase {
    public override void mainEntry(TriggerParameters tp) {
        for (Payment_Receipt__c r : (List<Payment_Receipt__c>)tp.newList) {
            Payment_Receipt__c oldRec = (Payment_Receipt__c)tp.oldMap.get(r.id);

            // Check if the record has already been synced with SAP
            if (oldRec.SAP_External_Id__c != null) {
                Boolean isAllowedAction = (r.Receipt_Status__c == 'Bounced' || r.Receipt_Status__c == 'Cancelled') 
                                           && (r.Receipt_Status__c != oldRec.Receipt_Status__c || r.SAP_Sync_Status__c != oldRec.SAP_Sync_Status__c ||
                                              r.SAPSyncMessage__c != oldRec.SAPSyncMessage__c);


                if (!isAllowedAction) {
                    r.addError('Synced receipts cannot be updated');
                }
            }
        }
    }
}