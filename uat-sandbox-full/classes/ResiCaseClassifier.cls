/**
 * Keyword classifier for inbound email cases (run from CaseClassificationTrigger).
 * Anything legal, financial-dispute or policy-exception flavoured is COMPLEX so the email agent
 * hands it to the CRM team instead of answering. Never downgrades a COMPLEX case.
 */
public with sharing class ResiCaseClassifier {

    // Checked in order; the first reason with a matching phrase wins.
    private static final List<String> ORDER = new List<String>{
        'Fraud or unauthorised transaction', 'Legal or RERA complaint', 'Cancellation or refund',
        'Possession delay or compensation', 'Payment dispute', 'Ownership transfer', 'Construction quality'
    };
    private static final Map<String, List<String>> KEYWORDS = new Map<String, List<String>>{
        'Fraud or unauthorised transaction' => new List<String>{ 'fraud', 'scam', 'unauthorised', 'unauthorized', 'cheated', 'cyber crime', 'phishing', 'fake receipt' },
        'Legal or RERA complaint' => new List<String>{ 'legal notice', 'lawyer', 'advocate', ' court', 'rera', 'consumer forum', 'litigation', 'police', ' fir ', 'legal action' },
        'Cancellation or refund' => new List<String>{ 'cancel', 'refund', 'withdraw my booking', 'exit the booking', 'money back', 'return my money' },
        'Possession delay or compensation' => new List<String>{ 'compensation', 'possession delay', 'delay in possession', 'delayed possession', 'delay penalty', 'penalty for delay' },
        'Payment dispute' => new List<String>{ 'wrong demand', 'incorrect demand', 'excess charge', 'double charged', 'overcharged', 'dispute', 'waive', 'waiver' },
        'Ownership transfer' => new List<String>{ 'ownership transfer', 'transfer ownership', 'transfer the unit', 'resale', 'add co-applicant', 'remove co-applicant', 'nominee' },
        'Construction quality' => new List<String>{ 'leakage', 'seepage', 'crack', 'poor quality', 'defect', 'snag' }
    };

    public static void classify(List<Case> cases) {
        for (Case c : cases) {
            if (c.Case_Classification__c == ResiAgentService.COMPLEX) {
                continue;
            }
            Boolean isEmail = c.Origin == 'Email' || String.isNotBlank(c.SuppliedEmail);
            String reason = isEmail ? detect(c.Subject + ' ' + c.Description) : null;
            if (reason != null) {
                c.Case_Classification__c = ResiAgentService.COMPLEX;
                c.Escalation_Reason__c = reason;
            } else if (isEmail && String.isBlank(c.Case_Classification__c)) {
                c.Case_Classification__c = ResiAgentService.SIMPLE;
            }
        }
    }

    public static String detect(String text) {
        if (String.isBlank(text)) {
            return null;
        }
        String t = ' ' + text.toLowerCase() + ' ';
        for (String reason : ORDER) {
            for (String k : KEYWORDS.get(reason)) {
                if (t.contains(k)) {
                    return reason;
                }
            }
        }
        return null;
    }
}