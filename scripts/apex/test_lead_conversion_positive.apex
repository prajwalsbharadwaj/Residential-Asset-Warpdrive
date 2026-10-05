// 1. Create a fresh Lead
Lead rohan = new Lead(
    FirstName = 'Rohan',
    LastName = 'Mehra',
    Company = 'Mehra Innovations',
    Phone = '9902553348',
    MobilePhone = '9902553348',
    Status = 'Working - Contacted',
    Has_Site_Visit__c = false
);
insert rohan;
System.debug('Created Test Lead: ' + rohan.Id);

// 2. Fetch Project and Unit
Project__c proj = [SELECT Id, Name FROM Project__c LIMIT 1];
Unit__c unit = [SELECT Id, Name FROM Unit__c WHERE Floor__r.Tower__r.Project__c = :proj.Id LIMIT 1];
System.debug('Tagged Project: ' + proj.Name + ' (' + proj.Id + ')');
System.debug('Tagged Unit: ' + unit.Name + ' (' + unit.Id + ')');

// 3. Generate Simulated OTP
SiteVisitController.OtpResultWrapper otp = SiteVisitController.generateOtp('9902553348');
System.debug('Generated OTP: ' + otp.otpCode + ' for ' + otp.maskedMobile);

// 4. Log Site Visit via Controller
SiteVisitController.SiteVisitSaveResult saveRes = SiteVisitController.logSiteVisit(
    rohan.Id,
    proj.Id,
    unit.Id,
    '9902553348',
    otp.otpCode,
    'Hot',
    'Customer visited on-site with spouse. Loved the 3 BHK corner layout and park view. Ready to convert.',
    System.now()
);
System.debug('Site Visit Result: ' + saveRes.message + ' [ID: ' + saveRes.siteVisitId + ']');

// 5. Verify Lead Qualification State
Lead qualifiedLead = [SELECT Id, Has_Site_Visit__c, Site_Visit_Count__c, Status FROM Lead WHERE Id = :rohan.Id];
System.debug('Lead Status: ' + qualifiedLead.Status + ' | Has Verified Site Visit: ' + qualifiedLead.Has_Site_Visit__c + ' | Visit Count: ' + qualifiedLead.Site_Visit_Count__c);

if (!qualifiedLead.Has_Site_Visit__c) {
    throw new CalloutException('TEST FAILED: Has_Site_Visit__c was not set to true!');
}

// 6. Convert the Lead Now That Qualification Gate is Unlocked
Database.LeadConvert lc = new Database.LeadConvert();
lc.setLeadId(rohan.Id);
LeadStatus convertStatus = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];
lc.setConvertedStatus(convertStatus.MasterLabel);

Database.LeadConvertResult lcr = Database.convertLead(lc);
if (lcr.isSuccess()) {
    System.debug('==============================================');
    System.debug('SUCCESS! LEAD CONVERTED SUCCESSFULLY!');
    System.debug('Created Account ID:     ' + lcr.getAccountId());
    System.debug('Created Contact ID:     ' + lcr.getContactId());
    System.debug('Created Opportunity ID: ' + lcr.getOpportunityId());
    System.debug('==============================================');
} else {
    System.debug('CONVERSION FAILED: ' + lcr.getErrors());
}
