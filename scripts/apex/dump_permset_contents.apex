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

Map<Id, PermissionSet> psMap = new Map<Id, PermissionSet>([
    SELECT Id, Name, Label FROM PermissionSet WHERE Name IN :targetNames
]);

System.debug('=== 1. OBJECT PERMISSIONS ===');
for (ObjectPermissions op : [
    SELECT Parent.Name, SobjectType, PermissionsRead, PermissionsCreate, PermissionsEdit, PermissionsDelete, PermissionsViewAllRecords, PermissionsModifyAllRecords
    FROM ObjectPermissions
    WHERE ParentId IN :psMap.keySet()
    ORDER BY SobjectType, Parent.Name
]) {
    System.debug('OBJ: ' + op.Parent.Name + ' | ' + op.SobjectType + ' | R=' + op.PermissionsRead + ' C=' + op.PermissionsCreate + ' E=' + op.PermissionsEdit + ' D=' + op.PermissionsDelete + ' VA=' + op.PermissionsViewAllRecords + ' MA=' + op.PermissionsModifyAllRecords);
}

System.debug('=== 2. TAB SETTINGS ===');
for (PermissionSetTabSetting ts : [
    SELECT Parent.Name, Name, Visibility
    FROM PermissionSetTabSetting
    WHERE ParentId IN :psMap.keySet()
    ORDER BY Name
]) {
    System.debug('TAB: ' + ts.Parent.Name + ' | ' + ts.Name + ' | ' + ts.Visibility);
}

System.debug('=== 3. SETUP ENTITY ACCESS ===');
for (SetupEntityAccess sea : [
    SELECT Parent.Name, SetupEntityId, SetupEntityType
    FROM SetupEntityAccess
    WHERE ParentId IN :psMap.keySet()
]) {
    System.debug('SETUP: ' + sea.Parent.Name + ' | Type=' + sea.SetupEntityType + ' | Id=' + sea.SetupEntityId);
}
