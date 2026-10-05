// scripts/seed_payment_plans_and_reconciliation.apex
// Stage 5: Seed standard OC Received & CLP Payment Plans, SAP Billing, Invoice Generation, Receipts, and Finance Reconciliation

System.debug('=== Starting Stage 5 Payment Plan & Reconciliation Seed ===');

// 1. Get Projects
Project__c skylineProj = [SELECT Id, Name FROM Project__c WHERE Name LIKE '%Skyline Crest%' LIMIT 1];
Project__c nikooProj = [SELECT Id, Name FROM Project__c WHERE Name LIKE '%Nikoo Homes%' LIMIT 1];

// 2. Configure Plan A: Time Linked Plan (OC Received / Date-Based 10:90) on Skyline Crest
Payment_Plan__c ocPlan;
List<Payment_Plan__c> existingOcPlans = [
    SELECT Id, Name FROM Payment_Plan__c 
    WHERE Project__c = :skylineProj.Id AND Name LIKE '%OC Received%'
    LIMIT 1
];

if (existingOcPlans.isEmpty()) {
    ocPlan = new Payment_Plan__c(
        Name = 'Skyline Crest OC Received Date-Based Plan (10:90)',
        Project__c = skylineProj.Id,
        Plan_Type__c = 'Time Linked Plan (OC Received / Date-Based)',
        Active__c = true,
        Description__c = 'Ready-to-move-in date-based payment plan with 10% token and 90% across 30, 60, and 90-day intervals.'
    );
    insert ocPlan;
    System.debug('Created OC Received Plan: ' + ocPlan.Id);
} else {
    ocPlan = existingOcPlans[0];
    ocPlan.Plan_Type__c = 'Time Linked Plan (OC Received / Date-Based)';
    ocPlan.Active__c = true;
    update ocPlan;
}

// Ensure Milestones for OC Plan
delete [SELECT Id FROM Payment_Milestone__c WHERE Payment_Plan__c = :ocPlan.Id];

List<Payment_Milestone__c> ocMilestones = new List<Payment_Milestone__c>{
    new Payment_Milestone__c(
        Name = 'Booking Token Amount (10%)',
        Payment_Plan__c = ocPlan.Id,
        Milestone_Order__c = 1,
        Milestone_Percentage__c = 10,
        Trigger_Event__c = 'Booking Token',
        Days_From_Booking__c = 0
    ),
    new Payment_Milestone__c(
        Name = '1st Date Installment - 30 Days Post Booking (30%)',
        Payment_Plan__c = ocPlan.Id,
        Milestone_Order__c = 2,
        Milestone_Percentage__c = 30,
        Trigger_Event__c = 'Agreement Execution',
        Days_From_Booking__c = 30
    ),
    new Payment_Milestone__c(
        Name = '2nd Date Installment - 60 Days Post Booking (30%)',
        Payment_Plan__c = ocPlan.Id,
        Milestone_Order__c = 3,
        Milestone_Percentage__c = 30,
        Trigger_Event__c = 'Superstructure',
        Days_From_Booking__c = 60
    ),
    new Payment_Milestone__c(
        Name = 'Final Date Installment - 90 Days / Possession (30%)',
        Payment_Plan__c = ocPlan.Id,
        Milestone_Order__c = 4,
        Milestone_Percentage__c = 30,
        Trigger_Event__c = 'Ready for Handover / Possession',
        Days_From_Booking__c = 90
    )
};
insert ocMilestones;
System.debug('Seeded ' + ocMilestones.size() + ' milestones for OC Received Plan.');

// 3. Configure Plan B: Construction Linked Plan (CLP / 10-Stage Civil Milestones) on Nikoo Homes
Payment_Plan__c clpPlan;
List<Payment_Plan__c> existingClpPlans = [
    SELECT Id, Name FROM Payment_Plan__c 
    WHERE Project__c = :nikooProj.Id AND Name LIKE '%10-Stage%'
    LIMIT 1
];

