// =========================================================================
// REAL ESTATE CRM DEMO DATA ENGINE - NIKOO & PREMIUM RESIDENTIAL BENCHMARKS
// =========================================================================

System.debug('>>> Starting Real Estate Rich Demo Data Seeding...');

// 1. CALIBRATE & STANDARDIZE PROJECTS
List<Project__c> projects = [SELECT Id, Name, Status__c, Location__c FROM Project__c ORDER BY CreatedDate ASC];
Project__c proj1;
Project__c proj2;
Project__c proj3;

if (projects.size() >= 1) {
    proj1 = projects[0];
    proj1.Name = 'Nikoo Homes II - Integrated Township';
    proj1.Location__c = 'Thanisandra Main Road, North Bengaluru';
    proj1.Status__c = 'Under Construction';
    update proj1;
}

if (projects.size() >= 2) {
    proj2 = projects[1];
    proj2.Name = 'Skyline Crest Residences';
    proj2.Location__c = 'Hebbal Lakeview, Bengaluru';
    proj2.Status__c = 'Under Construction';
    update proj2;
}

if (projects.size() < 3) {
    proj3 = new Project__c(
        Name = 'The Grand Orchards Luxury Towers',
        Location__c = 'Whitefield Tech Corridor, Bengaluru',
        Status__c = 'Under Construction'
    );
    insert proj3;
} else {
    proj3 = projects[2];
    proj3.Name = 'The Grand Orchards Luxury Towers';
    proj3.Location__c = 'Whitefield Tech Corridor, Bengaluru';
    update proj3;
}

System.debug('Projects standardized: ' + proj1.Name + ', ' + proj2.Name + ', ' + proj3.Name);

// 2. CALIBRATE ALL EXISTING UNITS TO SANE PER-SQFT BASE RATES & EXACT TOTALS
List<Unit__c> unitsToUpdate = [
    SELECT Id, Name, Configuration__c, Status__c, Base_Price__c, 
           Super_Built_Up_Area_SqFt__c, Carpet_Area_SqFt__c, Total_Price__c,
           Floor__r.Floor_Number__c, Floor__r.Tower__r.Name
    FROM Unit__c
];

Integer uCount = 0;
for (Unit__c u : unitsToUpdate) {
    Decimal flrNum = (u.Floor__r != null && u.Floor__r.Floor_Number__c != null) ? u.Floor__r.Floor_Number__c : 5;
    Decimal floorRise = Math.floor((flrNum - 1) / 4) * 50;

    if (u.Configuration__c == '1 BHK' || u.Configuration__c == 'Studio') {
        u.Configuration__c = '1 BHK';
        u.Super_Built_Up_Area_SqFt__c = 620;
        u.Carpet_Area_SqFt__c = 470;
        u.Base_Price__c = 4530;
        Decimal effRate = 4530 + floorRise;
        u.Total_Price__c = Math.round(620 * effRate);
    } else if (u.Configuration__c == '3 BHK') {
        u.Super_Built_Up_Area_SqFt__c = 1420;
        u.Carpet_Area_SqFt__c = 1100;
        u.Base_Price__c = 4650;
        Decimal effRate = 4650 + floorRise;
        u.Total_Price__c = Math.round(1420 * effRate);
    } else if (u.Configuration__c == '4 BHK') {
        u.Super_Built_Up_Area_SqFt__c = 1950;
        u.Carpet_Area_SqFt__c = 1520;
        u.Base_Price__c = 4850;
        Decimal effRate = 4850 + floorRise;
        u.Total_Price__c = Math.round(1950 * effRate);
    } else {
        // Default 2 BHK
        u.Configuration__c = '2 BHK';
        u.Super_Built_Up_Area_SqFt__c = 1050;
        u.Carpet_Area_SqFt__c = 798;
        u.Base_Price__c = 4580;
        Decimal effRate = 4580 + floorRise;
        u.Total_Price__c = Math.round(1050 * effRate);
    }
    
    // Assign varied inventory statuses
    if (Math.mod(uCount, 12) == 0) {
        u.Status__c = 'Sold';
    } else if (Math.mod(uCount, 7) == 0) {
        u.Status__c = 'Blocked';
    } else {
        u.Status__c = 'Available';
    }
    uCount++;
}
update unitsToUpdate;
System.debug('Successfully calibrated ' + unitsToUpdate.size() + ' units to real estate standards.');

