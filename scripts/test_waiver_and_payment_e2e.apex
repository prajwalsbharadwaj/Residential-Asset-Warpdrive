// End-to-End Functional Verification of Customer Ledger Hub
Installment__c inst4 = [
    SELECT Id, Name, Booking__c, Amount__c, Paid_Amount__c, Due_Date__c, Status__c,
           Days_Overdue__c, Overdue_Interest__c, Waiver_Status__c, Demand_Note_Number__c
    FROM Installment__c
    WHERE Name = 'INST-0004'
    LIMIT 1
];

System.debug('--- BEFORE WAIVER: Overdue Interest = ' + inst4.Overdue_Interest__c + ' | Status = ' + inst4.Waiver_Status__c);

// 1. Issue Demand Note
CustomerLedgerController.ActionResultWrapper dnRes = CustomerLedgerController.issueDemandNote(inst4.Id);
System.debug('1. Issue Demand Note Result: ' + dnRes.message);

// 2. Request Interest Waiver of ₹10,000
CustomerLedgerController.ActionResultWrapper reqRes = CustomerLedgerController.requestInterestWaiver(
    inst4.Id,
    10000,
    'Customer requested 50% interest concession due to home loan disbursement delay by HDFC Bank.'
);
System.debug('2. Request Waiver Result: ' + reqRes.message);

// 3. Finance Review & Approval
CustomerLedgerController.ActionResultWrapper appRes = CustomerLedgerController.reviewInterestWaiver(
    inst4.Id,
    true,
    'Special concession approved by Finance Controller per festive scheme guidelines.'
);
System.debug('3. Approval Result: ' + appRes.message);

// Verify post-approval state
Installment__c postWaiverInst = [
    SELECT Id, Name, Overdue_Interest__c, Waived_Interest_Amount__c, Waiver_Status__c,
           Interest_Waived__c, Waiver_Reason__c, Demand_Note_Number__c, Demand_Note_Date__c
    FROM Installment__c
    WHERE Id = :inst4.Id
];
System.debug('--- AFTER APPROVAL: Remaining Interest = ' + postWaiverInst.Overdue_Interest__c + 
             ' | Waived = ' + postWaiverInst.Waived_Interest_Amount__c + 
             ' | Waiver Status = ' + postWaiverInst.Waiver_Status__c + 
             ' | DN# = ' + postWaiverInst.Demand_Note_Number__c);

// 4. Log Quick Payment Receipt of ₹5,00,000
CustomerLedgerController.ActionResultWrapper rcptRes = CustomerLedgerController.logQuickReceipt(
    inst4.Booking__c,
    inst4.Id,
    500000,
    'NEFT/RTGS',
    'HDFC-E2E-TEST-881920',
    Date.today()
);
System.debug('4. Quick Receipt Result: ' + rcptRes.message);

// Re-check updated summary
CustomerLedgerController.LedgerSummaryWrapper finalSummary = CustomerLedgerController.getLedgerSummary(inst4.Booking__c);
System.debug('--- FINAL LEDGER SUMMARY ---');
System.debug('Agreement Value: ₹' + finalSummary.agreementValue);
System.debug('Total Demanded: ₹' + finalSummary.totalDemanded);
System.debug('Total Received: ₹' + finalSummary.totalReceived);
System.debug('Outstanding Principal: ₹' + finalSummary.outstandingPrincipal);
System.debug('Total Overdue Interest: ₹' + finalSummary.totalOverdueInterest);
System.debug('Total Interest Waived: ₹' + finalSummary.totalInterestWaived);
System.debug('Net Payable Today: ₹' + finalSummary.netPayableToday);