if (existingClpPlans.isEmpty()) {
    clpPlan = new Payment_Plan__c(
        Name = 'Nikoo Homes Construction Linked Plan (CLP / 10-Stage Civil Milestones)',
        Project__c = nikooProj.Id,
        Plan_Type__c = 'Construction Linked Plan (CLP / Milestone-Based)',
        Active__c = true,
        Description__c = 'Standard 10-stage civil construction linked plan from token through handover.'
    );
    insert clpPlan;
    System.debug('Created CLP 10-Stage Plan: ' + clpPlan.Id);
} else {
    clpPlan = existingClpPlans[0];
    clpPlan.Plan_Type__c = 'Construction Linked Plan (CLP / Milestone-Based)';
    clpPlan.Active__c = true;
    update clpPlan;
}

// Ensure 10 Civil Milestones for CLP Plan
delete [SELECT Id FROM Payment_Milestone__c WHERE Payment_Plan__c = :clpPlan.Id];

List<Payment_Milestone__c> clpMilestones = new List<Payment_Milestone__c>{
    new Payment_Milestone__c(
        Name = 'Stage 1: Booking Token & Application Advance (10%)',
        Payment_Plan__c = clpPlan.Id,
        Milestone_Order__c = 1,
        Milestone_Percentage__c = 10,
        Trigger_Event__c = 'Booking Token',
        Days_From_Booking__c = 0
    ),
    new Payment_Milestone__c(
        Name = 'Stage 2: On Agreement Signing & Allotment (10%)',
        Payment_Plan__c = clpPlan.Id,
        Milestone_Order__c = 2,
        Milestone_Percentage__c = 10,
        Trigger_Event__c = 'Agreement Execution',
        Days_From_Booking__c = 30
    ),
    new Payment_Milestone__c(
        Name = 'Stage 3: On Completion of Foundation & Excavation (10%)',
        Payment_Plan__c = clpPlan.Id,
        Milestone_Order__c = 3,
        Milestone_Percentage__c = 10,
        Trigger_Event__c = 'Foundation',
        Days_From_Booking__c = 75
    ),
    new Payment_Milestone__c(
        Name = 'Stage 4: On Casting of Plinth / Basement Slab (10%)',
        Payment_Plan__c = clpPlan.Id,
        Milestone_Order__c = 4,
        Milestone_Percentage__c = 10,
        Trigger_Event__c = 'Plinth / Basement Slab',
        Days_From_Booking__c = 120
    ),
    new Payment_Milestone__c(
        Name = 'Stage 5: On Completion of 1st Floor Slab (10%)',
        Payment_Plan__c = clpPlan.Id,
        Milestone_Order__c = 5,
        Milestone_Percentage__c = 10,
        Trigger_Event__c = '1st Floor Slab',
        Days_From_Booking__c = 165
    ),
    new Payment_Milestone__c(
        Name = 'Stage 6: On Completion of 3rd Floor Slab (10%)',
        Payment_Plan__c = clpPlan.Id,
        Milestone_Order__c = 6,
        Milestone_Percentage__c = 10,
        Trigger_Event__c = '3rd Floor Slab',
        Days_From_Booking__c = 210
    ),
    new Payment_Milestone__c(
        Name = 'Stage 7: On Completion of 5th Floor Slab (10%)',
        Payment_Plan__c = clpPlan.Id,
        Milestone_Order__c = 7,
        Milestone_Percentage__c = 10,
        Trigger_Event__c = '5th Floor Slab',
        Days_From_Booking__c = 255
    ),
    new Payment_Milestone__c(
        Name = 'Stage 8: On Brickwork & Internal Plastering (10%)',
        Payment_Plan__c = clpPlan.Id,
        Milestone_Order__c = 8,
        Milestone_Percentage__c = 10,
        Trigger_Event__c = 'Brickwork & Plastering',
        Days_From_Booking__c = 300
    ),
    new Payment_Milestone__c(
        Name = 'Stage 9: On Flooring & Internal MEP / Finishes (10%)',
        Payment_Plan__c = clpPlan.Id,
        Milestone_Order__c = 9,
        Milestone_Percentage__c = 10,
        Trigger_Event__c = 'Flooring & Internal Finishes',
        Days_From_Booking__c = 345
    ),
    new Payment_Milestone__c(
        Name = 'Stage 10: On Intimation of Handover & Possession (10%)',
        Payment_Plan__c = clpPlan.Id,
        Milestone_Order__c = 10,
        Milestone_Percentage__c = 10,
        Trigger_Event__c = 'Ready for Handover / Possession',
        Days_From_Booking__c = 390
    )
};
insert clpMilestones;
System.debug('Seeded ' + clpMilestones.size() + ' milestones for CLP 10-Stage Plan.');

