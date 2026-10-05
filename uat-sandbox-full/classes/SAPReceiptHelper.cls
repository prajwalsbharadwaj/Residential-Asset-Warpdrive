public without sharing class SAPReceiptHelper {
    
    // ---------------------------
    // Request payload wrapper //
    // ---------------------------
    public class ReceiptPayload {
         public transient string milestoneCode = '';
         public  Documentheader DOCUMENTHEADER;
         public List<KunnrItem> KUNNR;
         public List<DmbtrItem> DMBTR;


   }

    public class Documentheader {
        public String BUKRS ='';
        public String BLDAT ='';
        public String BUDAT ='';
        public Integer GJAHR =0;
        public String BLART ='';
        public String BKTXT ='';
        public String PRCTR ='';
        public String ZUONR ='';
        public String XBLNR ='';
        public String HKONT ='';
        public String HBKID ='';
        public String HKTID ='';
        public String TXT50 ='';
        public String MWSKZ ='';
        public Decimal CGST=0;
        public Decimal SGST=0;
        public String XREF1 ='';
        public String XREF2 ='';
        public String XREF3 ='';
    }
    public class KunnrItem {
        public String ITEM_1 ='';
        public String KUNNR_1 ='';
        public String PRCTR_1 ='';
    }

    public class DmbtrItem {
        public String ITEM_1 ='';
        public Decimal DMBTR_1=0;
    }


    
    // request payload wrapper for receipt cancellation/bounced.
    public class ReceiptCancellationPayload {
        public String TXT50;
        public String STGRD;
        public String BUKRS;
        public Integer GJHAR;
        public String BLART;
        public String BLDAT;
        public String BUDAT;
    }
    
    
    // ---------------------------
    // Response wrapper (typed)
    // JSON sample (array root):
    // [{"type":"S","srno":"","belnr":"1900000063","gjahr":1000,"bukrs":"2025","msg":"..."}]
    // ---------------------------
    public class SapResponseItem {
        public String  type;
        public String  srno;
        public String  belnr;
        public String gjahr;
        public String  bukrs;
        public String  msg;
    }
    //Response Wrapper for LWC :- Retry Sap Sync Quick Action.
    public class responseWrapper{
        public integer statusCode;
        public string responseBody;
    }
    
    public static final String CUSTOMER_PAYMENT_DOC_TYPE_CODE;
    public static final String CUSTOMER_PAYMENT_REVERSAL_DOC_TYPE_CODE;
    public static final String CURRENT_PERIOD;
    public static final String CLOSED_PERIOD;
    static {
        List<External_Code_Dictionary__mdt> docTypeRecords = [
            SELECT Code__c, Display_Label__c
            FROM External_Code_Dictionary__mdt 
            WHERE Domain__c IN ('Document Type', 'Receipt Reversal') AND Display_Label__c IN ('Customer Payment', 'Customer Payment Reversal', 'Current Period', 'Closed Period')
        ];
        
        
        for(External_Code_Dictionary__mdt mdt : docTypeRecords){
            switch on mdt.Display_Label__c {
                when 'Customer Payment' {
                    CUSTOMER_PAYMENT_DOC_TYPE_CODE = mdt.Code__c;
                }
                when 'Customer Payment Reversal'{
                    CUSTOMER_PAYMENT_REVERSAL_DOC_TYPE_CODE = mdt.Code__c;
                }
                when 'Current Period'{
                    CURRENT_PERIOD = mdt.Code__c;
                }
                when 'Closed Period'{
                    CLOSED_PERIOD = mdt.Code__c;
                }
            }
        }
    }
    
    public static ReceiptPayload buildPayload(Id receiptId) {

    Payment_Receipt__c receipt = [
        SELECT
            ChequeNumber__c,
            Amount_Paid__c,
            Date_Of_Payment__c,
            Mode_Of_Payment__c,
            Demand__r.SAP_External_Id__c,
            Booking_Payment_Schedule__r.Milestone_Code__c,
            Booking_Payment_Schedule__r.Payment_Schedule_Id__r.Milestone_Code__c,
            Booking_Payment_Schedule__r.Booking__r.SAP_External_Id__c, 
            Booking_Payment_Schedule__r.Booking__r.Project__r.SAP_External_Id__c,
            Booking_Payment_Schedule__r.Booking__r.Unit_Id__r.Tower__r.SAP_External_Id__c,
            Booking_Payment_Schedule__r.Booking__r.Unit_Id__r.Tower__r.Name,
            Booking_Payment_Schedule__r.Booking__r.Token_Amount__c,
            Booking_Payment_Schedule__r.Booking__r.Account_Id__r.SAP_External_Id__c, 
            Booking_Payment_Schedule__r.Booking__r.Account_Id__r.Company_Code__c,
            Company_Bank_Account__r.House_Bank_Id__c,
            SAP_External_Id__c
        FROM Payment_Receipt__c
        WHERE Id = :receiptId
        LIMIT 1
    ];

    ReceiptPayload payload = new ReceiptPayload();
     payload.KUNNR = new List<KunnrItem>();
     payload.DMBTR = new List<DmbtrItem>();

    // =====================================================
    // INTERNAL / LEGACY FIELDS (KEEP AS REQUESTED)
    // =====================================================
    //payload.BLART = CUSTOMER_PAYMENT_DOC_TYPE_CODE;

    Booking_Payment_Schedule__c bookingPaymentSch = receipt.Booking_Payment_Schedule__r;
    Payment_Schedule__c bps = bookingPaymentSch.Payment_Schedule_Id__r;
    Booking__c booking = bookingPaymentSch.Booking__r;
    Tower__c tower = booking.Unit_Id__r.Tower__r;

// SAFE MILESTONE DETECTION: Formulas are often null in Tests. We check the parent lookup as fallback.
        String safeMilestone = (bookingPaymentSch.Milestone_Code__c != null) ? 
                                bookingPaymentSch.Milestone_Code__c : 
                                bookingPaymentSch.Payment_Schedule_Id__r.Milestone_Code__c;
        
        payload.milestoneCode = safeMilestone; // internal only

    // FORMAT DATE (YYYYMMDD)

    Date d = receipt.Date_Of_Payment__c;
    String formattedDate =
        d.year() +
        String.valueOf(d.month()).leftPad(2, '0') +
        String.valueOf(d.day()).leftPad(2, '0');

    // DOCUMENT HEADER (SAP PAYLOAD)
  
    payload.DOCUMENTHEADER = new Documentheader();
    Documentheader hdr = payload.DOCUMENTHEADER;


    hdr.BUKRS = booking.Account_Id__r?.Company_Code__c;
    hdr.BLDAT = formattedDate;
    hdr.BUDAT = formattedDate;
    //hdr.GJAHR = UtilityClass.CURRENT_FISCAL_YEAR;
    hdr.GJAHR = Integer.valueOf(Label.SAP_FISCAL_YEAR);// Add by AP
    hdr.BLART = CUSTOMER_PAYMENT_DOC_TYPE_CODE;
    hdr.BKTXT = booking.SAP_External_Id__c;
    hdr.ZUONR = receipt.ChequeNumber__c +'';
    hdr.XBLNR = receipt.SAP_External_Id__c;
    //hdr.TXT50 = bookingPaymentSch?.Milestone_Code__c;
    hdr.TXT50 = safeMilestone;
    hdr.XREF1 = SAPCodeTranslationUtil.getMilestoneCodeMap()
                    .get(safeMilestone);
    hdr.XREF2 = safeMilestone;
    hdr.XREF3 = receipt.Demand__r.SAP_External_Id__c;

    //   SCENARIO HANDLING (TDS vs NON-TDS)

    KunnrItem customerLine = new KunnrItem();
    Boolean isTDS = receipt.Mode_Of_Payment__c == 'TDS';
    
    Decimal amount = receipt.Amount_Paid__c.setScale(2);

    if (isTDS) {
        hdr.HKONT = '';
        hdr.HBKID = '';
        hdr.HKTID = '';
        hdr.MWSKZ = '';

        // KUNNR ITEMS        
        customerLine.ITEM_1  = '0000000001';
        customerLine.KUNNR_1 = booking.Account_Id__r.SAP_External_Id__c;
        customerLine.PRCTR_1 = SAPCodeTranslationUtil.getTowerExternalId(tower.SAP_External_Id__c);
        payload.KUNNR.add(customerLine);

        KunnrItem companyLine = new KunnrItem();
        companyLine.ITEM_1  = '0000000002';
        companyLine.KUNNR_1 = Label.Sub_GL_Code;
        companyLine.PRCTR_1 = SAPCodeTranslationUtil.getTowerExternalId(tower.SAP_External_Id__c);
        payload.KUNNR.add(companyLine);

        // DMBTR ITEMS (DECIMAL SAFE)


        DmbtrItem debit = new DmbtrItem();
        debit.ITEM_1  = '0000000001';
        debit.DMBTR_1 = -amount;
        payload.DMBTR.add(debit);

        DmbtrItem credit = new DmbtrItem();
        credit.ITEM_1  = '0000000002';
        credit.DMBTR_1 = amount;
        payload.DMBTR.add(credit);


    } else {
        hdr.PRCTR = SAPCodeTranslationUtil.getTowerExternalId(tower.SAP_External_Id__c);
        hdr.HBKID = receipt.Company_Bank_Account__r.House_Bank_Id__c;
        hdr.HKTID = receipt.Company_Bank_Account__r.House_Bank_Id__c;
        hdr.HKONT = Label.PaymentReceipt_HKONT_ID;
        hdr.MWSKZ = 'OA';

        // KUNNR ITEMS       
        customerLine.ITEM_1  = '';//customer debit
        customerLine.KUNNR_1 ='';//customer code
        customerLine.PRCTR_1 = '';//profit center
        payload.KUNNR.add(customerLine);

        KunnrItem companyLine = new KunnrItem();
        companyLine.ITEM_1  = '0000000002';//company tds account customer// company credit
        companyLine.KUNNR_1 = booking.Account_Id__r.SAP_External_Id__c;
        companyLine.PRCTR_1 = '';//profit center
        payload.KUNNR.add(companyLine);


        // DMBTR ITEMS (DECIMAL SAFE)

        
        DmbtrItem debit = new DmbtrItem();
        debit.ITEM_1  = '0000000001';
        debit.DMBTR_1 = amount;
        payload.DMBTR.add(debit);

        DmbtrItem credit = new DmbtrItem();
        credit.ITEM_1  = '0000000002';
        credit.DMBTR_1 = -amount;
        payload.DMBTR.add(credit);
    }

    // // DMBTR ITEMS (DECIMAL SAFE)

    // Decimal amount = receipt.Amount_Paid__c.setScale(2);

    // DmbtrItem debit = new DmbtrItem();
    // debit.ITEM_1  = '0000000001';
    // debit.DMBTR_1 = -amount;
    // payload.DMBTR.add(debit);

    // DmbtrItem credit = new DmbtrItem();
    // credit.ITEM_1  = '0000000002';
    // credit.DMBTR_1 = amount;
    // payload.DMBTR.add(credit);

    System.debug('Final SAP Payload => ' + JSON.serialize(payload));
    return payload;
}

    /**
* Sends the payload and handles the response with a typed wrapper.
*/  
    public static responseWrapper sendPayload(string payload, String receiptEndpoint, Id receiptId) {
        ResponseWrapper resWrapper = new ResponseWrapper();
        if (!Test.isRunningTest()) {
            if (!IntegrationToggle.isEnabled('Residential', 'Create Payment Receipt', 'SAP')) {
                System.debug('SAPReceiptHelper.sendPayload: Integration toggle OFF. Skipping callout.');
                resWrapper.statusCode = 500;
                resWrapper.responseBody = 'Integration is disabled';
                return resWrapper;
            }
        }
        
        System.debug('SAPReceiptHelper.sendPayload: START. Endpoint=' + receiptEndpoint + ', ReceiptId=' + receiptId);
        System.debug('SAPReceiptHelper.sendPayload: Request body=' + payload);
        
        Integer statusCode;
        String responseBody;
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:SAP/' + receiptEndpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json;charset=UTF-8');
        req.setBody(payload);
        System.debug('playload is:'+ payload);
        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            statusCode   = res.getStatusCode();
            responseBody = res.getBody();
            
            System.debug('SAPReceiptHelper.sendPayload: HTTP Status=' + statusCode);
            System.debug('SAPReceiptHelper.sendPayload: Raw Response=' + responseBody);
            resWrapper.statusCode = statusCode;
            resWrapper.responseBody = responseBody;
        } catch (Exception ex) {
            System.debug('SAPReceiptHelper.sendPayload: Exception during callout: ' + ex.getMessage());
            upsertReceiptSyncFields(receiptId, null, 'Error', ex.getMessage(), null);
            ExceptionLogger.ExceptionLogPayload exceptionPayload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('SAPReceipt Callout')
                .withException(ex)
                .withClassName('SAPReceiptHelper')
                .withMethodName('sendPayload')
                .withRequestBody(JSON.Serialize(payload))
                .withEndpoint(req.getEndpoint())
                .withDomain('SAP')
                .withRelatedRecordId(receiptId);
            ExceptionLogger.logException(exceptionPayload);
            resWrapper.statusCode = 500;
            resWrapper.responseBody = 'Unhandled Error Occured with Error : '+ex.getMessage();
            return resWrapper;
        }
        
        handleReceiptResponseTyped(receiptId, statusCode, payload, responseBody, req.getEndpoint());
        return resWrapper;
    }
    
    @Future(callout = true)
    public static void createCustomerReceipt(Id receiptId){
        ReceiptPayload payload;
        try{
            System.debug('SAPReceiptHelper.createCustomerReceipt: START for receiptId=' + receiptId);
            
            payload = buildPayload(receiptId);
            
            System.debug('payload: ' + payload);
            //String ms = receipt.Booking_Payment_Schedule__r.Payment_Schedule_Id__r.Milestone_Code__c;
            string ms = payload.milestoneCode;
            system.debug('Milestone Code in Payload: '+ ms);
            if (ms == 'Initial Token Advance'){
                sendPayload(JSON.Serialize(payload), 'tokenamount', receiptId);
            } else {
                System.debug('SAPReceiptHelper.createCustomerReceipt: Milestone=' + ms + ', endpoint=customerreceipt');
                sendPayload(JSON.Serialize(payload), 'customerreceipt', receiptId);
            }
            
            System.debug('SAPReceiptHelper.createCustomerReceipt: END for receiptId=' + receiptId);
        } catch(Exception ex){
            ExceptionLogger.ExceptionLogPayload exceptionPayload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('SAPReceipt Callout')
                .withException(ex)
                .withClassName('SAPReceiptHelper')
                .withMethodName('createCustomerReceipt')
                .withRequestBody(JSON.Serialize(payload))
                .withDomain('SAP')
                .withRelatedRecordId(receiptId);
            ExceptionLogger.logException(exceptionPayload);
        }
        
    }
    
    /**
* Typed response handling using the SapResponseItem wrapper.
*/
    private static void handleReceiptResponseTyped(Id receiptId, Integer statusCode, String requestBody, String responseBody, String endpoint) {
        System.debug('SAPReceiptHelper.handleReceiptResponseTyped: START. Status=' + statusCode + ', Body=' + responseBody);
        
        String syncStatus  = 'Error';
        String syncMessage = null;
        String belnr       = null;
        String typeVal     = null;
        
        try {
            if (statusCode != null && statusCode >= 200 && statusCode < 300 && String.isNotBlank(responseBody)) {
                // Deserialize directly into a typed list of wrappers
                List<SapResponseItem> items = (List<SapResponseItem>) JSON.deserialize(responseBody, List<SapResponseItem>.class);
                System.debug('SAPReceiptHelper.handleReceiptResponseTyped: Parsed items size=' + (items == null ? 0 : items.size()));
                
                if (items != null && !items.isEmpty()) {
                    SapResponseItem first = items[0];
                    typeVal     = first != null ? first.type : null;
                    belnr       = first != null ? first.belnr : null;
                    syncMessage = first != null ? first.msg   : null;
                    
                    System.debug('SAPReceiptHelper.handleReceiptResponseTyped: First item = ' + JSON.serialize(first));
                    
                    if ('S'.equalsIgnoreCase(typeVal) && String.isNotBlank(belnr)) {
                        System.debug('SAPReceiptHelper.handleReceiptResponseTyped: Receipt Document Created.');
                        syncStatus = 'Success';
                    } else {
                        System.debug('SAPReceiptHelper.handleReceiptResponseTyped: Receipt Document NOT created (non-success type or missing belnr).');
                        if (String.isBlank(syncMessage)) {
                            syncMessage = 'SAP responded without success or missing belnr.';
                        }
                    }
                } else {
                    syncMessage = 'Empty SAP response array.';
                    System.debug('SAPReceiptHelper.handleReceiptResponseTyped: ' + syncMessage);
                }
            } else {
                syncMessage = 'HTTP ' + statusCode + ' received from SAP.';
                System.debug('SAPReceiptHelper.handleReceiptResponseTyped: ' + syncMessage);
                ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                    .withComponentName('SAPReceipt Callout Response')
                    .withClassName('SAPReceiptHelper')
                    .withMethodName('handleReceiptResponseTyped')
                    .withResponseBody(responseBody)
                    .withRequestBody(requestBody)
                    .withStatusCode(string.valueOf(statusCode))
                    .withEndpoint(endpoint)
                    .withDomain('SAP')
                    .withRelatedRecordId(receiptId);
                ExceptionLogger.logException(payload);
            }
        } catch (Exception parseEx) {
            System.debug('SAPReceiptHelper.handleReceiptResponseTyped: Exception while parsing: ' + parseEx.getMessage());
            syncMessage = (syncMessage == null) ? parseEx.getMessage() : syncMessage;
        }
        
        if(syncStatus == 'Error'){
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('SAPReceipt Callout Response')
                .withClassName('SAPReceiptHelper')
                .withMethodName('handleReceiptResponseTyped')
                .withResponseBody(responseBody)
                .withRequestBody(requestBody)
                .withStatusCode(string.valueOf(statusCode))
                .withEndpoint(endpoint)
                .withDomain('SAP')
                .withRelatedRecordId(receiptId);
            ExceptionLogger.logException(payload);
        }
        
        try {
            upsertReceiptSyncFields(receiptId, belnr, syncStatus, syncMessage, typeVal);
        } catch (DmlException dmlEx) {
            
            System.debug('DML Update failed in Parent: ' + dmlEx.getMessage());
        }
        System.debug('SAPReceiptHelper.handleReceiptResponseTyped: END.');
    }
    
    private static void upsertReceiptSyncFields(
        Id receiptId,
        String belnr,
        String syncStatus,
        String syncMessage,
        String typeVal
    ) {
        System.debug('SAPReceiptHelper.upsertReceiptSyncFields: START for receiptId=' + receiptId
                     + ', belnr=' + belnr + ', status=' + syncStatus + ', type=' + typeVal + ', msg=' + syncMessage);
        
        Payment_Receipt__c pr = new Payment_Receipt__c(Id = receiptId);
        if ('Success'.equalsIgnoreCase(syncStatus) && String.isNotBlank(belnr)) {
            System.debug('SAPReceiptHelper.upsertReceiptSyncFields: Receipt Document Created');
            pr.SAP_External_Id__c = belnr; // store belnr as-is
            pr.SAP_Sync_Status__c = 'Success';
        } else {
            System.debug('SAPReceiptHelper.upsertReceiptSyncFields: Receipt Document did NOT get created');
            pr.SAP_Sync_Status__c = 'Error';
        }
        
        if (String.isNotBlank(syncMessage)) {
            pr.SAPSyncMessage__c  = syncMessage.length() > 255 ? syncMessage.substring(0, 255) : syncMessage;
        }
        
    //     try {
    //     update pr;
    // } catch (DmlException e) {
    //     System.debug('Update restricted by validation rule: ' + e.getMessage());
    // }
          update pr;  
    }
    
    private static String toStr(Object o) { return (o == null) ? null : String.valueOf(o); }
    
    
    public static ReceiptCancellationPayload buildCancellationPayload(Payment_Receipt__c receipt){
        System.debug('SAPReceiptHelper.buildCancellationPayload: START for receipt Id=' + receipt.Id);
        
        ReceiptCancellationPayload payload = new ReceiptCancellationPayload();
        
        Date currentDate = receipt.Date_Of_Payment__c;
        String formattedDate = currentDate.year() +
            String.valueOf(currentDate.month()).leftPad(2, '0') +
            String.valueOf(currentDate.day()).leftPad(2, '0');
        Integer fiscalYear = currentDate.year();
        
        payload.TXT50 = receipt.SAP_External_Id__c;
        payload.STGRD = CURRENT_PERIOD; //Closed Period Or Current Period.
        payload.BUKRS = receipt.Account__r?.Company_Code__c;
        payload.GJHAR = fiscalYear;
        payload.BLART = CUSTOMER_PAYMENT_REVERSAL_DOC_TYPE_CODE; // Reversal Document Type 
        payload.BLDAT = formattedDate;
        payload.BUDAT = formattedDate;
        
        System.debug('SAPReceiptHelper.buildCancellationPayload: Built payload=' + JSON.serialize(payload));
        return payload;
    }
    
    @Future(Callout = true)
    public static void cancelReceipt(Id receiptId){
        Payment_Receipt__c receipt = [
            SELECT 
            ChequeNumber__c,
            Amount_Paid__c ,
            Date_Of_Payment__c,
            Demand__r.SAP_External_Id__c,
            Booking_Payment_Schedule__r.Payment_Schedule_Id__r.Milestone_Code__c,
            Booking_Payment_Schedule__r.Booking__r.SAP_External_Id__c, 
            Booking_Payment_Schedule__r.Booking__r.Project__r.SAP_External_Id__c,
            Booking_Payment_Schedule__r.Booking__r.Unit_Id__r.Tower__r.SAP_External_Id__c,
            Booking_Payment_Schedule__r.Booking__r.Token_Amount__c,
            Booking_Payment_Schedule__r.Booking__r.Account_Id__r.SAP_External_Id__c, 
            Booking_Payment_Schedule__r.Booking__r.Account_Id__r.Company_Code__c,
            Company_Bank_Account__c,
            Company_Bank_Account__r.House_Bank_Id__c,
            Account__r.Company_Code__c, SAP_External_Id__c
            FROM Payment_Receipt__c 
            WHERE Id = :receiptId
            LIMIT 1
        ];
        
        ReceiptCancellationPayload payload = buildCancellationPayload(receipt);
        sendPayload(JSON.Serialize(payload), 'brokerinvoicereversal', receipt.Id);
        
        System.debug('SAPReceiptHelper.receiptCancellation: END for receiptId=' + receiptId);
    }
}