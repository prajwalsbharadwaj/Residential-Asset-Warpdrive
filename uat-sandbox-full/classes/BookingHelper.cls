public class BookingHelper {
    //Whenever a booking record is created this method will create opportunity team member records for users with role: 'CRM_Head, CRM_Member, CRM_Finance_Head'.
    public static void createOppTeamMemberForCRMTeam(set<Id> opIds ){
        
        list<User> UsersByRole = [SELECT Id, Name, UserRole.DeveloperName FROM User WHERE UserRole.DeveloperName IN: ResidentialConstants.CRM_USER_ROLES 
                                  AND Profile.Name =: ResidentialConstants.RESIDENTIAL_BASE_PROFILE];
        system.debug('UsersByRole--> '+ UsersByRole);
        if(UsersByRole.isEmpty()) return;
        list<OpportunityTeamMember> otmList = new list<OpportunityTeamMember>();
        for(Id opId: opIds){
            for(user u:UsersByRole){
                opportunityTeamMember opMember = new opportunityTeamMember();
                opMember.UserId = u.Id;
                opMember.OpportunityAccessLevel = 'Read';
                opMember.TeamMemberRole = ResidentialConstants.CRM_Member;
                opMember.OpportunityId = opId;
                otmList.add(opMember); 
            }
        }
        if(!otmList.isEmpty()){
            insert otmList;
        }
    }
}