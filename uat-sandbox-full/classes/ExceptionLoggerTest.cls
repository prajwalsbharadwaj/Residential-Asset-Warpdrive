@IsTest
private class ExceptionLoggerTest {
    // Helper to create a long string for truncate checks
    private static String makeLong(Integer len) {
        String s = 'x';
        while (s.length() < len) s += s;
        return s.substring(0, len);
    }

    @IsTest
    static void testAddAndInsertLogsIfAny_insertsQueuedRecords() {
        Test.startTest();

        // Queue two logs via addException (deferred insert)
        ExceptionLogger.ExceptionLogPayload p1 = new ExceptionLogger.ExceptionLogPayload()
            .withComponentName('CompA')
            .withDescription('Desc A')
            .withClassName('MyClass')
            .withMethodName('doWork')
            .withRequestBody('{"foo":1}')
            .withResponseBody('{"bar":2}')
            .withEndpoint('https://api.example.com/a')
            .withDomain('SAP')
            .withIntegrationType('REST')
            .withStatusCode('500')
            .withErrorType('HTTP')
            .withStackTrace('some stack');

        ExceptionLogger.ExceptionLogPayload p2 = new ExceptionLogger.ExceptionLogPayload()
            .withComponentName('CompB')
            .withDescription('Desc B');

        ExceptionLogger.addException(p1);
        ExceptionLogger.addException(p2);

        // Nothing inserted yet
        System.assertEquals(0, [SELECT COUNT() FROM Error_Log__c], 'No records should exist before flushing.');

        // Flush queued logs
        ExceptionLogger.insertLogsIfAny();

        Test.stopTest();

        // Validate two records inserted
        List<Error_Log__c> inserted = [
            SELECT Id, Name, Error_Message__c, Triggered_From__c, Request_Body__c, Response_Body__c,
                   Endpoint__c, External_System__c, Integration_Type__c, Status_Code__c, Error_Type__c,
                   Stack_Trace__c, CreatedDate
            FROM Error_Log__c
            ORDER BY CreatedDate ASC
        ];
        System.assertEquals(2, inserted.size(), 'Expected exactly two inserted logs.');

        // Validate field mapping on the richer payload (p1) — should be one of the two
        Error_Log__c rich = null;
        for (Error_Log__c r : inserted) {
            if (r.Endpoint__c == 'https://api.example.com/a') {
                rich = r; break;
            }
        }
        System.assertNotEquals(null, rich, 'Expected to find the record with the specific endpoint.');
        System.assertEquals('SAP', rich.External_System__c);
        System.assertEquals('REST', rich.Integration_Type__c);
        System.assertEquals('500', rich.Status_Code__c);
        System.assertEquals('HTTP', rich.Error_Type__c);
        System.assertEquals('{"foo":1}', rich.Request_Body__c);
        System.assertEquals('{"bar":2}', rich.Response_Body__c);
        System.assertEquals('https://api.example.com/a', rich.Endpoint__c);
        System.assert(!String.isBlank(rich.Error_Message__c), 'Error message should be populated.');
        System.Assert.isTrue(rich.Triggered_From__c.contains('MyClass.doWork'), 'Triggered_From should contain Class.Method.');
        System.Assert.isTrue(!String.isBlank(rich.Stack_Trace__c), 'Stack trace should be populated.');
    }

    @IsTest
    static void testLogException_singleInsert_andWithException() {
        Exception ex;
        try {
            Integer a = 1 / 0;
        } catch (Exception e) {
            ex = e;
        }
        System.Assert.isTrue(ex != null, 'Expected an exception to be captured.');

        Test.startTest();
        ExceptionLogger.ExceptionLogPayload p = new ExceptionLogger.ExceptionLogPayload()
            .withComponentName('CompC')
            .withDescription('Single insert path')
            .withClassName('C1')
            .withMethodName('m1')
            .withException(ex); // populates errorDetail (message + stack)
        ExceptionLogger.logException(p);
        Test.stopTest();

        List<Error_Log__c> rows = [
            SELECT Id, Error_Message__c, Stack_Trace__c, Triggered_From__c, CreatedDate
            FROM Error_Log__c ORDER BY CreatedDate DESC LIMIT 1
        ];
        System.Assert.areEqual(1, rows.size(), 'Exactly one record should be inserted.');
        System.Assert.isTrue(rows[0].Error_Message__c.contains(ex.getMessage()), 'Error_Message__c should include exception message.');
        System.Assert.isTrue(rows[0].Triggered_From__c.contains('C1.m1'), 'Triggered_From should be set.');
    }

