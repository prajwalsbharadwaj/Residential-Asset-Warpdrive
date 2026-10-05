/** Agent action "Get Booking Details" – the residential equivalent of v10's Fetch Increff Order Details. */
// Runs as the Einstein agent user; access is scoped by matching the case sender to the customer, not by sharing.
public without sharing class ResiAgentBookingDetails {

    public class Request {
        @InvocableVariable(required=true label='Case Id' description='Id of the email Case (emailCaseId).')
        public Id caseId;
        @InvocableVariable(label='Booking Reference' description='Booking number (e.g. BO-00000013) or unit number (e.g. SS-SK1-700) the customer mentioned. Optional when the customer has only one booking.')
        public String bookingReference;
    }

    public class Result {
        @InvocableVariable(label='Found' description='true when a booking belonging to this customer was matched.')
        public Boolean found;
        @InvocableVariable(label='Needs Booking Reference' description='true when the customer has several bookings and did not say which one; ask them to choose.')
        public Boolean needsBookingReference;
        @InvocableVariable(label='Booking Details' description='Unit, project, booking status, agreement and allotment status, payment plan, funding and possession date.')
        public String details;
    }

    @InvocableMethod(label='Get Booking Details' description='Returns the details of one booking (unit, project, status, agreement, allotment, payment plan, home loan and possession date) after verifying it belongs to the customer who sent the email.' category='Nikoo Homes Agent')
    public static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request r : requests) {
            Result res = new Result();
            res.found = false;
            res.needsBookingReference = false;
            ResiAgentService.CustomerContext ctx = ResiAgentService.resolveCustomer(r.caseId);
            if (!ctx.found) {
                res.details = 'The sender is not a registered customer.';
                results.add(res);
                continue;
            }
            List<Booking__c> bookings = ResiAgentService.bookingsFor(ctx.account.Id);
            Booking__c b = ResiAgentService.pickBooking(bookings, r.bookingReference);
            if (b == null) {
                res.needsBookingReference = bookings.size() > 1 && String.isBlank(r.bookingReference);
                res.details = bookings.isEmpty()
                    ? 'This customer has no bookings.'
                    : 'No booking matching "' + r.bookingReference + '" belongs to this customer.';
                results.add(res);
                continue;
            }
            res.found = true;
            res.details = describe(b, ctx.account.Id);
            results.add(res);
        }
        return results;
    }

    private static String describe(Booking__c b, Id accountId) {
        List<String> lines = new List<String>{
            'Booking: ' + b.Name + (b.Account_Id__c == accountId ? ' (primary applicant)' : ' (co-applicant)'),
            'Unit: ' + b.Unit_Id__r?.Name + ' – ' + ResiAgentService.join(new List<String>{
                b.Unit_Id__r?.BHK_Configuration__c,
                b.Unit_Id__r?.Saleable_Area__c == null ? null : b.Unit_Id__r.Saleable_Area__c.setScale(0) + ' sq ft saleable',
                b.Unit_Id__r?.Carpet_Area__c == null ? null : b.Unit_Id__r.Carpet_Area__c.setScale(0) + ' sq ft carpet'
            }, ', '),
            'Location: ' + ResiAgentService.join(new List<String>{
                b.Project__r?.Name, b.Unit_Id__r?.Tower__r?.Name, b.Unit_Id__r?.Floor__r?.Name == null ? null : 'Floor ' + b.Unit_Id__r.Floor__r.Name
            }, ', '),
            'Booking status: ' + b.Status__c,
            'Booking date: ' + ResiAgentService.fmt(b.Booking_Date__c != null ? b.Booking_Date__c : b.CreatedDate.date()),
            'Agreement value: ' + ResiAgentService.inr(b.Final_Amount__c),
            'Payment plan: ' + (b.Payment_Plan_Id__r == null ? 'not linked yet' : b.Payment_Plan_Id__r.Name),
            'Allotment letter: ' + (b.Allotment_Shared__c == true ? 'shared on ' + ResiAgentService.fmt(b.Allotment_Letter_Date__c) : 'not issued yet'),
            'Sale agreement: ' + (b.Is_Agreement_Signed__c == true
                ? 'signed' + (b.Agreement_Executed_Date__c == null ? '' : ' on ' + ResiAgentService.fmt(b.Agreement_Executed_Date__c))
                : 'not signed yet'),
            'Agreement registration: ' + (b.Agreement_Registered_Date__c == null ? 'pending' : 'registered on ' + ResiAgentService.fmt(b.Agreement_Registered_Date__c)),
            'Funding: ' + (b.Funding_Method__c == 'Loan-Availed'
                ? 'home loan from ' + b.HomeLoanBank__c + (b.Loan_Sanctioned_Amount__c == null ? '' : ', sanctioned ' + ResiAgentService.inr(b.Loan_Sanctioned_Amount__c))
                : (String.isBlank(b.Funding_Method__c) ? 'not specified' : b.Funding_Method__c)),
            'Expected possession: ' + ResiAgentService.fmt(b.Possession_Date__c)
        };
        if (b.Ownership_Transfer_In_Progress__c == true) {
            lines.add('Note: an ownership transfer is in progress for this booking – handled by the CRM team.');
        }
        return String.join(lines, '\n');
    }
}