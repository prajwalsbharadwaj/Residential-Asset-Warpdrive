/** Agent action "Check Case Classification" – the residential replacement for the broken v10 action. */
// Runs as the Einstein agent user; access is scoped by matching the case sender to the customer, not by sharing.
public without sharing class ResiAgentCheckClassification {

    public class Request {
        @InvocableVariable(required=true label='Case Id' description='Id of the email Case the agent is working on (emailCaseId).')
        public Id caseId;
    }

    public class Result {
        @InvocableVariable(label='Is Complex Case' description='true when the case must go to the CRM team instead of being answered by the agent.')
        public Boolean isComplexCase;
        @InvocableVariable(label='Classification' description='SIMPLE or COMPLEX.')
        public String classification;
        @InvocableVariable(label='Escalation Reason' description='Why the case was classified COMPLEX, if it was.')
        public String escalationReason;
    }

    @InvocableMethod(label='Check Case Classification' description='Returns whether the customer email case is COMPLEX (legal, RERA, cancellation/refund, possession delay, payment dispute, fraud, quality or ownership transfer) and must be escalated.' category='Nikoo Homes Agent')
    public static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request r : requests) {
            Case c = ResiAgentService.getCase(r.caseId);
            Result res = new Result();
            res.classification = String.isBlank(c.Case_Classification__c) ? ResiAgentService.SIMPLE : c.Case_Classification__c;
            res.isComplexCase = res.classification == ResiAgentService.COMPLEX;
            res.escalationReason = c.Escalation_Reason__c;
            results.add(res);
        }
        return results;
    }
}