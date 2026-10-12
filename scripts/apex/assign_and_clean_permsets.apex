Set<Id> userIds = new Set<Id>{
    '005Va00000MUBphIAH', // Manvi Dixit
    '005aj00000VDBOnAAP', // Namit Dasappanavar
    '005Va00000MTjltIAD', // Prajwal Bharadwaj
    '005Va00000MYR9BIAX', // Shubham Nayak
    '005Va00000MY1bXIAT', // Somya Sharma
    '005Va00000MtSjyIAF'  // Swapna Badagowni
};

// 1. Get Master Permission Set
PermissionSet masterPs = [SELECT Id, Name, Label FROM PermissionSet WHERE Name = 'Nikoo_Residential_Master_Access' LIMIT 1];
System.debug('Master Permission Set: ' + masterPs.Name + ' (' + masterPs.Id + ')');

// 2. Assign Master Permission Set to all 6 users
List<PermissionSetAssignment> newAssignments = new List<PermissionSetAssignment>();
Set<Id> alreadyAssigned = new Set<Id>();
for (PermissionSetAssignment psa : [
    SELECT AssigneeId FROM PermissionSetAssignment
    WHERE PermissionSetId = :masterPs.Id AND AssigneeId IN :userIds
]) {
    alreadyAssigned.add(psa.AssigneeId);
}

for (Id uId : userIds) {
    if (!alreadyAssigned.contains(uId)) {
        newAssignments.add(new PermissionSetAssignment(
            PermissionSetId = masterPs.Id,
            AssigneeId = uId
        ));
    }
}
if (!newAssignments.isEmpty()) {
    insert newAssignments;
    System.debug('Assigned Nikoo_Residential_Master_Access to ' + newAssignments.size() + ' users.');
} else {
    System.debug('All 6 users already have Nikoo_Residential_Master_Access.');
}

// 3. Remove redundant custom permission set assignments for these 6 users
Set<String> redundantNames = new Set<String>{
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

List<PermissionSetAssignment> redundantAssignments = [
    SELECT Id, PermissionSet.Name, Assignee.Name
    FROM PermissionSetAssignment
    WHERE AssigneeId IN :userIds AND PermissionSet.Name IN :redundantNames
];

System.debug('Found ' + redundantAssignments.size() + ' redundant custom assignments across the 6 users.');
for (PermissionSetAssignment psa : redundantAssignments) {
    System.debug('Removing redundant: ' + psa.PermissionSet.Name + ' from ' + psa.Assignee.Name);
}
delete redundantAssignments;
System.debug('Successfully cleaned up ' + redundantAssignments.size() + ' redundant assignments.');

// 4. Verify Final State
System.debug('=== FINAL STATE FOR TEAM MEMBERS ===');
for (User u : [SELECT Id, Name, Username FROM User WHERE Id IN :userIds]) {
    List<PermissionSetAssignment> current = [
        SELECT PermissionSet.Name, PermissionSet.Label
        FROM PermissionSetAssignment
        WHERE AssigneeId = :u.Id AND PermissionSet.IsOwnedByProfile = false
        ORDER BY PermissionSet.Name ASC
    ];
    List<String> psNames = new List<String>();
    for (PermissionSetAssignment psa : current) {
        if (!psa.PermissionSet.Name.startsWith('X00')) {
            psNames.add(psa.PermissionSet.Name);
        }
    }
    System.debug('USER ' + u.Name + ' (' + u.Username + ') active custom permsets: ' + String.join(psNames, ', '));
}
