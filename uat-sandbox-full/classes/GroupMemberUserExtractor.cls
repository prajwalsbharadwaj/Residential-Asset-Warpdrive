public with sharing class GroupMemberUserExtractor {

    public class InputWrapper {
        @InvocableVariable(required=true)
        public Id groupId;
    }

    public class OutputWrapper {
        @InvocableVariable
        public List<String> userIds;

        @InvocableVariable
        public List<String> userEmails;
    }

    @InvocableMethod(label='Get Active User IDs and Emails from Public Groups')
    public static List<OutputWrapper> getGroupMembers(List<InputWrapper> inputList) {
        final String COMPONENT = 'GroupMemberUserExtractor';
        final String CLASS_NAME = 'GroupMemberUserExtractor';
        final String METHOD_NAME = 'getGroupMembers';

        try {
            Set<Id> groupIds = new Set<Id>();
            for (InputWrapper input : inputList) {
                if (input != null && input.groupId != null) {
                    groupIds.add(input.groupId);
                }
            }

            if (groupIds.isEmpty()) {
                return new List<OutputWrapper>();
            }

            // Step 1: Get UserOrGroupIds from GroupMember
            /*Map<Id, Set<Id>> groupToUserIdMap = new Map<Id, Set<Id>>();
            Set<Id> allUserIds = new Set<Id>();

            for (GroupMember gm : [
                SELECT GroupId, UserOrGroupId
                FROM GroupMember
                WHERE GroupId IN :groupIds
            ]) {
                if (gm.UserOrGroupId != null && gm.UserOrGroupId.getSObjectType() == User.SObjectType) {
                    if (!groupToUserIdMap.containsKey(gm.GroupId)) {
                        groupToUserIdMap.put(gm.GroupId, new Set<Id>());
                    }
                    groupToUserIdMap.get(gm.GroupId).add(gm.UserOrGroupId);
                    allUserIds.add(gm.UserOrGroupId);
                }
            }*/
            
            //----------------------------------------------
            // Map to store GroupId → Set of UserIds
            Map<Id, Set<Id>> groupToUserIdMap = new Map<Id, Set<Id>>();
            
            // Set to store all UserIds from all groups
            Set<Id> allUserIds = new Set<Id>();
            
            // Loop through all Group Members
            for (GroupMember gm : [
                SELECT GroupId, UserOrGroupId
                FROM GroupMember
                WHERE GroupId IN :groupIds
            ]) {
            
                // Check if the member is a User (not another group)
                if (gm.UserOrGroupId != null &&
                    gm.UserOrGroupId.getSObjectType() == User.SObjectType) {
            
                    // Step 1: Store GroupId in a variable
                    Id currentGroupId = gm.GroupId;
            
                    // Step 2: Store UserId in a variable
                    Id currentUserId = gm.UserOrGroupId;
            
                    // Step 3: If group is not already in map, create empty Set
                    if (!groupToUserIdMap.containsKey(currentGroupId)) {
                        Set<Id> emptyUserSet = new Set<Id>();
                        groupToUserIdMap.put(currentGroupId, emptyUserSet);
                    }
            
                    // Step 4: Get the Set of users who are already present in the group .
                    Set<Id> usersInThisGroup = groupToUserIdMap.get(currentGroupId);
            
                    // Step 5: Add on the user to the Set
                    usersInThisGroup.add(currentUserId);
            
                    // Step 6: Put the updated Set back into the Map (for clarity)
                    groupToUserIdMap.put(currentGroupId, usersInThisGroup);
            
                    // Step 7: Add user to master list of all users
                    allUserIds.add(currentUserId);
                }
            }
//------------------------------------------

            // Step 2: Get active users
            Map<Id, User> userMap = new Map<Id, User>(
                [SELECT Id, Email FROM User WHERE Id IN :allUserIds AND IsActive = true]
            );

            // Step 3: Construct output
            List<OutputWrapper> results = new List<OutputWrapper>();

            for (InputWrapper input : inputList) {
                List<String> userIds = new List<String>();
                List<String> userEmails = new List<String>();

                if (groupToUserIdMap.containsKey(input.groupId)) {
                    for (Id uid : groupToUserIdMap.get(input.groupId)) {
                        if (userMap.containsKey(uid)) {
                            userIds.add(uid);
                            if (String.isNotBlank(userMap.get(uid).Email)) {
                                userEmails.add(userMap.get(uid).Email);
                            }
                        }
                    }
                }

                OutputWrapper ow = new OutputWrapper();
                ow.userIds = userIds;
                ow.userEmails = userEmails;
                results.add(ow);
            }

            return results;

        } catch (Exception ex) {
            ExceptionLogger.logException(
                new ExceptionLogger.ExceptionLogPayload()
                    .withComponentName(COMPONENT)
                    .withClassName(CLASS_NAME)
                    .withMethodName(METHOD_NAME)
                    .withRequestBody(JSON.serialize(inputList))
                    .withDomain('Core')
                    .withIntegrationType('Internal')
                    .withErrorType('Unhandled Exception')
                    .withException(ex)
            );

            // Safe fallback return
            return new List<OutputWrapper>();
        }
    }
}