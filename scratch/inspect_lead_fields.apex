Map<String, Schema.SObjectField> fields = Schema.SObjectType.Lead.fields.getMap();
for (String fName : fields.keySet()) {
    if (fName.endsWith('__c')) {
        System.debug('LEAD FIELD: ' + fName);
    }
}