// 4. Attach CLP Plan & Generate 10 Civil Installments for Booking BKG-0016 (Arjun Mehta, BR-82914)
Booking__c bkg16 = [SELECT Id, Name, Total_Booking_Amount__c, Token_Amount__c, Payment_Plan__c FROM Booking__c WHERE Booking_Reference_ID__c = 'BR-82914' LIMIT 1];
bkg16.Payment_Plan__c = clpPlan.Id;
update bkg16;

// Clear prior installments & receipts for BKG-0016
delete [SELECT Id FROM Receipt__c WHERE Booking__c = :bkg16.Id];
delete [SELECT Id FROM Installment__c WHERE Booking__c = :bkg16.Id];

// Generate 10 Civil Installments
CustomerLedgerController.generatePaymentPlanInstallments(bkg16.Id, clpPlan.Id);

List<Installment__c> bkg16Insts = [
    SELECT Id, Name, Due_Date__c, Amount__c, Paid_Amount__c, Status__c, Payment_Milestone__r.Milestone_Order__c,
           Payment_Milestone__r.Name
    FROM Installment__c 
    WHERE Booking__c = :bkg16.Id 
    ORDER BY Payment_Milestone__r.Milestone_Order__c ASC
];

System.debug('Generated ' + bkg16Insts.size() + ' installments for BKG-0016.');

// Milestone 1 (Token - ₹762,500): Paid & Confirmed
Installment__c inst1 = bkg16Insts[0];
inst1.Status__c = 'Paid';
inst1.Paid_Amount__c = 762500;
inst1.Due_Date__c = Date.today().addDays(-45);
inst1.Demand_Note_Number__c = 'DN-2026-9011';
inst1.Demand_Note_Date__c = Date.today().addDays(-45);
inst1.SAP_Bill_Block_Removed__c = true;
inst1.SAP_Invoice_Number__c = 'INV-SAP-2026-10021';
inst1.SAP_Invoice_Date__c = Date.today().addDays(-45);
update inst1;

Receipt__c rcpt1 = new Receipt__c(
    Booking__c = bkg16.Id,
    Installment__c = inst1.Id,
    Amount__c = 762500,
    Payment_Mode__c = 'NEFT/RTGS',
    Transaction_Reference__c = 'UTR-HDFC-9988112',
    Receipt_Date__c = Date.today().addDays(-44),
    Instrument_Date__c = Date.today().addDays(-44),
    Instrument_Number__c = 'HDFC-RTGS-9988112',
    Bank_Name__c = 'HDFC Bank, Koramangala',
    Status__c = 'Confirmed',
    SAP_Reconciled_Date__c = Date.today().addDays(-43),
    Finance_Approver__c = 'Prajwal Bharadwaj (Finance Controller)',
    Reconciliation_Notes__c = 'Cleared in SAP Bank GL account 110200.'
);
insert rcpt1;

// Milestone 2 (Agreement - ₹762,500): Paid & Confirmed
Installment__c inst2 = bkg16Insts[1];
inst2.Status__c = 'Paid';
inst2.Paid_Amount__c = 762500;
inst2.Due_Date__c = Date.today().addDays(-20);
inst2.Demand_Note_Number__c = 'DN-2026-9012';
inst2.Demand_Note_Date__c = Date.today().addDays(-20);
inst2.SAP_Bill_Block_Removed__c = true;
inst2.SAP_Invoice_Number__c = 'INV-SAP-2026-10042';
inst2.SAP_Invoice_Date__c = Date.today().addDays(-20);
update inst2;

