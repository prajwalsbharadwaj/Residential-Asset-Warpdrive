// scripts/apex/load_demo_data.apex
// Seeds realistic Indian residential real estate demo data (Idempotent)

System.debug('Starting Residential Sales Demo Data Seeding...');

// Clean up existing demo data for clean re-run
delete [SELECT Id FROM Cancellation_Request__c];
delete [SELECT Id FROM Receipt__c];
delete [SELECT Id FROM Installment__c];
delete [SELECT Id FROM Booking_Applicant__c];
delete [SELECT Id FROM Booking__c];
delete [SELECT Id FROM Site_Visit__c];
delete [SELECT Id FROM Opportunity WHERE Name LIKE '%Deal'];
delete [SELECT Id FROM Lead WHERE Email LIKE '%.fake'];
delete [SELECT Id FROM Unit__c];
delete [SELECT Id FROM Floor__c];
delete [SELECT Id FROM Tower__c];
delete [SELECT Id FROM Payment_Milestone__c];
delete [SELECT Id FROM Payment_Plan__c];
delete [SELECT Id FROM Project__c WHERE Name LIKE 'Bhartiya City%'];
delete [SELECT Id FROM Contact WHERE Email LIKE '%.fake'];
delete [SELECT Id FROM Account WHERE Name LIKE 'Square Yards%' OR Name IN ('Arjun Mehta', 'Meera Nambiar', 'Suresh Hegde', 'Vikram Malhotra', 'Priya Nair')];

// Query Record Types
Id custAccRtId = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Customer' LIMIT 1].Id;
Id cpAccRtId = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Channel_Partner' LIMIT 1].Id;
Id resOppRtId = [SELECT Id FROM RecordType WHERE SobjectType = 'Opportunity' AND DeveloperName = 'Residential_Sales' LIMIT 1].Id;

// 1. CREATE CHANNEL PARTNER & CUSTOMER ACCOUNTS
Account cpAgency = new Account(
    Name = 'Square Yards Real Estate Solutions Pvt Ltd',
    RecordTypeId = cpAccRtId,
    RERA_Number__c = 'AG/KA/2026/001428',
    Agency_Name__c = 'Square Yards Karnataka',
    Phone = '+91 80 4123 5678'
);
insert cpAgency;

Contact brokerContact = new Contact(
    FirstName = 'Manish',
    LastName = 'Pandey',
    AccountId = cpAgency.Id,
    Title = 'Senior Channel Partner Manager',
    Email = 'manish.pandey@squareyards.fake',
    Phone = '+91 98450 11223'
);
insert brokerContact;

// Buyer Accounts & Contacts
List<Account> buyerAccounts = new List<Account>{
    new Account(Name = 'Arjun Mehta', RecordTypeId = custAccRtId, Phone = '+91 98201 23456'),
    new Account(Name = 'Meera Nambiar', RecordTypeId = custAccRtId, Phone = '+91 98452 34567'),
    new Account(Name = 'Suresh Hegde', RecordTypeId = custAccRtId, Phone = '+91 98860 45678'),
    new Account(Name = 'Vikram Malhotra', RecordTypeId = custAccRtId, Phone = '+91 99001 56789'),
    new Account(Name = 'Priya Nair', RecordTypeId = custAccRtId, Phone = '+91 98112 67890')
};
insert buyerAccounts;

List<Contact> buyerContacts = new List<Contact>{
    new Contact(FirstName = 'Arjun', LastName = 'Mehta', AccountId = buyerAccounts[0].Id, Email = 'arjun.mehta@example.fake', Phone = '+91 98201 23456'),
    new Contact(FirstName = 'Meera', LastName = 'Nambiar', AccountId = buyerAccounts[1].Id, Email = 'meera.nambiar@example.fake', Phone = '+91 98452 34567'),
    new Contact(FirstName = 'Suresh', LastName = 'Hegde', AccountId = buyerAccounts[2].Id, Email = 'suresh.hegde@example.fake', Phone = '+91 98860 45678'),
    new Contact(FirstName = 'Vikram', LastName = 'Malhotra', AccountId = buyerAccounts[3].Id, Email = 'vikram.malhotra@example.fake', Phone = '+91 99001 56789'),
    new Contact(FirstName = 'Priya', LastName = 'Nair', AccountId = buyerAccounts[4].Id, Email = 'priya.nair@example.fake', Phone = '+91 98112 67890'),
    new Contact(FirstName = 'Sunita', LastName = 'Hegde', AccountId = buyerAccounts[2].Id, Email = 'sunita.hegde@example.fake', Phone = '+91 98860 45679') // Co-applicant
};
insert buyerContacts;