// 3. CREATE RICH LEADS WITH DIVERSE SOURCES & ARCHIVE POLICIES
List<Lead> sampleLeads = new List<Lead>{
    new Lead(
        FirstName = 'Dr. Sandeep',
        LastName = 'Kulkarni',
        Company = 'Manipal Hospitals - Cardiology',
        Title = 'Chief Interventional Cardiologist',
        Email = 'sandeep.kulkarni@manipal.example.com',
        Phone = '9845123981',
        LeadSource = 'MagicBricks',
        Status = 'Working - Contacted',
        Budget_Range__c = '1 Cr - 2 Cr',
        Configuration_Interested__c = '3 BHK',
        Archive_For_In_Days__c = 14,
        Project_Enquired__c = proj1.Id
    ),
    new Lead(
        FirstName = 'Vikramaditya',
        LastName = 'Roy',
        Company = 'Google Cloud India',
        Title = 'Engineering Director',
        Email = 'vikram.roy@gcloud.example.com',
        Phone = '9880192847',
        LeadSource = '99acres',
        Status = 'SV Scheduled',
        Budget_Range__c = '3.5 Cr+',
        Configuration_Interested__c = '4 BHK',
        Project_Enquired__c = proj1.Id
    ),
    new Lead(
        FirstName = 'Pooja',
        LastName = 'Nambiar',
        Company = 'Swiggy Technologies',
        Title = 'VP Product Management',
        Email = 'pooja.nambiar@swiggy.example.com',
        Phone = '9741284719',
        LeadSource = 'Walk-in',
        Status = 'SV Done',
        Budget_Range__c = '1 Cr - 2 Cr',
        Configuration_Interested__c = '2 BHK',
        Project_Enquired__c = proj1.Id
    ),
    new Lead(
        FirstName = 'Meera',
        LastName = 'Sundaram',
        Company = 'EdVantage Ventures',
        Title = 'Managing Partner',
        Email = 'meera@edvantage.example.com',
        Phone = '9632819402',
        LeadSource = 'Channel Partner',
        Status = 'New - Not Contacted',
        Budget_Range__c = '50L - 1 Cr',
        Configuration_Interested__c = '1 BHK',
        Archive_For_In_Days__c = 7,
        Project_Enquired__c = proj2.Id
    ),
    new Lead(
        FirstName = 'Kunal',
        LastName = 'Singhania',
        Company = 'Studio Terra Architects',
        Title = 'Principal Partner',
        Email = 'kunal@studioterra.example.com',
        Phone = '9900218493',
        LeadSource = 'Website',
        Status = 'Working - Contacted',
        Budget_Range__c = '2 Cr - 3.5 Cr',
        Configuration_Interested__c = '3 BHK',
        Project_Enquired__c = proj3.Id
    )
};
insert sampleLeads;
System.debug('Created ' + sampleLeads.size() + ' rich real estate Leads.');

// 4. CREATE LOGGED & OTP-VERIFIED SITE VISITS FOR LEADS
List<Site_Visit__c> visits = new List<Site_Visit__c>();
visits.add(new Site_Visit__c(
    Lead__c = sampleLeads[0].Id,
    Project__c = proj1.Id,
    Visit_Date_Time__c = DateTime.now().addDays(-2),
    OTP_Verified__c = true,
    OTP_Code__c = '839201',
    Status__c = 'Conducted',
    Rating__c = 'Hot',
    Visitor_Mobile__c = sampleLeads[0].Phone,
    Feedback__c = 'Doctor loved the 3 BHK corner view and Olympic pool clubhouse. Keen on Tower A Level 8.'
));

visits.add(new Site_Visit__c(
    Lead__c = sampleLeads[2].Id,
    Project__c = proj1.Id,
    Visit_Date_Time__c = DateTime.now().addDays(-1),
    OTP_Verified__c = true,
    OTP_Code__c = '492817',
    Status__c = 'Conducted',
    Rating__c = 'Warm',
    Visitor_Mobile__c = sampleLeads[2].Phone,
    Feedback__c = 'Sample flat walk completed. Loved the open modular kitchen and Italian marble finish.'
));
insert visits;

