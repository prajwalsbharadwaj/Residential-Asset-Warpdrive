/**
 * @description A helper class to fetch unit status mappings from a custom metadata type.
 * This centralizes the logic to avoid code duplication and makes the app more flexible.
 */
public with sharing class UnitStatusHelper {

    /**
     * @description A private static final variable to cache the map. This improves performance
     * by querying the custom metadata only once per transaction.
     */
    private static final Map<String, String> CODE_TO_STATUS_MAP = new Map<String, String>();
    private static final Map<String, String> STATUS_TO_CODE_MAP = new Map<String, String>();

    static {
        // Query for all active records where the Domain is 'Unit Status'.
        List<External_Code_Dictionary__mdt> statusRecords = [
            SELECT Code__c, Display_Label__c
            FROM External_Code_Dictionary__mdt
            WHERE Domain__c = 'Unit Status' AND Is_Active__c = true
        ];
        
        // Loop through the records and populate both maps.
        for (External_Code_Dictionary__mdt statusRec : statusRecords) {
            // Ensure the code is not null before adding it to the map.
            if (statusRec.Code__c != null) {
                CODE_TO_STATUS_MAP.put(statusRec.Code__c, statusRec.Display_Label__c);
                STATUS_TO_CODE_MAP.put(statusRec.Display_Label__c, statusRec.Code__c);
            }
        }
    }

    /**
     * @description Fetches the map of status codes to display labels.
     * @return A map with the status code (Code__c) as the key and the display label (Display_Label__c) as the value.
     */
    public static Map<String, String> getCodeToStatusMap() {
        return CODE_TO_STATUS_MAP;
    }

    /**
     * @description Fetches the map of display labels to status codes.
     * @return A map with the display label (Display_Label__c) as the key and the status code (Code__c) as the value.
     */
    public static Map<String, String> getStatusToCodeMap() {
        return STATUS_TO_CODE_MAP;
    }
}