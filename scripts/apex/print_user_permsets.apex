Set<Id> teamIds = new Set<Id>{
    '005Va00000MUBphIAH', // Manvi Dixit
    '005aj00000VDBOnAAP', // Namit Dasappanavar
    '005Va00000MTjltIAD', // Prajwal Bharadwaj
    '005Va00000MYR9BIAX', // Shubham Nayak
    '005Va00000MY1bXIAT', // Somya Sharma
    '005Va00000MtSjyIAF'  // Swapna Badagowni
};

for (Id uId : teamIds) {
    User u = [SELECT Name, Username FROM User WHERE Id = :uId];
    List<PermissionSetAssignment> psas = [
        SELECT PermissionSet.Name, PermissionSet.Label, PermissionSet.IsCustom
        FROM PermissionSetAssignment
        WHERE AssigneeId = :uId AND PermissionSet.IsOwnedByProfile = false
        ORDER BY PermissionSet.Name ASC
    ];
    List<String> names = new List<String>();
    for (PermissionSetAssignment psa : psas) {
        if (!psa.PermissionSet.Name.startsWith('X00')) {
            names.add(psa.PermissionSet.Name + ' (' + psa.PermissionSet.Label + ')');
        }
    }
    System.debug('>>> ' + u.Name + ' (' + names.size() + '): ' + String.join(names, ' || '));
}
