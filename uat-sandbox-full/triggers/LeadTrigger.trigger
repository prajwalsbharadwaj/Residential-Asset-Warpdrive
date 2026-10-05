// Trigger for the Lead object to handle business logic via a trigger framework.
trigger LeadTrigger on Lead (before insert,after insert,before update, after update,before delete, after delete) {
    // The trigger will execute on the 'after update' event.
    // This is necessary to access the new Opportunity ID after conversion.
    TriggerFactory.createTriggerDispatcher(Lead.sObjectType);
}