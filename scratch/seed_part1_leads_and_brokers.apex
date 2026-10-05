System.debug('=== PART 1: SEEDING BROKERS & DIVERSE LEADS ===');

Id cpRtId = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Channel_Partner_Residential' LIMIT 1].Id;

// 1. Broker 1: Sanjay Singhania (Square Yards)
if ([SELECT count() FROM Account WHERE LastName = 'Singhania' AND RecordTypeId = :cpRtId] == 0) {
    Account b1 = new Account(
        FirstName = 'Sanjay',
        LastName = 'Singhania',
        CompanyName__c = 'Square Yards Realty LLP',
        RecordTypeId = cpRtId,
        PersonMobilePhone = '+91 98450 12345',
        Phone = '+91 80 4920 1100',
        PersonEmail = 'sanjay.singhania@squareyards.demo',
        Website = 'https://www.squareyards.com',
        CP_Approval_Status__c = 'Approved',
        RERA_Number__c = 'AG/170824/000122',
        GST_No__c = '29AABCS1429B1Z4',
        PAN_Number__c = 'AABCS1429B',
        Distribution_Channel__c = 'Channel sale(Broker)'
    );
    insert b1;
    System.debug('Created Broker: Sanjay Singhania (Square Yards Realty)');
}

// 2. Broker 2: Pooja Sharma (Anarock)
if ([SELECT count() FROM Account WHERE LastName = 'Sharma' AND RecordTypeId = :cpRtId] == 0) {
    Account b2 = new Account(
        FirstName = 'Pooja',
        LastName = 'Sharma',
        CompanyName__c = 'Anarock Property Consultants Pvt Ltd',
        RecordTypeId = cpRtId,
        PersonMobilePhone = '+91 99001 23456',
        Phone = '+91 80 6735 4400',
        PersonEmail = 'pooja.sharma@anarock.demo',
        Website = 'https://www.anarock.com',
        CP_Approval_Status__c = 'Approved',
        RERA_Number__c = 'AG/180215/000344',
        GST_No__c = '29AAACA2310C1Z8',
        PAN_Number__c = 'AAACA2310C',
        Distribution_Channel__c = 'Channel sale(Broker)'
    );
    insert b2;
    System.debug('Created Broker: Pooja Sharma (Anarock)');
}

// 3. Broker 3: Vikramaditya Rao (PropTiger)
if ([SELECT count() FROM Account WHERE LastName = 'Rao' AND RecordTypeId = :cpRtId] == 0) {
    Account b3 = new Account(
        FirstName = 'Vikramaditya',
        LastName = 'Rao',
        CompanyName__c = 'PropTiger Advisory Services',
        RecordTypeId = cpRtId,
        PersonMobilePhone = '+91 97402 34567',
        Phone = '+91 80 3051 8800',
        PersonEmail = 'vikram.rao@proptiger.demo',
        Website = 'https://www.proptiger.com',
        CP_Approval_Status__c = 'Pending Approval',
        RERA_Number__c = 'AG/210519/000789',
        GST_No__c = '29AABCP9912D1Z2',
        PAN_Number__c = 'AABCP9912D',
        Distribution_Channel__c = 'Channel sale(Broker)'
    );
    insert b3;
    System.debug('Created Broker: Vikramaditya Rao (PropTiger)');
}

// 4. 8 Diverse Non-Converted Leads
Id leadRtId = [SELECT Id FROM RecordType WHERE SobjectType = 'Lead' AND DeveloperName = 'Standard_Lead_Residential' LIMIT 1].Id;