// Update Lead flags
sampleLeads[0].Has_Site_Visit__c = true;
sampleLeads[0].Site_Visit_Count__c = 1;
sampleLeads[2].Has_Site_Visit__c = true;
sampleLeads[2].Site_Visit_Count__c = 1;
update new List<Lead>{ sampleLeads[0], sampleLeads[2] };

System.debug('Site Visits logged and Leads updated.');

// 5. SEED STANDARD REAL ESTATE PIPELINE OPPORTUNITIES WITH CALIBRATED QUOTES
// Pick 5 distinct Available units
List<Unit__c> freeUnits = [
    SELECT Id, Name, Configuration__c, Base_Price__c, Super_Built_Up_Area_SqFt__c, Floor__r.Floor_Number__c
    FROM Unit__c 
    WHERE Status__c = 'Available' 
    ORDER BY Floor__r.Floor_Number__c ASC 
    LIMIT 10
];

// Accounts for Opportunities
Account accRajesh = new Account(Name = 'Rajesh Verma (IT Exec)', Phone = '9845112233', BillingCity = 'Bengaluru');
Account accVikram = new Account(Name = 'Vikramaditya Roy (Director)', Phone = '9880192847', BillingCity = 'Bengaluru');
Account accAmit = new Account(Name = 'Amit & Pooja Nambiar', Phone = '9741284719', BillingCity = 'Bengaluru');
Account accArjun = new Account(Name = 'Arjun Mehta (Senior Architect)', Phone = '9988776655', BillingCity = 'Bengaluru');
insert new List<Account>{ accRajesh, accVikram, accAmit, accArjun };

// -------------------------------------------------------------
// OPP 1: STAGE = 'Unit Selection' (Evaluating inventory)
// -------------------------------------------------------------
Opportunity oppUnitSel = new Opportunity(
    Name = 'Vikramaditya Roy - Skyline Crest 3 BHK',
    AccountId = accVikram.Id,
    Project__c = proj2.Id,
    Tagged_Unit__c = freeUnits[0].Id,
    StageName = 'Unit Selection',
    Amount = 6845000,
    CloseDate = Date.today().addDays(45)
);
insert oppUnitSel;

// -------------------------------------------------------------
// OPP 2: STAGE = 'Quotation Shared' (Quote generated, shared with customer)
// -------------------------------------------------------------
Unit__c u2 = freeUnits[1];
Opportunity oppQuoteShared = new Opportunity(
    Name = 'Amit & Pooja Nambiar - Nikoo II 2 BHK',
    AccountId = accAmit.Id,
    Project__c = proj1.Id,
    Tagged_Unit__c = u2.Id,
    StageName = 'Quotation Shared',
    Amount = 5389650,
    CloseDate = Date.today().addDays(30)
);
insert oppQuoteShared;

Quote q2 = new Quote(
    OpportunityId = oppQuoteShared.Id,
    Name = 'Quotation - ' + u2.Name + ' (2 BHK)',
    Status = 'Presented',
    Description = 'Unit: ' + u2.Name + ' | Config: 2 BHK | SBA: 1050 Sq.Ft. | Base Rate: ₹4,580/sq.ft. | Discount: ₹50/sq.ft. | 1 Covered Parking: ₹2,75,000 | Grand Total: ₹53,89,650'
);
insert q2;

// -------------------------------------------------------------
// OPP 3: STAGE = 'Negotiation & Review' (Reviewing commercial terms)
// -------------------------------------------------------------
Unit__c u3 = freeUnits[2];
Opportunity oppNeg = new Opportunity(
    Name = 'Dr. Sandeep Kulkarni - Nikoo II 3 BHK Luxury',
    AccountId = accRajesh.Id,
    Project__c = proj1.Id,
    Tagged_Unit__c = u3.Id,
    StageName = 'Negotiation & Review',
    Amount = 7468800,
    CloseDate = Date.today().addDays(20)
);
insert oppNeg;