// 2. CREATE 2 PROJECTS
Project__c p1 = new Project__c(
    Name = 'Bhartiya City Nikoo Homes IV',
    Location__c = 'Thanisandra Main Road, Bengaluru',
    Status__c = 'Under Construction',
    RERA_Registration_Number__c = 'PRM/KA/RERA/1251/472/PR/210526/004123',
    Total_Towers__c = 2,
    Description__c = 'Integrated smart township featuring premium 2, 3 and 4 BHK residential apartments.'
);
Project__c p2 = new Project__c(
    Name = 'Bhartiya City Leela Residences',
    Location__c = 'Hebbal, Bengaluru',
    Status__c = 'Under Construction',
    RERA_Registration_Number__c = 'PRM/KA/RERA/1251/309/PR/190820/002814',
    Total_Towers__c = 2,
    Description__c = 'Luxury branded residences offering bespoke concierge and five-star amenities.'
);
insert new List<Project__c>{ p1, p2 };

// 3. CREATE 4 TOWERS (2 per project)
Tower__c t1 = new Tower__c(Name = 'Tower A (Aspire)', Project__c = p1.Id, Total_Floors__c = 3, Construction_Status__c = 'Superstructure');
Tower__c t2 = new Tower__c(Name = 'Tower B (Breeze)', Project__c = p1.Id, Total_Floors__c = 3, Construction_Status__c = 'Plinth');
Tower__c t3 = new Tower__c(Name = 'Tower 1 (Orchid)', Project__c = p2.Id, Total_Floors__c = 3, Construction_Status__c = 'Finishing');
Tower__c t4 = new Tower__c(Name = 'Tower 2 (Palms)', Project__c = p2.Id, Total_Floors__c = 3, Construction_Status__c = 'Superstructure');
insert new List<Tower__c>{ t1, t2, t3, t4 };

// 4. CREATE 12 FLOORS (3 per tower)
List<Floor__c> floors = new List<Floor__c>();
List<Tower__c> allTowers = new List<Tower__c>{ t1, t2, t3, t4 };
for (Tower__c t : allTowers) {
    for (Integer f = 1; f <= 3; f++) {
        floors.add(new Floor__c(
            Name = t.Name + ' - Floor ' + f,
            Tower__c = t.Id,
            Floor_Number__c = f,
            Units_Per_Floor__c = 6
        ));
    }
}
insert floors;

// 5. CREATE 72 UNITS (6 units per floor)
List<Unit__c> units = new List<Unit__c>();
String[] configs = new String[]{ '2 BHK', '2 BHK', '3 BHK', '3 BHK', '3 BHK', '4 BHK' };
Decimal[] carpetAreas = new Decimal[]{ 980.0, 1050.0, 1420.0, 1550.0, 1680.0, 2250.0 };
Decimal[] basePrices = new Decimal[]{ 9500000.0, 10500000.0, 14500000.0, 16000000.0, 17500000.0, 26000000.0 };

