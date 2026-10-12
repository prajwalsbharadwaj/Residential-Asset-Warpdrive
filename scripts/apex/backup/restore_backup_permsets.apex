/**
 * RESTORE SCRIPT: Restores original individual permission set assignments
 * for all 6 team members if ever needed.
 */
Map<Id, List<String>> userToOriginalSets = new Map<Id, List<String>>{
    '005Va00000MTjltIAD' => new List<String>{'GRE_Front_Desk_Access', 'Handover_Administrator', 'Lead_Archive_Access'}, // Prajwal
    '005Va00000MUBphIAH' => new List<String>{'Handover_Administrator'}, // Manvi
    '005Va00000MYR9BIAX' => new List<String>{'Handover_Administrator'}, // Shubham
    '005Va00000MY1bXIAT' => new List<String>{'Handover_Administrator', 'ResaleAssistance_Access', 'Residential_Handover_Manager'}, // Somya
    '005Va00000MtSjyIAF' => new List<String>{'GRE_Front_Desk_Access', 'Handover_Administrator', 'Lead_Archive_Access', 'ResaleAssistance_Access'}, // Swapna
    '005aj00000VDBOnAAP' => new List<String>{'Handover_Administrator', 'Nikoo_Sales_Targets', 'ResaleAssistance_Access', 'WD_Customer_Documents', 'WD_Glass_UI'} // Namit
};

// Map PermissionSet Name to Id
Map<String, Id> psNameToId = new Map<String, Id>();
for (PermissionSet ps : [SELECT Id, Name FROM PermissionSet]) {
    psNameToId.put(ps.Name, ps.Id);
}

// Find existing assignments to avoid duplicates
Set<String> existingPairs = new Set<String>();
for (PermissionSetAssignment psa : [
    SELECT AssigneeId, PermissionSetId FROM PermissionSetAssignment
    WHERE AssigneeId IN :userToOriginalSets.keySet()
]) {
    existingPairs.add(psa.AssigneeId + '-' + psa.PermissionSetId);
}

List<PermissionSetAssignment> toRestore = new List<PermissionSetAssignment>();
for (Id uId : userToOriginalSets.keySet()) {
    for (String psName : userToOriginalSets.get(uId)) {
        Id psId = psNameToId.get(psName);
        if (psId != null && !existingPairs.contains(uId + '-' + psId)) {
            toRestore.add(new PermissionSetAssignment(
                AssigneeId = uId,
                PermissionSetId = psId
            ));
        }
    }
}

if (!toRestore.isEmpty()) {
    insert toRestore;
    System.debug('Successfully restored ' + toRestore.size() + ' original permission set assignments.');
} else {
    System.debug('All original assignments already in place.');
}
