public with sharing class WelcomeLetterController {
    public String fileName { get; set; }
    
    // Wrapper for VF rendering
    public class WelcomeLetterWrapper {
        public String letterDate { get; set; }
        public String customerName { get; set; }
        public String customerEmail { get; set; }
        public String projectName { get; set; }
        public String projectAddress { get; set; }
        public String configuration { get; set; }
        public String unitNumber { get; set; }
        public String carpetArea { get; set; }
        public String floorNumber { get; set; }
        public String towerName { get; set; }
    }
    
    public WelcomeLetterWrapper letter { get; set; }
    public Id bookingId { get; set; }

    public WelcomeLetterController() {
        try {
            bookingId = ApexPages.currentPage().getParameters().get('id');
            if (bookingId != null) {
                loadLetterData(bookingId);
            }
        } catch (Exception ex) {
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('WelcomeLetterController')
                .withClassName('WelcomeLetterController')
                .withMethodName('Constructor')
                .withDescription('Error initializing WelcomeLetterController')
                .withException(ex);
            ExceptionLogger.logException(payload);
        }
    }

    private void loadLetterData(Id bookingId) {
        try {
            Booking__c b = [
                SELECT Id, Name,
                       Account_Id__r.Name, Account_Id__r.PersonEmail,
                       Unit_Id__r.Name, Unit_Id__r.Carpet_Area__c,
                       Unit_Id__r.BHK_Configuration__c,
                       Unit_Id__r.Floor__r.Name,
                       Unit_Id__r.Tower__r.Name,
                       Unit_Id__r.Property__r.Name, Unit_Id__r.Property__r.Address__c
                FROM Booking__c
                WHERE Id = :bookingId
                LIMIT 1
            ];

            letter = new WelcomeLetterWrapper();
            letter.letterDate     = Date.today().format();
            letter.customerName   = b.Account_Id__r != null ? b.Account_Id__r.Name : 'Valued Customer';
            letter.customerEmail  = b.Account_Id__r != null ? b.Account_Id__r.PersonEmail : '';
            letter.projectName    = b.Unit_Id__r.Property__r != null ? b.Unit_Id__r.Property__r.Name : '';
            letter.projectAddress = b.Unit_Id__r.Property__r != null ? b.Unit_Id__r.Property__r.Address__c : '';
            letter.configuration  = b.Unit_Id__r.BHK_Configuration__c;
            letter.unitNumber     = b.Unit_Id__r.Name;
            letter.carpetArea     = (b.Unit_Id__r.Carpet_Area__c != null) ? String.valueOf(b.Unit_Id__r.Carpet_Area__c) : '';
            letter.floorNumber    = b.Unit_Id__r.Floor__r != null ? b.Unit_Id__r.Floor__r.Name : '';
            letter.towerName      = b.Unit_Id__r.Tower__r != null ? b.Unit_Id__r.Tower__r.Name : '';
            fileName = 'Welcome_Letter_' + b.Id + '_' + Datetime.now().format('yyyyMMdd_HHmmss') + '.doc';
        } catch (Exception ex) {
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('WelcomeLetterController')
                .withClassName('WelcomeLetterController')
                .withMethodName('loadLetterData')
                .withDescription('Error while loading Booking and related data')
                .withRequestBody('BookingId: ' + bookingId)
                .withException(ex);
            ExceptionLogger.logException(payload);
        }
    }

    // 🔹 Subclass for Flow Apex Action
    public class EmailRequest {
        @InvocableVariable(required=true)
        public Id bookingId;
        
        @InvocableVariable(required=true)
        public String recipient; // Single email address instead of List
        
        @InvocableVariable(required=true)
        public String subject;
        
        @InvocableVariable(required=true)
        public String body; // Rich Text from Flow
    }
    
    public class EmailResponse {
        @InvocableVariable
        public Boolean success;
        
        @InvocableVariable
        public String message;
    }

    // 🔹 Flow Invocable Method
    @InvocableMethod(label='Send Welcome Letter' description='Generates Welcome Letter doc and emails it')
    public static List<EmailResponse> sendWelcomeLetter(List<EmailRequest> requests) {
        List<EmailResponse> responses = new List<EmailResponse>();
        
        for (EmailRequest req : requests) {
            EmailResponse res = new EmailResponse();
            try {
                // 1️⃣ Get VF page content
                PageReference pageRef = Page.WelcomeLetter;
                pageRef.getParameters().put('id', req.bookingId);
                Blob wordBlob = Test.isRunningTest() ? Blob.valueOf('Test') : pageRef.getContent();
                Attachment att = new Attachment();
                att.Name = 'WelcomeLetter_' + Date.today().format() + '.doc';
                att.Body = wordBlob;
                att.ParentId = req.bookingId;
                att.ContentType = 'application/msword';
                insert att;
                
                // 3️⃣ Send Email with Attachment
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new String[] { req.recipient });
                mail.setSubject(req.subject);
                mail.setHtmlBody(req.body);
                
                Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
                efa.setFileName(att.Name);
                efa.setBody(att.Body);
                efa.setContentType('application/msword');
                
                mail.setFileAttachments(new Messaging.EmailFileAttachment[] { efa });
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                
                res.success = true;
                res.message = 'Email sent successfully with attachment.';
            } catch (Exception ex) {
                res.success = false;
                res.message = ex.getMessage();
                
                ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                    .withComponentName('WelcomeLetterController')
                    .withClassName('WelcomeLetterController')
                    .withMethodName('sendWelcomeLetter')
                    .withDescription('Error while generating or sending Welcome Letter email')
                    .withRequestBody('BookingId: ' + req.bookingId + ', Recipient: ' + req.recipient)
                    .withException(ex);
                ExceptionLogger.logException(payload);
            }
            responses.add(res);
        }
        
        return responses;
    }
}