Integer unitCounter = 1;
for (Floor__c fl : floors) {
    Integer fNum = fl.Floor_Number__c.intValue();
    for (Integer u = 1; u <= 6; u++) {
        String uCode = String.valueOf(fNum * 100 + u);
        String unitStatus = 'Available';
        if (unitCounter == 1 || unitCounter == 7 || unitCounter == 13) {
            unitStatus = 'Sold';
        } else if (unitCounter == 2 || unitCounter == 8) {
            unitStatus = 'Blocked';
        }
        
        Decimal bPrice = basePrices[u - 1];
        Decimal fRise = (fNum - 1) * 75000.0;
        Decimal tPrice = bPrice + fRise;

        units.add(new Unit__c(
            Name = 'Unit ' + uCode,
            Floor__c = fl.Id,
            Configuration__c = configs[u - 1],
            Carpet_Area_SqFt__c = carpetAreas[u - 1],
            Super_Built_Up_Area_SqFt__c = (carpetAreas[u - 1] * 1.35).setScale(2),
            Base_Price__c = bPrice,
            Total_Price__c = tPrice,
            Status__c = unitStatus,
            SAP_Material_Code__c = 'SAP-MAT-' + unitCounter
        ));
        unitCounter++;
    }
}
insert units;

// 6. CREATE PAYMENT PLAN & MILESTONES
Payment_Plan__c clpPlan = new Payment_Plan__c(
    Name = 'Nikoo Homes Construction Linked Plan (CLP)',
    Project__c = p1.Id,
    Plan_Type__c = 'Construction Linked Plan (CLP)',
    Active__c = true,
    Description__c = 'Standard 5-milestone construction linked payment plan.'
);
Payment_Plan__c subPlan = new Payment_Plan__c(
    Name = 'Leela Residences Premium Subvention Plan',
    Project__c = p2.Id,
    Plan_Type__c = 'Down Payment Plan',
    Active__c = true,
    Description__c = '10% on booking, 10% on agreement, 80% on possession.'
);
insert new List<Payment_Plan__c>{ clpPlan, subPlan };

List<Payment_Milestone__c> clpMilestones = new List<Payment_Milestone__c>{
    new Payment_Milestone__c(Name = 'Booking Token Amount', Payment_Plan__c = clpPlan.Id, Milestone_Order__c = 1, Milestone_Percentage__c = 10.0, Trigger_Event__c = 'Booking Token', Days_From_Booking__c = 0),
    new Payment_Milestone__c(Name = 'Agreement Execution', Payment_Plan__c = clpPlan.Id, Milestone_Order__c = 2, Milestone_Percentage__c = 10.0, Trigger_Event__c = 'Agreement Execution', Days_From_Booking__c = 30),
    new Payment_Milestone__c(Name = 'Foundation Completion', Payment_Plan__c = clpPlan.Id, Milestone_Order__c = 3, Milestone_Percentage__c = 20.0, Trigger_Event__c = 'Foundation', Days_From_Booking__c = 90),
    new Payment_Milestone__c(Name = 'Superstructure Slab', Payment_Plan__c = clpPlan.Id, Milestone_Order__c = 4, Milestone_Percentage__c = 30.0, Trigger_Event__c = 'Superstructure', Days_From_Booking__c = 180),
    new Payment_Milestone__c(Name = 'Possession & Handover', Payment_Plan__c = clpPlan.Id, Milestone_Order__c = 5, Milestone_Percentage__c = 30.0, Trigger_Event__c = 'Possession', Days_From_Booking__c = 360)
};
insert clpMilestones;

