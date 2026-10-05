public class PaymentReminderBatch implements Database.Batchable<SObject>, Database.Stateful {

    
    // Used to ensure task logic only runs ONCE
    Boolean taskProcessed = false;
    Id notifTypeId;

    public PaymentReminderBatch() {
        // Cache NotificationTypeId once (no SOQL in loop)
        notifTypeId = [
            SELECT Id 
            FROM CustomNotificationType
            WHERE DeveloperName = 'General_Custom_Notification'
            LIMIT 1
        ].Id;
    }

    // ------------------------ START ------------------------
    public Database.QueryLocator start(Database.BatchableContext bc) {

        Date reminderDate = Date.today().addDays(15);

        return Database.getQueryLocator([
            SELECT Id,
                   Installment_Amount__c,
                   Payment_Due_Date__c,
                   Booking__c,
                   Booking__r.OwnerId,
                   Booking__r.Owner.Email,
                   Booking__r.Owner.FirstName,
                   Booking__r.Account_Id__r.Name,
                   Booking__r.Unit_Id__r.Name
            FROM Booking_Payment_Schedule__c
            WHERE Payment_Due_Date__c = :reminderDate
        ]);
    }

    // ------------------------ EXECUTE ------------------------
    public void execute(Database.BatchableContext bc, List<Booking_Payment_Schedule__c> scope) {

        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();
        
        Set<Id> userIds = new Set<Id>();
        for (Booking_Payment_Schedule__c bps : scope) {
            userIds.add(bps.Booking__r.OwnerId);
        }
        
        Map<Id, User> users = new Map<Id, User>([SELECT Email FROM User WHERE Id IN :userIds]);

        for (Booking_Payment_Schedule__c bps : scope) {

            final String ownerEmail = users.get(bps.Booking__r.OwnerId).Email;
            
            // ---------------- EMAIL (Bulk Prepared) ----------------
            if (String.isNotBlank(ownerEmail)) {
                System.debug('Owner Email:'+ bps.Booking__r.Owner.Email);
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{ ownerEmail });

                mail.setSubject(
                    'Reminder: Payment Due in 15 Days – ' +
                    bps.Booking__r.Account_Id__r.Name
                );

                // FULL EMAIL BODY exactly like Flow
                String emailBody =
                    'Dear ' + bps.Booking__r.Owner.FirstName + ',\n\n' +
                    'This is a reminder to follow up with your assigned customer regarding an upcoming payment due in 15 days.\n\n' +
                    'Payment Details:\n' +
                    'Customer Name: ' + bps.Booking__r.Account_Id__r.Name + '\n' +
                    'Unit: ' + bps.Booking__r.Unit_Id__r.Name + '\n' +
                    'Payment Amount: ' + String.valueOf(bps.Installment_Amount__c) + '\n' +
                    'Scheduled Payment Date: ' + String.valueOf(bps.Payment_Due_Date__c) + '\n\n' +
                    'Action Required:\n' +
                    'Contact the customer to remind them about the upcoming payment.\n' +
                    'Log your follow-up actions in the system.\n' +
                    'Your timely follow-up is important to ensure smooth collections and avoid delays.\n' +
                    'Thank you for your prompt attention.\n\n' +
                    'Best regards,\n' +
                    'Phoenix Residential Notifications';

                mail.setPlainTextBody(emailBody);
                emailList.add(mail);
                System.debug('Owner Email:'+ emailList);
            }

            // ---------------- CUSTOM NOTIFICATION ----------------
            try {
                Messaging.CustomNotification notification = new Messaging.CustomNotification();
                notification.setNotificationTypeId(notifTypeId);

                notification.setTitle('Reminder: Payment Due in 15 Days');

                // EXACT FLOW NOTIFICATION BODY
                String notifBody =
                    'A payment is due in 15 days for customer ' +
                    bps.Booking__r.Account_Id__r.Name +
                    ' (' + bps.Booking__r.Unit_Id__r.Name + '). ' +
                    'Please contact the customer and log your follow-up.';

                notification.setBody(notifBody);
                notification.setTargetId(bps.Id);
                notification.setSenderId(UserInfo.getUserId());

                notification.send(new Set<String>{ bps.Booking__r.OwnerId });
                
            } catch (Exception ex) { ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload().withComponentName('PaymentReminderBatch').withClassName('PaymentReminderBatch').withMethodName('execute - Custom Notification').withRequestBody( 'BPS Id: ' + bps.Id +', OwnerId: ' + bps.Booking__r.OwnerId ).withDomain('Reminder Notification') .withErrorType('Unhandled Exception').withException(ex);ExceptionLogger.logException(payload); }
            
        }
        // ---------------- SEND ALL EMAILS TOGETHER ----------------
        if (!emailList.isEmpty()) {
            
            // Collect logs here instead of doing DML inside loops
            List<ExceptionLogger.ExceptionLogPayload> emailErrorPayloads =
                new List<ExceptionLogger.ExceptionLogPayload>();
            
            try {
                List<Messaging.SendEmailResult> results = Messaging.sendEmail(emailList);
                
                // Loop through each result
                for (Integer i = 0; i < results.size(); i++) {
                    
                    Messaging.SendEmailResult res = results[i];
                    
                    // If failure, collect log for later insertion
                    if (!res.isSuccess()) {
                        
                        Messaging.SendEmailError[] errors = res.getErrors();
                        
                        for (Messaging.SendEmailError err : errors) {
                            
                            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload().withComponentName('PaymentReminderBatch').withClassName('PaymentReminderBatch').withMethodName('execute - Email Sending').withRequestBody('Email Index: ' + i +', Status Code: ' + err.getStatusCode() +', Message: ' + err.getMessage()).withDomain('Email Notification').withErrorType('Email Send Failure');
                            
                            // Add to the list, no DML here
                            emailErrorPayloads.add(payload);
                        }
                    }
                }
            }
            catch (Exception ex) { /* Add general exception as payload*/ ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload().withComponentName('PaymentReminderBatch').withClassName('PaymentReminderBatch').withMethodName('execute - Email Sending (General)').withRequestBody('Email list size: ' + emailList.size() ).withDomain('Email Notification').withErrorType('Unhandled Exception').withException(ex); emailErrorPayloads.add(payload);
            }
            
            // BULK INSERT ALL LOGS TOGETHER (one DML only)
            if (!emailErrorPayloads.isEmpty()) {
                ExceptionLogger.logExceptions(emailErrorPayloads);
            }
        }
        
    }

    // ------------------------ FINISH ------------------------
    public void finish(Database.BatchableContext bc) {}
          
}