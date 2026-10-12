for (Schema.RecordTypeInfo info : Schema.SObjectType.Account.getRecordTypeInfos()) {
    System.debug('RT: ' + info.getName() + ' | DevName: ' + info.getDeveloperName() + ' | Id: ' + info.getRecordTypeId() + ' | isAvailable: ' + info.isAvailable() + ' | isDefault: ' + info.isDefaultRecordTypeMapping());
}