Receipt__c rcpt2 = new Receipt__c(
    Booking__c = bkg16.Id,
    Installment__c = inst2.Id,
    Amount__c = 762500,
    Payment_Mode__c = 'NEFT/RTGS',
    Transaction_Reference__c = 'UTR-ICICI-7744119',
    Receipt_Date__c = Date.today().addDays(-19),
    Instrument_Date__c = Date.today().addDays(-19),
    Instrument_Number__c = 'ICICI-RTGS-7744119',
    Bank_Name__c = 'ICICI Bank, Indiranagar',
    Status__c = 'Confirmed',
    SAP_Reconciled_Date__c = Date.today().addDays(-18),
    Finance_Approver__c = 'Prajwal Bharadwaj (Finance Controller)',
    Reconciliation_Notes__c = 'Reconciled via SAP daily bank statement sync.'
);
insert rcpt2;

// Milestone 3 (Foundation - ₹762,500): Demand Issued, Overdue by 16 days, Reminder 1 (15 Days) sent, Receipt Logged as "Pending Reconciliation"
Installment__c inst3 = bkg16Insts[2];
inst3.Status__c = 'Due';
inst3.Due_Date__c = Date.today().addDays(-16);
inst3.Demand_Note_Number__c = 'DN-2026-9013';
inst3.Demand_Note_Date__c = Date.today().addDays(-16);
inst3.SAP_Bill_Block_Removed__c = true;
inst3.SAP_Invoice_Number__c = 'INV-SAP-2026-10088';
inst3.SAP_Invoice_Date__c = Date.today().addDays(-16);
inst3.Demand_Reminder_Level__c = 'Reminder 1 (15 Days)';
inst3.Last_Reminder_Date__c = Date.today().addDays(-1);
inst3.Days_Overdue__c = 16;
// 18% p.a. standard RERA simple interest
inst3.Overdue_Interest__c = (762500 * (0.18 / 365.0) * 16).setScale(2, System.RoundingMode.HALF_UP);
update inst3;

// Pending Reconciliation Receipt on Milestone 3: Customer transferred ₹762,500 via Cheque/Bank UTR, awaiting Finance & SAP approval
Receipt__c rcpt3 = new Receipt__c(
    Booking__c = bkg16.Id,
    Installment__c = inst3.Id,
    Amount__c = 762500,
    Payment_Mode__c = 'Cheque',
    Transaction_Reference__c = 'CHQ-AXIS-009182',
    Receipt_Date__c = Date.today(),
    Instrument_Date__c = Date.today().addDays(-2),
    Instrument_Number__c = 'CHQ-AXIS-009182',
    Bank_Name__c = 'Axis Bank, MG Road Branch',
    Status__c = 'Pending Reconciliation',
    Reconciliation_Notes__c = 'Cheque deposited in Axis Collection Account. Awaiting SAP bank ledger clearance by Finance persona.'
);
insert rcpt3;

// Milestone 4 (Plinth): Demand Issued, Status Due
Installment__c inst4 = bkg16Insts[3];
inst4.Status__c = 'Due';
inst4.Due_Date__c = Date.today().addDays(14);
inst4.Demand_Note_Number__c = 'DN-2026-9014';
inst4.Demand_Note_Date__c = Date.today();
inst4.SAP_Bill_Block_Removed__c = true;
inst4.SAP_Invoice_Number__c = 'INV-SAP-2026-10115';
inst4.SAP_Invoice_Date__c = Date.today();
update inst4;

// 5. Also configure Booking BKG-0009 (Skyline Crest Residences, Suresh Hegde, BR-50850) with OC Plan
Booking__c bkg9 = [SELECT Id, Name, Total_Booking_Amount__c, Token_Amount__c, Payment_Plan__c FROM Booking__c WHERE Booking_Reference_ID__c = 'BR-50850' LIMIT 1];
bkg9.Payment_Plan__c = ocPlan.Id;
update bkg9;

