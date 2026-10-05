public with sharing class RetrySapSyncController {
    public class outputWrapper {
        @AuraEnabled public Boolean resp;
        @AuraEnabled public String responseMessage = '';
    }
    
    @AuraEnabled(cacheable=true)
    public static String getObjectApiName(Id recordId){
        if(recordId == null) return null;
        return recordId.getSobjectType().getDescribe().getName();
    }
    
    @AuraEnabled
    public static outputWrapper RetryBookingCalloutToSAP(Id bookingId) {
        outputWrapper wrapper = new outputWrapper();
        wrapper.resp = false;
        wrapper.responseMessage = null;
        
        SAPBookingIntegrationHandler.responseWrapper resWrapper;
        
        try {
            resWrapper = SAPBookingIntegrationHandler.sendBookingData(new Set<Id>{bookingId});
            
            if (resWrapper != null && (resWrapper.statusCode == 200 || resWrapper.statusCode == 201)) {
                wrapper.resp = true;
                wrapper.responseMessage = resWrapper.responseBody;
            } else if (resWrapper != null) {
                wrapper.resp = false;
                wrapper.responseMessage = resWrapper.responseBody;
            } else {wrapper.resp = false;wrapper.responseMessage = 'Null response from SAPBookingIntegrationHandler';
            }
            
        } catch (Exception ex) {
            // Log the exception and return a meaningful message
            wrapper.resp = false;
            wrapper.responseMessage = 'Exception during callout: ' + ex.getMessage();
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload().withComponentName('Retry SAP Sync Quick Action LWC').withException(ex).withClassName('RetrySapSyncController').withMethodName('RetryBookingCalloutToSAP').withEndpoint('callout:SAP/socreate').withDomain('SAP');
            ExceptionLogger.logException(payload);
        }
        return wrapper;
    }
    
    @AuraEnabled
    public static outputWrapper RetryAccountCalloutToSap(Id accountId){
        outputWrapper wrapper = new outputWrapper();
        wrapper.resp = false;
        wrapper.responseMessage = null;
        SapCustomerIntegrationHandler.responseWrapper resWrapper;
        
        try{
            resWrapper = SapCustomerIntegrationHandler.sendCustomerToSAP(new list<Id>{accountId});
            if (resWrapper != null && (resWrapper.statusCode == 200 || resWrapper.statusCode == 201)) {
                wrapper.resp = true;
                wrapper.responseMessage = resWrapper.responseBody;
            } else if (resWrapper != null) {
                wrapper.resp = false;
                wrapper.responseMessage = resWrapper.responseBody;
            } else {wrapper.resp = false;wrapper.responseMessage = 'Null response from SAPCustomerIntegrationHandler';
            }
        }catch(Exception ex){ wrapper.resp = false;wrapper.responseMessage = 'Exception during callout: ' + ex.getMessage();ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload().withComponentName('Retry SAP Sync Quick Action LWC').withException(ex).withClassName('RetrySapSyncController').withMethodName('RetryAccountCalloutToSap').withEndpoint('callout:SAP/customercreate').withDomain('SAP');ExceptionLogger.logException(payload);
        }
        return wrapper;
    }
    
    @AuraEnabled
    public static outputWrapper RetryChannelPartnerCalloutToSap(Id accountId) {
        outputWrapper wrapper = new outputWrapper();
        wrapper.resp = false;
        wrapper.responseMessage = null;

        // Use the new synchronous handler method
        SAPChannelPartnerIntegrationHandler.responseWrapper resWrapper;

        try {
            resWrapper = SAPChannelPartnerIntegrationHandler.sendChannelPartnerDataSync(accountId);

            // 204 (No Content) is also a valid success status for some update APIs
            if (resWrapper != null && (resWrapper.statusCode == 200 || resWrapper.statusCode == 201 || resWrapper.statusCode == 204)) {
                wrapper.resp = true;
                wrapper.responseMessage = resWrapper.responseBody;
            } else if (resWrapper != null) {
                wrapper.resp = false;
                wrapper.responseMessage = resWrapper.responseBody;
            } else {
                wrapper.resp = false;wrapper.responseMessage = 'Null response from SAPChannelPartnerIntegrationHandler';
            }
        } catch (Exception ex) {wrapper.resp = false;wrapper.responseMessage = 'Exception during callout: ' + ex.getMessage();
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('Retry SAP Sync Quick Action LWC').withException(ex).withClassName('RetrySapSyncController').withMethodName('RetryChannelPartnerCalloutToSap').withEndpoint('callout:SAP/brokercreation or /brokerupdate'); // Endpoint is dynamic.withDomain('SAP');
            ExceptionLogger.logException(payload);
        }
        return wrapper;
    }
    
    @AuraEnabled
    public static outputWrapper RetryPaymentReceiptCalloutToSap(Id receiptId){
        outputWrapper wrapper = new outputWrapper();
        wrapper.resp = false;
        wrapper.responseMessage = null;
        
        
        SAPReceiptHelper.ReceiptPayload payload;
        SAPReceiptHelper.responseWrapper resWrapper;
        
        payload = SAPReceiptHelper.buildPayload(receiptId);
        string milestoneCode = payload.milestoneCode;
        //Check Milestone Code.
        string endpoint;
        endpoint = (milestoneCode == 'Token Amount') ? 'tokenamount' : 'customerreceipt';
        
        try{
            resWrapper = SAPReceiptHelper.sendPayload(JSON.Serialize(payload), endpoint, receiptId);
            if (resWrapper != null && (resWrapper.statusCode == 200 || resWrapper.statusCode == 201)) {
                wrapper.resp = true;
                wrapper.responseMessage = resWrapper.responseBody;
            } else if (resWrapper != null) {
                wrapper.resp = false;
                wrapper.responseMessage = resWrapper.responseBody;
            } else {
                wrapper.resp = false;wrapper.responseMessage = 'Null response from SAPReceiptHelper';
            }
        }catch(Exception ex){
            wrapper.resp = false;wrapper.responseMessage = 'Exception during callout: ' + ex.getMessage();ExceptionLogger.ExceptionLogPayload log = new ExceptionLogger.ExceptionLogPayload().withComponentName('Retry SAP Sync Quick Action LWC').withException(ex).withClassName('RetrySapSyncController').withMethodName('RetryPaymentReceiptCalloutToSap').withEndpoint('callout:SAP/'+endpoint).withDomain('SAP');ExceptionLogger.logException(log);
        }
        return wrapper;
    }
}