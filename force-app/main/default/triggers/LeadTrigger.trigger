trigger LeadTrigger on Lead(before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    TriggerFactory.createTriggerDispatcher(Lead.sObjectType);
}