    @IsTest
    static void testLogExceptions_batchInsert_truncation_andGuard() {
        // Very long values to exercise abbreviate to 32768
        String longBody = makeLong(40000);

        List<ExceptionLogger.ExceptionLogPayload> payloads = new List<ExceptionLogger.ExceptionLogPayload>{
            new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('Batch1')
                .withDescription(longBody) // goes to Error_Message__c (since errorDetail is null)
                .withRequestBody(longBody)
                .withResponseBody(longBody)
                .withStackTrace(longBody),
            new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('Batch2')
                .withDescription('short desc')
                .withErrorType('Validation'),
            new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('Batch3')
                .withDescription('another one')
                .withEndpoint('https://api.example.com/b3')
        };

        // A payload that should be skipped by guard (both blank)
        ExceptionLogger.ExceptionLogPayload skip = new ExceptionLogger.ExceptionLogPayload();

        Integer before = [SELECT COUNT() FROM Error_Log__c];

        Test.startTest();
        ExceptionLogger.logExceptions(payloads);
        // This call should NO-OP because both componentName and description are blank
        ExceptionLogger.logException(skip);
        Test.stopTest();

        Integer after = [SELECT COUNT() FROM Error_Log__c];
        System.Assert.areEqual(before + 3, after, 'Should insert only the 3 valid payloads; guard should skip the blank one.');

        // Fetch the last 3 for truncation checks
        List<Error_Log__c> recent = [
            SELECT Id, Error_Message__c, Request_Body__c, Response_Body__c, Stack_Trace__c, Endpoint__c, CreatedDate
            FROM Error_Log__c
            ORDER BY CreatedDate DESC
            LIMIT 3
        ];

        // Verify truncation where fields were very long
        for (Error_Log__c r : recent) {
            if (r.Error_Message__c != null) System.Assert.isTrue(r.Error_Message__c.length() <= 32768, 'Error message should be abbreviated.');
            if (r.Request_Body__c  != null) System.Assert.isTrue(r.Request_Body__c.length()  <= 32768, 'Request body should be abbreviated.');
            if (r.Response_Body__c != null) System.Assert.isTrue(r.Response_Body__c.length() <= 32768, 'Response body should be abbreviated.');
            if (r.Stack_Trace__c   != null) System.Assert.isTrue(r.Stack_Trace__c.length()   <= 32768, 'Stack trace should be abbreviated.');
        }

        // Spot-check one mapping from the batch
        Boolean foundB3 = false;
        for (Error_Log__c r : recent) {
            if (r.Endpoint__c == 'https://api.example.com/b3') foundB3 = true;
        }
        System.Assert.isTrue(foundB3, 'Endpoint mapping should persist for Batch3.');
    }

    @IsTest
    static void testGuard_noInsertWhenBothBlank() {
        Integer before = [SELECT COUNT() FROM Error_Log__c];

        Test.startTest();
        ExceptionLogger.ExceptionLogPayload guard = new ExceptionLogger.ExceptionLogPayload();
        ExceptionLogger.logException(guard); // should do nothing
        ExceptionLogger.insertLogsIfAny();   // nothing queued either
        Test.stopTest();

        Integer after = [SELECT COUNT() FROM Error_Log__c];
        System.Assert.areEqual(before, after, 'No records should be inserted when both componentName and description are blank.');
    }
}