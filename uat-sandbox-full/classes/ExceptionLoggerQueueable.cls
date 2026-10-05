/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : ExceptionLoggerQueueable
 * Author          : <YourName>
 * Created Date    : Jan 14, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Jan 14, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jan 14, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public class ExceptionLoggerQueueable implements Queueable {

    private String payloadJson;

    public ExceptionLoggerQueueable(String payloadJson) {
        this.payloadJson = payloadJson;
    }

    public void execute(QueueableContext context) {
        try {
            ExceptionLogger.ExceptionLogPayload payload =
                (ExceptionLogger.ExceptionLogPayload)
                    JSON.deserialize(payloadJson, ExceptionLogger.ExceptionLogPayload.class);

            if (String.isBlank(payload.componentName) &&
                String.isBlank(payload.description)) {
                return;
            }

            insert new Error_Log__c(
                Name = payload.componentName?.abbreviate(80),
                Error_Message__c = payload.errorDetail?.abbreviate(32768)
                    ?? payload.description?.abbreviate(32768),
                Triggered_From__c = (payload.className + '.' + payload.methodName)?.abbreviate(255),
                Request_Body__c = payload.requestBody?.abbreviate(32768),
                External_System__c = payload.domain,
                Integration_Type__c = payload.integrationType,
                Error_Type__c = payload.errorType
            );
        } catch (Exception e) {
            System.debug('Queueable logging failed: ' + e.getMessage());
        }
    }
}