delete [SELECT Id FROM Receipt__c WHERE Booking__c = :bkg9.Id];
delete [SELECT Id FROM Installment__c WHERE Booking__c = :bkg9.Id];

CustomerLedgerController.generatePaymentPlanInstallments(bkg9.Id, ocPlan.Id);

List<Installment__c> bkg9Insts = [
    SELECT Id, Name, Due_Date__c, Amount__c, Paid_Amount__c, Status__c, Payment_Milestone__r.Milestone_Order__c,
           Payment_Milestone__r.Name
    FROM Installment__c 
    WHERE Booking__c = :bkg9.Id 
    ORDER BY Payment_Milestone__r.Milestone_Order__c ASC
];

// Milestone 1 (Token - ₹965,000): Paid
Installment__c b9Inst1 = bkg9Insts[0];
b9Inst1.Status__c = 'Paid';
b9Inst1.Paid_Amount__c = 965000;
b9Inst1.Demand_Note_Number__c = 'DN-2026-8001';
b9Inst1.Demand_Note_Date__c = Date.today().addDays(-60);
b9Inst1.SAP_Bill_Block_Removed__c = true;
b9Inst1.SAP_Invoice_Number__c = 'INV-SAP-2026-0801';
b9Inst1.SAP_Invoice_Date__c = Date.today().addDays(-60);
update b9Inst1;

insert new Receipt__c(
    Booking__c = bkg9.Id,
    Installment__c = b9Inst1.Id,
    Amount__c = 965000,
    Payment_Mode__c = 'NEFT/RTGS',
    Transaction_Reference__c = 'UTR-KOTAK-338821',
    Receipt_Date__c = Date.today().addDays(-59),
    Instrument_Date__c = Date.today().addDays(-59),
    Instrument_Number__c = 'KOTAK-RTGS-338821',
    Bank_Name__c = 'Kotak Mahindra Bank',
    Status__c = 'Confirmed',
    SAP_Reconciled_Date__c = Date.today().addDays(-58),
    Finance_Approver__c = 'Prajwal Bharadwaj',
    Reconciliation_Notes__c = 'SAP confirmed receipt.'
);

// Milestone 2 (30-day - ₹2,895,000): Demand Note issued, SAP Bill Block removed, SAP Tax Invoice generated
Installment__c b9Inst2 = bkg9Insts[1];
b9Inst2.Status__c = 'Due';
b9Inst2.Due_Date__c = Date.today().addDays(-15);
b9Inst2.Demand_Note_Number__c = 'DN-2026-8002';
b9Inst2.Demand_Note_Date__c = Date.today().addDays(-15);
b9Inst2.SAP_Bill_Block_Removed__c = true;
b9Inst2.SAP_Invoice_Number__c = 'INV-SAP-2026-0802';
b9Inst2.SAP_Invoice_Date__c = Date.today().addDays(-15);
b9Inst2.Demand_Reminder_Level__c = 'Reminder 1 (15 Days)';
b9Inst2.Last_Reminder_Date__c = Date.today();
update b9Inst2;

// Log pending partial receipt on Milestone 2
insert new Receipt__c(
    Booking__c = bkg9.Id,
    Installment__c = b9Inst2.Id,
    Amount__c = 1000000,
    Payment_Mode__c = 'NEFT/RTGS',
    Transaction_Reference__c = 'UTR-SBI-55991102',
    Receipt_Date__c = Date.today(),
    Instrument_Date__c = Date.today(),
    Instrument_Number__c = 'UTR-SBI-55991102',
    Bank_Name__c = 'State Bank of India',
    Status__c = 'Pending Reconciliation',
    Reconciliation_Notes__c = 'Partial NEFT payment of ₹10,00,000 received. Verification in SAP bank feeder pending.'
);

System.debug('=== Successfully Seeded Stage 5 Payment Plans, Milestones, SAP Invoices, and Reconciliation Receipts ===');
