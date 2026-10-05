CustomerLedgerController.LedgerSummaryWrapper s = CustomerLedgerController.getLedgerSummary('a0Gbm00000Px0jyEAB');
System.debug('=== LEDGER SUMMARY ===\n' + JSON.serializePretty(s));
List<CustomerLedgerController.InstallmentItemWrapper> insts = CustomerLedgerController.getInstallments('a0Gbm00000Px0jyEAB');
System.debug('=== INSTALLMENTS COUNT === ' + insts.size());
for (CustomerLedgerController.InstallmentItemWrapper i : insts) {
    System.debug(i.name + ' | ' + i.milestoneName + ' | Amt: ' + i.amount + ' | Paid: ' + i.paidAmount + ' | Status: ' + i.status + ' | DN: ' + i.demandNoteNumber + ' | SAP Inv: ' + i.sapInvoiceNumber + ' | Block Removed: ' + i.sapBillBlockRemoved + ' | Rem: ' + i.demandReminderLevel);
}
List<CustomerLedgerController.ReceiptItemWrapper> rcpts = CustomerLedgerController.getReceipts('a0Gbm00000Px0jyEAB');
System.debug('=== RECEIPTS COUNT === ' + rcpts.size());
for (CustomerLedgerController.ReceiptItemWrapper r : rcpts) {
    System.debug(r.name + ' | ' + r.amount + ' | ' + r.paymentMode + ' | ' + r.status + ' | Bank: ' + r.bankName + ' | Inst #: ' + r.instrumentNumber + ' | Approver: ' + r.financeApprover + ' | Reconciled Date: ' + r.formattedSapReconciledDate);
}
