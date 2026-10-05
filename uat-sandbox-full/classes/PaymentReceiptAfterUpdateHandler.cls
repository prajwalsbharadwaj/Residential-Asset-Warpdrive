public class PaymentReceiptAfterUpdateHandler extends TriggerHandlerBase {
    private static Boolean isProcessing = false;

    public override void mainEntry(TriggerParameters tp) {
        if (isProcessing) {
            return;
        }
        isProcessing = true;
        try {
            List<Payment_Receipt__c> newReceipts = (List<Payment_Receipt__c>)tp.newList;
            Map<Id, Payment_Receipt__c> oldMap = (Map<Id, Payment_Receipt__c>)tp.oldMap;
            if (newReceipts == null || newReceipts.isEmpty()) {
                return;
            }
            handleLedgerActions(newReceipts, oldMap);
            handleSapNotifications(newReceipts, oldMap);
        } finally {
            isProcessing = false;
        }
    }

    private static void handleLedgerActions(List<Payment_Receipt__c> newReceipts,Map<Id, Payment_Receipt__c> oldMap) {
        List<Payment_Receipt__c> toPost = new List<Payment_Receipt__c>();
        List<Payment_Receipt__c> toReverse = new List<Payment_Receipt__c>();
        for (Payment_Receipt__c receipt : newReceipts) {
            if (receipt == null) {
                continue;
            }
            StatusSnapshot snapshot = captureStatus(receipt);
            StatusSnapshot prior = (oldMap != null && oldMap.containsKey(receipt.Id))
                ? captureStatus(oldMap.get(receipt.Id))
                : new StatusSnapshot();

            if (snapshot.isReversal() && !prior.isReversal()) {
                toReverse.add(receipt);
            }
        }
        System.debug('toReverse: ' + toReverse.isEmpty());
        if (!toReverse.isEmpty()) {
            reverseReceipts(toReverse);
        }
    }

    private static void handleSapNotifications(List<Payment_Receipt__c> newReceipts, Map<Id, Payment_Receipt__c> oldMap) {
        //get sync from date to trigger integration only from after these dates.
         Date syncFromDateForCreate = IntegrationToggle.getSyncDates('Create Payment Receipt', 'SAP', 'Residential');
         Date syncFromDateForReversal = IntegrationToggle.getSyncDates('Reverse Payment Receipt', 'SAP', 'Residential');
        system.debug('syncFromDateForCreate ->  '+syncFromDateForCreate);
        system.debug('syncFromDateForReversal ->  '+syncFromDateForReversal);
        for (Payment_Receipt__c receipt : newReceipts) {
            if (receipt == null) {
                continue;
            }
            Payment_Receipt__c prior = oldMap != null ? oldMap.get(receipt.Id) : null;
            if (receipt.Approval_Status__c == 'Approved'&& (prior == null || prior.Approval_Status__c != 'Approved')
                && receipt.SAP_External_Id__c == null && (receipt.Date_Of_Payment__c >= syncFromDateForCreate || syncFromDateForCreate == null)) {
                SAPReceiptHelper.createCustomerReceipt(receipt.Id);
                system.debug('sync from date conditions fulfilled');
            } 
            //approval status approved, old status posted, new cancelled/bounced
            if(receipt.Approval_Status__c == 'Approved' && prior.receipt_status__c == 'Posted' && (receipt.Receipt_Status__c == 'Cancelled' || receipt.Receipt_Status__c == 'Bounced')
              && (receipt.Date_Of_Payment__c >= syncFromDateForReversal || syncFromDateForReversal == null)){
                SAPReceiptHelper.cancelReceipt(receipt.Id);
            }
        }
    }

    private static void reverseReceipts(List<Payment_Receipt__c> receipts) {
        for (Payment_Receipt__c receipt : receipts) {
            LedgerEntryService.reverseReceipt(receipt);
        }
    }

    private class StatusSnapshot {
        String approval;
        String lifecycle;

        Boolean isApproved() {
            return isApprovedStatus(approval) || isApprovedStatus(lifecycle);
        }

        Boolean isReversal() {
            return isReversalStatus(approval) || isReversalStatus(lifecycle);
        }
    }

    private static StatusSnapshot captureStatus(Payment_Receipt__c receipt) {
        StatusSnapshot snapshot = new StatusSnapshot();
        snapshot.approval = normalizeStatus(receipt == null ? null : receipt.Approval_Status__c);
        snapshot.lifecycle = normalizeStatus(readLifecycleStatus(receipt));
        return snapshot;
    }

    private static String normalizeStatus(String status) {
        return String.isBlank(status) ? null : status.trim().toLowerCase();
    }

    private static Boolean isApprovedStatus(String status) {
        if (String.isBlank(status)) {
            return false;
        }
        return status == 'approved' || status == 'posted';
    }

    private static Boolean isReversalStatus(String status) {
        if (String.isBlank(status)) {
            return false;
        }
        return status == 'cancelled' || status == 'canceled' || status == 'bounced';
    }

    private static String readLifecycleStatus(Payment_Receipt__c sobj) {
        return sobj.Receipt_Status__c;
    }
}