public class UnitBeforeUpdateTriggerHandler extends TriggerHandlerBase {
    
    private UnitHelper helper = new UnitHelper();
    
    //SAP is also updating the unit status using API ResUnitStatusUpdateAPI so in that case 
    //we don't have to call SAP system again for the unit status update 
    public static Boolean unitStatusUpdateInProgress = false;
    
    public override void mainEntry(TriggerParameters tp) {
        
        if(unitStatusUpdateInProgress) return;
        
        for(Unit__c unit : (List<Unit__c>)tp.newList){
            if(unit.Status__c != ((Unit__c)tp.oldMap.get(unit.Id)).Status__c){
                unit.SAP_Sync_Status__c = 'Pending update';
            }
        }
        
    }
}