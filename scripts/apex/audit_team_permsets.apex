Set<Id> teamIds = new Set<Id>{
    '005Va00000MUBphIAH', // Manvi Dixit
    '005aj00000VDBOnAAP', // Namit Dasappanavar
    '005Va00000MTjltIAD', // Prajwal Bharadwaj
    '005Va00000MYR9BIAX', // Shubham Nayak
    '005Va00000MY1bXIAT', // Somya Sharma
    '005Va00000MtSjyIAF'  // Swapna Badagowni
};

// Query all assignments for these 6 users
List<PermissionSetAssignment> assignments = [
    SELECT PermissionSetId, PermissionSet.Name, PermissionSet.Label, PermissionSet.IsCustom, Assignee.Name, Assignee.Username
    FROM PermissionSetAssignment
    WHERE AssigneeId IN :teamIds AND PermissionSet.IsOwnedByProfile = false
];

Map<String, Set<String>> userToPermSets = new Map<String, Set<String>>();
Map<String, String> psNameToLabel = new Map<String, String>();
Map<String, Boolean> psNameToIsCustom = new Map<String, Boolean>();
Map<String, Set<String>> psToUsers = new Map<String, Set<String>>();

for (PermissionSetAssignment psa : assignments) {
    String uName = psa.Assignee.Name;
    String psName = psa.PermissionSet.Name;
    if (psName.startsWith('X00')) continue;
    
    if (!userToPermSets.containsKey(uName)) userToPermSets.put(uName, new Set<String>());
    userToPermSets.get(uName).add(psName);
    
    if (!psToUsers.containsKey(psName)) psToUsers.put(psName, new Set<String>());
    psToUsers.get(psName).add(uName);
    
    psNameToLabel.put(psName, psa.PermissionSet.Label);
    psNameToIsCustom.put(psName, psa.PermissionSet.IsCustom);
}

for (String u : userToPermSets.keySet()) {
    System.debug('USER ' + u + ' has ' + userToPermSets.get(u).size() + ' permsets: ' + String.join(new List<String>(userToPermSets.get(u)), ', '));
}

// Also check permission sets created by Prajwal, Manvi, Shubham, Somya, Swapna
for (PermissionSet ps : [
    SELECT Id, Name, Label, CreatedBy.Name, CreatedDate
    FROM PermissionSet
    WHERE CreatedById IN :teamIds AND (NOT Name LIKE 'X00%') AND IsOwnedByProfile = false
]) {
    if (!psToUsers.containsKey(ps.Name)) {
        System.debug('UNASSIGNED CREATED PERMSET: ' + ps.Name + ' | Label: ' + ps.Label + ' | CreatedBy: ' + ps.CreatedBy.Name);
    }
}
