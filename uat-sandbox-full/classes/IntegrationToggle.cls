/** Basic toggle checker for Integration_Control__mdt. */
public with sharing class IntegrationToggle {
    // Per-transaction cache: key = "project|module|integrationName"
    private static final Map<String, Boolean> CACHE = new Map<String, Boolean>();

    public static String key(String project, String module, String integrationName) {
        return (project == null ? '' : project.trim()) + '|' +
               (module  == null ? '' : module.trim())  + '|' +
               (integrationName == null ? '' : integrationName.trim());
    }

    /**
     * Check a specific integration entry (Project + Module + Integration Name).
     * If no record is found, returns false (safe default).
     */
    public static Boolean isEnabled(String project, String module, String integrationName) {
        String k = key(project, module, integrationName);
        if (CACHE.containsKey(k)) return CACHE.get(k);

        List<Integration_Control__mdt> rows = [
            SELECT Is_Enabled__c
            FROM Integration_Control__mdt
            WHERE Project__c = :project
              AND Module__c = :module
              AND Integration_Name__c = :integrationName
            LIMIT 1
        ];
        Boolean isEnabled = !rows.isEmpty() && rows[0].Is_Enabled__c;
        CACHE.put(k, isEnabled);
        return isEnabled;
    }

    /**
     * Module-level check (Project + Module).
     * Returns true if **any** matching record is enabled.
     */
    public static Boolean isModuleEnabled(String project, String module) {
        String k = key(project, module, null);
        if (CACHE.containsKey(k)) return CACHE.get(k);

        Integer enabledCount = [
            SELECT COUNT()
            FROM Integration_Control__mdt
            WHERE Project__c = :project
              AND Module__c  = :module
              AND Is_Enabled__c = true
        ];
        Boolean isEnabled = enabledCount > 0;
        CACHE.put(k, isEnabled);
        return isEnabled;
    }
    
    public static Date getSyncDates(string module, string integrationName, string project){
        
        List<Integration_Control__mdt> rows = [
            SELECT Sync_From_Date__c
            FROM Integration_Control__mdt
            WHERE  Module__c = :module
              AND Integration_Name__c = :integrationName
            AND Project__c =: project
            LIMIT 1
        ];
        return rows[0].Sync_From_Date__c;
    }

    /** For tests or explicit refresh. */
    public static void clearCache() { CACHE.clear(); }
    
    public static boolean isLogsEnabled(string module, string integrationName, string project, string type){
        List<Integration_Control__mdt> rows = [
            SELECT Enable_Logs__c
            FROM Integration_Control__mdt
            WHERE  Module__c = :module
              AND Integration_Name__c = :integrationName
            AND Project__c =: project AND Type__c =: type
            LIMIT 1
        ];
        return rows[0].Enable_Logs__c;
    }
    
    
}