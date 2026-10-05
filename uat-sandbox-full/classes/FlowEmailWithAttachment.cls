/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : FlowEmailWithAttachment
 * Author          : <YourName>
 * Created Date    : May 3, 2026
 * Last Modified By: <YourName>
 * Last Modified On: May 3, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  May 3, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public class FlowEmailWithAttachment {

    public class EmailInput {
        @InvocableVariable(label='Recipient Email') public String toEmail;
        @InvocableVariable(label='Recipient Name') public String recipientName;
        @InvocableVariable(label='ContentVersion Id') public Id contentVersionId;
    }

    @InvocableMethod(label='Send Email with Attachment')
    public static void sendEmail(List<EmailInput> requests) {
        for (EmailInput req : requests) {
            if (req.toEmail == null || req.recipientName == null || req.contentVersionId == null ) {
                continue; 
            }

            try {
                ContentVersion file = [
                    SELECT Title, VersionData, FileExtension
                    FROM ContentVersion
                    WHERE id =: req.contentVersionId limit 1
                ];

                // Compose body
                String body = 'Dear ' + req.recipientName + ',\n\n' +
                    'Thank you for showing your interest in Century Housing. We truly appreciate you considering us for your housing needs.\n\n' +
                    'We are confident that our properties represent the best of what this neighborhood has to offer, with meticulously designed homes and a host of amenities crafted for a superior living experience. This is an exceptional opportunity to own a home in a thriving community.\n\n' +
                    'Please find attached our detailed brochure, which provides comprehensive information about the property, floor plans, pricing, and much more. We encourage you to explore it at your convenience to discover all the fantastic details.\n\n' +
                    'We are excited about the possibility of welcoming you to the Century Housing community! Please do not hesitate to reach out if you have any questions or would like to schedule a site visit.\n\n' +
                    'Sincerely,\nCentury Housing Team';

                Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                attachment.setFileName(file.Title + '.' + file.FileExtension);
                attachment.setBody(file.VersionData);
                attachment.setContentType('application/octet-stream');

                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(new String[] { req.toEmail });
                email.setSubject('Thank You for Your Interest in Century Housing');
                email.setPlainTextBody(body);
                email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });

                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });

            } catch (Exception e) {
                System.debug('Error sending email: ' + e.getMessage());
            }
        }
    }
}