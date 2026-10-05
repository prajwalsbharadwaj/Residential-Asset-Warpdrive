/**
 * @description: Apex controller to search for records of a specified SObject type.
 * This controller uses dynamic SOQL to be reusable for any object.
 */
public with sharing class RecordSearchController {

    /**
     * @description: Searches for records based on a search term for a given SObject.
     * @param objectApiName The API name of the SObject to search (e.g., 'Account', 'Contact').
     * @param searchTerm The text to search for in the Name field.
     * @return A list of SObjects matching the search criteria.
     */
    @AuraEnabled(cacheable=true)
    public static List<SObject> searchRecords(String objectApiName, String searchTerm) {
        final String COMPONENT = 'RecordSearchController';
        final String CLASS_NAME = 'RecordSearchController';
        final String METHOD_NAME = 'searchRecords';

        try {
            Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
            if (!schemaMap.containsKey(objectApiName)) {
                throw new AuraHandledException('Invalid SObject API Name: ' + objectApiName);
            }

            // Sanitize the search term to prevent SOQL injection.
            String sanitizedSearchTerm = '%' + String.escapeSingleQuotes(searchTerm) + '%';

            // Build and execute dynamic query.
            String query = 'SELECT Id, Name FROM ' + objectApiName + 
                           ' WHERE Name LIKE :sanitizedSearchTerm ORDER BY Name ASC LIMIT 10';
            return Database.query(query);

        } catch (Exception ex) {
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName(COMPONENT)
                .withClassName(CLASS_NAME)
                .withMethodName(METHOD_NAME)
                .withRequestBody('objectApiName=' + objectApiName + ', searchTerm=' + searchTerm)
                .withDomain('Core')
                .withIntegrationType('Internal')
                .withErrorType('Unhandled Exception')
                .withException(ex);
            ExceptionLogger.logException(payload);

            throw new AuraHandledException('An error occurred while searching for records.');
        }
    }
}