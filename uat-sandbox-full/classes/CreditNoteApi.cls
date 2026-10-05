@RestResource(urlMapping='/sap/v1/credit-note/*')
global without sharing class CreditNoteApi {

    public class CreditNotePayload {
        public String creditNoteNumber;   // VBELN
        public String demandNumber;       // VBELN (if ref)
        public String bookingNumber;      // VBELN (if ref)
        public String customerReference;  // BSTKN
        public Decimal orderQty;          // KWMENG
        public Decimal invoiceValue;      // NETWR_FR
        public Decimal taxValue;          // MWSBP
        public String unitCode;
    }

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        List<Map<String, Object>> responses = new List<Map<String, Object>>();

        try {
            String body = req.requestBody.toString();
            System.debug('Body: ' + body);
            List<CreditNotePayload> inputList = (List<CreditNotePayload>) JSON.deserialize(body, List<CreditNotePayload>.class);

            Set<String> demandIds = new Set<String>();
            Set<String> bookingIds = new Set<String>();
            Set<String> accountRefs = new Set<String>();
            Set<String> unitRefs = new Set<String>();
            

            for (CreditNotePayload p : inputList) {
                if (!String.isBlank(p.demandNumber)) demandIds.add(p.demandNumber);
                if (!String.isBlank(p.bookingNumber)) bookingIds.add(p.bookingNumber);
                if (!String.isBlank(p.customerReference)) accountRefs.add(p.customerReference);
                if (!String.isBlank(p.unitCode)) unitRefs.add(p.unitCode);
            }

            Map<String, Id> demandMap = new Map<String, Id>();
            for (Demand__c d : [SELECT Id, SAP_External_Id__c FROM Demand__c WHERE SAP_External_Id__c IN :demandIds]) {
                demandMap.put(d.SAP_External_Id__c, d.Id);
            }

            Map<String, Id> bookingMap = new Map<String, Id>();
            for (Booking__c b : [SELECT Id, SAP_External_Id__c FROM Booking__c WHERE SAP_External_Id__c IN :bookingIds]) {
                bookingMap.put(b.SAP_External_Id__c, b.Id);
            }

            Map<String, Id> accountMap = new Map<String, Id>();
            for (Account a : [SELECT Id, SAP_External_Id__c FROM Account WHERE SAP_External_Id__c IN :accountRefs]) {
                accountMap.put(a.SAP_External_Id__c, a.Id);
            }


            Map<String, Id> unitMap = new Map<String, Id>();
            for (Unit__c u : [SELECT Id, SAP_External_Id__c FROM Unit__c WHERE SAP_External_Id__c IN :unitRefs]) {
                unitMap.put(u.SAP_External_Id__c, u.Id);
            }

            List<Credit_Note__c> notesToInsert = new List<Credit_Note__c>();
            Map<Integer, String> indexToKey = new Map<Integer, String>();

            for (Integer i = 0; i < inputList.size(); i++) {
                CreditNotePayload p = inputList[i];
                Map<String, Object> resMap = new Map<String, Object>{ 'externalId' => p.creditNoteNumber };

                List<String> validationErrors = new List<String>();
                if (String.isBlank(p.creditNoteNumber)) {
                    validationErrors.add('Missing required field: creditNoteNumber');
                }
                if (String.isBlank(p.customerReference)) {
                    validationErrors.add('Missing required field: customerReference');
                } else if (!accountMap.containsKey(p.customerReference)) {
                    validationErrors.add('Customer with reference ' + p.customerReference + ' not found');
                }


                if (String.isBlank(p.unitCode)) {
                    validationErrors.add('Missing required field: UnitId '+ p.unitCode);
                } else if (!unitMap.containsKey(p.unitCode)) {
                    validationErrors.add('UnitCode with reference ' + p.unitCode + ' not found');
                }



                if (p.orderQty == null) {
                    validationErrors.add('Missing required field: orderQty');
                }
                if (p.invoiceValue == null) {
                    validationErrors.add('Missing required field: invoiceValue');
                }

                if (!validationErrors.isEmpty()) {
                    resMap.put('status', 'Failure');
                    resMap.put('message', String.join(validationErrors, '; '));
                    responses.add(resMap);
                    
                    ExceptionLogger.addException(new ExceptionLogger.ExceptionLogPayload()
                        .withComponentName('CreditNoteApi')
                        .withDescription('Error in creating credit note')
                        .withClassName('CreditNoteApi')
                        .withMethodName('doPost')
                        .withRequestBody(body) // Log the raw request body
                        .withResponseBody(String.join(validationErrors, '; ')) // Log any response generated so far
                        .withEndpoint(req.requestURI) // Log the API endpoint hit
                        .withDomain('SAP Inbound')); // Specify the integration domain
                    continue;
                }

                List<Credit_Note__c> existing = [SELECT Id FROM Credit_Note__c WHERE SAP_External_Id__c = :p.creditNoteNumber LIMIT 1];
                if (!existing.isEmpty()) {
                    resMap.put('status', 'Failure');
                    resMap.put('message', 'Credit Note already exists');
                    responses.add(resMap);
                    continue;
                }

                Credit_Note__c cn = new Credit_Note__c();
                cn.SAP_External_Id__c = p.creditNoteNumber;
                if (p.demandNumber != null) cn.Demand__c = demandMap.get(p.demandNumber);
                if (p.bookingNumber != null) cn.Booking_Id__c  = bookingMap.get(p.bookingNumber);
                cn.Account__c = accountMap.get(p.customerReference);
                cn.Order_Quantity__c = p.orderQty;
                cn.Invoice_Value__c = p.invoiceValue;
                cn.Tax_Value__c = p.taxValue;
                cn.Unit__c = unitMap.get(p.unitCode);

                notesToInsert.add(cn);
                indexToKey.put(notesToInsert.size() - 1, p.creditNoteNumber);
            }

            if (!notesToInsert.isEmpty()) {
                Database.SaveResult[] results = Database.insert(notesToInsert, false);
                for (Integer i = 0; i < results.size(); i++) {
                    String key = indexToKey.get(i);
                    Map<String, Object> resMap = new Map<String, Object>();
                    resMap.put('externalId', key);
                    if (results[i].isSuccess()) {
                        resMap.put('status', 'Success');
                        resMap.put('creditNoteId', results[i].getId());
                        resMap.put('message', 'New credit note created successfully');
                    } else {
                        resMap.put('status', 'Failure');
                        resMap.put('message', results[i].getErrors()[0].getMessage());
                    }
                    responses.add(resMap);
                }
            }

            res.addHeader('Content-Type', 'application/json');
            res.responseBody = Blob.valueOf(JSON.serialize(responses));
            res.statusCode = 200;

        } catch (Exception ex) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new List<Map<String, Object>>{
                new Map<String, Object>{
                    'status' => 'Failure',
                    'message' => 'Unhandled exception: ' + ex.getMessage()
                }
            }));
        } finally{
            ExceptionLogger.insertLogsIfAny();
        }
    }
}