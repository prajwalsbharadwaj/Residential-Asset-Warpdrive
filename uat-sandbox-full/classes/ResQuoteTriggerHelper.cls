public class ResQuoteTriggerHelper {
   
    public static void markPrimaryQuote(List<Quote> newList) {
        Set<Id> oppIds = new Set<Id>();

        for (Quote q : newList) {
            if (q.OpportunityId != null) {
                oppIds.add(q.OpportunityId);
            }
        }

        if (oppIds.isEmpty()) return;

        // Fetch existing quotes for these opportunities (excluding the new ones to avoid double update)
        List<Quote> existingQuotes = [SELECT Id, Primary__c, OpportunityId FROM Quote WHERE OpportunityId IN :oppIds AND Id NOT IN :newList];

        List<Quote> updateExistingQuote = new List<Quote>();

        // Set all existing quotes to false
        for (Quote q : existingQuotes) {
            if (q.Primary__c) {
                q.Primary__c = false;
                updateExistingQuote.add(q);
            }
        }

        // Set all new quotes to true
        for (Quote newQ : newList) {
            if (newQ.OpportunityId != null && newQ.Primary__c != true) {
                newQ.Primary__c = true;
            }
        }

        if (!updateExistingQuote.isEmpty()) {
            update updateExistingQuote;
        }
    }
}