// scripts/apex/test_closed_won_flow.apex
Opportunity opp = [SELECT Id, StageName, Tagged_Unit__c, Amount FROM Opportunity WHERE Name = 'Meera Nambiar - Nikoo B-203 Deal' LIMIT 1];
opp.StageName = 'Closed Won';
update opp;

Unit__c u = [SELECT Id, Name, Status__c FROM Unit__c WHERE Id = :opp.Tagged_Unit__c];
System.debug('*** VERIFICATION: Updated Unit Status = ' + u.Status__c);

Booking__c b = [SELECT Id, Name, Status__c, Total_Booking_Amount__c FROM Booking__c WHERE Opportunity__c = :opp.Id AND Unit__c = :opp.Tagged_Unit__c ORDER BY CreatedDate DESC LIMIT 1];
System.debug('*** VERIFICATION: Auto-created Booking = ' + b.Name + ' | Status = ' + b.Status__c + ' | Amount = ' + b.Total_Booking_Amount__c);
