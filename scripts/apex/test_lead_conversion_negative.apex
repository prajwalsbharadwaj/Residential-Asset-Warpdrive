Lead testLead = new Lead(
    FirstName = 'Aarav',
    LastName = 'Kapoor',
    Company = 'Kapoor & Sons Tech',
    Phone = '9880123456',
    MobilePhone = '9880123456',
    Status = 'Working - Contacted',
    Has_Site_Visit__c = false
);
insert testLead;
System.debug('Inserted test Lead ID: ' + testLead.Id);

Database.LeadConvert lc = new Database.LeadConvert();
lc.setLeadId(testLead.Id);

LeadStatus convertStatus = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];
lc.setConvertedStatus(convertStatus.MasterLabel);

try {
    Database.LeadConvertResult lcr = Database.convertLead(lc);
    if (lcr.isSuccess()) {
        System.debug('TEST FAILED: Lead was converted without a Site Visit!');
    } else {
        System.debug('TEST PASSED: Conversion was blocked as expected. Errors: ' + lcr.getErrors());
    }
} catch (DmlException e) {
    System.debug('TEST PASSED: Exception caught blocking conversion: ' + e.getMessage());
}
