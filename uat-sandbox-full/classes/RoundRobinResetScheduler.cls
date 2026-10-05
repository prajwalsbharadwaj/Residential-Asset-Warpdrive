global class RoundRobinResetScheduler implements Schedulable {
    
    @TestVisible static Boolean throwExceptionForTest = false;

    global void execute(SchedulableContext sc) {
        try {
            if (throwExceptionForTest) {
                // Force an exception for test coverage
                throw new DmlException('Forced exception for test');
            }
            
            Date today = Date.today();

            List<Round_Robin_Assignee__c> toReset = [
                SELECT Id, Assigned_Today__c, Last_Assignment_Date__c
                FROM Round_Robin_Assignee__c
                WHERE Last_Assignment_Date__c != :today
            ];

            for (Round_Robin_Assignee__c a : toReset) {
                a.Assigned_Today__c = 0;
                a.Last_Assignment_Date__c = today;
            }

            if (!toReset.isEmpty()) {
                update toReset;
            }

            System.debug('✅ Round Robin assignee counts reset for ' + toReset.size() + ' users.');
        } catch (Exception e) {
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('RoundRobinResetScheduler')
                .withDescription('Failed to reset round robin assignee counts. ' + e.getMessage())
                .withClassName('RoundRobinResetScheduler')
                .withMethodName('execute')
                .withErrorType('Scheduled Job')
                .withException(e);
            ExceptionLogger.logException(payload);
        }
    }
}