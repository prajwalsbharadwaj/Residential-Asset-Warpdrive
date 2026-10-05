public class PaymentReceiptBeforeDeleteHandler extends TriggerHandlerBase {
    public override void mainEntry(TriggerParameters tp) {
        
        if(UserInfo.getProfileId() == Constants.PROFILE_ID_SYSTEM_ADMINISTRATOR && !Test.isRunningTest()) return;
        
        for (Payment_Receipt__c r : (List<Payment_Receipt__c>)tp.oldList) {
            if (r.Approval_Status__c == 'Approved' || r.SAP_External_Id__c != null) {
                r.addError('Approved receipts cannot be deleted.');
            }
        }
    }
}