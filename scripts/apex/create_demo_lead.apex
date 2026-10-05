Project__c p = [SELECT Id, Name FROM Project__c LIMIT 1];

Lead demoLead = new Lead(
    FirstName = 'Pooja',
    LastName = 'Hegde',
    Company = 'Zenith Ventures',
    Phone = '9902553348',
    MobilePhone = '9902553348',
    Email = 'pooja.hegde@example.com',
    Status = 'Working - Contacted',
    Project_Enquired__c = p.Id,
    Configuration_Interested__c = '3 BHK',
    Budget_Range__c = '1 Cr - 2 Cr',
    Has_Site_Visit__c = false,
    Site_Visit_Count__c = 0
);
insert demoLead;

System.debug('*** DEMO LEAD CREATED ***');
System.debug('ID: ' + demoLead.Id);
System.debug('Name: Pooja Hegde');
System.debug('Project: ' + p.Name);
System.debug('Has Verified Site Visit: ' + demoLead.Has_Site_Visit__c);
