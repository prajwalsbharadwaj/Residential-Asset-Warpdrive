System.debug('=== LEAD PICKLIST ENTRIES ===');
for (Schema.PicklistEntry pe : Schema.SObjectType.Lead.fields.Budget__c.getPicklistValues()) {
    if (pe.isActive()) System.debug('BUDGET: ' + pe.getValue());
}
for (Schema.PicklistEntry pe : Schema.SObjectType.Lead.fields.Type_of_Units__c.getPicklistValues()) {
    if (pe.isActive()) System.debug('TYPE_OF_UNITS: ' + pe.getValue());
}
