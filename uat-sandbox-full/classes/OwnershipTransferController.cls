public with sharing class OwnershipTransferController {
    @AuraEnabled
    public static void createOwnershipTransfer(String payload) {
        String className = 'OwnershipTransferController';
        String methodName = 'createOwnershipTransfer';

        try {
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(payload);
            Ownership_Transfer__c transfer = new Ownership_Transfer__c();

            // 1. Map Basic Fields from LWC payload
            transfer.Transfer_Reason__c = (String) data.get('transferReason');
            String transferDateStr = (String) data.get('transferDate');

            if (String.isNotBlank(transferDateStr)) {
                transfer.Transfer_Effective_Date__c = Date.valueOf(transferDateStr);
            }

            Id parentId = (Id) data.get('parentRecordId');
            String parentObjectApiName = (String) data.get('parentObjectApiName');
            Id bookingId;

            // 2. Identify the parent Booking Record (Handle both API name variations)
            if (parentId != null) {
                if (parentObjectApiName == 'Booking' || parentObjectApiName == 'Booking__c') {
                    transfer.Booking_Id__c = parentId;
                    bookingId = parentId;
                }
            }
            
            // 3. Fetch current details from the Booking
            if (bookingId != null) {
                try {
                    // Using Account_Id__c as confirmed by your latest screenshot
                    Booking__c booking = [
                        SELECT Id, Unit_Id__c, Account_Id__c FROM Booking__c WHERE Id = :bookingId LIMIT 1
                    ];
                    transfer.Unit_Id__c = booking.Unit_Id__c;
                    transfer.Current_Account_Id__c = booking.Account_Id__c;
                } catch (Exception ex) {
                    throw new AuraHandledException('Error fetching Booking data: ' + ex.getMessage());
                }
            } else {
                throw new AuraHandledException('Could not link to Booking. Invalid Parent Object: ' + parentObjectApiName);
            }

            // 4. Set New Account information
            String type = (String) data.get('transferType');
            if (type == 'Account') {
                transfer.New_Account_Id__c = (Id) data.get('newAccountId'); 
            }
            
            transfer.Status__c = 'Submitted';

            // 5. Attempt to Insert the Record
            try {
                insert transfer;
            } catch (Exception ex) {
                // This will show exactly which field or validation rule failed
                throw new AuraHandledException('Save Failed: ' + ex.getMessage());
            }

            // 6. Submit for Approval
            if (!Test.isRunningTest()) {
                try {
                    Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest(); 
                    req.setObjectId(transfer.Id); 
                    Approval.ProcessResult result = Approval.process(req);
                
                    if (!result.isSuccess()) { 
                        throw new AuraHandledException('Approval process failed to start.'); 
                    }
                } catch (Exception ex) {
                    // This often fails if there is no ACTIVE approval process for Ownership_Transfer__c
                    throw new AuraHandledException('Record created, but Approval submission failed: ' + ex.getMessage());
                }
            }

        } catch (AuraHandledException ex) {
            // Log properly and rethrow our custom messages
            logError(className, methodName, payload, ex);
            throw ex; 
        } catch (Exception ex) {
            // General system error - reveal the message for debugging
            logError(className, methodName, payload, ex);
            throw new AuraHandledException('System Error: ' + ex.getMessage());
        }
    }

    // Helper logging method (internal functionality preserved)
    private static void logError(String cls, String mthd, String req, Exception ex) {
        if(ex instanceof AuraHandledException) return; // Optional: skip logging expected errors
        ExceptionLogger.logException(
            new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('Ownership Transfer')
                .withClassName(cls)
                .withMethodName(mthd)
                .withRequestBody(req)
                .withDescription('Ownership Transfer Processing Error')
                .withDomain('Core')
                .withIntegrationType('Internal')
                .withErrorType('Exception')
                .withException(ex)
        );
    }
}