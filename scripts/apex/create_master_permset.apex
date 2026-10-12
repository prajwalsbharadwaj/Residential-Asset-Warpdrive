List<String> sourceNames = new List<String>{
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

Map<Id, PermissionSet> sourceSets = new Map<Id, PermissionSet>([
    SELECT Id, Name, Label FROM PermissionSet WHERE Name IN :sourceNames
]);

System.debug('Found ' + sourceSets.size() + ' source permission sets to combine.');

// 1. Get or Create Master Permission Set
PermissionSet masterPs;
List<PermissionSet> existing = [SELECT Id, Name, Label FROM PermissionSet WHERE Name = 'Nikoo_Residential_Master_Access' LIMIT 1];
if (!existing.isEmpty()) {
    masterPs = existing[0];
    System.debug('Existing Master Permission Set found: ' + masterPs.Id);
} else {
    masterPs = new PermissionSet(
        Name = 'Nikoo_Residential_Master_Access',
        Label = 'Nikoo Residential Master Access',
        Description = 'Unified Master Access combining all custom permissions created by and for Prajwal, Manvi, Shubham, Namit, Somya, and Swapna.'
    );
    insert masterPs;
    System.debug('Created new Master Permission Set: ' + masterPs.Id);
}

// 2. Combine ObjectPermissions
Map<String, ObjectPermissions> existingMasterObjs = new Map<String, ObjectPermissions>();
for (ObjectPermissions op : [SELECT Id, SobjectType, PermissionsRead, PermissionsCreate, PermissionsEdit, PermissionsDelete, PermissionsViewAllRecords, PermissionsModifyAllRecords FROM ObjectPermissions WHERE ParentId = :masterPs.Id]) {
    existingMasterObjs.put(op.SobjectType, op);
}

Map<String, ObjectPermissions> mergedObjs = new Map<String, ObjectPermissions>();
for (ObjectPermissions op : [
    SELECT SobjectType, PermissionsRead, PermissionsCreate, PermissionsEdit, PermissionsDelete, PermissionsViewAllRecords, PermissionsModifyAllRecords
    FROM ObjectPermissions
    WHERE ParentId IN :sourceSets.keySet()
]) {
    if (!mergedObjs.containsKey(op.SobjectType)) {
        mergedObjs.put(op.SobjectType, new ObjectPermissions(
            ParentId = masterPs.Id,
            SobjectType = op.SobjectType,
            PermissionsRead = op.PermissionsRead,
            PermissionsCreate = op.PermissionsCreate,
            PermissionsEdit = op.PermissionsEdit,
            PermissionsDelete = op.PermissionsDelete,
            PermissionsViewAllRecords = op.PermissionsViewAllRecords,
            PermissionsModifyAllRecords = op.PermissionsModifyAllRecords
        ));
    } else {
        ObjectPermissions target = mergedObjs.get(op.SobjectType);
        target.PermissionsRead = target.PermissionsRead || op.PermissionsRead;
        target.PermissionsCreate = target.PermissionsCreate || op.PermissionsCreate;
        target.PermissionsEdit = target.PermissionsEdit || op.PermissionsEdit;
        target.PermissionsDelete = target.PermissionsDelete || op.PermissionsDelete;
        target.PermissionsViewAllRecords = target.PermissionsViewAllRecords || op.PermissionsViewAllRecords;
        target.PermissionsModifyAllRecords = target.PermissionsModifyAllRecords || op.PermissionsModifyAllRecords;
    }
}

List<ObjectPermissions> objsToInsert = new List<ObjectPermissions>();
List<ObjectPermissions> objsToUpdate = new List<ObjectPermissions>();
for (String sobj : mergedObjs.keySet()) {
    if (existingMasterObjs.containsKey(sobj)) {
        ObjectPermissions ex = existingMasterObjs.get(sobj);
        ObjectPermissions src = mergedObjs.get(sobj);
        ex.PermissionsRead = ex.PermissionsRead || src.PermissionsRead;
        ex.PermissionsCreate = ex.PermissionsCreate || src.PermissionsCreate;
        ex.PermissionsEdit = ex.PermissionsEdit || src.PermissionsEdit;
        ex.PermissionsDelete = ex.PermissionsDelete || src.PermissionsDelete;
        ex.PermissionsViewAllRecords = ex.PermissionsViewAllRecords || src.PermissionsViewAllRecords;
        ex.PermissionsModifyAllRecords = ex.PermissionsModifyAllRecords || src.PermissionsModifyAllRecords;
        objsToUpdate.add(ex);
    } else {
        objsToInsert.add(mergedObjs.get(sobj));
    }
}
if (!objsToInsert.isEmpty()) insert objsToInsert;
if (!objsToUpdate.isEmpty()) update objsToUpdate;
System.debug('Merged ObjectPermissions: inserted ' + objsToInsert.size() + ', updated ' + objsToUpdate.size());

// 3. Combine FieldPermissions
Map<String, FieldPermissions> existingMasterFields = new Map<String, FieldPermissions>();
for (FieldPermissions fp : [SELECT Id, SobjectType, Field, PermissionsRead, PermissionsEdit FROM FieldPermissions WHERE ParentId = :masterPs.Id]) {
    existingMasterFields.put(fp.Field, fp);
}

Map<String, FieldPermissions> mergedFields = new Map<String, FieldPermissions>();
for (FieldPermissions fp : [
    SELECT SobjectType, Field, PermissionsRead, PermissionsEdit
    FROM FieldPermissions
    WHERE ParentId IN :sourceSets.keySet()
]) {
    if (!mergedFields.containsKey(fp.Field)) {
        mergedFields.put(fp.Field, new FieldPermissions(
            ParentId = masterPs.Id,
            SobjectType = fp.SobjectType,
            Field = fp.Field,
            PermissionsRead = fp.PermissionsRead,
            PermissionsEdit = fp.PermissionsEdit
        ));
    } else {
        FieldPermissions target = mergedFields.get(fp.Field);
        target.PermissionsRead = target.PermissionsRead || fp.PermissionsRead;
        target.PermissionsEdit = target.PermissionsEdit || fp.PermissionsEdit;
    }
}

List<FieldPermissions> fieldsToInsert = new List<FieldPermissions>();
List<FieldPermissions> fieldsToUpdate = new List<FieldPermissions>();
for (String fld : mergedFields.keySet()) {
    if (existingMasterFields.containsKey(fld)) {
        FieldPermissions ex = existingMasterFields.get(fld);
        FieldPermissions src = mergedFields.get(fld);
        Boolean changed = false;
        if (!ex.PermissionsRead && src.PermissionsRead) { ex.PermissionsRead = true; changed = true; }
        if (!ex.PermissionsEdit && src.PermissionsEdit) { ex.PermissionsEdit = true; changed = true; }
        if (changed) fieldsToUpdate.add(ex);
    } else {
        fieldsToInsert.add(mergedFields.get(fld));
    }
}
if (!fieldsToInsert.isEmpty()) insert fieldsToInsert;
if (!fieldsToUpdate.isEmpty()) update fieldsToUpdate;
System.debug('Merged FieldPermissions: inserted ' + fieldsToInsert.size() + ', updated ' + fieldsToUpdate.size() + ' (Total unique: ' + mergedFields.size() + ')');

// 4. Combine SetupEntityAccess
Set<Id> existingEntities = new Set<Id>();
for (SetupEntityAccess sea : [SELECT SetupEntityId FROM SetupEntityAccess WHERE ParentId = :masterPs.Id]) {
    existingEntities.add(sea.SetupEntityId);
}

List<SetupEntityAccess> entitiesToInsert = new List<SetupEntityAccess>();
for (SetupEntityAccess sea : [SELECT SetupEntityId, SetupEntityType FROM SetupEntityAccess WHERE ParentId IN :sourceSets.keySet()]) {
    if (!existingEntities.contains(sea.SetupEntityId)) {
        existingEntities.add(sea.SetupEntityId);
        entitiesToInsert.add(new SetupEntityAccess(
            ParentId = masterPs.Id,
            SetupEntityId = sea.SetupEntityId
        ));
    }
}
if (!entitiesToInsert.isEmpty()) insert entitiesToInsert;
System.debug('Merged SetupEntityAccess: inserted ' + entitiesToInsert.size());
