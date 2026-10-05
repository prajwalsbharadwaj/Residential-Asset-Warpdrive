public with sharing class SAPCustomerIntegrationHandler {
    
    @future(callout=true)
    public static void sendCustomerDataAsync(List<Id> accountIds){
        sendCustomerToSAP(accountIds);
    }
    public static List<SAPCustomerWrapper> buildCustomerPayload(List<Id> accountIds) {
        if(!Test.isRunningTest()){
            if (!IntegrationToggle.isEnabled('Residential', 'Create Customer', 'SAP')) {
                return null;
            }
        }
        System.debug('Received Account IDs in future method: ' + accountIds);
        
        if (accountIds.isEmpty()) {
            System.debug('No Account IDs provided to sendCustomerDataAsync.');
            return null;
        }
        
        // Query for the latest account data within the future method
        // This is crucial to get the most up-to-date information
        List<Account> accountsToProcess = [
            SELECT
            Id, Name, Middle_Name__c, Search_Term_1__c, Salutation,
            BillingStreet, BillingPostalCode, BillingCity, BillingCountryCode, BillingState,
            Phone, PersonMobilePhone, Fax, PersonEmail,
            GST_No__c, Company_Code__c, Reconciliation_Account__c, PAN_Number__c,
            Sales_Org__c, Sales_Group__c, Distribution_Channel__c, Division__c,
            Shipping_Condition__c, Tax_Class_CGST__c, Tax_Class_SGST__c, Tax_Class_IGST__c, Tax_Class_UTGST__c,
            LastName, FirstName
            FROM Account
            WHERE Id IN :accountIds
        ];
        
        List<SAPCustomerWrapper> sapCustomerList = new List<SAPCustomerWrapper>();
        
        for (Account acc : accountsToProcess) {
            
            System.debug('Account ID: ' + acc.Id +
                         ' - Queried Values for Sales Area: ' +
                         'Sales_Org__c=' + acc.Sales_Org__c +
                         ', Distribution_Channel__c=' + acc.Distribution_Channel__c +
                         ', Division__c=' + acc.Division__c);
            
            if (String.isBlank(acc.Sales_Org__c) || String.isBlank(acc.Distribution_Channel__c) || String.isBlank(acc.Division__c)) {
                System.debug('WARNING: One or more Sales Area fields are blank for Account ID: ' + acc.Id + ' after re-querying.');
            }
            if (String.isNotBlank(acc.LastName)) {
                SAPCustomerWrapper customer = new SAPCustomerWrapper();
                
                customer.CUSTOMER_ID         = acc.Id;
                customer.name1               = acc.FirstName;
                customer.last_name           = acc.LastName;
                customer.middlename          = acc.Middle_Name__c;
                customer.searchterm1         = acc.Search_Term_1__c;
                customer.title               = AccountHelper.getTitleCode(acc.Salutation); 
                
                if (String.isNotBlank(acc.BillingStreet)) {
                    List<String> streetParts = acc.BillingStreet.split(',', 4);
                    customer.Street1 = streetParts.size() > 0 ? streetParts[0].trim() : '';
                    customer.Street2 = streetParts.size() > 1 ? streetParts[1].trim() : '';
                    customer.Street3 = streetParts.size() > 2 ? streetParts[2].trim() : '';
                    customer.Street4 = streetParts.size() > 3 ? streetParts[3].trim() : '';
                }
                
                customer.Postalcode          = acc.BillingPostalCode;
                customer.City                = acc.BillingCity;
                customer.Country             = acc.BillingCountryCode;
                customer.Region              = AccountHelper.getRegionCode(acc.BillingState); // Using helper method
                customer.telephone1          = acc.Phone;
                customer.mobile1             = acc.PersonMobilePhone;
                customer.faxNo               = acc.Fax;
                customer.email               = acc.PersonEmail;
                customer.taxnum1             = acc.GST_No__c;
                customer.compCode            = acc.Company_Code__c;
                customer.recAcc              = acc.Reconciliation_Account__c;
                customer.pancard             = acc.PAN_Number__c;
                customer.salesorg            = SAPCodeTranslationUtil.getSalesOrgMap().get(acc.Sales_Org__c);
                customer.salesoffice         = SAPCodeTranslationUtil.getSalesOrgMap().get(acc.Sales_Org__c);//same as sales org
                
                customer.salesgroup = String.isNotBlank(acc.Sales_Group__c) ? acc.Sales_Group__c : '';
                
                customer.shipping            = acc.Shipping_Condition__c;
                customer.taxkd1              = acc.Tax_Class_CGST__c;
                customer.taxkd2              = acc.Tax_Class_SGST__c;
                customer.taxkd3              = acc.Tax_Class_IGST__c;
                customer.taxkd4              = acc.Tax_Class_UTGST__c;
                customer.distributionchannel = SAPCodeTranslationUtil.getDistributionChannelMap().get(acc.Distribution_Channel__c);
                customer.division            = SAPCodeTranslationUtil.getDivisionMap().get(acc.Division__c);
                
                sapCustomerList.add(customer);
            }
        }
        
        System.debug('SAP Customer List size (after re-query and mapping): ' + sapCustomerList.size());
        if (!sapCustomerList.isEmpty()) {
            System.debug('No eligible customers to send to SAP after re-querying and mapping.');
        }
        system.debug('Customer JSON Body: '+JSON.Serialize(sapCustomerList));
        return sapCustomerList;
    }
    
    public class responseWrapper{
        public integer statusCode;
        public string responseBody;
    }
    
    public static responseWrapper sendCustomerToSAP(list<Id> accountIds) {
        responseWrapper resWrapper = new responseWrapper();
        if(!Test.isRunningTest()){
            if (!IntegrationToggle.isEnabled('Residential', 'Create Customer', 'SAP')) {
                resWrapper.statusCode = 500;
                resWrapper.responseBody = 'Integration is disabled';
                return resWrapper;
            }
        }
        
        String jsonBody;
        List<SAPCustomerWrapper> customerList = new List<SAPCustomerWrapper>();
        customerList = buildCustomerPayload(accountIds);
        if(!customerList.isEmpty()){
            jsonBody = JSON.serialize(customerList);
        }
        
        jsonBody = jsonBody.replace('"currencyCode":', '"currency":');
        
        String endpointURL = 'callout:SAP/customercreate';
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        HttpResponse response = null;
        
        try {
            request.setEndpoint(endpointURL);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            request.setTimeout(20000);
            
            System.debug('Final payload before SAP callout: ' + jsonBody);
            request.setBody(jsonBody);
            
            response = http.send(request);
            resWrapper.statusCode = response.getStatusCode();
            resWrapper.responseBody = response.getBody();
            System.debug('SAP Response Status: ' + response.getStatusCode());
            System.debug('SAP Response Body: ' + response.getBody());
            
            if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
                List<SAPCustomerResponseProcessor.SAPCustomerResponse> responseWrapperList = 
                    (List<SAPCustomerResponseProcessor.SAPCustomerResponse>) JSON.deserialize(response.getBody(), 
                                                                                              List<SAPCustomerResponseProcessor.SAPCustomerResponse>.class);
                SAPCustomerResponseProcessor.processResponse(customerList, responseWrapperList, response.getBody());
            } else {
                ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                    .withComponentName('SAPCustomerIntegrationHandler')
                    .withDescription('HTTP Error: ' + response.getStatus())
                    .withClassName('SAPCustomerIntegrationHandler')
                    .withMethodName('sendCustomerToSAP')
                    .withRequestBody(jsonBody)
                    .withResponseBody(response.getBody())
                    .withEndpoint(endpointURL)
                    .withDomain('SAP');
                ExceptionLogger.logException(payload);
                //return 'Error: ' + response.getStatus() + ' - ' + response.getBody();
            }
            
        } catch (Exception ex) {
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('SAPCustomerIntegrationHandler')
                .withException(ex)
                .withClassName('SAPCustomerIntegrationHandler')
                .withMethodName('sendCustomerToSAP')
                .withRequestBody(jsonBody)
                .withResponseBody(response != null ? response.getBody() : '')
                .withEndpoint(endpointURL)
                .withDomain('SAP');
            ExceptionLogger.logException(payload);
            //return 'Exception: ' + ex.getMessage();
        }
        return resWrapper;
    }
}