// 1. Create a fresh Lead (Individual Residential Buyer)
Lead rohan = new Lead(
    FirstName = 'Rohan',
    LastName = 'Mehra',
    Company = null,
    Phone = '9902553348',
    MobilePhone = '9902553348',
    Status = 'Allocated',
    Has_Site_Visit__c = false
);
insert rohan;
System.debug('Created Test Lead: ' + rohan.Id);

// 2. Fetch Property and Unit
Property__c proj = [SELECT Id, Name FROM Property__c LIMIT 1];
List<Unit__c> units = [SELECT Id, Name FROM Unit__c WHERE Property__c = :proj.Id OR Floor__r.Tower__r.Property__c = :proj.Id LIMIT 1];
Id unitId = units.isEmpty() ? null : units[0].Id;
System.debug('Tagged Project: ' + proj.Name + ' (' + proj.Id + ')');
if (unitId != null) System.debug('Tagged Unit: ' + units[0].Name);

// 3. Generate Simulated OTP
SiteVisitController.OtpResultWrapper otp = SiteVisitController.generateOtp('9902553348');
System.debug('Generated OTP: ' + otp.otpCode + ' for ' + otp.maskedMobile);

// 4. Log Site Visit via Controller
SiteVisitController.SiteVisitSaveResult saveRes = SiteVisitController.logSiteVisit(
    rohan.Id,
    proj.Id,
    unitId,
    '9902553348',
    otp.otpCode,
    'Hot',
    'Customer visited on-site with spouse. Loved the 3 BHK layout and park view. Ready to convert.',
    System.now()
);
System.debug('Site Visit Result: ' + saveRes.message + ' [ID: ' + saveRes.siteVisitId + ']');

// 5. Verify Lead Qualification State
Lead qualifiedLead = [SELECT Id, Has_Site_Visit__c, Status FROM Lead WHERE Id = :rohan.Id];
System.debug('Lead Status: ' + qualifiedLead.Status + ' | Has Verified Site Visit: ' + qualifiedLead.Has_Site_Visit__c);

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
    System.debug('Created Opportunity ID: ' + lcr.getOpportunityId());

    // Verify Person Account
    Account acc = [SELECT Id, Name, IsPersonAccount, RecordType.DeveloperName FROM Account WHERE Id = :lcr.getAccountId()];
    System.debug('Account RecordType: ' + acc.RecordType.DeveloperName + ' | IsPersonAccount: ' + acc.IsPersonAccount);

    // Verify Simple Opportunity
    Opportunity opp = [SELECT Id, Name, RecordType.DeveloperName, StageName FROM Opportunity WHERE Id = :lcr.getOpportunityId()];
    System.debug('Opportunity RecordType: ' + opp.RecordType.DeveloperName + ' | Stage: ' + opp.StageName);

    // Verify Site Visit repointing
    List<Site_Visit__c> visits = [SELECT Id, Opportunity__c, Lead__c FROM Site_Visit__c WHERE Lead__c = :rohan.Id];
    System.debug('Linked Site Visits Count: ' + visits.size() + ' | Pointing to Opp: ' + (visits.isEmpty() ? 'none' : String.valueOf(visits[0].Opportunity__c)));
    System.debug('==============================================');
} else {
    System.debug('CONVERSION FAILED: ' + lcr.getErrors());
}
