List<Handover__c> hoList = [SELECT Id, Name, Stage__c, Status__c, Handover_Owner__r.Name FROM Handover__c ORDER BY CreatedDate DESC LIMIT 5];
for (Handover__c ho : hoList) {
    System.debug('HO: ' + ho.Name + ' | Id: ' + ho.Id + ' | Stage: ' + ho.Stage__c + ' | Status: ' + ho.Status__c);
    List<Inspection__c> inspList = [SELECT Id, Name, Status__c, Inspection_Type__c FROM Inspection__c WHERE Handover__c = :ho.Id];
    for (Inspection__c insp : inspList) {
        System.debug('   --> INSP: ' + insp.Name + ' | Status: ' + insp.Status__c + ' | Type: ' + insp.Inspection_Type__c);
    }
}
