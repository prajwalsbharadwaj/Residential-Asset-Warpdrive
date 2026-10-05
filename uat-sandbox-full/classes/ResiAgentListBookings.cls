/** Agent action "Get Customer Bookings" – the residential equivalent of v10's Fetch Account Orders. */
// Runs as the Einstein agent user; access is scoped by matching the case sender to the customer, not by sharing.
public without sharing class ResiAgentListBookings {

    public class Request {
        @InvocableVariable(required=true label='Case Id' description='Id of the email Case (emailCaseId).')
        public Id caseId;
    }

    public class Result {
        @InvocableVariable(label='Customer Found' description='false when the sender is not a registered customer.')
        public Boolean customerFound;
        @InvocableVariable(label='Booking Count' description='Number of bookings found.')
        public Integer bookingCount;
        @InvocableVariable(label='Bookings' description='One line per booking: booking number, unit, configuration, project, building and status.')
        public String bookings;
    }

    @InvocableMethod(label='Get Customer Bookings' description='Lists every booking of the customer who sent the email case, with booking number, unit number, project and booking status, so the customer can pick one.' category='Nikoo Homes Agent')
    public static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request r : requests) {
            ResiAgentService.CustomerContext ctx = ResiAgentService.resolveCustomer(r.caseId);
            Result res = new Result();
            res.customerFound = ctx.found;
            res.bookingCount = 0;
            if (ctx.found) {
                List<String> lines = new List<String>();
                for (Booking__c b : ResiAgentService.bookingsFor(ctx.account.Id)) {
                    lines.add('- ' + ResiAgentService.bookingLine(b));
                }
                res.bookingCount = lines.size();
                res.bookings = lines.isEmpty() ? 'No bookings found for this customer.' : String.join(lines, '\n');
            }
            results.add(res);
        }
        return results;
    }
}