// 7. CREATE 10 REAL ESTATE LEADS
List<Lead> demoLeads = new List<Lead>{
    new Lead(FirstName = 'Rahul', LastName = 'Verma', Company = 'Infosys Technologies', Email = 'rahul.verma@example.fake', Phone = '+91 98450 12345', LeadSource = 'Website', Status = 'New - Not Contacted', Project_Enquired__c = p1.Id, Budget_Range__c = '1 Cr - 2 Cr', Configuration_Interested__c = '3 BHK'),
    new Lead(FirstName = 'Ananya', LastName = 'Sen', Company = 'Wipro Enterprises', Email = 'ananya.sen@example.fake', Phone = '+91 98451 23456', LeadSource = '99acres', Status = 'Working - Contacted', Project_Enquired__c = p1.Id, Budget_Range__c = '50L - 1 Cr', Configuration_Interested__c = '2 BHK'),
    new Lead(FirstName = 'Rohan', LastName = 'Joshi', Company = 'Cisco Systems India', Email = 'rohan.joshi@example.fake', Phone = '+91 98452 34567', LeadSource = 'MagicBricks', Status = 'Working - Contacted', Project_Enquired__c = p1.Id, Budget_Range__c = '1 Cr - 2 Cr', Configuration_Interested__c = '2.5 BHK'),
    new Lead(FirstName = 'Kavita', LastName = 'Rao', Company = 'Biocon Ltd', Email = 'kavita.rao@example.fake', Phone = '+91 98453 45678', LeadSource = 'Facebook Ads', Status = 'New - Not Contacted', Project_Enquired__c = p2.Id, Budget_Range__c = '2 Cr - 3.5 Cr', Configuration_Interested__c = '3 BHK'),
    new Lead(FirstName = 'Deepak', LastName = 'Patel', Company = 'Self Employed (Architect)', Email = 'deepak.patel@example.fake', Phone = '+91 98454 56789', LeadSource = 'Walk-in', Status = 'Working - Contacted', Project_Enquired__c = p1.Id, Budget_Range__c = '1 Cr - 2 Cr', Configuration_Interested__c = '3 BHK'),
    new Lead(FirstName = 'Siddharth', LastName = 'Menon', Company = 'Goldman Sachs Services', Email = 'siddharth.m@example.fake', Phone = '+91 98455 67890', LeadSource = 'Channel Partner', Status = 'Nurturing - Contacted', Project_Enquired__c = p2.Id, Budget_Range__c = '3.5 Cr+', Configuration_Interested__c = '4 BHK'),
    new Lead(FirstName = 'Pooja', LastName = 'Bhatia', Company = 'Myntra Designs', Email = 'pooja.bhatia@example.fake', Phone = '+91 98456 78901', LeadSource = 'Website', Status = 'New - Not Contacted', Project_Enquired__c = p1.Id, Budget_Range__c = '50L - 1 Cr', Configuration_Interested__c = '2 BHK'),
    new Lead(FirstName = 'Kiran', LastName = 'Deshmukh', Company = 'Dell EMC Bengaluru', Email = 'kiran.d@example.fake', Phone = '+91 98457 89012', LeadSource = '99acres', Status = 'Working - Contacted', Project_Enquired__c = p1.Id, Budget_Range__c = '1 Cr - 2 Cr', Configuration_Interested__c = '3 BHK'),
    new Lead(FirstName = 'Aditya', LastName = 'Kashyap', Company = 'Amazon Development Centre', Email = 'aditya.k@example.fake', Phone = '+91 98458 90123', LeadSource = 'Facebook Ads', Status = 'Nurturing - Contacted', Project_Enquired__c = p2.Id, Budget_Range__c = '2 Cr - 3.5 Cr', Configuration_Interested__c = '3 BHK'),
    new Lead(FirstName = 'Tanvi', LastName = 'Saxena', Company = 'Flipkart Internet Pvt Ltd', Email = 'tanvi.s@example.fake', Phone = '+91 98459 01234', LeadSource = 'Walk-in', Status = 'Working - Contacted', Project_Enquired__c = p1.Id, Budget_Range__c = '1 Cr - 2 Cr', Configuration_Interested__c = '2.5 BHK')
};
insert demoLeads;

