public class BookingAfterInsertTriggerHandler extends TriggerHandlerBase {
    
    public override void mainEntry(TriggerParameters tp) {
        List<Booking__c> newList = (List<Booking__c>) tp.newList;
        set<Id> opIds = new set<Id>();
        for(Booking__c b:newList){
            if(b.opportunity_Id__c != null){
                opIds.add(b.opportunity_Id__c);
            }
        }
        if(!opIds.isEmpty()){
            BookingHelper.createOppTeamMemberForCRMTeam(opIds);
        }
    }
}