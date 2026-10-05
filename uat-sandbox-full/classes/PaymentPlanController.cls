public with sharing class PaymentPlanController {
    @AuraEnabled(cacheable=true)
    public static List<Payment_Plan__c> searchPaymentPlans(String searchTerm) {
        return [
            SELECT Id, Name, Description__c, Active__c, Use_in_Quotation__c,No_Of_Installments__c
            FROM Payment_Plan__c
            WHERE Active__c = true
              AND Use_in_Quotation__c = true
              AND Name LIKE :('%' + searchTerm + '%')
            LIMIT 50
        ];
    }

    /**
     * @description Fetches the associated Unit__c ID from an Opportunity record.
     * This method is called by the LWC component when a user clicks the button on an Opportunity.
     * @param opportunityId The ID of the Opportunity record.
     * @return The ID of the linked Unit__c record, or null if not found.
     */
    @AuraEnabled(cacheable=true)
    public static Id getUnitIdFromOpportunity(Id opportunityId) {
        try {
            // Assuming the lookup field on Opportunity is named 'Interested_Unit__c'.
            Opportunity opp = [SELECT Id, Interested_Unit__c FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
            return opp.Interested_Unit__c;
        } catch (Exception e) {
            System.debug('Error in getUnitIdFromOpportunity: ' + e.getMessage());
            return null;
        }
    }
}