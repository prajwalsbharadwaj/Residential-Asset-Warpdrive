public with sharing class UtilityClass {
    
    public static Integer CURRENT_FISCAL_YEAR {
        get {
            if(CURRENT_FISCAL_YEAR == null){
                Period period = [SELECT FiscalYearSettings.Name FROM Period WHERE StartDate <= TODAY AND EndDate >= TODAY AND Type = 'Year'];
                CURRENT_FISCAL_YEAR = Integer.valueOf(period.FiscalYearSettings.Name);
            }
            return CURRENT_FISCAL_YEAR;
        } private set;
    }
    
    /** 
     *  Manages SYNCHRONOUS DML recursion.
     *  Set to true right before a DML statement inside the trigger helper.
     */
    public static Boolean isAfterUpdateRunning = false;
    
    public static Boolean isCPApprovalResetInProgress = false;

	// Static boolean to handle recursion.
	public static Boolean isSAPSyncInProgress = false;
	/*
	* @description Gets the type name of the SObject.
	* @param SObject The SObject for which the name to be obtained.
	* @return String - The type name.
	*/
    
    //static boolean to handle before insert booking condition records
    public static Boolean isBeforeInsertProcessing = false;
    
	public static String getSObjectTypeName(SObject so) {
		return so.getSObjectType().getDescribe().getName();
	}
    
    /*
    * @description Checks if triggers are globally disabled using Trigger_Setting__mdt.
    *              Uses getAll().values() to fetch the only CMDT record.
    */
    private static Boolean isTriggerDisabledCached;
    
    public static Boolean isTriggerGloballyDisabled() {
        if (isTriggerDisabledCached == null) {
            isTriggerDisabledCached = false;
            List<Trigger_Setting__mdt> allSettings = new List<Trigger_Setting__mdt>(Trigger_Setting__mdt.getAll().values());
            if (!allSettings.isEmpty()) {
                isTriggerDisabledCached = allSettings[0].Disable_Trigger__c;
            }
        }
        return isTriggerDisabledCached;
    }
}