/**
 * @description Processes the response from the SAP Channel Partner creation callout.
 * It is now tailored to handle the specific JSON structure with 'vendor', 'type', and 'msg' fields.
 */
public class SAPChannelPartnerResponseProcessor {

    /**
     * @description Represents the structure of the JSON response from SAP.
     * MODIFIED: Property names now match the lowercase JSON keys from the actual response.
     */
    public class SAPChannelPartnerResponse {
        public String type;     // Was TYPE
        public String srno;     // Was SRNO
        public String vendor;   // MODIFIED: Was CUSTOMER
        public String msg;      // Was MSG
    }

    /**
     * @description Main method to process the list of responses from SAP.
     * @param originalAccountIds The list of Salesforce Account IDs that were part of the original request.
     * @param responseList The list of deserialized response objects from SAP.
     * @param responseBody The raw JSON string of the entire response, used for logging on failure.
     */
    public static void processResponse(List<Id> originalAccountIds, List<SAPChannelPartnerResponse> responseList, String responseBody) {
        System.debug('Response Body '+responseBody);
        System.debug('Response List'+responseList);
        if (originalAccountIds.size() != responseList.size()) {
            Integer payloadSize =  originalAccountIds.size();
            Integer responseSize = responseList.size();
            //throw new CalloutException('Channel Partner request list size (' + payloadSize + ') does not match response list size (' + responseSize + ').');
            //exceptionlogger record - return
            processErrorResponse(originalAccountIds,responseBody);
            return;
        }

        try {
            System.debug('Entered SAPChannelPartnerResponseProcessor.processResponse for ' + originalAccountIds.size() + ' records.');
            
            List<Account> accountsToUpdate = new List<Account>();

            for (Integer i = 0; i < originalAccountIds.size(); i++) {
                Id accountId = originalAccountIds.get(i);
                SAPChannelPartnerResponse sapResponse = responseList.get(i);
				
                if (accountId == null) {
                    System.debug('Skipping response at index ' + i + ' because the original Account ID is null.');
                    continue;
                }

                Account accToUpdate = new Account(Id = accountId);

                // --- MODIFIED: Logic now checks for 'sapResponse.vendor' and 'sapResponse.type' ---
                // This condition checks for a success type ('S') AND the presence of the vendor ID.
                if (sapResponse.type != null && sapResponse.type.equalsIgnoreCase('S') && String.isNotBlank(sapResponse.vendor)) {
                    System.debug('Processing SUCCESS for Account ID: ' + accountId);
                    
                    // Assign the SAP ID from the 'vendor' field.
                    //accToUpdate.SAP_External_Id__c = sapResponse.vendor.replaceFirst('^0+','');
                    accToUpdate.SAP_External_Id__c = sapResponse.vendor;
                    accToUpdate.SAP_Sync_Status__c = 'Success';
                    accToUpdate.SAP_Sync_Message__c = sapResponse.msg;
                } else {
                    System.debug('Processing ERROR for Account ID: ' + accountId);
                    
                    accToUpdate.SAP_Sync_Status__c = 'Error';
                    accToUpdate.SAP_Sync_Message__c = 'SAP Error: ' + sapResponse.msg;
                }
                accountsToUpdate.add(accToUpdate);
            }

            if (!accountsToUpdate.isEmpty()) {
                update accountsToUpdate;
                System.debug('Successfully updated ' + accountsToUpdate.size() + ' Channel Partner Account(s).');
            }

        } catch (Exception e) {
            System.debug('CRITICAL DML FAILURE. Error: ' + e.getMessage());
        }
    }
    
   /**
 * @description Handles SAP JSON responses where type != 'S' (explicit SAP error).
 * Only updates records if SAP returned an error JSON.
 */
    public static void processErrorResponse(List<Id> originalAccountIds,String responseBody) {

            List<Account> accountsToUpdate = new List<Account>();
            for(Id accId:originalAccountIds){
                Account acc = new Account(Id = accId);
                acc.SAP_Sync_Status__c = 'Error';
                acc.SAP_Sync_Message__c = responseBody.abbreviate(131072);
                
                accountsToUpdate.add(acc);
            }
            
            if (!accountsToUpdate.isEmpty()) {
                update accountsToUpdate;
                System.debug('Updated ' + accountsToUpdate.size() + ' Account records with SAP ERROR status.');
            } 
        
    }

}