Quote q3 = new Quote(
    OpportunityId = oppNeg.Id,
    Name = 'Quotation - ' + u3.Name + ' (3 BHK) [Under Review]',
    Status = 'Presented',
    Description = 'Unit: ' + u3.Name + ' | Config: 3 BHK | SBA: 1420 Sq.Ft. | Base Rate: ₹4,650/sq.ft. | Discount: ₹100/sq.ft. | 1 Covered Parking: ₹2,75,000 | Grand Total: ₹74,68,800'
);
insert q3;

// -------------------------------------------------------------
// OPP 4: STAGE = 'Quotation Agreed' (Customer accepted, ready for SAP sync!)
// Exact Nikoo Homes II benchmark: 620 sqft, Level 6 -> Grand Total = ₹36,43,400!
// -------------------------------------------------------------
Unit__c u4 = freeUnits[3];
Opportunity oppAgreed = new Opportunity(
    Name = 'Rajesh Verma - Nikoo II 1 BHK Benchmark Deal',
    AccountId = accRajesh.Id,
    Project__c = proj1.Id,
    Tagged_Unit__c = u4.Id,
    StageName = 'Quotation Agreed',
    Amount = 3643400,
    CloseDate = Date.today().addDays(15)
);
insert oppAgreed;

Quote q4 = new Quote(
    OpportunityId = oppAgreed.Id,
    Name = 'Quotation - ' + u4.Name + ' (1 BHK - Level 6 Benchmark)',
    Status = 'Accepted',
    Description = 'Unit: ' + u4.Name + ' | Config: 1 BHK | Super Built-Up Area: 620 Sq.Ft. (Locked) | Base Rate: ₹4,580/sq.ft. | PLC: ₹100/sq.ft. | Parking: 1 Bay (₹2,75,000) | Net Agreement Value: ₹31,76,600 | Grand Total: ₹36,43,400 (Exact Nikoo Benchmark)'
);
insert q4;

// -------------------------------------------------------------
// OPP 5: STAGE = 'Closed Won' (Booked, SAP Synced, Ledger Active!)
// -------------------------------------------------------------
Unit__c u5 = freeUnits[4];

Opportunity oppClosed = new Opportunity(
    Name = 'Arjun Mehta - Nikoo II 3 BHK Executive Suite',
    AccountId = accArjun.Id,
    Project__c = proj1.Id,
    Tagged_Unit__c = u5.Id,
    StageName = 'Quotation Agreed', // temporary stage to satisfy OpportunityTrigger
    Amount = 7625000,
    CloseDate = Date.today().addDays(-5)
);
insert oppClosed;

Quote q5 = new Quote(
    OpportunityId = oppClosed.Id,
    Name = 'Quotation - ' + u5.Name + ' (3 BHK Agreed)',
    Status = 'Accepted',
    Description = 'Unit: ' + u5.Name + ' | Config: 3 BHK | SBA: 1420 Sq.Ft. | Base Rate: ₹4,650/sq.ft. | 1 Parking Bay | Grand Total: ₹76,25,000'
);
insert q5;

// Now mark unit as Blocked upon booking
u5.Status__c = 'Blocked';
update u5;

// Advance to Closed Won
oppClosed.StageName = 'Closed Won';
update oppClosed;

// Create Booking record
Booking__c bkg = new Booking__c(
    Opportunity__c = oppClosed.Id,
    Customer__c = accArjun.Id,
    Unit__c = u5.Id,
    Booking_Reference_ID__c = 'BR-82914',
    SAP_Customer_Code__c = 'SAP-CUST-91402',
    Status__c = 'Active',
    Booking_Date__c = Date.today().addDays(-10),
    Total_Booking_Amount__c = 7625000,
    Token_Amount__c = 762500 // 10%
);
insert bkg;

// Create Primary Booking Applicant
Booking_Applicant__c bkgApp = new Booking_Applicant__c(
    Booking__c = bkg.Id,
    Applicant_Role__c = 'Primary Applicant',
    KYC_Status__c = 'Verified',
    Is_Financial_Applicant__c = true,
    PAN__c = 'ABCDE1234F',
    Aadhaar_Masked__c = 'XXXXXXXX1098'
);
insert bkgApp;

