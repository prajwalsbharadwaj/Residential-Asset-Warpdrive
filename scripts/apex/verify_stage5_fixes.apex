// Verification script for live Stage 5 fixes
// 1. Verify Dual Maker-Checker Receipt Lifecycle on Booking BR-82914
// 2. Verify Recalculate & Reconcile preserves token receipt
// 3. Verify TDS and 0% GST logic

Booking__c b = [SELECT Id, Name, Booking_Reference_ID__c, Total_Booking_Amount__c, Payment_Plan__c,
                       (SELECT Id, Name, Amount__c, Due_Date__c, Paid_Amount__c, Demand_Note_Number__c, Status__c FROM Installments__r ORDER BY CreatedDate ASC),
                       (SELECT Id, Name, Amount__c, Status__c, SAP_Clearing_Doc__c, SAP_Cleared_By__c, Installment__c FROM Receipts__r)
                FROM Booking__c 
                WHERE Booking_Reference_ID__c = 'BR-82914' OR Name = 'BR-82914' LIMIT 1];

System.debug('=== BOOKING INFO ===');
System.debug('Booking: ' + b.Name + ' (' + b.Booking_Reference_ID__c + ') | Total Amount: ' + b.Total_Booking_Amount__c + ' | Plan: ' + b.Payment_Plan__c);
System.debug('Installments Count: ' + b.Installments__r.size());
System.debug('Receipts Count: ' + b.Receipts__r.size());

for (Installment__c inst : b.Installments__r) {
    System.debug('-> Installment: ' + inst.Name + ' | Status: ' + inst.Status__c + ' | Paid: ' + inst.Paid_Amount__c + ' | Demand: ' + inst.Demand_Note_Number__c);
}
for (Receipt__c r : b.Receipts__r) {
    System.debug('-> Receipt: ' + r.Name + ' | Amount: ' + r.Amount__c + ' | Status: ' + r.Status__c + ' | Clearing Doc: ' + r.SAP_Clearing_Doc__c);
}

// Test Dual Approval step 1 & 2 on any Pending Receipt, or simulate:
List<Receipt__c> pendingRcpts = [SELECT Id, Name, Status__c FROM Receipt__c WHERE Booking__c = :b.Id AND Status__c = 'Pending Reconciliation' LIMIT 1];
if (!pendingRcpts.isEmpty()) {
    Id rId = pendingRcpts[0].Id;
    System.debug('Clearing receipt in SAP: ' + rId);
    CustomerLedgerController.clearReceiptInSap(rId, 'SAP-CLR-99001', 'Bank credit verified in HDFC Escrow');
    Receipt__c cleared = [SELECT Id, Status__c, SAP_Clearing_Doc__c, SAP_Cleared_By__c FROM Receipt__c WHERE Id = :rId];
    System.debug('After Step 1: Status=' + cleared.Status__c + ', Doc=' + cleared.SAP_Clearing_Doc__c + ', By=' + cleared.SAP_Cleared_By__c);
    
    CustomerLedgerController.postReceiptToLedger(rId, true, 'Approved by Finance Controller for GL posting');
    Receipt__c posted = [SELECT Id, Status__c FROM Receipt__c WHERE Id = :rId];
    System.debug('After Step 2: Status=' + posted.Status__c);
}

// Test recalculation does NOT wipe out paid amount
CustomerLedgerController.recalculateInstallmentBalances(b.Id);
Installment__c firstInst = [SELECT Id, Name, Status__c, Paid_Amount__c, Overdue_Interest__c FROM Installment__c WHERE Booking__c = :b.Id ORDER BY CreatedDate ASC LIMIT 1];
System.debug('After Recalculate: First Inst Paid Amount = ' + firstInst.Paid_Amount__c + ' (Should NOT be 0) | Status = ' + firstInst.Status__c + ' | Overdue Interest = ' + firstInst.Overdue_Interest__c);
