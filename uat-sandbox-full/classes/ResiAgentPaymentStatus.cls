/**
 * Agent action "Get Payment Status" – the residential equivalent of v10's Refund Status.
 * Dues come from Booking Payment Schedules; approved receipts tagged to an instalment count as paid
 * even when the ledger has not allocated them yet (same rule as the glass Account page).
 */
// Runs as the Einstein agent user; access is scoped by matching the case sender to the customer, not by sharing.
public without sharing class ResiAgentPaymentStatus {

    public class Request {
        @InvocableVariable(required=true label='Case Id' description='Id of the email Case (emailCaseId).')
        public Id caseId;
        @InvocableVariable(label='Booking Reference' description='Booking number or unit number. Leave blank to cover all of the customer\'s bookings.')
        public String bookingReference;
    }

    public class Result {
        @InvocableVariable(label='Found' description='true when payment information was returned.')
        public Boolean found;
        @InvocableVariable(label='Has Overdue' description='true when at least one instalment is past its due date and unpaid.')
        public Boolean hasOverdue;
        @InvocableVariable(label='Payment Status' description='Per booking: agreement value, paid to date, outstanding, overdue instalments with interest, next instalment, recent receipts and receipts pending approval.')
        public String paymentStatus;
    }

    @InvocableMethod(label='Get Payment Status' description='Returns the payment position of the customer\'s booking(s): amount paid, outstanding balance, overdue instalments and interest, the next instalment due and recent receipts. Only for bookings owned by the email sender.' category='Nikoo Homes Agent')
    public static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request r : requests) {
            Result res = new Result();
            res.found = false;
            res.hasOverdue = false;
            ResiAgentService.CustomerContext ctx = ResiAgentService.resolveCustomer(r.caseId);
            if (!ctx.found) {
                res.paymentStatus = 'The sender is not a registered customer.';
                results.add(res);
                continue;
            }
            List<Booking__c> bookings = ResiAgentService.bookingsFor(ctx.account.Id);
            if (String.isNotBlank(r.bookingReference)) {
                Booking__c one = ResiAgentService.pickBooking(bookings, r.bookingReference);
                bookings = one == null ? new List<Booking__c>() : new List<Booking__c>{ one };
            }
            if (bookings.isEmpty()) {
                res.paymentStatus = String.isBlank(r.bookingReference)
                    ? 'This customer has no bookings.'
                    : 'No booking matching "' + r.bookingReference + '" belongs to this customer.';
                results.add(res);
                continue;
            }
            List<String> blocks = new List<String>();
            for (Booking__c b : bookings) {
                Summary s = summarise(b);
                res.hasOverdue = res.hasOverdue || s.overdue;
                blocks.add(s.text);
            }
            res.found = true;
            res.paymentStatus = String.join(blocks, '\n\n');
            results.add(res);
        }
        return results;
    }

    private class Summary {
        String text;
        Boolean overdue = false;
    }

    private static Summary summarise(Booking__c b) {
        Summary out = new Summary();
        Date today = Date.today();

        Map<Id, Decimal> approvedBySchedule = new Map<Id, Decimal>();
        Decimal pending = 0;
        List<String> recent = new List<String>();
        for (Payment_Receipt__c pr : [
            SELECT Name, Amount_Paid__c, Date_Of_Payment__c, Mode_Of_Payment__c, Approval_Status__c, Booking_Payment_Schedule__c
            FROM Payment_Receipt__c
            WHERE Booking_Payment_Schedule__r.Booking__c = :b.Id AND Approval_Status__c != 'Rejected'
            ORDER BY Date_Of_Payment__c DESC NULLS LAST
        ]) {
            Decimal amt = ResiAgentService.nz(pr.Amount_Paid__c);
            if (pr.Approval_Status__c == 'Approved') {
                Decimal prior = approvedBySchedule.containsKey(pr.Booking_Payment_Schedule__c) ? approvedBySchedule.get(pr.Booking_Payment_Schedule__c) : 0;
                approvedBySchedule.put(pr.Booking_Payment_Schedule__c, prior + amt);
            } else {
                pending += amt;
            }
            if (recent.size() < 3) {
                recent.add(pr.Name + ': ' + ResiAgentService.inr(amt) + ' on ' + ResiAgentService.fmt(pr.Date_Of_Payment__c)
                    + (String.isBlank(pr.Mode_Of_Payment__c) ? '' : ' by ' + pr.Mode_Of_Payment__c)
                    + (pr.Approval_Status__c == 'Approved' ? '' : ' (under verification)'));
            }
        }

        Decimal paid = 0;
        Decimal outstanding = 0;
        List<String> overdueLines = new List<String>();
        String nextLine;
        for (Booking_Payment_Schedule__c s : [
            SELECT Id, Name, Milestone_Code__c, Installment_Number__c, Payment_Due_Date__c, Installment_Amount__c,
                   Outstanding_Principal__c, TotalInterestOutstandingnet__c
            FROM Booking_Payment_Schedule__c
            WHERE Booking__c = :b.Id
            ORDER BY Payment_Due_Date__c ASC NULLS LAST
        ]) {
            Decimal amount = ResiAgentService.nz(s.Installment_Amount__c);
            Decimal ledgerOut = s.Outstanding_Principal__c == null ? amount : s.Outstanding_Principal__c;
            Decimal receiptOut = amount - (approvedBySchedule.containsKey(s.Id) ? approvedBySchedule.get(s.Id) : 0);
            Decimal due = Math.max(0, Math.min(ledgerOut, receiptOut));
            paid += amount - due;
            outstanding += due;
            if (due <= 0) {
                continue;
            }
            String label = String.isNotBlank(s.Milestone_Code__c) && s.Milestone_Code__c != 'Other Charges'
                ? s.Milestone_Code__c
                : 'Instalment ' + (s.Installment_Number__c == null ? s.Name : String.valueOf(s.Installment_Number__c.intValue()));
            if (s.Payment_Due_Date__c != null && s.Payment_Due_Date__c < today) {
                out.overdue = true;
                Decimal interest = ResiAgentService.nz(s.TotalInterestOutstandingnet__c);
                overdueLines.add(label + ': ' + ResiAgentService.inr(due) + ' was due on ' + ResiAgentService.fmt(s.Payment_Due_Date__c)
                    + ' (' + s.Payment_Due_Date__c.daysBetween(today) + ' days overdue'
                    + (interest > 0 ? ', delayed-payment interest so far ' + ResiAgentService.inr(interest) : '') + ')');
            } else if (nextLine == null) {
                nextLine = label + ': ' + ResiAgentService.inr(due) + ' due on ' + ResiAgentService.fmt(s.Payment_Due_Date__c);
            }
        }

        List<String> lines = new List<String>{
            'Booking ' + b.Name + ' – Unit ' + b.Unit_Id__r?.Name + ', ' + b.Project__r?.Name,
            'Agreement value: ' + ResiAgentService.inr(b.Final_Amount__c),
            'Paid to date: ' + ResiAgentService.inr(paid),
            'Outstanding balance: ' + ResiAgentService.inr(outstanding)
        };
        lines.add(overdueLines.isEmpty() ? 'Overdue: none – all instalments due so far are paid.' : 'Overdue:\n  - ' + String.join(overdueLines, '\n  - '));
        lines.add('Next instalment: ' + (nextLine == null ? 'none scheduled' : nextLine));
        if (pending > 0) {
            lines.add('Payments under verification: ' + ResiAgentService.inr(pending) + ' (receipt is issued once finance approves it)');
        }
        if (!recent.isEmpty()) {
            lines.add('Recent payments:\n  - ' + String.join(recent, '\n  - '));
        }
        out.text = String.join(lines, '\n');
        return out;
    }
}