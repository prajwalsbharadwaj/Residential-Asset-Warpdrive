List<String> targetNames = new List<String>{
    'GRE_Front_Desk_Access',
    'Lead_Archive_Access',
    'Handover_Administrator',
    'Residential_Handover_Manager',
    'ResaleAssistance_Access',
    'Resale_Rental_Manager',
    'Rental_Journey',
    'WD_Customer_Documents',
    'Nikoo_Sales_Targets',
    'WD_Glass_UI'
};

for (PermissionSet ps : [SELECT Id, Name, Label FROM PermissionSet WHERE Name IN :targetNames]) {
    Integer objCount = [SELECT COUNT() FROM ObjectPermissions WHERE ParentId = :ps.Id];
    Integer fldCount = [SELECT COUNT() FROM FieldPermissions WHERE ParentId = :ps.Id];
    Integer tabCount = [SELECT COUNT() FROM PermissionSetTabSetting WHERE ParentId = :ps.Id];
    Integer setupCount = [SELECT COUNT() FROM SetupEntityAccess WHERE ParentId = :ps.Id];
    System.debug('PS: ' + ps.Name + ' (' + ps.Label + ') -> Objects: ' + objCount + ', Fields: ' + fldCount + ', Tabs: ' + tabCount + ', SetupEntities: ' + setupCount);
}
