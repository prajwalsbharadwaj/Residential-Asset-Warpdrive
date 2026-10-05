PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Handover_Administrator' LIMIT 1];
List<PermissionSetAssignment> toInsert = new List<PermissionSetAssignment>();
for (User u : [SELECT Id FROM User WHERE IsActive = true AND Profile.Name = 'System Administrator']) {
    Integer existing = [SELECT count() FROM PermissionSetAssignment WHERE AssigneeId = :u.Id AND PermissionSetId = :ps.Id];
    if (existing == 0) {
        toInsert.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id));
    }
}
if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('Assigned Handover_Administrator to ' + toInsert.size() + ' users.');
} else {
    System.debug('All admin users already have Handover_Administrator.');
}
