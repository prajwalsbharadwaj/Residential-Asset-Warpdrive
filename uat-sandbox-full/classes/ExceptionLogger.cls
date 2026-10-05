public class ExceptionLogger {
    // Change the static list to hold Error_Log__c records
    private static List<Error_Log__c> logs = new List<Error_Log__c>();

    public static void addException(ExceptionLogPayload payload) {
        if (String.isBlank(payload.componentName) && String.isBlank(payload.description)) return;
        logs.add(buildLog(payload));
    }

    public static void logException(ExceptionLogPayload payload) {
        if (String.isBlank(payload.componentName) && String.isBlank(payload.description)) return;
        insertLogs(new List<Error_Log__c>{ buildLog(payload) });
    }
    
@future
    public static void logExceptionAsync(String payloadJson) {
        try {
            ExceptionLogPayload payload =
                (ExceptionLogPayload) JSON.deserialize(payloadJson, ExceptionLogPayload.class);

            if (String.isBlank(payload.componentName) &&
                String.isBlank(payload.description)) {
                return;
            }

            insert new List<Error_Log__c>{ buildLog(payload) };

        } catch (Exception e) {
            System.debug('Failed to insert logs asynchronously: ' + e.getMessage());
        }
    }


    public static void logExceptions(List<ExceptionLogPayload> payloads) {
        List<Error_Log__c> logs = new List<Error_Log__c>();
        for (ExceptionLogPayload payload : payloads) {
            logs.add(buildLog(payload));
        }
        insertLogs(logs);
    }

    // Change the return type to Error_Log__c and map fields to Error_Log__c
    private static Error_Log__c buildLog(ExceptionLogPayload payload) {
        return new Error_Log__c(
            Name = payload.componentName?.abbreviate(80),
            Error_Message__c = payload.errorDetail?.abbreviate(32768) ?? payload.description?.abbreviate(32768),
            Triggered_From__c = (payload.className + '.' + payload.methodName)?.abbreviate(255),
            Request_Body__c = payload.requestBody?.abbreviate(32768),
            Response_Body__c = payload.responseBody?.abbreviate(32768),
            Endpoint__c = payload.endpoint?.abbreviate(255),
            External_System__c = payload.domain,
            Integration_Type__c = payload.integrationType,
            Status_Code__c = payload.statusCode,
            Error_Type__c = payload.errorType,
            Stack_Trace__c = payload.stackTrace?.abbreviate(32768),
            Related_Record_Id__c = payload.relatedRecordId
        );
    }

    @TestVisible
    // Change the parameter type to List<Error_Log__c>
    private static void insertLogs(List<Error_Log__c> logs) {
        if (logs.isEmpty()) return;
        try {
            insert logs;
        } catch (Exception e) {
            System.debug('Failed to insert logs: ' + e.getMessage());
        }
    }

    public static void insertLogsIfAny() {
        if (logs.isEmpty()) return;
        try {
            insert logs;
        } catch (Exception e) {
            System.debug('Failed to insert logs: ' + e.getMessage());
        }
    }
    
    public static Boolean isLogsCreated(){
        return !logs.isEmpty();
    }

    public class ExceptionLogPayload {
        public String componentName;
        public String description;
        public String className;
        public String methodName;
        public String requestBody;
        public String responseBody;
        public String endpoint;
        public String domain;
        public String integrationType;
        public String statusCode;
        public String errorType;
        public String stackTrace; 
        public String errorDetail;
        public String relatedRecordId;

        public ExceptionLogPayload withComponentName(String val) {
            this.componentName = val;
            return this;
        }
        public ExceptionLogPayload withDescription(String val) {
            this.description = val;
            return this;
        }
        public ExceptionLogPayload withClassName(String val) {
            this.className = val;
            return this;
        }
        public ExceptionLogPayload withMethodName(String val) {
            this.methodName = val;
            return this;
        }
        public ExceptionLogPayload withRequestBody(String val) {
            this.requestBody = val;
            return this;
        }
        public ExceptionLogPayload withResponseBody(String val) {
            this.responseBody = val;
            return this;
        }
        public ExceptionLogPayload withEndpoint(String val) {
            this.endpoint = val;
            return this;
        }
        public ExceptionLogPayload withDomain(String val) {
            this.domain = val;
            return this;
        }
        public ExceptionLogPayload withIntegrationType(String val) {
            this.integrationType = val;
            return this;
        }
        public ExceptionLogPayload withStatusCode(String val) {
            this.statusCode = val;
            return this;
        }
        public ExceptionLogPayload withErrorType(String val) {
            this.errorType = val;
            return this;
        }
        public ExceptionLogPayload withStackTrace(String val) {
            this.stackTrace = val;
            return this;
        }
        public ExceptionLogPayload withException(Exception ex) {
            this.errorDetail = ex.getMessage() + ': ' + ex.getStackTraceString();
            return this;
        }
        public ExceptionLogPayload withRelatedRecordId(String relatedRecordId) {
            this.relatedRecordId = relatedRecordId;
            return this;
        } 
    }
}