// 8. CREATE 5 OPPORTUNITIES AT DIFFERENT STAGES (TAGGED TO UNITS)
List<Opportunity> demoOpps = new List<Opportunity>{
    new Opportunity(
        Name = 'Arjun Mehta - Nikoo A-101 Deal',
        AccountId = buyerAccounts[0].Id,
        RecordTypeId = resOppRtId,
        StageName = 'Closed Won',
        CloseDate = Date.today().addDays(-20),
        Amount = units[0].Total_Price__c,
        Project__c = p1.Id,
        Tagged_Unit__c = units[0].Id,
        Booking_Form_Approved__c = true,
        Token_Payment_Received__c = true
    ),
    new Opportunity(
        Name = 'Meera Nambiar - Nikoo B-203 Deal',
        AccountId = buyerAccounts[1].Id,
        RecordTypeId = resOppRtId,
        StageName = 'Booking Form Approved',
        CloseDate = Date.today().addDays(5),
        Amount = units[7].Total_Price__c,
        Project__c = p1.Id,
        Tagged_Unit__c = units[7].Id,
        Booking_Form_Approved__c = true,
        Token_Payment_Received__c = true
    ),
    new Opportunity(
        Name = 'Suresh Hegde - Leela Orchid-102 Deal',
        AccountId = buyerAccounts[2].Id,
        RecordTypeId = resOppRtId,
        StageName = 'Closed Won',
        CloseDate = Date.today().addDays(-60),
        Amount = units[12].Total_Price__c,
        Project__c = p2.Id,
        Tagged_Unit__c = units[12].Id,
        Booking_Form_Approved__c = true,
        Token_Payment_Received__c = true
    ),
    new Opportunity(
        Name = 'Vikram Malhotra - Nikoo A-102 Deal',
        AccountId = buyerAccounts[3].Id,
        RecordTypeId = resOppRtId,
        StageName = 'In Progress',
        CloseDate = Date.today().addDays(30),
        Amount = units[1].Total_Price__c,
        Project__c = p1.Id,
        Tagged_Unit__c = units[1].Id
    ),
    new Opportunity(
        Name = 'Priya Nair - Leela Palms-103 Deal',
        AccountId = buyerAccounts[4].Id,
        RecordTypeId = resOppRtId,
        StageName = 'SV Done',
        CloseDate = Date.today().addDays(45),
        Amount = units[14].Total_Price__c,
        Project__c = p2.Id,
        Tagged_Unit__c = units[14].Id
    )
};
insert demoOpps;

// 9. CREATE SITE VISITS
List<Site_Visit__c> demoSiteVisits = new List<Site_Visit__c>{
    new Site_Visit__c(
        Lead__c = demoLeads[4].Id,
        Project__c = p1.Id,
        Visit_Date_Time__c = DateTime.now().addDays(-2),
        Status__c = 'Conducted',
        Rating__c = 'Hot',
        Feedback__c = 'Customer loved the 3 BHK show home layout and Nikoo clubhouse facilities. Likely to book this week.'
    ),
    new Site_Visit__c(
        Opportunity__c = demoOpps[4].Id,
        Customer__c = buyerAccounts[4].Id,
        Project__c = p2.Id,
        Visit_Date_Time__c = DateTime.now().addDays(-5),
        Status__c = 'Conducted',
        Rating__c = 'Hot',
        Feedback__c = 'Impressed by the Leela branded service specifications. Requested detailed cost sheet and subvention plan.'
    ),
    new Site_Visit__c(
        Lead__c = demoLeads[0].Id,
        Project__c = p1.Id,
        Visit_Date_Time__c = DateTime.now().addDays(2),
        Status__c = 'Scheduled',
        Rating__c = 'Warm',
        Feedback__c = 'Site visit confirmed for Saturday morning. GRE team notified.'
    )
};
insert demoSiteVisits;

