/**
 * @description Handles the integration with SAP for creating and updating Channel Partner Accounts.
 * Contains both asynchronous methods (for triggers - Queueable callouts) and synchronous methods (for manual retry).
 */
public with sharing class SAPChannelPartnerIntegrationHandler {

    private SAPChannelPartnerIntegrationHandler() {}
    @TestVisible
    private static Boolean forceToggleCheckInTests = false;

    /**
     * @description Inner class to hold the synchronous response for the LWC retry component.
     */
    public class responseWrapper {
        @AuraEnabled public integer statusCode;
        @AuraEnabled public string responseBody;
    }

    // =================================================================================
    // ASYNCHRONOUS METHODS (for Triggers) - No changes here
    // =================================================================================

    public static void sendChannelPartnerDataAsync(List<Id> accountIds) {
        if (!Test.isRunningTest() || forceToggleCheckInTests) {
            if (!IntegrationToggle.isEnabled('Residential', 'Create Broker', 'SAP')) {
                System.debug('Broker creation integration is disabled.');
                return;
            }
        }
        if (accountIds != null && !accountIds.isEmpty()) {
            //System.debug('Accounts to be processed '+accountIds);
            System.enqueueJob(new SAPChannelPartnerQueueable(accountIds));
        } else {
            System.debug('No Account IDs provided to sendChannelPartnerDataAsync.');
        }
    }

    public static void sendChannelPartnerUpdateAsync(List<Id> accountIds) {
       if (!Test.isRunningTest() || forceToggleCheckInTests) {
            if (!IntegrationToggle.isEnabled('Residential', 'Update Broker', 'SAP')) {
                System.debug('Broker update integration is disabled.');
                return;
            }
        }
        if (accountIds != null && !accountIds.isEmpty()) {
            System.enqueueJob(new SAPChannelPartnerUpdateQueueable(accountIds));
        } else {
            System.debug('No Account IDs provided for Channel Partner Update.');
        }
    }


    // =================================================================================
    // SYNCHRONOUS METHOD (for LWC Retry Button)
    // This performs the callout immediately and returns a direct response.
    // =================================================================================
    public static responseWrapper sendChannelPartnerDataSync(Id accountId) {
       //try-catch
        responseWrapper resWrapper = new responseWrapper();
        String jsonBody = null;
        String endpointURL = null;
        try{
            // Query for all fields needed for either a create or an update payload.
            List<Account> accounts = [
                SELECT Id, SAP_External_Id__c, Name, BillingStreet, BillingPostalCode, BillingCity, BillingState,
                Phone, PersonMobilePhone, PersonEmail, GST_No__c, PAN_Number__c, Account_Group__c, Search_Term_1__c, Language__c,
                Reconciliation_Account__c, Name_1_of_Vendor_Organization__c, Name_2_of_Vendor_Organization__c,
                Name_3_of_Vendor_Organization__c, Tax_Number_Category__c, Bank_Country__c,
                IFSC_Code__c, BANK_ACCOUNT_NO__c, Beneficiary_Name_Account_Holder_Name__c,
                Withholding_Tax_Type__c, Withholding_Tax_Code__c, Lower_Deduction_Certificate_No__c,
                RERA_Number__c, RERA_VALID_FROM__c, RERA_VALID_TO__c
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];
            
            if (accounts.isEmpty()) {
                resWrapper.statusCode = 404;
                resWrapper.responseBody = 'Account record not found.';
                return resWrapper;
            }
            
            Account acc = accounts[0];

            
            // Determine if this is a CREATE or UPDATE call based on the SAP External ID
            if (String.isBlank(acc.SAP_External_Id__c)) {
                // --- CREATE LOGIC ---
                if (!IntegrationToggle.isEnabled('Residential', 'Create Broker', 'SAP')) {
                    resWrapper.statusCode = 500; resWrapper.responseBody = 'Broker creation integration is disabled.'; return resWrapper;
                }
                SAPChannelPartnerWrapper createPayload = buildChannelPartnerPayload(acc);
                jsonBody = JSON.serialize(createPayload);
                endpointURL = 'callout:SAP/brokercreation';
                System.debug('Payload '+createPayload);
                
            } else {
                // --- UPDATE LOGIC ---
                if (!IntegrationToggle.isEnabled('Residential', 'Update Broker', 'SAP')) {
                    resWrapper.statusCode = 500; resWrapper.responseBody = 'Broker update integration is disabled.'; return resWrapper;
                }
                SAPChannelPartnerWrapper updatePayload = buildUpdatePayload(acc);
                jsonBody = JSON.serialize(updatePayload);
                endpointURL = 'callout:SAP/brokerupdate';
            }
            
            // Perform the HTTP Callout
            HttpResponse response = performHttpCallout(endpointURL, jsonBody);
            
            if (response != null) {
                resWrapper.statusCode = response.getStatusCode();
                resWrapper.responseBody = response.getBody();
                
                // Process the response to update the SF record, just like the Queueable does
                // A 204 (No Content) status is also a success for some update APIs.
                
                 
                if (response.getStatusCode() == 200) {    
                    List<SAPChannelPartnerResponseProcessor.SAPChannelPartnerResponse> responseWrapperList =
                    (List<SAPChannelPartnerResponseProcessor.SAPChannelPartnerResponse>) JSON.deserialize(
                        response.getBody(),
                        List<SAPChannelPartnerResponseProcessor.SAPChannelPartnerResponse>.class);
                    SAPChannelPartnerResponseProcessor.processResponse(new List<Id>{ accountId }, responseWrapperList, response.getBody());
                    
                } else {
                    //removde exception logger and add it to the catch block, also call the errormethod of the response processor
                    SAPChannelPartnerResponseProcessor.processErrorResponse(new List<Id>{ accountId }, response.getBody());
                }
            } else {
                resWrapper.statusCode = 500;
                resWrapper.responseBody = 'Callout failed. Check exception logs for details.';
            }
    	}
        catch(Exception e){resWrapper.statusCode = 500;resWrapper.responseBody = e.getMessage();

        ExceptionLogger.logException(new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('SAPChannelPartnerIntegrationHandler').withDescription('Unhandled exception in sendChannelPartnerDataSync').withRequestBody(jsonBody).withResponseBody(resWrapper.responseBody).withEndpoint(endpointURL)
                .withClassName('SAPChannelPartnerIntegrationHandler').withMethodName('sendChannelPartnerDataSync')
        );
        }
        return resWrapper;
    }

    private static HttpResponse performHttpCallout(String endpointURL, String jsonBody) {
        HttpResponse response = null;
        try {
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpointURL);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            request.setBody(jsonBody);
            response = new Http().send(request);
        } catch (Exception ex) {
            ExceptionLogger.logException(
                new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('SAPChannelPartnerIntegrationHandler')
                .withException(ex).withRequestBody(jsonBody).withEndpoint(endpointURL)
                .withClassName('SAPChannelPartnerIntegrationHandler').withMethodName('performHttpCallout')
            );
        }
        return response;
    }

    /**
     * @description Builds the payload for a NEW Channel Partner.
     * Logic is identical to the original SAPChannelPartnerQueueable.
     */
