public class BookingPaymentSchHelper {
    // Assign Annual Interest Rate, Grace Period Days & GST/VAT Rate by fetching from Finance Policy CMDT on Before Insert.
    public static void assignFinanceDetails(List<Booking_Payment_Schedule__c> newList) {
    try {
        if (newList == null || newList.isEmpty()) {
            return;
        }
        Set<Id> oppIds = new Set<Id>();
        for (Booking_Payment_Schedule__c bps : newList) {
            if (bps.Opportunity__c != null) oppIds.add(bps.Opportunity__c);
        }

        Map<Id, Opportunity> opMap = oppIds.isEmpty()
            ? new Map<Id, Opportunity>()
            : new Map<Id, Opportunity>([
                SELECT Id, Interested_Unit__r.Property__r.Name
                FROM Opportunity
                WHERE Id IN :oppIds
            ]);

        for (Booking_Payment_Schedule__c bps : newList) {
            Opportunity opp = opMap.get(bps.Opportunity__c);
            FinancePolicyProvider.Policy policy = FinancePolicyProvider.forOpportunity(opp);
            bps.Annual_Interest_Rate__c = policy.annualRate;
            bps.Grace_Period_Days__c = policy.graceDays;
            bps.GST_VAT_Rate_On_Interest__c = policy.taxRate;
        }
    } catch (Exception ex) {
        new ExceptionLogger.ExceptionLogPayload().withComponentName('Booking Payment Schedule before insert Trigger').withClassName('BookingPaymentSchHelper').withMethodName('assignFinanceDetails').withDescription('Assign finance details from Finance Policy CMDT dynamically').withException(ex);
    }
}
}