// 10. CREATE 3 REALISTIC BOOKINGS WITH INSTALLMENTS
// Booking 1: Arjun Mehta (Active, Paid Milestones)
Booking__c b1 = new Booking__c(
    Opportunity__c = demoOpps[0].Id,
    Customer__c = buyerAccounts[0].Id,
    Unit__c = units[0].Id,
    Payment_Plan__c = clpPlan.Id,
    Booking_Date__c = Date.today().addDays(-20),
    Total_Booking_Amount__c = units[0].Total_Price__c,
    Status__c = 'Active',
    SAP_Customer_Code__c = 'SAP-CUST-10492'
);
// Booking 2: Meera Nambiar (KYC in Progress)
Booking__c b2 = new Booking__c(
    Opportunity__c = demoOpps[1].Id,
    Customer__c = buyerAccounts[1].Id,
    Unit__c = units[7].Id,
    Payment_Plan__c = clpPlan.Id,
    Booking_Date__c = Date.today().addDays(-3),
    Total_Booking_Amount__c = units[7].Total_Price__c,
    Status__c = 'KYC in Progress',
    SAP_Customer_Code__c = 'SAP-CUST-10518'
);
// Booking 3: Suresh Hegde (Active, DELIBERATELY OVERDUE INSTALLMENT)
Booking__c b3 = new Booking__c(
    Opportunity__c = demoOpps[2].Id,
    Customer__c = buyerAccounts[2].Id,
    Unit__c = units[12].Id,
    Payment_Plan__c = clpPlan.Id,
    Booking_Date__c = Date.today().addDays(-60),
    Total_Booking_Amount__c = units[12].Total_Price__c,
    Status__c = 'Active',
    SAP_Customer_Code__c = 'SAP-CUST-10385'
);
insert new List<Booking__c>{ b1, b2, b3 };

// Junction: Booking Applicants (12-character masked Aadhaar format XXXXXXXX1234)
List<Booking_Applicant__c> applicants = new List<Booking_Applicant__c>{
    new Booking_Applicant__c(Booking__c = b1.Id, Contact__c = buyerContacts[0].Id, Applicant_Role__c = 'Primary Applicant', Is_Financial_Applicant__c = true, PAN__c = 'ABCDE1234F', Aadhaar_Masked__c = 'XXXXXXXX9012', KYC_Status__c = 'Verified'),
    new Booking_Applicant__c(Booking__c = b2.Id, Contact__c = buyerContacts[1].Id, Applicant_Role__c = 'Primary Applicant', Is_Financial_Applicant__c = true, PAN__c = 'BNKPM5678G', Aadhaar_Masked__c = 'XXXXXXXX4531', KYC_Status__c = 'Submitted'),
    new Booking_Applicant__c(Booking__c = b3.Id, Contact__c = buyerContacts[2].Id, Applicant_Role__c = 'Primary Applicant', Is_Financial_Applicant__c = true, PAN__c = 'CHGPS9012H', Aadhaar_Masked__c = 'XXXXXXXX8921', KYC_Status__c = 'Verified'),
    new Booking_Applicant__c(Booking__c = b3.Id, Contact__c = buyerContacts[5].Id, Applicant_Role__c = 'Co-Applicant', Is_Financial_Applicant__c = true, PAN__c = 'DHGPM3456K', Aadhaar_Masked__c = 'XXXXXXXX7722', KYC_Status__c = 'Verified')
};
insert applicants;

// Installments for Booking 1 (Arjun Mehta - Paid)
Decimal b1Amt = units[0].Total_Price__c;
Installment__c b1_inst1 = new Installment__c(Booking__c = b1.Id, Payment_Milestone__c = clpMilestones[0].Id, Due_Date__c = Date.today().addDays(-20), Amount__c = b1Amt * 0.10, Paid_Amount__c = b1Amt * 0.10, Status__c = 'Paid');
Installment__c b1_inst2 = new Installment__c(Booking__c = b1.Id, Payment_Milestone__c = clpMilestones[1].Id, Due_Date__c = Date.today().addDays(10), Amount__c = b1Amt * 0.10, Paid_Amount__c = 0.0, Status__c = 'Upcoming');
insert new List<Installment__c>{ b1_inst1, b1_inst2 };

// Installments for Booking 2 (Meera Nambiar - Due Token)
Decimal b2Amt = units[7].Total_Price__c;
Installment__c b2_inst1 = new Installment__c(Booking__c = b2.Id, Payment_Milestone__c = clpMilestones[0].Id, Due_Date__c = Date.today().addDays(2), Amount__c = b2Amt * 0.10, Paid_Amount__c = 0.0, Status__c = 'Due');
insert b2_inst1;

