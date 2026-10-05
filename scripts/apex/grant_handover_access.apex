// Check Handover tab and permission set
Id userId = UserInfo.getUserId();
System.debug('Current user ID: ' + userId);

// Find admin permission set or create a dedicated Handover permission set
List<PermissionSet> existingPS = [SELECT Id, Name FROM PermissionSet WHERE Name = 'Handover_Administrator'];
PermissionSet ps;
if (existingPS.isEmpty()) {
    ps = new PermissionSet(
        Name = 'Handover_Administrator',
        Label = 'Handover Administrator'
    );
    insert ps;
    System.debug('Created PermissionSet: ' + ps.Id);
} else {
    ps = existingPS[0];
    System.debug('Found PermissionSet: ' + ps.Id);
}

// 1. Grant ObjectPermissions on Booking__c (Parent master-detail object)
List<ObjectPermissions> bookingPerms = [SELECT Id FROM ObjectPermissions WHERE ParentId = :ps.Id AND SobjectType = 'Booking__c'];
if (bookingPerms.isEmpty()) {
    insert new ObjectPermissions(
        ParentId = ps.Id,
        SobjectType = 'Booking__c',
        PermissionsRead = true,
        PermissionsCreate = true,
        PermissionsEdit = true,
        PermissionsDelete = true,
        PermissionsViewAllRecords = true,
        PermissionsModifyAllRecords = true
    );
    System.debug('Granted ObjectPermissions on Booking__c');
}

// 2. Grant ObjectPermissions on Handover__c
List<ObjectPermissions> objPerms = [SELECT Id FROM ObjectPermissions WHERE ParentId = :ps.Id AND SobjectType = 'Handover__c'];
if (objPerms.isEmpty()) {
    insert new ObjectPermissions(
        ParentId = ps.Id,
        SobjectType = 'Handover__c',
        PermissionsRead = true,
        PermissionsCreate = true,
        PermissionsEdit = true,
        PermissionsDelete = true,
        PermissionsViewAllRecords = true,
        PermissionsModifyAllRecords = true
    );
    System.debug('Granted ObjectPermissions on Handover__c');
}

// 3. Set PermissionSetTabSetting for Handover__c
List<PermissionSetTabSetting> tabSettings = [SELECT Id, Name, Visibility FROM PermissionSetTabSetting WHERE ParentId = :ps.Id AND Name = 'Handover__c'];
if (tabSettings.isEmpty()) {
    insert new PermissionSetTabSetting(
        ParentId = ps.Id,
        Name = 'Handover__c',
        Visibility = 'DefaultOn'
    );
    System.debug('Set PermissionSetTabSetting Handover__c to DefaultOn');
}

// 4. Assign PermissionSet to current user and all System Administrators
List<User> admins = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true];
List<PermissionSetAssignment> newAssignments = new List<PermissionSetAssignment>();
Set<Id> alreadyAssigned = new Set<Id>();
for (PermissionSetAssignment psa : [SELECT AssigneeId FROM PermissionSetAssignment WHERE PermissionSetId = :ps.Id]) {
    alreadyAssigned.add(psa.AssigneeId);
}
for (User u : admins) {
    if (!alreadyAssigned.contains(u.Id)) {
        newAssignments.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id));
    }
}
if (!newAssignments.isEmpty()) {
    insert newAssignments;
    System.debug('Assigned Handover_Administrator to ' + newAssignments.size() + ' active System Administrators.');
}
