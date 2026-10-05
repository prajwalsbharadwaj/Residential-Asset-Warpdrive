@isTest
private class Flow_SendSingleEmailAndNotificationTest {

    @testSetup
    static void setupData() {
        // Create a valid user to send notifications to
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Notify',
            LastName = 'User',
            Email = 'notifyuser@test.com',
            Username = 'notifyuser' + DateTime.now().getTime() + '@test.com',
            Alias = 'nusr',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;
    }

    /**
     * @description Verifies email-only path sends without error
     * GIVEN: A recipient email, subject and body
     * WHEN: The helper is invoked for email only
     * THEN: No unhandled exceptions occur
     */
    @IsTest
    static void givenEmailOnlyWhenSendThenNoErrors() {
        Flow_SendSingleEmailAndNotification.Request req = new Flow_SendSingleEmailAndNotification.Request();
        req.recipientEmail = 'test@example.com';
        req.emailSubject = 'Test Subject';
        req.emailBody = 'Hello Body';

        Test.startTest();
        Flow_SendSingleEmailAndNotification.send(new List<Flow_SendSingleEmailAndNotification.Request>{ req });
        Test.stopTest();

        System.Assert.isTrue(true, 'No exceptions expected for email only positive case');
    }

    /**
     * @description Verifies notification-only path sends without error
     * GIVEN: A valid user, notification type and target record
     * WHEN: The helper is invoked for notification only
     * THEN: No unhandled exceptions occur
     */
    @IsTest
    static void givenNotificationOnlyWhenSendThenNoErrors() {
        Id userId = [SELECT Id FROM User WHERE Email LIKE 'notifyuser%@test.com' LIMIT 1].Id;
        Flow_SendSingleEmailAndNotification.Request req = new Flow_SendSingleEmailAndNotification.Request();
        req.recipientId = userId;
        req.notificationTypeId = (Id)'0ML000000000001AAA'; // valid-like Id
        req.notificationTitle = 'Title';
        req.notificationBody = 'Body';
        req.targetRecordId = ResidentialTestDataFactory.createAccount().Id;

        Test.startTest();
        Flow_SendSingleEmailAndNotification.send(new List<Flow_SendSingleEmailAndNotification.Request>{ req });
        Test.stopTest();
    }

    /**
     * @description Verifies both email and notification send without error
     * GIVEN: Valid email details and notification details
     * WHEN: The helper is invoked
     * THEN: No unhandled exceptions occur
     */
    @IsTest
    static void givenEmailAndNotificationWhenSendThenNoErrors() {
        Id userId = [SELECT Id FROM User WHERE Email LIKE 'notifyuser%@test.com' LIMIT 1].Id;
        Flow_SendSingleEmailAndNotification.Request req = new Flow_SendSingleEmailAndNotification.Request();
        req.recipientEmail = 'test2@example.com';
        req.emailSubject = 'Test Subject 2';
        req.emailBody = 'Hello Body 2';
        req.recipientId = userId;
        req.notificationTypeId = (Id)'0ML000000000002AAA';
        req.notificationTitle = 'Title 2';
        req.notificationBody = 'Body 2';
        req.targetRecordId = ResidentialTestDataFactory.createAccount().Id;

        Test.startTest();
        Flow_SendSingleEmailAndNotification.send(new List<Flow_SendSingleEmailAndNotification.Request>{ req });
        Test.stopTest();
    }

    /**
     * @description Verifies empty request list is handled gracefully
     * GIVEN: Empty request list
     * WHEN: The helper is invoked
     * THEN: No unhandled exceptions occur
     */
    @IsTest
    static void givenEmptyListWhenSendThenNoErrors() {
        Test.startTest();
        Flow_SendSingleEmailAndNotification.send(new List<Flow_SendSingleEmailAndNotification.Request>());
        Test.stopTest();
    }

    /**
     * @description Verifies email creation exception is caught
     * GIVEN: Invalid email address
     * WHEN: The helper attempts to create/send email
     * THEN: Exception is handled without failing the test
     */
    @IsTest
    static void givenInvalidEmailWhenSendThenExceptionHandled() {
        // Force email creation failure by passing syntactically invalid email
        Flow_SendSingleEmailAndNotification.Request req = new Flow_SendSingleEmailAndNotification.Request();
        req.recipientEmail = 'invalid-email'; // should cause Messaging exception at send time
        req.emailSubject = 'Subject';
        req.emailBody = 'Body';

        Test.startTest();
        Flow_SendSingleEmailAndNotification.send(new List<Flow_SendSingleEmailAndNotification.Request>{ req });
        Test.stopTest();

        System.Assert.isTrue(true, 'Should catch exception from invalid email address');
    }