// Payment Plan & Milestones for Ledger
Payment_Plan__c clpPlan = new Payment_Plan__c(
    Name = 'Construction Linked Plan (CLP) - 10:10:80',
    Project__c = proj1.Id,
    Plan_Type__c = 'Construction Linked Plan (CLP)',
    Active__c = true
);
insert clpPlan;

Payment_Milestone__c pm1 = new Payment_Milestone__c(Name = 'Booking Token Advance', Payment_Plan__c = clpPlan.Id, Milestone_Percentage__c = 10, Milestone_Order__c = 1);
Payment_Milestone__c pm2 = new Payment_Milestone__c(Name = 'On Agreement Signing (10%)', Payment_Plan__c = clpPlan.Id, Milestone_Percentage__c = 10, Milestone_Order__c = 2);
Payment_Milestone__c pm3 = new Payment_Milestone__c(Name = 'On Completion of Excavation (5%)', Payment_Plan__c = clpPlan.Id, Milestone_Percentage__c = 5, Milestone_Order__c = 3);
Payment_Milestone__c pm4 = new Payment_Milestone__c(Name = 'On 5th Floor Slab Cast (10%)', Payment_Plan__c = clpPlan.Id, Milestone_Percentage__c = 10, Milestone_Order__c = 4);
insert new List<Payment_Milestone__c>{ pm1, pm2, pm3, pm4 };

// Create Milestone Installments for Customer Ledger
List<Installment__c> instList = new List<Installment__c>{
    new Installment__c(
        Booking__c = bkg.Id,
        Payment_Milestone__c = pm1.Id,
        Amount__c = 762500,
        Due_Date__c = Date.today().addDays(-10),
        Status__c = 'Paid',
        Paid_Amount__c = 762500,
        Demand_Note_Number__c = 'DN-2026-001',
        Demand_Note_Date__c = Date.today().addDays(-15),
        Waiver_Status__c = 'None'
    ),
    new Installment__c(
        Booking__c = bkg.Id,
        Payment_Milestone__c = pm2.Id,
        Amount__c = 762500,
        Due_Date__c = Date.today().addDays(-2),
        Status__c = 'Paid',
        Paid_Amount__c = 762500,
        Demand_Note_Number__c = 'DN-2026-002',
        Demand_Note_Date__c = Date.today().addDays(-20),
        Waiver_Status__c = 'None'
    ),
    new Installment__c(
        Booking__c = bkg.Id,
        Payment_Milestone__c = pm3.Id,
        Amount__c = 381250,
        Due_Date__c = Date.today().addDays(15),
        Status__c = 'Due',
        Paid_Amount__c = 0,
        Demand_Note_Number__c = 'DN-2026-003',
        Demand_Note_Date__c = Date.today(),
        Waiver_Status__c = 'None'
    ),
    new Installment__c(
        Booking__c = bkg.Id,
        Payment_Milestone__c = pm4.Id,
        Amount__c = 762500,
        Due_Date__c = Date.today().addDays(60),
        Status__c = 'Upcoming',
        Paid_Amount__c = 0,
        Waiver_Status__c = 'None'
    )
};
insert instList;

// Create Receipts for Paid Installments
List<Receipt__c> receipts = new List<Receipt__c>{
    new Receipt__c(
        Booking__c = bkg.Id,
        Installment__c = instList[0].Id,
        Amount__c = 762500,
        Receipt_Date__c = Date.today().addDays(-10),
        Payment_Mode__c = 'NEFT/RTGS',
        Transaction_Reference__c = 'HDFC-RTGS-982140',
        Status__c = 'Confirmed'
    ),
    new Receipt__c(
        Booking__c = bkg.Id,
        Installment__c = instList[1].Id,
        Amount__c = 762500,
        Receipt_Date__c = Date.today().addDays(-2),
        Payment_Mode__c = 'NEFT/RTGS',
        Transaction_Reference__c = 'ICIC-NEFT-671209',
        Status__c = 'Confirmed'
    )
};
insert receipts;

System.debug('>>> Real Estate Rich Demo Data Seeding Completed Successfully!');
