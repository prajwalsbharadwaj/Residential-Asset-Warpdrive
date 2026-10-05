List<Lead> unqual = [SELECT Id, Status, Drop_Reason__c FROM Lead WHERE Status = 'Unqualified'];
for (Lead l : unqual) {
    l.Status = 'Dropped';
    if (String.isBlank(l.Drop_Reason__c)) {
        l.Drop_Reason__c = 'Requirement mismatch';
    }
}
update unqual;
System.debug('Migrated ' + unqual.size() + ' leads from Unqualified to Dropped.');
