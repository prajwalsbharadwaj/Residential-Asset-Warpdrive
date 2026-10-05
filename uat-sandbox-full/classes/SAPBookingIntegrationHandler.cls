public without sharing class SAPBookingIntegrationHandler {
    //Booking Creation callout
    @future(callout=true)
    public static void sendBookingDataAsync(set<Id> bookingIds) {
        UtilityClass.isSAPSyncInProgress = true;
        
        sendBookingData(bookingIds);
    }
    
    public static responseWrapper sendBookingData(Set<Id> bookingIds){
        responseWrapper resWrapper = new responseWrapper();
        if(!Test.isRunningTest()){
            if (!IntegrationToggle.isEnabled('Residential', 'Create Booking', 'SAP')) {
                resWrapper.statusCode = 500;
                resWrapper.responseBody = 'Integration is disabled';
                return resWrapper;
            }
        }
        String jsonBody;
        BookingSapPayloadBuilder bookingPayloadBuilder = new BookingSapPayloadBuilder();
        list<BookingWrapper> wrapperList = new list<BookingWrapper>();
        wrapperList = bookingPayloadBuilder.prepareJSONBodyForBooking(bookingIds);
        if(!wrapperList.isEmpty()){
            jsonBody = JSON.serialize(wrapperList);
            // ADDED DEBUG POINT
            System.debug('SAP_JSON_OUTPUT_CREATE_BOOKING: ' + jsonBody);
        }
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        
        req.setEndpoint('callout:SAP/socreate');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        //req.setHeader('Accept-Language', 'en');
        req.setTimeout(20000);
        req.setBody(jsonBody);
        try {
        HttpResponse res;
        
            res = http.send(req);
            System.debug('Response: ' + res.getBody());
            resWrapper.statusCode = res.getStatusCode();
            resWrapper.responseBody = res.getBody();
            
            
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                
                //Deserializing Response in BookingResponseProcessor.BookingResponse
                list<BookingResponseProcessor.BookingResponse> responseWrapperList = new list<BookingResponseProcessor.BookingResponse>();
                responseWrapperList = (List<BookingResponseProcessor.BookingResponse>) JSON.deserialize(res.getBody(), List<BookingResponseProcessor.BookingResponse>.class);
                
                //Calling Response Class via sending payload and response as list of wrapper.
                BookingResponseProcessor.processBookingCreationResponse(wrapperList, responseWrapperList, res.getBody());
                
            } else{
                ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('SAPBookingIntegrationHandler')
                .withClassName('SAPBookingIntegrationHandler')
                .withMethodName('sendBookingDataAsync')
                .withRequestBody(jsonBody)
                .withResponseBody(res.getBody())
                .withStatusCode(JSON.serialize(res.getStatusCode()))
                .withEndpoint(req.getEndpoint())
                .withDomain('SAP');
            ExceptionLogger.logException(payload);
            }
        } catch (Exception ex) {
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('SAPBookingIntegrationHandler')
                .withException(ex)
                .withClassName('SAPBookingIntegrationHandler')
                .withMethodName('sendBookingDataAsync')
                .withRequestBody(jsonBody)
                .withEndpoint(req.getEndpoint())
                .withDomain('SAP');
            ExceptionLogger.logException(payload);
        }
        system.debug('Payload--> '+ JSON.Serialize(resWrapper));
        return resWrapper;
        
    }
    
    public class responseWrapper{
        public integer statusCode;
        public string responseBody;
    }
    
    //Booking Update callout which will trigger when booking condition record changes.
    @Future(Callout=true)
    public static void sendBookingConUpdatedData(Set<Id> bookingIds, set<Id> bookingConditionIds){
        if(!Test.isRunningTest()){
            if (!IntegrationToggle.isEnabled('Residential', 'Update Booking', 'SAP')) {
                return;
            }
        }
        string jsonBody;
        BookingSapPayloadBuilder payloadBuilder = new BookingSapPayloadBuilder();
        list<BookingUpdateWrapper> payLoadList = new list<BookingUpdateWrapper>();
        payLoadList = payloadBuilder.jsonBodyForBookingConditionUpdate(bookingIds, bookingConditionIds);
        if(!payLoadList.isEmpty()){
            jsonBody = JSON.serialize(payLoadList);
            // ADDED DEBUG POINT
            System.debug('SAP_JSON_OUTPUT_CONDITION_UPDATE: ' + jsonBody);
        }
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:SAP/zsoupdate');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);   
        try{
        Http http = new Http();
        HttpResponse res;
        res = http.send(req);
        
       
            
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                System.debug('Booking update response');
                System.debug('Response Body--> '+ res.getBody());
                
                //Deserializing Response in BookingResponseProcessor.BookingResponse
                list<BookingResponseProcessor.BookingResponse> responseWrapperList = new list<BookingResponseProcessor.BookingResponse>();
                responseWrapperList = (List<BookingResponseProcessor.BookingResponse>) JSON.deserialize(res.getBody(), List<BookingResponseProcessor.BookingResponse>.class);
                
                //Calling Response Class via sending payload and response as list of wrapper.
                BookingResponseProcessor.processBookingUpdateResponse(payLoadList, responseWrapperList, res.getBody());
            } else{
                ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('SAPBookingIntegrationHandler')
                .withClassName('SAPBookingIntegrationHandler')
                .withMethodName('sendBookingConUpdatedData')
                .withResponseBody(res.getBody())
                .withRequestBody(jsonBody)
                .withEndpoint(req.getEndpoint())
                .withStatusCode(JSON.serialize(res.getStatusCode()))
                .withDomain('SAP');
            ExceptionLogger.logException(payload);
            }
            
        }catch (Exception ex) {
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('SAPBookingIntegrationHandler')
                .withException(ex)
                .withClassName('SAPBookingIntegrationHandler')
                .withMethodName('sendBookingConUpdatedData')
                .withRequestBody(jsonBody)
                .withEndpoint(req.getEndpoint())
                .withDomain('SAP');
            ExceptionLogger.logException(payload);
        }
    }
    
    //Booking Update callout which will trigger when booking condition record changes.
    @Future(Callout=true)
    public static void sendBookingPaymentSchUpdatedData(Set<Id> bookingIds, set<Id> bookingPaymentSchIds){
        if(!Test.isRunningTest()){
            if (!IntegrationToggle.isEnabled('Residential', 'Update Booking', 'SAP')) {
                return;
            }
        }
        string jsonBody;
        BookingSapPayloadBuilder payloadBuilder = new BookingSapPayloadBuilder();
        list<BookingUpdateWrapper> payLoadList = new list<BookingUpdateWrapper>();
        payLoadList = payloadBuilder.jsonBodyForBookingPaymentScheduleUpdate(bookingIds, bookingPaymentSchIds);
        if(!payLoadList.isEmpty()){
            jsonBody = JSON.serialize(payLoadList);
            // ADDED DEBUG POINT
            System.debug('SAP_JSON_OUTPUT_STANDARD_BPS_UPDATE: ' + jsonBody);
        }
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:SAP/zsoupdate');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);   
        try{
        Http http = new Http();
        HttpResponse res;
        
        
            res = http.send(req);
            
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                
                System.debug('Booking update response');
                System.debug('Response Body--> '+res.getBody());
                //Deserializing Response in BookingResponseProcessor.BookingResponse
                list<BookingResponseProcessor.BookingResponse> responseWrapperList = new list<BookingResponseProcessor.BookingResponse>();
                responseWrapperList = (List<BookingResponseProcessor.BookingResponse>) JSON.deserialize(res.getBody(), List<BookingResponseProcessor.BookingResponse>.class);
                
                //Calling Response Class via sending payload and response as list of wrapper.
                BookingResponseProcessor.processBookingUpdateResponse(payLoadList, responseWrapperList, res.getBody());
            }else{
                ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('SAPBookingIntegrationHandler')
                .withClassName('SAPBookingIntegrationHandler')
                .withMethodName('sendBookingPaymentSchUpdatedData')
                .withRequestBody(jsonBody)
                .withResponseBody(res.getBody())
                .withEndpoint(req.getEndpoint())
                .withStatusCode(JSON.serialize(res.getStatusCode()))
                .withDomain('SAP');
            ExceptionLogger.logException(payload);
            }
            
        }catch (Exception ex) {
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('SAPBookingIntegrationHandler')
                .withException(ex)
                .withClassName('SAPBookingIntegrationHandler')
                .withMethodName('sendBookingPaymentSchUpdatedData')
                .withRequestBody(jsonBody)
                .withEndpoint(req.getEndpoint())
                .withDomain('SAP');
            ExceptionLogger.logException(payload);
        }
    }

    @Future(Callout=true)
    public static void sendBookingPaymentSchUpdatedOtherChargesData(Set<Id> bookingIds, set<Id> bookingPaymentSchIds){
        System.debug('sendBookingPaymentSchUpdatedOtherChargesData');
        if(!Test.isRunningTest()){
            if (!IntegrationToggle.isEnabled('Residential', 'Update Booking', 'SAP')) {
                return;
            }
        }
        string jsonBody;
        BookingSapPayloadBuilder payloadBuilder = new BookingSapPayloadBuilder();
        list<BookingPaySchedOtherChargesUpdateWrapper> payLoadList = new list<BookingPaySchedOtherChargesUpdateWrapper>();
        payLoadList = payloadBuilder.jsonBodyForOtherchargesBookingPaymentScheduleUpdate(bookingIds, bookingPaymentSchIds);
        if(!payLoadList.isEmpty()){
            jsonBody = JSON.serialize(payLoadList);
            // ADDED DEBUG POINT
            System.debug('SAP_JSON_OUTPUT_OTHER_CHARGES_UPDATE: ' + jsonBody);
        }
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:SAP/zsoupdate');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);   
        try{
        Http http = new Http();
        HttpResponse res;
        
        
            res = http.send(req);
            
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                
                System.debug('Booking update response');
                System.debug('Response Body--> '+res.getBody());
                //Deserializing Response in BookingResponseProcessor.BookingResponse
                list<BookingResponseProcessor.BookingResponse> responseWrapperList = new list<BookingResponseProcessor.BookingResponse>();
                responseWrapperList = (List<BookingResponseProcessor.BookingResponse>) JSON.deserialize(res.getBody(), List<BookingResponseProcessor.BookingResponse>.class);
                
                //Calling Response Class via sending payload and response as list of wrapper.
                //TODO: BookingResponseProcessor.processBookingUpdateResponse(payLoadList, responseWrapperList, res.getBody());
            }else{
                ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('SAPBookingIntegrationHandler')
                .withClassName('SAPBookingIntegrationHandler')
                .withMethodName('sendBookingPaymentSchUpdatedOtherChargesData')
                .withRequestBody(jsonBody)
                .withResponseBody(res.getBody())
                .withEndpoint(req.getEndpoint())
                .withStatusCode(JSON.serialize(res.getStatusCode()))
                .withDomain('SAP');
            ExceptionLogger.logException(payload);
            }
            
        }catch (Exception ex) {
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('SAPBookingIntegrationHandler')
                .withException(ex)
                .withClassName('SAPBookingIntegrationHandler')
                .withMethodName('sendBookingPaymentSchUpdatedOtherChargesData')
                .withRequestBody(jsonBody)
                .withEndpoint(req.getEndpoint())
                .withDomain('SAP');
            ExceptionLogger.logException(payload);
        }
    }
    
    //Booking Update callout which will trigger when Co-Applicant is changed on Booking record.
    @Future(Callout=true)
    public static void sendBookingCoApplicantUpdatedData(Set<Id> bookingIds){
        if(!Test.isRunningTest()){
            if (!IntegrationToggle.isEnabled('Residential', 'Create Booking', 'SAP')) {
                return;
            }
        }
        string jsonBody;
        BookingSapPayloadBuilder payloadBuilder = new BookingSapPayloadBuilder();
        list<BookingUpdateWrapper> payLoadList = new list<BookingUpdateWrapper>();
        payLoadList = payloadBuilder.jsonBodyForCoApplicantUpdate(bookingIds);
        if(!payLoadList.isEmpty()){
            jsonBody = JSON.serialize(payLoadList);
            // ADDED DEBUG POINT
            System.debug('SAP_JSON_OUTPUT_CO_APPLICANT_UPDATE: ' + jsonBody);
        }
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:SAP/zsoupdate');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);   
        try{
        Http http = new Http();
        HttpResponse res;
        
        
            res = http.send(req);
            
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                
                System.debug('Booking update response');
                System.debug('Response Body--> '+res.getBody());
                //Deserializing Response in BookingResponseProcessor.BookingResponse
                list<BookingResponseProcessor.BookingResponse> responseWrapperList = new list<BookingResponseProcessor.BookingResponse>();
                responseWrapperList = (List<BookingResponseProcessor.BookingResponse>) JSON.deserialize(res.getBody(), List<BookingResponseProcessor.BookingResponse>.class);
                
                //Calling Response Class via sending payload and response as list of wrapper.
                BookingResponseProcessor.processBookingUpdateResponse(payLoadList, responseWrapperList, res.getBody());
            } else{
                ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('SAPBookingIntegrationHandler')
                .withClassName('SAPBookingIntegrationHandler')
                .withMethodName('sendBookingCoApplicantUpdatedData')
                .withRequestBody(jsonBody)
                .withResponseBody(res.getBody())
                .withEndpoint(req.getEndpoint())
                .withStatusCode(JSON.serialize(res.getStatusCode()))
                .withDomain('SAP');
            ExceptionLogger.logException(payload);
            }
            
        }catch (Exception ex) {
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('SAPBookingIntegrationHandler')
                .withException(ex)
                .withClassName('SAPBookingIntegrationHandler')
                .withMethodName('sendBookingCoApplicantUpdatedData')
                .withRequestBody(jsonBody)
                .withEndpoint(req.getEndpoint())
                .withDomain('SAP');
            ExceptionLogger.logException(payload);
        }
    }
    
}