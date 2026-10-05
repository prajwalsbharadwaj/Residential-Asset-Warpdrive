for (Schema.RecordTypeInfo rti : Schema.SObjectType.Account.getRecordTypeInfos()) {
    if (rti.isAvailable() && rti.getName() != 'Master') {
        System.debug('AVAILABLE ACC RT: ' + rti.getName() + ' | Id: ' + rti.getRecordTypeId() + ' | DevName: ' + rti.getDeveloperName());
    }
}
for (Schema.RecordTypeInfo rti : Schema.SObjectType.Lead.getRecordTypeInfos()) {
    if (rti.isAvailable() && rti.getName() != 'Master') {
        System.debug('AVAILABLE LEAD RT: ' + rti.getName() + ' | Id: ' + rti.getRecordTypeId() + ' | DevName: ' + rti.getDeveloperName());
    }
}
