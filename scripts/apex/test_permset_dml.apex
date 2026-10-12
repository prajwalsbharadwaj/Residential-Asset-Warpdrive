// Test if we can insert PermissionSet via Apex
Savepoint sp = Database.setSavepoint();
try {
    PermissionSet ps = new PermissionSet(
        Name = 'Test_Perm_Set_Delete_Me',
        Label = 'Test Perm Set'
    );
    insert ps;
    System.debug('Inserted PermissionSet: ' + ps.Id);
    
    // Test inserting ObjectPermissions
    ObjectPermissions op = new ObjectPermissions(
        ParentId = ps.Id,
        SobjectType = 'Handover__c',
        PermissionsRead = true,
        PermissionsCreate = true,
        PermissionsEdit = true,
        PermissionsDelete = true,
        PermissionsViewAllRecords = true,
        PermissionsModifyAllRecords = true
    );
    insert op;
    System.debug('Inserted ObjectPermissions: ' + op.Id);
    
    // Test inserting FieldPermissions
    FieldPermissions fp = new FieldPermissions(
        ParentId = ps.Id,
        SobjectType = 'Handover__c',
        Field = 'Handover__c.Stage__c',
        PermissionsRead = true,
        PermissionsEdit = true
    );
    insert fp;
    System.debug('Inserted FieldPermissions: ' + fp.Id);
} catch (Exception e) {
    System.debug('ERROR: ' + e.getMessage());
} finally {
    Database.rollback(sp);
    System.debug('Rollback complete');
}
