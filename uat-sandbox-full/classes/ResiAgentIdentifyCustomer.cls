/** Agent action "Identify Customer By Email" – matches the sender to a Nikoo Homes customer and links the case. */
// Runs as the Einstein agent user; access is scoped by matching the case sender to the customer, not by sharing.
public without sharing class ResiAgentIdentifyCustomer {

    public class Request {
        @InvocableVariable(required=true label='Case Id' description='Id of the email Case (emailCaseId).')
        public Id caseId;
    }

    public class Result {
        @InvocableVariable(label='Customer Found' description='true when the sender email belongs to a registered customer.')
        public Boolean customerFound;
        @InvocableVariable(label='Customer Name' description='Name to address the customer by.')
        public String customerName;
        @InvocableVariable(label='Customer Email' description='The sender email address the case came from.')
        public String customerEmail;
        @InvocableVariable(label='Booking Count' description='Number of bookings (as primary applicant or co-applicant).')
        public Integer bookingCount;
        @InvocableVariable(label='Relationship Manager' description='Name of the CRM executive who owns this customer.')
        public String relationshipManager;
    }

    @InvocableMethod(label='Identify Customer By Email' description='Finds the Nikoo Homes customer whose registered email matches the email case sender, links the case to them and returns their name and number of bookings.' category='Nikoo Homes Agent')
    public static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request r : requests) {
            ResiAgentService.CustomerContext ctx = ResiAgentService.resolveCustomer(r.caseId);
            Result res = new Result();
            res.customerFound = ctx.found;
            res.customerEmail = ctx.email;
            if (ctx.found) {
                ResiAgentService.linkCase(ctx);
                res.customerName = String.isNotBlank(ctx.account.FirstName) ? ctx.account.FirstName : ctx.account.Name;
                res.bookingCount = ResiAgentService.bookingsFor(ctx.account.Id).size();
                res.relationshipManager = ctx.account.Owner.Name;
            } else {
                res.bookingCount = 0;
            }
            results.add(res);
        }
        return results;
    }
}