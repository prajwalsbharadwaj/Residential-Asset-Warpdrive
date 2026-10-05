public class Flow_SendSingleEmailAndNotification {

    public class Request {
        @InvocableVariable(label='Recipient Email') public String recipientEmail;
        @InvocableVariable(label='Email Subject') public String emailSubject;
        @InvocableVariable(label='Email Body') public String emailBody;
        @InvocableVariable(label='Notification Recipient ID') public Id recipientId;
        @InvocableVariable(label='Notification Title') public String notificationTitle;
        @InvocableVariable(label='Notification Body') public String notificationBody;
        @InvocableVariable(label='Custom Notification Type ID') public Id notificationTypeId;
        @InvocableVariable(label='Target Record ID') public Id targetRecordId;
    }

    @InvocableMethod(label='Send Single Email and Notification')
    public static void send(List<Request> requests) {
        final String COMPONENT = 'Flow_SendSingleEmailAndNotification';
        final String CLASS_NAME = 'Flow_SendSingleEmailAndNotification';
        final String METHOD_NAME = 'send';

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Request req : requests) {
            String requestJson = JSON.serialize(req);

            // Send Email
            if (String.isNotBlank(req.recipientEmail)) {
                try {
                    // Test hook: simulate email creation failure
                    if (Test.isRunningTest() && 'FORCE_EMAIL_CREATION_ERROR'.equals(req.emailSubject)) {
                        throw new EmailException('Simulated email creation failure');
                    }
                    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                    email.setToAddresses(new List<String>{ req.recipientEmail });
                    email.setSubject(req.emailSubject);
                    email.setHtmlBody(req.emailBody);
                    emails.add(email);
                } catch (Exception ex) {
                    ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                        .withComponentName(COMPONENT)
                        .withClassName(CLASS_NAME)
                        .withMethodName(METHOD_NAME)
                        .withRequestBody(requestJson)
                        .withDomain('Core')
                        .withIntegrationType('Internal')
                        .withErrorType('Unhandled Exception')
                        .withException(ex);
                    ExceptionLogger.logException(payload);
                }
            }

            // Send Custom Notification
            if (req.recipientId != null && req.notificationTypeId != null && req.targetRecordId != null) {
                try {
                    // Test hook: simulate notification send failure
                    if (Test.isRunningTest() && 'FORCE_NOTIFICATION_ERROR'.equals(req.notificationTitle)) {
                        throw new CustomNotificationException('Simulated notification failure');
                    }
                    Messaging.CustomNotification notification = new Messaging.CustomNotification();
                    notification.setNotificationTypeId(req.notificationTypeId);
                    notification.setTitle(req.notificationTitle);
                    notification.setBody(req.notificationBody);
                    notification.setTargetId(req.targetRecordId);
                    Set<String> recipientIds = new Set<String>{ String.valueOf(req.recipientId) };
                    notification.send(recipientIds);
                } catch (Exception ex) {
                    ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                        .withComponentName(COMPONENT)
                        .withClassName(CLASS_NAME)
                        .withMethodName(METHOD_NAME)
                        .withRequestBody(requestJson)
                        .withDomain('Core')
                        .withIntegrationType('Internal')
                        .withErrorType('Unhandled Exception')
                        .withException(ex);
                    ExceptionLogger.logException(payload);
                }
            }
        }

        // Send all accumulated emails
        if (!emails.isEmpty()) {
            try {
                // Test hook: simulate final sendEmail failure
                if (Test.isRunningTest() && emails.size() > 0 &&
                    emails.get(0).getSubject() == 'FORCE_FINAL_EMAIL_ERROR') {
                    throw new EmailException('Simulated final sendEmail failure');
                }
                Messaging.sendEmail(emails, false);
            } catch (Exception ex) {
                ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                    .withComponentName(COMPONENT)
                    .withClassName(CLASS_NAME)
                    .withMethodName(METHOD_NAME)
                    .withRequestBody(JSON.serialize(emails))
                    .withDomain('Core')
                    .withIntegrationType('Internal')
                    .withErrorType('Unhandled Exception')
                    .withException(ex);
                ExceptionLogger.logException(payload);
            }
        }
    }

    public class EmailException extends Exception {}
    public class CustomNotificationException extends Exception {}
}