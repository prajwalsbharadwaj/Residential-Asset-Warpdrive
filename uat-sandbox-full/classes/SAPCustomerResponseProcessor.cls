public class SAPCustomerResponseProcessor {

    public class SAPCustomerResponse {
        public String TYPE;
        public String SRNO;
        public String CUSTOMER;
        public String MSG;
    }

    public static void processResponse(List<SAPCustomerWrapper> payloadList, List<SAPCustomerResponse> responseList, String responseBody) {
        
        if (payloadList == null || responseList == null || payloadList.size() != responseList.size()) {
            Integer payloadSize = (payloadList == null) ? 0 : payloadList.size();
            Integer responseSize = (responseList == null) ? 0 : responseList.size();
            throw new CalloutException('Request list size (' + payloadSize + ') does not match response list size (' + responseSize + ').');
        }

        try {
            System.debug('Entered the SAPCustomerResponseProcessor.processResponse ');
            
            List<Account> accountsToUpdate = new List<Account>();

            for (Integer i = 0; i < payloadList.size(); i++) {
                SAPCustomerWrapper originalPayload = payloadList.get(i);
                SAPCustomerResponse sapResponse = responseList.get(i);
				
                Id accountId = originalPayload.CUSTOMER_ID;

                if(accountId == null) {
                    System.debug('Skipping response at index ' + i + ' because the original payload is missing a CUSTOMER_ID.');
                    continue; // Skip this iteration and move to the next
                }

                Account accToUpdate = new Account(Id = accountId);

                if (String.isNotBlank(sapResponse.CUSTOMER)) {
                    system.debug('Customer Created');
                    //accToUpdate.SAP_External_Id__c = sapResponse.CUSTOMER.replaceFirst('^0+','');
                    accToUpdate.SAP_External_Id__c = sapResponse.CUSTOMER;
                    accToUpdate.SAP_Sync_Status__c = 'Success';
                    accToUpdate.SAP_Sync_Message__c = sapResponse.MSG;
                } else {
                    system.debug('Customer did not get Created');
                    accToUpdate.SAP_Sync_Status__c = 'Error';
                    accToUpdate.SAP_Sync_Message__c = sapResponse.MSG;
                }
                accountsToUpdate.add(accToUpdate);
            }

            if (!accountsToUpdate.isEmpty()) {
                update accountsToUpdate;
            }

        } catch (Exception e) {
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload().withComponentName('SAPCustomerResponseProcessor').withDescription('Failed to process SAP customer response: ' + e.getMessage()).withClassName('SAPCustomerResponseProcessor').withMethodName('processResponse').withRequestBody(responseBody).withDomain('SAP').withException(e);
            ExceptionLogger.logException(payload);
        }
    }
}