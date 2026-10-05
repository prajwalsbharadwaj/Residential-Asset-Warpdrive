public class FinalReminderController {
    
    static final String SEND_REMINDER_EMAIL_ERROR_MESSAGE = 'Failed to send reminder email: ';
    
    @AuraEnabled
    public static void sendReminderEmail(Id bpsId) {
        try {
            // Fetch Booking Payment Schedule and related info
            Booking_Payment_Schedule__c bps = [
                SELECT Id, Name, Installment_Amount__c, Payment_Due_Date__c,
                       Amount_Paid__c, Adjusted_Amount__c,
                       Booking__r.Name, Booking__r.Booking_Date__c,
                       Booking__r.Account_Id__r.Name, Booking__r.Account_Id__r.PersonEmail, Booking__r.Account_Id__r.Phone, Booking__r.Account_Id__r.Salutation,
                       Booking__r.Unit_Id__r.Name,
                       Booking__r.Project__r.Name, Booking__r.Project__r.Address__c
                FROM Booking_Payment_Schedule__c
                WHERE Id = :bpsId
                LIMIT 1
            ];

            // Validate email
            String email = bps.Booking__r.Account_Id__r.PersonEmail;
            if (String.isBlank(email)) {
                throw new EmailException('Customer email not available.');
            }

            // Dates
            String today = Date.today().format();
            String dueDate = formatDate(bps.Payment_Due_Date__c);
            String bookingDate = formatDate(bps.Booking__r.Booking_Date__c);

            // Amounts
            Decimal installment = bps.Installment_Amount__c != null ? bps.Installment_Amount__c : 0;
            Decimal paid = bps.Amount_Paid__c != null ? bps.Amount_Paid__c : 0;
            Decimal adjusted = bps.Adjusted_Amount__c != null ? bps.Adjusted_Amount__c : 0;
            Decimal pending = installment - (paid + adjusted);
            Decimal interest = 0; // Optional: calculate if required

            // Rich Text HTML Email Body
            String htmlBody = 
            '<html>' +
            '<head>' +
            '    <meta charset="UTF-8">' +
            '    <meta name="viewport" content="width=device-width, initial-scale=1.0">' +
            '    <style>' +
            '        body { font-family: "Inter", sans-serif; background-color: #f0f2f5; margin: 0; padding: 20px; display: flex; justify-content: center; align-items: flex-start; min-height: 100vh; box-sizing: border-box; }' +
            '        .email-container { max-width: 650px; width: 100%; background-color: #ffffff; border-radius: 12px; box-shadow: 0 8px 25px rgba(0, 0, 0, 0.1); padding: 40px; box-sizing: border-box; border: 1px solid #e2e8f0; }' +
            '        .date { font-size: 0.9375rem; color: #64748b; margin-bottom: 25px; text-align: right; }' +
            '        .salutation, .subject-line { font-size: 1.25rem; font-weight: 600; color: #2d3748; margin-bottom: 20px; }' +
            '        .paragraph { font-size: 1.0625rem; line-height: 1.7; color: #4a5568; margin-bottom: 20px; }' +
            '        .highlight { font-weight: 600; color: #1a202c; }' +
            '        .closing { font-size: 1.0625rem; color: #4a5568; margin-top: 30px; margin-bottom: 8px; }' +
            '        .signature-block { margin-top: 25px; padding-top: 20px; border-top: 1px solid #e5e7eb; }' +
            '        .signature-name { font-size: 1.25rem; font-weight: 700; color: #1a202c; margin-bottom: 5px; margin-top: 100px; }' +
            '        .company-info { font-size: 1rem; color: #4a5568; }' +
            '        .disclaimer { font-size: 0.75rem; color: #94a3b8; margin-top: 40px; text-align: center; padding-top: 20px; border-top: 1px solid #e5e7eb; }' +
            '        @media (max-width: 640px) { body { padding: 10px; } .email-container { padding: 25px; border-radius: 8px; box-shadow: 0 4px 15px rgba(0, 0, 0, 0.08); } .salutation { font-size: 1.125rem; } .paragraph { font-size: 1rem; } .signature-name { font-size: 1.125rem; } }' +
            '    </style>' +
            '</head>' +
            '<body>' +
            '    <div class="email-container">' +
            '        <p class="date">Date: <span class="highlight">' + today + '</span></p>' +
            '        <p class="salutation">Dear ' + ' <span class="highlight">' + bps.Booking__r.Account_Id__r.Name + '</span>,</p>' +
            '        <p class="paragraph">This has reference to your booking of flat <span class="highlight">' + bps.Booking__r.Unit_Id__r.Name + '</span> in “' + bps.Booking__r.Project__r.Name + '” on <span class="highlight">' + bookingDate + '</span>.</p>' +
            '        <p class="paragraph">We had issued you a demand note on <span class="highlight">' + dueDate + '</span> requesting you to effect the payment of <span class="highlight">' + formatCurrency(installment) + '</span> as part of scheduled payments within the due date. However, we have not received the due amount of <span class="highlight">' + formatCurrency(pending) + '</span> (as on <span class="highlight">' + today + '</span>) till date.</p>' +
            '        <p class="paragraph">Your payment of <span class="highlight">' + formatCurrency(pending) + '</span> (Towards <span class="highlight">' + (bps.Name != null ? bps.Name : 'Installment') + '</span>) is now long overdue. We request you to clear this immediately with interest, which has accrued from the original due date (interest as on <span class="highlight">' + today + '</span> is <span class="highlight">' + formatCurrency(interest) + '</span>) as per the terms of the agreement dated <span class="highlight">' + bookingDate + '</span>.</p>' +
            '        <p class="paragraph">Kindly clear the outstanding at the earliest to avoid further charges on delayed payment. Please note that payments without interest will not be accepted.</p>' +
            '        <p class="paragraph">Please feel free to call or mail us for any information or clarifications on the subject.</p>' +
            '        <div class="signature-block">' +
            '            <p class="closing">Thanks & Regards,</p>' +
            '            <p class="company-info">For M/s. Palladium Constructions Pvt. Ltd.,</p>' +
            '            <p class="signature-name">Authorized Signatory</p>' +
            '        </div>' +
            '        <p class="disclaimer">This is an auto-generated email. Please do not reply to this message.</p>' +
            '    </div>' +
            '</body>' +
            '</html>';

            // Send email (rich text = HTML)
            Messaging.SingleEmailMessage emailMsg = new Messaging.SingleEmailMessage();
            emailMsg.setToAddresses(new String[] { email });
            emailMsg.setSubject('Final Reminder: Overdue Payment for Flat No. ' + bps.Booking__r.Unit_Id__r.Name + ' – ' + bps.Booking__r.Project__r.Name);
            emailMsg.setHtmlBody(htmlBody);
            emailMsg.setSaveAsActivity(true);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { emailMsg });
                
        } catch (Exception ex) {
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('Final Reminder Email')
                .withClassName('FinalReminderController')
                .withMethodName('sendReminderEmail')
                .withRequestBody('bpsId = ' + String.valueOf(bpsId))
                .withDomain('Core')
                .withIntegrationType('Internal')
                .withErrorType('Unhandled Exception')
                .withException(ex)
                .withDescription('Error occurred while sending final reminder email to customer');

            ExceptionLogger.logException(payload);
            AuraHandledException auraEx = new AuraHandledException(SEND_REMINDER_EMAIL_ERROR_MESSAGE + ex.getMessage());
            auraEx.setMessage(SEND_REMINDER_EMAIL_ERROR_MESSAGE + ex.getMessage());
            throw auraEx;
            
        }
    }

    private static String formatDate(Date d) {
        return d == null ? '__________' : d.format();
    }

    private static String formatAmount(Decimal amt) {
        return amt == null ? '__________' : String.valueOf(amt.setScale(2));
    }
    
    private static String formatCurrency(Decimal amount) {
        if (amount == null) return '₹ 0.00';
        return '₹' + amount.setScale(2).format();
    }

    public class EmailException extends Exception {}
}