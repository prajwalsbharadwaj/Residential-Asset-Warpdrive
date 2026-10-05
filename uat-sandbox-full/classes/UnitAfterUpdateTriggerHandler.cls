public class UnitAfterUpdateTriggerHandler extends TriggerHandlerBase {

    private UnitHelper helper = new UnitHelper();
    
    public override void mainEntry(TriggerParameters tp) {
        
        List<Id> unitIds = new List<Id>();
        for(Unit__c unit : (List<Unit__c>)tp.newList){
            if(unit.Status__c != ((Unit__c)tp.oldMap.get(unit.Id)).Status__c && unit.SAP_Sync_Status__c == 'Pending update'){
                unitIds.add(unit.Id);
            }
        }
        
        if(!unitIds.isEmpty()){
            SAPUnitIntegrationHandler.sendUnitStatusUpdateDataAsync(unitIds);
        }
    }
}