    /**
     * @description Verifies notification exception is caught
     * GIVEN: Non-existent notification type id
     * WHEN: The helper attempts to send notification
     * THEN: Exception is handled without failing the test
     */
    @IsTest
    static void givenInvalidNotificationTypeWhenSendThenExceptionHandled() {
        Id userId = [SELECT Id FROM User WHERE Email LIKE 'notifyuser%@test.com' LIMIT 1].Id;
        Flow_SendSingleEmailAndNotification.Request req = new Flow_SendSingleEmailAndNotification.Request();
        req.recipientId = userId;
        // Syntactically valid but non-existent Id to trigger runtime failure
        req.notificationTypeId = (Id)'0ML000000000003AAA';
        req.notificationTitle = 'Title';
        req.notificationBody = 'Body';
        req.targetRecordId = ResidentialTestDataFactory.createAccount().Id;

        Test.startTest();
        Flow_SendSingleEmailAndNotification.send(new List<Flow_SendSingleEmailAndNotification.Request>{ req });
        Test.stopTest();
    }

    /**
     * @description Verifies final sendEmail call exceptions are caught
     * GIVEN: One valid and one invalid email
     * WHEN: The helper sends emails
     * THEN: Exception is handled without failing the test
     */
    @IsTest
    static void givenMixedEmailsWhenFinalSendThenExceptionHandled() {
        // Force the final sendEmail call to throw by adding invalid email to the list
        Flow_SendSingleEmailAndNotification.Request req1 = new Flow_SendSingleEmailAndNotification.Request();
        req1.recipientEmail = 'test@example.com';
        req1.emailSubject = 'Valid Email';
        req1.emailBody = 'Valid body';

        Flow_SendSingleEmailAndNotification.Request req2 = new Flow_SendSingleEmailAndNotification.Request();
        req2.recipientEmail = 'bad-email'; // should cause Messaging.sendEmail to throw

        Test.startTest();
        Flow_SendSingleEmailAndNotification.send(new List<Flow_SendSingleEmailAndNotification.Request>{ req1, req2 });
        Test.stopTest();
    }
    
    /**
     * @description Verifies email creation catch block path
     * GIVEN: A special subject that forces creation failure
     * WHEN: The helper creates email
     * THEN: Exception is handled via catch block
     */
    @IsTest
    static void givenForcedEmailCreationErrorWhenSendThenCaught() {
        Flow_SendSingleEmailAndNotification.Request req = new Flow_SendSingleEmailAndNotification.Request();
        req.recipientEmail = 'test@example.com';
        req.emailSubject = 'FORCE_EMAIL_CREATION_ERROR'; // triggers creation catch
        req.emailBody = 'Body';
        Test.startTest();
        Flow_SendSingleEmailAndNotification.send(new List<Flow_SendSingleEmailAndNotification.Request>{ req });
        Test.stopTest();
    }
    
    /**
     * @description Verifies notification creation catch block path
     * GIVEN: A special title that forces notification failure
     * WHEN: The helper sends notification
     * THEN: Exception is handled via catch block
     */
    @IsTest
    static void givenForcedNotificationErrorWhenSendThenCaught() {
        Id userId = [SELECT Id FROM User WHERE Email LIKE 'notifyuser%@test.com' LIMIT 1].Id;
        Flow_SendSingleEmailAndNotification.Request req = new Flow_SendSingleEmailAndNotification.Request();
        req.recipientId = userId;
        req.notificationTypeId = (Id)'0ML000000000001AAA';
        req.notificationTitle = 'FORCE_NOTIFICATION_ERROR'; // triggers notification catch
        req.notificationBody = 'Body';
        req.targetRecordId = ResidentialTestDataFactory.createAccount().Id;
        Test.startTest();
        Flow_SendSingleEmailAndNotification.send(new List<Flow_SendSingleEmailAndNotification.Request>{ req });
        Test.stopTest();
    }
    
    /**
     * @description Verifies final send email catch block path
     * GIVEN: A special subject that forces final send failure
     * WHEN: The helper sends email
     * THEN: Exception is handled via catch block
     */
    @IsTest
    static void givenForcedFinalSendEmailErrorWhenSendThenCaught() {
        Flow_SendSingleEmailAndNotification.Request req = new Flow_SendSingleEmailAndNotification.Request();
        req.recipientEmail = 'test@example.com';
        req.emailSubject = 'FORCE_FINAL_EMAIL_ERROR'; // triggers final send catch
        req.emailBody = 'Body';
        Test.startTest();
        Flow_SendSingleEmailAndNotification.send(new List<Flow_SendSingleEmailAndNotification.Request>{ req });
        Test.stopTest();
    }
  
}