List<Lead> leads = new List<Lead>{
    new Lead(FirstName = 'Vikram', LastName = 'Malhotra', Email = 'vikram.malhotra@demo.com', MobilePhone = '+91 98860 11001', Phone = '+91 98860 11001', LeadSource = 'Website', Status = 'New', Projects__c = 'Nikoo Homes', Type_of_Units__c = '3BHK', Budget__c = '2-3 Cr', Preferred_City__c = 'Bengaluru', City = 'Bengaluru', Company = 'Self-Employed (Consultant)', RecordTypeId = leadRtId, Description = 'Inquired via digital portal for Phase 4 3BHK high-rise unit. Fresh lead ready for round-robin assignment.'),
    new Lead(FirstName = 'Sneha', LastName = 'Kulkarni', Email = 'sneha.kulkarni@demo.com', MobilePhone = '+91 98860 11002', Phone = '+91 98860 11002', LeadSource = 'Google', Status = 'Working', Projects__c = 'Varthur Vista', Type_of_Units__c = '2BHK', Budget__c = '2-3 Cr', Preferred_City__c = 'Bengaluru', City = 'Bengaluru', Company = 'Amazon India', RecordTypeId = leadRtId, Description = 'Google search campaign click. Prefers east-facing 2BHK with balcony. Follow-up call logged.'),
    new Lead(FirstName = 'Kavita', LastName = 'Krishnan', Email = 'kavita.krishnan@demo.com', MobilePhone = '+91 98860 11003', Phone = '+91 98860 11003', LeadSource = 'Partner', Status = 'Site Visit', Projects__c = 'Nikoo Homes', Type_of_Units__c = '2BHK', Budget__c = '2-3 Cr', Preferred_City__c = 'Bengaluru', City = 'Bengaluru', Company = 'Infosys Technologies', RecordTypeId = leadRtId, Description = 'Referred by Square Yards Realty. Confirmed site visit scheduled for this Saturday 11:00 AM.'),
    new Lead(FirstName = 'Ramesh Chandra', LastName = 'Gupta', Email = 'ramesh.gupta@demo.com', MobilePhone = '+91 98860 11004', Phone = '+91 98860 11004', LeadSource = 'Manual', Status = 'Qualified', Projects__c = 'Saket Square', Type_of_Units__c = '4BHK', Budget__c = '3-4 Cr', Preferred_City__c = 'Bengaluru', City = 'Bengaluru', Company = 'Gupta Steel Traders', RecordTypeId = leadRtId, Description = 'Walk-in buyer to Experience Center. Completed verified site visit with 5-star rating. Budget ₹3 Cr.'),
    new Lead(FirstName = 'Ananya', LastName = 'Deshmukh', Email = 'ananya.deshmukh@demo.com', MobilePhone = '+91 98860 11005', Phone = '+91 98860 11005', LeadSource = 'Social Media', Status = 'Contacted', Projects__c = 'Banjara Beam', Type_of_Units__c = '4BHK', Budget__c = '2-3 Cr', Preferred_City__c = 'Hyderabad', City = 'Hyderabad', Company = 'Deloitte USI', RecordTypeId = leadRtId, Description = 'Instagram carousel ad inquiry. Requested floor plan and pricing sheet for Tower B top-floor units.'),
    new Lead(FirstName = 'Devendra', LastName = 'Patil', Email = 'devendra.patil@demo.com', MobilePhone = '+91 98860 11006', Phone = '+91 98860 11006', LeadSource = 'Marketing Event', Status = 'Qualified', Projects__c = 'Miyapur Manor', Type_of_Units__c = 'Above 4BHK', Budget__c = '2-3 Cr', Preferred_City__c = 'Hyderabad', City = 'Hyderabad', Company = 'Microsoft IDC', RecordTypeId = leadRtId, Description = 'Met at Manyata Tech Park Corporate Showcase. High intent buyer, corporate tie-up discount applicable.'),
    new Lead(FirstName = 'Rajeev', LastName = 'Nambiar', Email = 'rajeev.nambiar@demo.com', MobilePhone = '+91 98860 11007', Phone = '+91 98860 11007', LeadSource = 'Cold Call', Status = 'Dropped', Projects__c = 'Nikoo Homes', Type_of_Units__c = '2BHK', Budget__c = '2-3 Cr', Preferred_City__c = 'Bengaluru', City = 'Bengaluru', Company = 'Independent Professional', Drop_Reason__c = 'Budget Mismatch', Archive_For_In_Days__c = 30, Archive_Follow_Up_Date__c = Date.today().addDays(30), Archive_Populated_Date__c = Date.today(), RecordTypeId = leadRtId, Description = 'Unqualified due to budget mismatch. Placed in 30-day cooling off archival period.'),
    new Lead(FirstName = 'Harish', LastName = 'Iyer', Email = 'harish.iyer@demo.com', MobilePhone = '+91 98860 11008', Phone = '+91 98860 11008', LeadSource = 'Referral', Status = 'Working', Projects__c = 'Yalahanka Yard', Type_of_Units__c = '3BHK', Budget__c = '2-3 Cr', Preferred_City__c = 'Bengaluru', City = 'Bengaluru', Company = 'Goldman Sachs', RecordTypeId = leadRtId, Description = 'Warm referral from existing Nikoo Homes resident. Looking for rapid closure.')
};

Set<String> emails = new Set<String>();
for (Lead l : leads) emails.add(l.Email);
Map<String, Lead> existing = new Map<String, Lead>();
for (Lead l : [SELECT Email FROM Lead WHERE Email IN :emails]) existing.put(l.Email, l);

List<Lead> toInsert = new List<Lead>();
for (Lead l : leads) {
    if (!existing.containsKey(l.Email)) toInsert.add(l);
}
if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('Successfully inserted ' + toInsert.size() + ' diverse non-converted leads.');
} else {
    System.debug('All 8 demo leads already exist.');
}
