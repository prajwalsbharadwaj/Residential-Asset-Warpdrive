System.debug('=== ORG STATE INSPECTION ===');

// 1. Users
for (User u : [SELECT Id, Name, Email, Profile.Name, IsActive FROM User WHERE IsActive = true AND UserType = 'Standard' LIMIT 5]) {
    System.debug('USER: ' + u.Id + ' | ' + u.Name + ' | ' + u.Profile.Name);
}

// 2. Counts
System.debug('COUNT Property__c: ' + [SELECT count() FROM Property__c]);
System.debug('COUNT Tower__c: ' + [SELECT count() FROM Tower__c]);
System.debug('COUNT Floor__c: ' + [SELECT count() FROM Floor__c]);
System.debug('COUNT Unit__c: ' + [SELECT count() FROM Unit__c]);
System.debug('COUNT Lead: ' + [SELECT count() FROM Lead]);
System.debug('COUNT Account: ' + [SELECT count() FROM Account]);
System.debug('COUNT Contact: ' + [SELECT count() FROM Contact]);
System.debug('COUNT Opportunity: ' + [SELECT count() FROM Opportunity]);
System.debug('COUNT Booking__c: ' + [SELECT count() FROM Booking__c]);
System.debug('COUNT Handover__c: ' + [SELECT count() FROM Handover__c]);
System.debug('COUNT Site_Visit__c: ' + [SELECT count() FROM Site_Visit__c]);

// 3. Lead picklist values & current leads
for (AggregateResult ar : [SELECT LeadSource, count(Id) cnt FROM Lead GROUP BY LeadSource]) {
    System.debug('LEAD SOURCE: ' + ar.get('LeadSource') + ' (' + ar.get('cnt') + ')');
}
for (AggregateResult ar : [SELECT Status, count(Id) cnt FROM Lead GROUP BY Status]) {
    System.debug('LEAD STATUS: ' + ar.get('Status') + ' (' + ar.get('cnt') + ')');
}

// 4. Account RecordTypes & counts
for (AggregateResult ar : [SELECT RecordType.Name, count(Id) cnt FROM Account GROUP BY RecordType.Name]) {
    System.debug('ACCOUNT RT: ' + ar.get('Name') + ' (' + ar.get('cnt') + ')');
}

// 5. Existing Bookings & Handovers
for (Booking__c b : [SELECT Id, Name, Status__c, (SELECT Id, Name, Stage__c, Status__c FROM Handovers__r) FROM Booking__c LIMIT 10]) {
    System.debug('BOOKING: ' + b.Id + ' | ' + b.Name + ' | ' + b.Status__c + ' | Child Handovers count: ' + b.Handovers__r.size());
}
