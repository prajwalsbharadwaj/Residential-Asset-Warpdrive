public with sharing class SAPCustomerUpdateResponseProcessor {

    public class SAPUpdateResponse {
        public String TYPE;      // e.g., 'S' for Success, 'E' for Error
        public String SRNO;      // Serial number from SAP, if provided
        public String CUSTOMER;  // The SAP External ID, used to identify the record
        public String MSG;       // The detailed success or error message from SAP
    }

    public static void processResponse(List<SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper> payloadList, List<SAPUpdateResponse> responseList, String responseBody) {
        
        if (payloadList == null || responseList == null) {
            logProcessingError('Payload or Response list is null. Cannot process.', null, responseBody);
            return;
        }

        try {
            List<Account> accountsToUpdate = new List<Account>();
            if (responseList.isEmpty() && !payloadList.isEmpty()) {
                for (SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper payload : payloadList) {
                    accountsToUpdate.add(new Account(
                        Id = payload.CUSTOMER_ID,
                        SAP_Sync_Status__c = 'Success',
                        SAP_Sync_Message__c = 'Update processed successfully by SAP.'
                    ));
                }
            } else {
                // For standard responses with a body, use a map for reliable correlation.
                Map<String, SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper> payloadMap = new Map<String, SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper>();
                for (SAPCustomerUpdateHandler.SAPCustomerUpdateWrapper payload : payloadList) {
                    if (String.isNotBlank(payload.businesspartner)) {
                        payloadMap.put(payload.businesspartner, payload);
                    }
                }

                // Iterate through each response item received from SAP
                for (SAPUpdateResponse sapResponse : responseList) {
                    if (String.isNotBlank(sapResponse.CUSTOMER) && payloadMap.containsKey(sapResponse.CUSTOMER)) {
                        
                        Id accountId = payloadMap.get(sapResponse.CUSTOMER).CUSTOMER_ID;
                        Account accToUpdate = new Account(Id = accountId);

                        if ('S'.equalsIgnoreCase(sapResponse.TYPE)) {
                            accToUpdate.SAP_Sync_Status__c = 'Success';
                        } else {
                            accToUpdate.SAP_Sync_Status__c = 'Error';
                        }
                        accToUpdate.SAP_Sync_Message__c = sapResponse.MSG;
                        
                        accountsToUpdate.add(accToUpdate);
                    }
                }
            }

            if (!accountsToUpdate.isEmpty()) {
                update accountsToUpdate;
            }

        } catch (Exception e) {
            logProcessingError('Failed to process SAP customer update response.', e, responseBody);
        }
    }

    /**
     * @description Centralized helper method for logging exceptions.
     */
    private static void logProcessingError(String description, Exception ex, String responseBody) {
        ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
            .withComponentName('SAPCustomerUpdateResponseProcessor')
            .withDescription(description)
            .withClassName('SAPCustomerUpdateResponseProcessor')
            .withMethodName('processResponse')
            .withResponseBody(responseBody)
            .withDomain('SAP');
        
        if (ex != null) {
            payload.withException(ex);
        }
        
        ExceptionLogger.logException(payload);
    }
}