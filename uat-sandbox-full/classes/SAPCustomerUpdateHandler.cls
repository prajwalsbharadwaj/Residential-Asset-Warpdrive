public with sharing class SAPCustomerUpdateHandler {
    
    public class SAPCustomerUpdateWrapper {
        public transient Id CUSTOMER_ID; // Salesforce Record ID, not sent to SAP
        public String businesspartner;
        public String name1;
        public String middlename;
        public String Lastname;
        public String langu = 'EN';
        public String searchterm1;
        public String Street1;
        public String Street2;
        public String Street3;
        public String Street4;
        public String Postalcode;
        public String City;
        public String Country;
        public String Region;
        public String telephone1;
        public String email;
        public String taxnum1;
        public String panno;
        public String compCode;
        public String recAcc;
        public String salesorg;
        public String distributionchannel;
        public String division;
        public String salesDist = 'NORTH';
        public String currencyCode = 'INR';
        public String priceGroup;
        public String custpriceprocedure;
        public String vwerk;
        public String shipping;
        public String zterm = 'Z002';
        public String ktgrd = 'Z1';
        public String taxkd1;
        public String taxkd2;
        public String taxkd3;
        public String taxkd4;
        public String taxkd5;
        public String adhar;
        public String bank_key;
        public String bank_acc;
        public String Valid_From;
        public String Valid_To;
        public String hold_name;
        public String sales_off;
        public String sales_grp;
    }
    
    /**
* @description Asynchronous method to send Account updates to SAP.
* This method is wrapped in a try/finally block to ensure the recursion guard is always reset.
*/
    @future(callout=true)
    public static void sendCustomerUpdateAsync(Set<Id> accountIds) {
        if(!Test.isRunningTest()){
            if (!IntegrationToggle.isEnabled('Residential', 'Customer Update', 'SAP')) {
                return;
            }
        }
        
        // Activate the asynchronous guard to prevent other jobs from starting
        UtilityClass.isSAPSyncInProgress = true;
        
        try {
            if (accountIds == null || accountIds.isEmpty()) {
                System.debug('No Account IDs provided to sendCustomerUpdateAsync.');
                return; // Exit if no IDs were provided
            }
            
            // Query for the most up-to-date record data
            List<Account> accountsToProcess = [
                SELECT Id, Name, SAP_External_Id__c, FirstName, Middle_Name__c, LastName, Search_Term_1__c,
                BillingStreet, BillingPostalCode, BillingCity, BillingCountryCode, BillingState, Phone, PersonEmail, 
                GST_No__c, PAN_Number__c, Aadhar_Number__c, Company_Code__c, Reconciliation_Account__c, Sales_Org__c, 
                Distribution_Channel__c, Division__c, Shipping_Condition__c, Acct_Assignment_Group__c, 
                Tax_Class_CGST__c, Tax_Class_SGST__c, Tax_Class_IGST__c, IFSC_Code__c, BANK_ACCOUNT_NO__c,Tax_Class_UTGST__c,
                Beneficiary_Name_Account_Holder_Name__c, Sales_Group__c
                FROM Account
                WHERE Id IN :accountIds
            ];
            
            List<SAPCustomerUpdateWrapper> sapCustomerList = new List<SAPCustomerUpdateWrapper>();
            
            for (Account acc : accountsToProcess) {
                SAPCustomerUpdateWrapper customer = new SAPCustomerUpdateWrapper();
                
                // --- Field Mapping ---
                // CRITICAL: Map the SF ID for the response processor to use
                customer.CUSTOMER_ID = acc.Id; 
                
                customer.businesspartner = acc.SAP_External_Id__c;
                customer.name1 = acc.FirstName;
                customer.middlename = acc.Middle_Name__c;
                customer.Lastname = acc.LastName;
                customer.searchterm1 = acc.Search_Term_1__c;
                
                if (String.isNotBlank(acc.BillingStreet)) {
                    List<String> streetParts = acc.BillingStreet.split(',', 4);
                    customer.Street1 = streetParts.size() > 0 ? streetParts[0].trim() : '';
                    customer.Street2 = streetParts.size() > 1 ? streetParts[1].trim() : '';
                    customer.Street3 = streetParts.size() > 2 ? streetParts[2].trim() : '';
                    customer.Street4 = streetParts.size() > 3 ? streetParts[3].trim() : '';
                }
                
                customer.Postalcode = acc.BillingPostalCode;
                customer.City = acc.BillingCity;
                customer.Country = acc.BillingCountryCode;
                customer.Region = AccountHelper.getRegionCode(acc.BillingState);
                customer.telephone1 = acc.Phone;
                customer.email = acc.PersonEmail;
                customer.taxnum1 = acc.GST_No__c;
                customer.panno = acc.PAN_Number__c;
                customer.compCode = acc.Company_Code__c;
                customer.recAcc = acc.Reconciliation_Account__c;
                customer.salesorg = SAPCodeTranslationUtil.getSalesOrgMap().get(acc.Sales_Org__c);
                customer.sales_off = SAPCodeTranslationUtil.getSalesOrgMap().get(acc.Sales_Org__c);
                customer.distributionchannel = SAPCodeTranslationUtil.getDistributionChannelMap().get(acc.Distribution_Channel__c);
                customer.division = SAPCodeTranslationUtil.getDivisionMap().get(acc.Division__c);
                customer.shipping = acc.Shipping_Condition__c;
                customer.taxkd1 = acc.Tax_Class_CGST__c;
                customer.taxkd2 = acc.Tax_Class_SGST__c;
                customer.taxkd3 = acc.Tax_Class_IGST__c;
                customer.taxkd4 = acc.Tax_Class_UTGST__c;
                customer.bank_key = acc.IFSC_Code__c;
                customer.bank_acc = acc.BANK_ACCOUNT_NO__c;
                customer.hold_name = acc.Beneficiary_Name_Account_Holder_Name__c;
                customer.sales_grp = String.isNotBlank(acc.Sales_Group__c) ? acc.Sales_Group__c : '';
                customer.adhar = acc.Aadhar_Number__c;
                //customer.priceGroup
                //customer.custpriceprocedure
                //customer.vwerk //blank ?
                //customer.taxkd5
                //customer.Valid_from = DateTime.now().format('dd.MM.yyyy');
                //customer.Valid_to  = '31.12.9999';
                //
                sapCustomerList.add(customer);
            }
            
            if (!sapCustomerList.isEmpty()) {
                sendUpdateToSAP(sapCustomerList);
            }
            
        } catch (Exception e) {
            System.debug(e.getMessage());
            ExceptionLogger.logException(
                new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('SAPCustomerUpdateHandler')
                .withDescription('An unexpected error occurred in the async update process.')
                .withClassName('SAPCustomerUpdateHandler')
                .withMethodName('sendCustomerUpdateAsync')
                .withException(e)
            );
        } finally {
            // CRITICAL: Always reset the guard so the next trigger execution can queue a new job.
            UtilityClass.isSAPSyncInProgress = false;
        }
    }
    
    /**
* @description Constructs and sends the HTTP request to SAP and handles the response.
*/
    public static void sendUpdateToSAP(List<SAPCustomerUpdateWrapper> customerList) {
        String endpointURL = 'callout:SAP/zcustomerupdate';
        String jsonBody = JSON.serialize(customerList)
            .replace('Valid_From', 'Valid from')
            .replace('Valid_To', 'Valid to')
			.replace('"currencyCode":', '"currency":');
        HttpResponse response = null;
        System.debug('jsonBody: ' + jsonBody);
        System.debug(jsonBody);
        try {
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpointURL);
            request.setMethod('PATCH'); // Or PUT, depending on API requirements
            request.setHeader('Content-Type', 'application/json');
            request.setBody(jsonBody);
            
            response = new Http().send(request);
            System.debug(response.getBody());
            if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
                // Handle success responses that are expected to have a body
                List<SAPCustomerUpdateResponseProcessor.SAPUpdateResponse> responseList = 
                    (List<SAPCustomerUpdateResponseProcessor.SAPUpdateResponse>) JSON.deserialize(
                        response.getBody(), List<SAPCustomerUpdateResponseProcessor.SAPUpdateResponse>.class
                    );
                SAPCustomerUpdateResponseProcessor.processResponse(customerList, responseList, response.getBody());
                
            } else if (response.getStatusCode() == 204) {
                // Handle 'No Content' success response, assuming all were successful
                // Note: This block is for APIs that don't return a body on success.
                // If your API always returns a body, this block may not be needed.
                SAPCustomerUpdateResponseProcessor.processResponse(customerList, new List<SAPCustomerUpdateResponseProcessor.SAPUpdateResponse>(), '');
                
            } else {
                // Handle all other non-success status codes as errors
                ExceptionLogger.logException(
                    new ExceptionLogger.ExceptionLogPayload()
                    .withComponentName('SAPCustomerUpdateHandler')
                    .withDescription('HTTP Error on update: ' + response.getStatus())
                    .withRequestBody(jsonBody)
                    .withResponseBody(response.getBody())
                    .withEndpoint(endpointURL)
                );
            }
            
        } catch (Exception ex) {
            ExceptionLogger.logException(
                new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('SAPCustomerUpdateHandler')
                .withDescription('Exception during SAP update callout.')
                .withException(ex)
                .withRequestBody(jsonBody)
                .withResponseBody(response != null ? response.getBody() : '')
                .withEndpoint(endpointURL)
            );
        }
    }
}