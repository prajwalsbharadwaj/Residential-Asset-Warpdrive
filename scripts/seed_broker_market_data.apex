/**
 * Seed Market-Wise Rich Demo Data for Channel Partners across Bengaluru, Hyderabad, and Gurugram
 * Architecture note: Channel_Partner_Residential and Customer accounts in this org are Person Accounts.
 * We use LastName / FirstName for DML.
 */

System.debug('--- Starting Channel Partner Data Seeding ---');

// 1. Get Channel Partner Record Type (Person Account)
Id partnerRtId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Channel_Partner_Residential' AND IsPersonType = true LIMIT 1].Id;
Id personRtId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'PersonAccount' AND IsPersonType = true LIMIT 1].Id;

// 2. Resolve Properties
Map<String, Property__c> propMap = new Map<String, Property__c>();
for (Property__c p : [SELECT Id, Name FROM Property__c]) {
    propMap.put(p.Name, p);
}
Property__c nikoo = propMap.get('Nikoo Homes');
Property__c saket = propMap.get('Saket Square');
Property__c banjara = propMap.get('Banjara Beam');
Property__c varthur = propMap.get('Varthur Vista');

// 3. Setup / Update Partner Accounts
// A. Meridian Partners (Bengaluru)
Account meridian = null;
List<Account> meridianList = [SELECT Id FROM Account WHERE Id = '001aj00002OH7mlAAD' LIMIT 1];
if (!meridianList.isEmpty()) {
    meridian = new Account(
        Id = meridianList[0].Id,
        RERA_Number__c = 'PRM/KA/RERA/1251/CP8891',
        CP_Approval_Status__c = 'Approved',
        Channel_Partner_Status__c = 'Active',
        Brokerage_Percentage__c = 2.5,
        Partner_Program_Level__c = 'Platinum Partner',
        Phone = '+91 80 4123 9901'
    );
    update meridian;
}

// B. Deccan Landmark Partners (Hyderabad)
Account deccan = null;
List<Account> deccanList = [SELECT Id FROM Account WHERE LastName LIKE '%Deccan Landmark%' LIMIT 1];
if (!deccanList.isEmpty()) {
    deccan = new Account(
        Id = deccanList[0].Id,
        RERA_Number__c = 'P02400004812/CP/HYD',
        CP_Approval_Status__c = 'Approved',
        Channel_Partner_Status__c = 'Active',
        Brokerage_Percentage__c = 3.0,
        Partner_Program_Level__c = 'Signature Partner'
    );
    update deccan;
} else {
    deccan = new Account(
        RecordTypeId = partnerRtId,
        LastName = 'Deccan Landmark Partners',
        FirstName = 'Hyderabad',
        Phone = '+91 40 6622 4400',
        RERA_Number__c = 'P02400004812/CP/HYD',
        CP_Approval_Status__c = 'Approved',
        Channel_Partner_Status__c = 'Active',
        Brokerage_Percentage__c = 3.0,
        Partner_Program_Level__c = 'Signature Partner'
    );
    insert deccan;
}

// C. CyberCity Realty Advisory (Gurugram)
Account cyber = null;
List<Account> cyberList = [SELECT Id FROM Account WHERE LastName LIKE '%CyberCity Realty%' LIMIT 1];
if (!cyberList.isEmpty()) {
    cyber = new Account(
        Id = cyberList[0].Id,
        RERA_Number__c = 'HARERA/GGM/2026/719',
        CP_Approval_Status__c = 'Approved',
        Channel_Partner_Status__c = 'Active',
        Brokerage_Percentage__c = 2.75,
        Partner_Program_Level__c = 'Gold Partner'
    );
    update cyber;
} else {
    cyber = new Account(
        RecordTypeId = partnerRtId,
        LastName = 'CyberCity Realty Advisory',
        FirstName = 'Gurugram',
        Phone = '+91 124 459 8800',
        RERA_Number__c = 'HARERA/GGM/2026/719',
        CP_Approval_Status__c = 'Approved',
        Channel_Partner_Status__c = 'Active',
        Brokerage_Percentage__c = 2.75,
        Partner_Program_Level__c = 'Gold Partner'
    );
    insert cyber;
}