/*
    private static SAPChannelPartnerWrapper buildCreatePayload(Account acc) {
        SAPChannelPartnerWrapper partner = new SAPChannelPartnerWrapper();
        partner.NAME_ORG1 = acc.Name_1_of_Vendor_Organization__c;
        partner.KTOKK = new Map<String, String>{'Residential Sales' => 'V001'}.get(acc.Account_Group__c);
        partner.SORTL = acc.Search_Term_1__c;
        if (String.isNotBlank(acc.BillingStreet)) {
            List<String> streetParts = acc.BillingStreet.split(',', 4);
            partner.STR_SUPPL1 = streetParts.size() > 0 ? streetParts[0].trim() : '';
            partner.STR_SUPPL2 = streetParts.size() > 1 ? streetParts[1].trim() : '';
            partner.STR_SUPPL3 = streetParts.size() > 2 ? streetParts[2].trim() : '';
            partner.STR_SUPPL4 = streetParts.size() > 3 ? streetParts[3].trim() : '';
        }
        partner.PSTLZ = acc.BillingPostalCode;
        partner.MCOD3 = acc.BillingCity;
        partner.REGIO = AccountHelper.getRegionCode(acc.BillingState);
        partner.SPRAS = acc.Language__c;
        partner.TEL_NUMBER = acc.Phone;
        partner.MOB_NUMBER = acc.Phone; // Create uses Phone for both
        partner.TAXNUMXL = acc.GST_No__c;
        partner.J_1IPANNO = acc.PAN_Number__c;
        partner.AKONT = acc.Reconciliation_Account__c;
        partner.NAME_ORG2 = acc.Name_2_of_Vendor_Organization__c;
        partner.NAME_ORG3 = acc.Name_3_of_Vendor_Organization__c;
        partner.TAXTYPE = acc.Tax_Number_Category__c;
        partner.BANKS = acc.Bank_Country__c;
        partner.BANKL = acc.IFSC_Code__c;
        partner.BANKN = acc.BANK_ACCOUNT_NO__c;
        partner.ACCNAME = acc.Beneficiary_Name_Account_Holder_Name__c;
        partner.WT_TYPE = acc.Withholding_Tax_Type__c;
        partner.WT_CODE = acc.Withholding_Tax_Code__c;
        partner.LOWER_DED_CERT_NO = acc.Lower_Deduction_Certificate_No__c;
        partner.RENA_NUMBER = acc.RERA_Number__c;
        partner.RERA_VALID_FROM = acc.RERA_VALID_FROM__c != null ? String.valueOf(acc.RERA_VALID_FROM__c.year()) + String.valueOf(acc.RERA_VALID_FROM__c.month()).leftPad(2, '0') + String.valueOf(acc.RERA_VALID_FROM__c.day()).leftPad(2, '0') : null;
        partner.RERA_VALID_TO = acc.RERA_VALID_TO__c != null ? String.valueOf(acc.RERA_VALID_TO__c.year()) + String.valueOf(acc.RERA_VALID_TO__c.month()).leftPad(2, '0') + String.valueOf(acc.RERA_VALID_TO__c.day()).leftPad(2, '0') : null;
        return partner;
    }
*/
  
    private static SAPChannelPartnerWrapper buildUpdatePayload(Account acc) {
        SAPChannelPartnerWrapper partner = buildChannelPartnerPayload(acc);
        partner.PARTNER = acc.SAP_External_Id__c;
        return partner;
    }
    
    private static SAPChannelPartnerWrapper buildChannelPartnerPayload(Account acc) {
        SAPChannelPartnerWrapper partner = new SAPChannelPartnerWrapper();
        // The key fields for an update
        partner.NAME_ORG1 = acc.Name; // Name should be passed instead of Org1

        // All other relevant fields
        partner.KTOKK = new Map<String, String>{'Residential Sales' => 'V001'}.get(acc.Account_Group__c);
        partner.SORTL = acc.Search_Term_1__c;
        if (String.isNotBlank(acc.BillingStreet)) {
            List<String> streetParts = acc.BillingStreet.split(',', 4);
            partner.STR_SUPPL1 = streetParts.size() > 0 ? streetParts[0].trim() : '';
            partner.STR_SUPPL2 = streetParts.size() > 1 ? streetParts[1].trim() : '';
            partner.STR_SUPPL3 = streetParts.size() > 2 ? streetParts[2].trim() : '';
            partner.STR_SUPPL4 = streetParts.size() > 3 ? streetParts[3].trim() : '';
        }
        partner.PSTLZ = acc.BillingPostalCode;
        partner.MCOD3 = acc.BillingCity;
        partner.REGIO = AccountHelper.getRegionCode(acc.BillingState);
        partner.SPRAS = acc.Language__c;
        partner.TEL_NUMBER = acc.Phone;
        partner.MOB_NUMBER = acc.PersonMobilePhone; // Update payload uses PersonMobilePhone
        partner.SMTP_ADDR = acc.PersonEmail;
        partner.TAXNUMXL = acc.GST_No__c;
        partner.J_1IPANNO = acc.PAN_Number__c;
        partner.AKONT = acc.Reconciliation_Account__c;
        partner.NAME_ORG2 = acc.Name_2_of_Vendor_Organization__c;
        partner.NAME_ORG3 = acc.Name_3_of_Vendor_Organization__c;
        partner.TAXTYPE = acc.Tax_Number_Category__c;
        partner.BANKS = acc.Bank_Country__c;
        partner.BANKL = acc.IFSC_Code__c;
        partner.BANKN = acc.BANK_ACCOUNT_NO__c;
        partner.ACCNAME = acc.Beneficiary_Name_Account_Holder_Name__c;
        partner.WT_TYPE = acc.Withholding_Tax_Type__c;
        partner.WT_CODE = acc.Withholding_Tax_Code__c;
        partner.LOWER_DED_CERT_NO = acc.Lower_Deduction_Certificate_No__c;
        partner.RENA_NUMBER = acc.RERA_Number__c;
        partner.RERA_VALID_FROM = acc.RERA_VALID_FROM__c != null ? String.valueOf(acc.RERA_VALID_FROM__c.year()) + (acc.RERA_VALID_FROM__c.month() < 10 ? '0' : '') + acc.RERA_VALID_FROM__c.month() + (acc.RERA_VALID_FROM__c.day() < 10 ? '0' : '') + acc.RERA_VALID_FROM__c.day() : null;
        partner.RERA_VALID_TO = acc.RERA_VALID_TO__c != null ? String.valueOf(acc.RERA_VALID_TO__c.year()) + (acc.RERA_VALID_TO__c.month() < 10 ? '0' : '') + acc.RERA_VALID_TO__c.month() + (acc.RERA_VALID_TO__c.day() < 10 ? '0' : '') + acc.RERA_VALID_TO__c.day() : null;
        return partner;
    }
}