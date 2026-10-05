public class SAPUnitIntegrationHandler {
    @future(callout=true)
    public static void sendUnitStatusUpdateDataAsync(List<Id> unitIds) {
        UtilityClass.isSAPSyncInProgress = true;
        sendUnitStatusUpdateData(unitIds);
    }
    
    public class UnitStatusUpdateRequestWrapper {
        public String unitcode;
        public String mat_status;
    }
    
    public static void sendUnitStatusUpdateData(List<Id> unitIds) {
        if(!Test.isRunningTest()){
            if (!IntegrationToggle.isEnabled('Residential', 'Unit Status Update', 'SAP')) {
                return;
            }
        }
        Map<String, String> statusToCodeMap = UnitStatusHelper.getStatusToCodeMap();
        List<UnitStatusUpdateRequestWrapper> wrapperList = new List<UnitStatusUpdateRequestWrapper>();
        
        for (Unit__c unit : [SELECT Status__c, SAP_External_Id__c FROM Unit__c WHERE Id IN :unitIds]) {
            UnitStatusUpdateRequestWrapper wr = new UnitStatusUpdateRequestWrapper();
            wr.unitcode = unit.SAP_External_Id__c;
            wr.mat_status = statusToCodeMap.get(unit.Status__c);
            wrapperList.add(wr);
        }
        
        String jsonBody = JSON.serialize(wrapperList);
        
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:SAP/materialstatusupdate');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);
        
        try {
            HttpResponse res = http.send(req);
            System.debug('Response: ' + res.getBody());
            
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                System.debug(res.getBody());
            }
        } catch (Exception ex) {
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('SAPBookingIntegrationHandler')
                .withException(ex)
                .withClassName('SAPBookingIntegrationHandler')
                .withMethodName('sendBookingDataAsync')
                .withRequestBody(jsonBody)
                .withEndpoint('https://dev-cpi-phoenix-812sl0bt...')
                .withDomain('SAP');
            ExceptionLogger.logException(payload);
        }
    }
}