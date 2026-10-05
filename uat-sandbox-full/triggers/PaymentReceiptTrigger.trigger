trigger PaymentReceiptTrigger on Payment_Receipt__c (before insert, after update,after Insert, before update, after delete, before delete) {
	
     if (UtilityClass.isTriggerGloballyDisabled()) {return;}
    TriggerFactory.CreateTriggerDispatcher(Payment_Receipt__c.SObjectType);
}