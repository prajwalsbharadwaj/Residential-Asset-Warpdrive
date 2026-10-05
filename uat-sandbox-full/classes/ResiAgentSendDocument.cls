/**
 * Agent action "Send Customer Document" – renders the org's existing document pages (Statement of Account,
 * Payment Ledger, Welcome Letter) as PDF, attaches it to the email case and emails it to the customer.
 */
// Runs as the Einstein agent user; access is scoped by matching the case sender to the customer, not by sharing.
public without sharing class ResiAgentSendDocument {

    public class Request {
        @InvocableVariable(required=true label='Case Id' description='Id of the email Case (emailCaseId).')
        public Id caseId;
        @InvocableVariable(required=true label='Document Type' description='One of: Statement of Account, Payment Ledger, Welcome Letter.')
        public String documentType;
        @InvocableVariable(label='Booking Reference' description='Booking number or unit number. Optional when the customer has one booking.')
        public String bookingReference;
        @InvocableVariable(label='Start Date' description='Statement period start. Defaults to the booking date.')
        public Date startDate;
        @InvocableVariable(label='End Date' description='Statement period end. Defaults to today.')
        public Date endDate;
    }

    public class Result {
        @InvocableVariable(label='Sent' description='true when the document was generated and emailed to the customer.')
        public Boolean sent;
        @InvocableVariable(label='Message' description='What happened, to use in the reply (or why it could not be sent).')
        public String message;
    }

    private static final Map<String, String> PAGES = new Map<String, String>{
        'statement of account' => 'StatementOfAccountDOC',
        'soa' => 'StatementOfAccountDOC',
        'payment ledger' => 'PaymentLedgerDOC',
        'ledger' => 'PaymentLedgerDOC',
        'welcome letter' => 'WelcomeLetter'
    };

    @InvocableMethod(label='Send Customer Document' description='Generates the Statement of Account, Payment Ledger or Welcome Letter for the customer booking as a PDF, attaches it to the case and emails it to the customer registered email address.' category='Nikoo Homes Agent')
    public static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request r : requests) {
            results.add(send(r));
        }
        return results;
    }

    private static Result send(Request r) {
        Result res = new Result();
        res.sent = false;
        String type = r.documentType == null ? '' : r.documentType.trim().toLowerCase();
        String page = PAGES.get(type);
        if (page == null) {
            res.message = 'Only the Statement of Account, Payment Ledger and Welcome Letter can be sent automatically.';
            return res;
        }
        ResiAgentService.CustomerContext ctx = ResiAgentService.resolveCustomer(r.caseId);
        if (!ctx.found) {
            res.message = 'The sender is not a registered customer, so no document was sent.';
            return res;
        }
        List<Booking__c> bookings = ResiAgentService.bookingsFor(ctx.account.Id);
        Booking__c b = ResiAgentService.pickBooking(bookings, r.bookingReference);
        if (b == null) {
            res.message = bookings.size() > 1
                ? 'The customer has more than one booking; ask which booking the document is for.'
                : 'No matching booking belongs to this customer.';
            return res;
        }
        if (page == 'WelcomeLetter' && (b.Status__c == 'Pending Confirmation' || b.Status__c == 'Cancelled')) {
            res.message = 'The welcome letter is issued once the booking is confirmed; booking ' + b.Name + ' is ' + b.Status__c + '.';
            return res;
        }
        String recipient = String.isNotBlank(ctx.account.PersonEmail) ? ctx.account.PersonEmail : ctx.email;
        if (String.isBlank(recipient)) {
            res.message = 'No registered email address on file.';
            return res;
        }

        Date startDate = r.startDate != null ? r.startDate : (b.Booking_Date__c != null ? b.Booking_Date__c : b.CreatedDate.date());
        Date endDate = r.endDate != null ? r.endDate : Date.today();
        PageReference pr = new PageReference('/apex/' + page);
        pr.getParameters().put('id', b.Id);
        pr.getParameters().put('startDate', String.valueOf(startDate));
        pr.getParameters().put('endDate', String.valueOf(endDate));
        Blob pdf = Test.isRunningTest() ? Blob.valueOf('test') : pr.getContentAsPDF();

        String label = page == 'StatementOfAccountDOC' ? 'Statement of Account' : (page == 'PaymentLedgerDOC' ? 'Payment Ledger' : 'Welcome Letter');
        String fileName = label.replace(' ', '_') + '_' + b.Name + '_' + String.valueOf(endDate) + '.pdf';

        insert new ContentVersion(Title = label + ' – ' + b.Name, PathOnClient = fileName, VersionData = pdf,
            FirstPublishLocationId = r.caseId);

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        if (ctx.account.PersonContactId != null) {
            mail.setTargetObjectId(ctx.account.PersonContactId);
            mail.setWhatId(r.caseId);
            mail.setSaveAsActivity(true);
        } else {
            mail.setToAddresses(new List<String>{ recipient });
        }
        mail.setSubject('Your ' + label + ' – ' + b.Name + ' (Case ' + ctx.caseRecord.CaseNumber + ')');
        mail.setPlainTextBody('Dear ' + (String.isNotBlank(ctx.account.FirstName) ? ctx.account.FirstName : ctx.account.Name) + ',\n\n'
            + 'Please find attached the ' + label + ' for booking ' + b.Name + ' (Unit ' + b.Unit_Id__r?.Name + ')'
            + (page == 'WelcomeLetter' ? '' : ' for the period ' + ResiAgentService.fmt(startDate) + ' to ' + ResiAgentService.fmt(endDate)) + '.\n\n'
            + 'Warm regards,\nCRM Team, Nikoo Homes');
        Messaging.EmailFileAttachment att = new Messaging.EmailFileAttachment();
        att.setFileName(fileName);
        att.setContentType('application/pdf');
        att.setBody(pdf);
        mail.setFileAttachments(new List<Messaging.EmailFileAttachment>{ att });
        try {
            if (!Test.isRunningTest()) {
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
            }
            res.sent = true;
            res.message = 'The ' + label + ' for booking ' + b.Name + ' has been emailed to ' + recipient + ' and saved on the case.';
        } catch (Exception e) {
            res.message = 'The ' + label + ' was generated and saved on the case, but the email could not be sent ('
                + e.getMessage() + '). The CRM team will share it.';
        }
        return res;
    }
}