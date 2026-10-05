public with sharing class InterestWaiverController {
    
    @AuraEnabled
    public static Id createInterestWaiverRequest(
        Id bookingPaymentScheduleId,
        Decimal waiverAmount,
        String waiverReason,
        String waiverScope
    ) {
        try {
            // Step 1: Retrieve the Booking Payment Schedule record
            Booking_Payment_Schedule__c sched = [
                SELECT Id, Booking__c 
                FROM Booking_Payment_Schedule__c
                WHERE Id = :bookingPaymentScheduleId 
                LIMIT 1
            ];

            // Step 2: Construct the Interest Waiver Request record
            Interest_Waiver_Request__c waiver = new Interest_Waiver_Request__c(
                Booking__c = sched.Booking__c,
                Booking_Payment_Schedule__c = sched.Id,
                Waiver_Amount__c = waiverAmount,
                Waiver_Reason__c = waiverReason,
                Waiver_Scope__c = waiverScope,
                Status__c = 'Draft'
            );

            // Step 3: Insert the waiver record
            insert waiver;

            // Step 4: Submit for approval
            Approval.ProcessSubmitRequest submitReq = new Approval.ProcessSubmitRequest(); 
            submitReq.setObjectId(waiver.Id); 
            Approval.ProcessResult approvalResult = Approval.process(submitReq);

            return waiver.Id;

        } catch (Exception ex) {
            // Step 5: Log the exception using centralized logger
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('Interest Waiver Request LWC')
                .withClassName('InterestWaiverController')
                .withMethodName('createInterestWaiverRequest')
                .withRequestBody('bookingPaymentScheduleId=' + String.valueOf(bookingPaymentScheduleId) +
                                 ', waiverAmount=' + String.valueOf(waiverAmount) +
                                 ', waiverReason=' + waiverReason +
                                 ', waiverScope=' + waiverScope)
                .withDomain('CRM')
                .withIntegrationType('Internal')
                .withErrorType('Unhandled Exception')
                .withException(ex)
                .withDescription('Failed to create and submit Interest_Waiver_Request__c for approval');

            //ExceptionLogger.logException(payload);
            ExceptionLogger.logExceptionAsync(JSON.serialize(payload));

//             System.enqueueJob(
//     new ExceptionLoggerQueueable(JSON.serialize(payload))
// );


            // Step 6: User-friendly error to LWC
            throw new AuraHandledException('Something went wrong while submitting the interest waiver request. Please contact support.');
        }
    }
}