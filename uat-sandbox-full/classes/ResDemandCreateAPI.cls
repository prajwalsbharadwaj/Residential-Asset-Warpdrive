@RestResource(urlMapping='/sap/v1/demand-invoice/*')
global without sharing class ResDemandCreateAPI {

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        String requestBodyString = ''; // Initialize to capture request body for logging

        try {
            // Capture request body string before deserialization
            requestBodyString = req.requestBody != null ? req.requestBody.toString() : '';

            // 1. Deserialize request into payload objects
            List<DemandService.DemandPayload> inputList = (List<DemandService.DemandPayload>) JSON.deserialize(
                requestBodyString,
                List<DemandService.DemandPayload>.class
            );

            // 2. Delegate all business logic to the service class
            Map<String, Map<String, Object>> responseMap = DemandService.createDemands(inputList);

            // 3. Build the HTTP response from the service class result
            // Convert the map values (individual record responses) into a list for JSON serialization
            res.responseBody = Blob.valueOf(JSON.serialize(responseMap.values()));
			System.debug('responseBody: ' + JSON.serialize(responseMap.values()));
            // Optional: Set a more descriptive status code
            boolean hasFailures = false;
            for(Map<String, Object> result : responseMap.values()){
                if(result.get('status') == 'Failure'){
                    hasFailures = true;
                    break;
                }
            }
            
            if(hasFailures){
                ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                    .withComponentName('ResDemandCreateAPI')
                    .withDescription('Error in creating demand invoice')
                    .withClassName('ResDemandCreateAPI')
                    .withMethodName('doPost')
                    .withRequestBody(requestBodyString) // Log the raw request body
                    .withResponseBody(res.responseBody != null ? res.responseBody.toString() : '') // Log any response generated so far
                    .withEndpoint(req.requestURI) // Log the API endpoint hit
                    .withDomain('SAP Inbound'); // Specify the integration domain

            	ExceptionLogger.addException(payload);
            }
            // Use 207 (Multi-Status) if there's a mix of success and failure, otherwise 200 (OK)
            res.statusCode = hasFailures ? 207 : 200;

        } catch (Exception ex) {
            // Handle exceptions like JSON parsing errors, unhandled service errors
            res.statusCode = 500; // Internal Server Error
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                'status' => 'Error',
                'message' => 'An unexpected error occurred: ' + ex.getMessage() + ' at line ' + ex.getLineNumber()
            }));

            // EFFECTIVE USE OF EXCEPTIONLOGGER
            // Log the exception for detailed internal tracking
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('ResDemandCreateAPI')
                .withDescription('Unhandled exception during Demand Create API call: ' + ex.getMessage())
                .withClassName('ResDemandCreateAPI')
                .withMethodName('doPost')
                .withRequestBody(requestBodyString) // Log the raw request body
                .withResponseBody(res.responseBody != null ? res.responseBody.toString() : '') // Log any response generated so far
                .withEndpoint(req.requestURI) // Log the API endpoint hit
                .withDomain('SAP Inbound') // Specify the integration domain
                .withException(ex); // Pass the exception object for stack trace etc.

            ExceptionLogger.addException(payload);
            System.debug(LoggingLevel.ERROR, 'ResDemandCreateAPI Error: ' + ex.getMessage() + ' at line ' + ex.getLineNumber() + '\n' + ex.getStackTraceString());
        } finally {
            
            if(!ExceptionLogger.isLogsCreated() && IntegrationToggle.isLogsEnabled('Demand Invoice', 'SAP', 'Residential', 'Inbound')) {
                //If no exception is thrown and there are no validation errors and the request was successful
                //And Logging is enabled in custom metadata then insert a success record for debugging
                ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                    .withComponentName('ResDemandCreateAPI')
                    .withDescription('Success log for debugging')
                    .withClassName('ResDemandCreateAPI')
                    .withMethodName('doPost')
                    .withRequestBody(requestBodyString) // Log the raw request body
                    .withResponseBody(res.responseBody != null ? res.responseBody.toString() : '') // Log any response generated so far
                    .withEndpoint(req.requestURI) // Log the API endpoint hit
                    .withDomain('SAP Inbound') // Specify the integration domain
                    .withErrorType('Success');
                	
                
                ExceptionLogger.addException(payload);
            }   
            
            ExceptionLogger.insertLogsIfAny();
            
        }
    }
}