// Installments for Booking 3 (Suresh Hegde - DELIBERATELY OVERDUE FOR INTEREST DEMO)
Decimal b3Amt = units[12].Total_Price__c;
Installment__c b3_inst1 = new Installment__c(Booking__c = b3.Id, Payment_Milestone__c = clpMilestones[0].Id, Due_Date__c = Date.today().addDays(-60), Amount__c = b3Amt * 0.10, Paid_Amount__c = b3Amt * 0.10, Status__c = 'Paid');
// Milestone 2 was due 45 days ago! Outstanding amount: 18,50,000
Decimal overdueOutstanding = (b3Amt * 0.10).setScale(2);
Integer daysOverdue = 45;
// 18% simple interest: Outstanding * 0.18 * (days / 365)
Decimal overdueInterest = (overdueOutstanding * 0.18 * (daysOverdue / 365.0)).setScale(2);

Installment__c b3_inst2 = new Installment__c(
    Booking__c = b3.Id,
    Payment_Milestone__c = clpMilestones[1].Id,
    Due_Date__c = Date.today().addDays(-daysOverdue),
    Amount__c = overdueOutstanding,
    Paid_Amount__c = 0.0,
    Status__c = 'Overdue',
    Days_Overdue__c = daysOverdue,
    Overdue_Interest__c = overdueInterest,
    Interest_Waived__c = false
);
insert new List<Installment__c>{ b3_inst1, b3_inst2 };

// 11. CREATE RECEIPTS
// Paid receipt for Booking 1 Token
Receipt__c r1 = new Receipt__c(
    Installment__c = b1_inst1.Id,
    Receipt_Date__c = Date.today().addDays(-20),
    Amount__c = b1_inst1.Amount__c,
    Payment_Mode__c = 'NEFT/RTGS',
    Transaction_Reference__c = 'HDFC-N98234710492',
    Status__c = 'Confirmed',
    Reconciliation_Notes__c = 'Verified in HDFC Project Escrow Account via SAP bank reconciliation statement.'
);

// PENDING RECONCILIATION Receipt for Suresh Hegde (ready for Approval Process demo!)
Receipt__c r2 = new Receipt__c(
    Installment__c = b3_inst2.Id,
    Receipt_Date__c = Date.today(),
    Amount__c = overdueOutstanding,
    Payment_Mode__c = 'NEFT/RTGS',
    Transaction_Reference__c = 'ICICI-UTR-90182746192',
    Status__c = 'Pending Reconciliation',
    Reconciliation_Notes__c = 'Customer shared UTR via WhatsApp after demand reminder. Awaiting Finance verification against SAP bank ledger.'
);
insert new List<Receipt__c>{ r1, r2 };

// 12. CREATE SAMPLE CANCELLATION REQUEST (DEMO EXCEPTION FLOW)
Cancellation_Request__c canReq = new Cancellation_Request__c(
    Booking__c = b1.Id,
    Request_Date__c = Date.today().addDays(-2),
    Reason__c = 'Personal Reasons',
    Status__c = 'Draft',
    Total_Paid_Amount__c = b1_inst1.Amount__c,
    Cancellation_Charges__c = 50000.0,
    Refund_Amount__c = b1_inst1.Amount__c - 50000.0,
    Remarks__c = 'Customer enquired about cancellation process due to overseas relocation opportunity; draft request logged for evaluation.'
);
insert canReq;

System.debug('Residential Sales Demo Data Seeding Completed Successfully!');
System.debug('Total Projects: ' + [SELECT COUNT() FROM Project__c]);
System.debug('Total Towers: ' + [SELECT COUNT() FROM Tower__c]);
System.debug('Total Floors: ' + [SELECT COUNT() FROM Floor__c]);
System.debug('Total Units: ' + [SELECT COUNT() FROM Unit__c]);
System.debug('Total Leads: ' + [SELECT COUNT() FROM Lead]);
System.debug('Total Opportunities: ' + [SELECT COUNT() FROM Opportunity]);
System.debug('Total Bookings: ' + [SELECT COUNT() FROM Booking__c]);
System.debug('Total Installments: ' + [SELECT COUNT() FROM Installment__c]);
System.debug('Total Receipts: ' + [SELECT COUNT() FROM Receipt__c]);
