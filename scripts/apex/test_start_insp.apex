HandoverWorkspaceController.startInspection('a4DVa000000z1dVMAQ', 'Internal', 'Somya Sharma', 'Nikoo QA', 'somya@example.com');
Handover__c ho = [SELECT Id, Name, Stage__c, Status__c FROM Handover__c WHERE Id = 'a4DVa000000z1dVMAQ'];
System.debug('AFTER startInspection -> HO: ' + ho.Name + ' | Stage: ' + ho.Stage__c + ' | Status: ' + ho.Status__c);