// D. Amit Raj (Apex Realty)
Account amit = null;
List<Account> amitList = [SELECT Id FROM Account WHERE Id = '001aj00002ZgNpSAAV' LIMIT 1];
if (!amitList.isEmpty()) {
    amit = new Account(
        Id = amitList[0].Id,
        RERA_Number__c = 'PRM/KA/RERA/1251/PR200',
        CP_Approval_Status__c = 'Approved',
        Channel_Partner_Status__c = 'Active',
        Brokerage_Percentage__c = 2.5,
        Partner_Program_Level__c = 'Platinum Partner',
        Phone = '+91 98450 11223'
    );
    update amit;
}

List<Account> partnersToSeed = new List<Account>();
if (meridian != null) partnersToSeed.add(meridian);
if (deccan != null) partnersToSeed.add(deccan);
if (cyber != null) partnersToSeed.add(cyber);
if (amit != null) partnersToSeed.add(amit);

// 4. Create Buyer Person Accounts, Tagged Leads, Opportunities, and Bookings
Integer pIdx = 0;
for (Account cp : partnersToSeed) {
    pIdx++;
    Property__c targetProp = nikoo != null ? nikoo : varthur;
    String cityTag = 'Bengaluru';
    if (cp.LastName != null && cp.LastName.contains('Deccan')) {
        if (banjara != null) targetProp = banjara;
        cityTag = 'Hyderabad';
    } else if (cp.LastName != null && cp.LastName.contains('CyberCity')) {
        if (saket != null) targetProp = saket;
        cityTag = 'Gurugram';
    }

    // Buyer 1 (Person Account)
    Account buyer1 = new Account(
        RecordTypeId = personRtId,
        LastName = 'Mehta (' + cityTag + ')',
        FirstName = 'Rohan & Neha',
        Phone = '+91 98765 ' + (10000 + pIdx * 111)
    );
    // Buyer 2 (Person Account)
    Account buyer2 = new Account(
        RecordTypeId = personRtId,
        LastName = 'Rao (' + cityTag + ')',
        FirstName = 'Deepika',
        Phone = '+91 98450 ' + (20000 + pIdx * 222)
    );
    insert new List<Account>{ buyer1, buyer2 };

    // Tagged Leads
    Lead ld1 = new Lead(
        LastName = 'Sundaram (' + cityTag + ')',
        FirstName = 'Karthik',
        Company = 'Fintech Capital ' + cityTag,
        Phone = '+91 99001 ' + (30000 + pIdx * 333),
        MobilePhone = '+91 99001 ' + (30000 + pIdx * 333),
        Email = 'karthik.' + pIdx + '@fintech.io',
        Status = 'Working - Contacted',
        Budget__c = '₹ 1.8 - 2.2 Cr',
        Type_of_Units__c = '3 BHK',
        Approved_Channel_Partner__c = cp.Id,
        Site_Visit_Scheduled__c = true
    );
    if (targetProp != null) ld1.ProjectL__c = targetProp.Id;

    Lead ld2 = new Lead(
        LastName = 'Singhania (' + cityTag + ')',
        FirstName = 'Vikramaditya',
        Company = 'Singhania Advisory ' + cityTag,
        Phone = '+91 98110 ' + (40000 + pIdx * 444),
        MobilePhone = '+91 98110 ' + (40000 + pIdx * 444),
        Email = 'vikram.' + pIdx + '@singhania.com',
        Status = 'Site Visit Scheduled',
        Budget__c = '₹ 2.5 - 3.2 Cr',
        Type_of_Units__c = '4 BHK Luxury',
        Approved_Channel_Partner__c = cp.Id,
        Site_Visit_Scheduled__c = true
    );
    if (targetProp != null) ld2.ProjectL__c = targetProp.Id;
    insert new List<Lead>{ ld1, ld2 };

    // Find available units for this property
    List<Unit__c> uList = [
        SELECT Id, Name, Tower__c, Tower__r.Name, Base_Price__c, Built_Up_Area_SBA__c 
        FROM Unit__c 
        WHERE Property__c = :targetProp.Id 
        ORDER BY Name ASC 
        LIMIT 2
    ];
    if (uList.isEmpty()) {
        uList = [SELECT Id, Name, Tower__c, Tower__r.Name, Base_Price__c, Built_Up_Area_SBA__c FROM Unit__c LIMIT 2];
    }

    Unit__c unit1 = !uList.isEmpty() ? uList[0] : null;
    Unit__c unit2 = uList.size() > 1 ? uList[1] : unit1;

    // Opportunities
    Opportunity opp1 = new Opportunity(
        Name = buyer1.LastName + ' - ' + (unit1 != null ? unit1.Name : 'Unit Deal'),
        AccountId = buyer1.Id,
        Approved_Channel_Partner__c = cp.Id,
        StageName = 'Quotation Agreed',
        CloseDate = Date.today().addDays(20),
        Amount = 16500000
    );
    if (unit1 != null) opp1.Interested_Unit__c = unit1.Id;

    Opportunity opp2 = new Opportunity(
        Name = buyer2.LastName + ' - ' + (unit2 != null ? unit2.Name : 'Unit Deal'),
        AccountId = buyer2.Id,
        Approved_Channel_Partner__c = cp.Id,
        StageName = 'Closed Won',
        CloseDate = Date.today().addDays(-5),
        Amount = 28500000
    );
    if (unit2 != null) opp2.Interested_Unit__c = unit2.Id;
    insert new List<Opportunity>{ opp1, opp2 };

    // Bookings
    Decimal slabPct = cp.Brokerage_Percentage__c != null ? cp.Brokerage_Percentage__c : 2.5;

    Booking__c b1 = new Booking__c(
        Account_Id__c = buyer1.Id,
        Opportunity_Id__c = opp1.Id,
        Approved_Channel_Partner__c = cp.Id,
        Final_Amount__c = 16500000,
        Brokerage_Value__c = 16500000 * (slabPct / 100),
        Status__c = 'Confirmed',
        Token_Amount__c = 1650000,
        SFDC_booking_reference_no__c = 'BO-00000' + (10 + pIdx)
    );
    if (targetProp != null) b1.Project__c = targetProp.Id;
    if (unit1 != null) b1.Unit_Id__c = unit1.Id;

    Booking__c b2 = new Booking__c(
        Account_Id__c = buyer2.Id,
        Opportunity_Id__c = opp2.Id,
        Approved_Channel_Partner__c = cp.Id,
        Final_Amount__c = 28500000,
        Brokerage_Value__c = 28500000 * (slabPct / 100),
        Status__c = 'Confirmed',
        Token_Amount__c = 2850000,
        SFDC_booking_reference_no__c = 'BO-00000' + (20 + pIdx)
    );
    if (targetProp != null) b2.Project__c = targetProp.Id;
    if (unit2 != null) b2.Unit_Id__c = unit2.Id;
    insert new List<Booking__c>{ b1, b2 };

    // Booking Payment Schedules for b1
    List<Booking_Payment_Schedule__c> scheds = new List<Booking_Payment_Schedule__c>{
        new Booking_Payment_Schedule__c(
            Booking__c = b1.Id,
            Installment_Number__c = 1,
            Installment_Amount__c = 1650000,
            Description__c = 'Booking Advance (10%)',
            Payment_Status__c = 'Paid',
            Payment_Due_Date__c = Date.today().addDays(-15)
        ),
        new Booking_Payment_Schedule__c(
            Booking__c = b1.Id,
            Installment_Number__c = 2,
            Installment_Amount__c = 2475000,
            Description__c = 'Execution of Agreement (15%)',
            Payment_Status__c = 'Paid',
            Payment_Due_Date__c = Date.today().addDays(-5)
        ),
        new Booking_Payment_Schedule__c(
            Booking__c = b1.Id,
            Installment_Number__c = 3,
            Installment_Amount__c = 4125000,
            Description__c = 'Completion of Foundation (25%)',
            Payment_Status__c = 'Due',
            Payment_Due_Date__c = Date.today().addDays(20)
        )
    };
    insert scheds;
}

System.debug('--- All Channel Partner Data Seeded Successfully ---');
