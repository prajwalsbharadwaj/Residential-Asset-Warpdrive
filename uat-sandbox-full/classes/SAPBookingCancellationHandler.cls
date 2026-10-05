public with sharing class SAPBookingCancellationHandler {
    
    private static final Map<String, String> REJECTION_REASON_MAP = new Map<String, String>{
        'Unit cancellation' => 'Z1', 'Buyer to Buyer Transfer' => 'Z3', 'Unit to Unit transfer' => 'Z3',
            'General inquiry' => 'Z4', 'High Pricing' => 'Z5', 'Unsuitable Location' => 'Z6',
            'Product dislike' => 'Z7', 'Insufficient budget' => 'Z8', 'Bank Loan rejection' => 'Z9',
            'Approval delayed' => 'ZA', 'Financial crisis' => 'ZB', 'Medical reason' => 'ZC',
            'Personal reason' => 'ZD', 'Others' => 'ZE', 'Ownership Transfer Refund' => 'Z01',
            'Unit to Unit Transfer' => 'Z02', 'General Debit Note' => 'Z04', 'General Credit Note' => 'Z05',
            'Unit Change Charges' => 'Z06', 'Modification Charges' => 'Z07', 'Cancellation opted by Customer' => 'Z08',
            'Cancellation opted by Company' => 'Z09', 'Excess payment received' => 'Z10', 'Recovery of charges' => 'Z11',
            'Excessive Billing' => 'Z12', 'Short fall of TDS' => 'Z13'
            };
                
                @future(callout=true)
                public static void sendBookingCancellationAsync(Set<Id> bookingIds) {
                    if (!Test.isRunningTest()) {
                        if (!IntegrationToggle.isEnabled('Residential', 'Booking Cancellation', 'SAP')) {
                            System.debug('ENtering this bLock');
                            return;
                        }
                    }
                    // This flag from your code is to prevent recursive trigger runs
                    UtilityClass.isSAPSyncInProgress = true; 
                    
                    System.debug('--- DEBUG: Starting sendBookingCancellationAsync for ' + bookingIds.size() + ' booking(s). IDs: ' + bookingIds);
                    
                    if (bookingIds == null || bookingIds.isEmpty()) {
                        System.debug('No Booking IDs provided. Exiting.');
                        return;
                    }
                    
                    List<Booking__c> bookingsToProcess;
                    try {
                        bookingsToProcess = [
                            SELECT Id, Name, Sales_Organization__c, Distribution_Channel__c, Division__c, Rejection_Reason__c, SAP_External_Id__c,
                            (SELECT Id, Name, Installment_Number__c FROM Booking_Payment_Schedules__r)
                            FROM Booking__c
                            WHERE Id IN :bookingIds
                        ];
                        System.debug('--- DEBUG: SOQL query returned ' + bookingsToProcess.size() + ' booking record(s).');
                    } catch (Exception e) {
                        System.debug('--- DEBUG: ERROR during SOQL query: ' + e.getMessage());
                        return; 
                    }
                    
                    List<SAPBookingCancellationWrappers.BookingCancellation> requestsToSend = new List<SAPBookingCancellationWrappers.BookingCancellation>();
                    
                    for (Booking__c booking : bookingsToProcess) {
                        SAPBookingCancellationWrappers.BookingCancellation request = new SAPBookingCancellationWrappers.BookingCancellation();
                        request.salesdocument = booking.SAP_External_Id__c;
                        request.sales_org = booking.Sales_Organization__c;
                        request.distr_chan = booking.Distribution_Channel__c;
                        request.division = booking.Division__c;
                        request.BOOKING_ID = booking.Id;
                        
                        String salesforceReason = booking.Rejection_Reason__c;
                        String sapReasonCode = REJECTION_REASON_MAP.get(salesforceReason);
                        
                        if (String.isBlank(sapReasonCode)) {
                            sapReasonCode = 'ZE'; // Default to 'Others'
                        }
                        
                        List<Booking_Payment_Schedule__c> schedules = booking.Booking_Payment_Schedules__r;
                        if (schedules != null) {
                            for (Booking_Payment_Schedule__c schedule : schedules) {
                                SAPBookingCancellationWrappers.ItemWrapper newItem = new SAPBookingCancellationWrappers.ItemWrapper();
                                Decimal installmentNumber = schedule.Installment_Number__c;
                                if (installmentNumber != null) {
                                    Integer sapNumber =  installmentNumber.intValue() * 10;
                                    newItem.ITM_NUMBER = String.valueOf(sapNumber).leftPad(6, '0');
                                }
                                newItem.REASON_REJ = sapReasonCode;
                                request.item.add(newItem);
                            }
                        }
                        
                        if (!request.item.isEmpty()) {
                            requestsToSend.add(request);
                        }
                    }
                    
                    System.debug('Final request: '+ requestsToSend);
                    if (!requestsToSend.isEmpty()) {
                        // *** FIX #1: Pass the 'bookingsToProcess' list into the next method ***
                        sendCancellationToSAP(bookingsToProcess, requestsToSend);
                    } else {
                        System.debug('--- DEBUG: No eligible schedules found to send to SAP.');
                    }
                }
    
    // *** FIX #2: Update the method signature to accept the List<Booking__c> ***
    private static void sendCancellationToSAP(
        List<Booking__c> bookingsToProcess, 
        List<SAPBookingCancellationWrappers.BookingCancellation> requestsToSend
    ) {
        String endpointURL = 'callout:SAP/zunitcancel';
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        String jsonBody = JSON.serialize(requestsToSend);
        HttpResponse response = null;
        
        try {
            request.setEndpoint(endpointURL);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json;charset=UTF-8');
            request.setBody(jsonBody);
            
            System.debug('--- DEBUG: FINAL JSON PAYLOAD SENT TO SAP: ' + jsonBody);
            
            response = http.send(request);
            System.debug('--- DEBUG: SAP Response Status: ' + response.getStatusCode());
            System.debug('--- DEBUG: SAP Response Body: ' + response.getBody());
            
            if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
                System.debug('SUCCESSFUL SAP Response Body: ' + response.getBody());
                
                // *** FIX #3: Pass the correct variable 'bookingsToProcess' to the response handler ***
                SAPBookingCancellationResponseProcessor.processResponse(bookingsToProcess, response.getBody());
                
            } else {
                // Your existing error handling logic
                ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                    .withComponentName('SAPBookingCancellationHandler')
                    .withDescription('HTTP Error: ' + response.getStatus())
                    .withClassName('SAPBookingCancellationHandler')
                    .withMethodName('sendCancellationToSAP')
                    .withRequestBody(jsonBody)
                    .withResponseBody(response.getBody())
                    .withEndpoint(endpointURL)
                    .withDomain('SAP');
                ExceptionLogger.logException(payload);
            }
            
        } catch (Exception ex) {
            // Your existing exception handling logic
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('SAPBookingCancellationHandler')
                .withException(ex)
                .withClassName('SAPBookingCancellationHandler')
                .withMethodName('sendCancellationToSAP')
                .withRequestBody(jsonBody)
                .withResponseBody(response != null ? response.getBody() : '')
                .withEndpoint(endpointURL)
                .withDomain('SAP');
            ExceptionLogger.logException(payload);
        }
    }
}