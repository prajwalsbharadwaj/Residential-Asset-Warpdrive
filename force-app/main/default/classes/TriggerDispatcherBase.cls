/*
* @description This class implements the ITriggerDispatcher and acts as an adapter to avoid implementing all the 
*				ITriggerDispatcher methods.
* @return Feedback__c The newly created feedback object.
*/
public virtual class TriggerDispatcherBase implements ITriggerDispatcher { 
	
	private static ITriggerHandler beforeInserthandler;
	private static ITriggerHandler beforeUpdatehandler;
	private static ITriggerHandler beforeDeleteHandler;
	private static ITriggerHandler afterInserthandler;
	private static ITriggerHandler afterUpdatehandler;
	private static ITriggerHandler afterDeleteHandler;
	private static ITriggerHandler afterUndeleteHandler;
	
    
    // Cache: RecordTypeId -> DeveloperName for current trigger scope
    public Map<Id, String> rtDevById;
	
    /*
	* @description This method is called prior to execution of a before trigger event. If you want 
	*				to load any lookup data or cache the data, then this is the place that you need 
	*				to put your code. 
	*/
    public virtual void bulkBefore() {}

    /*
	* @description This method is called prior to execution of an after trigger event. 
	*/
    public virtual void bulkAfter() {}

    /*
	* @description This method is called for records to be inserted during a BEFORE trigger.
	*/
    public virtual void beforeInsert(TriggerParameters tp) {}

    /*
	* @description This method is called for records to be updated during a BEFORE trigger.
	*/
    public virtual void beforeUpdate(TriggerParameters tp) {}

    /*
	* @description This method is called for records to be deleted during a BEFORE trigger.
	*/
    public virtual void beforeDelete(TriggerParameters tp) {}

    /*
	* @description This method is called for records inserted during an AFTER trigger. Always put field validation 
	*				in the 'After' methods in case another trigger has modified any values. The record is 'read only' 
	*				at this point.
	*/
    public virtual void afterInsert(TriggerParameters tp) {} 

    /*
	* @description This method is called iteratively for each record updated during an AFTER trigger.
	*/
    public virtual void afterUpdate(TriggerParameters tp) {}

    /*
	* @description This method is called iteratively for each record deleted during an AFTER trigger.
	*/
    public virtual void afterDelete(TriggerParameters tp) {}
    
    /*
	* @description This method is called prior to execution of a AFTER UNDELETE trigger. 
	*/
    public virtual void afterUnDelete(TriggerParameters tp) {}
    
    public virtual void andFinally() {}
    
    /*
	* @description Called by the event handlers. If this is the first call in the context, then this method will create a new 
	*				instance of the appropriate handler and execute the mainEntry method. If there is an existing call runing 
	*				on the same context, then this method will use the existing handler instance created by the original call
	*				and execute the inProgressEntry method.
	* @param ITriggerHandler The trigger handler instance. The dispatcher need to pass an instance of the trigger handler, such
	*							as AccountAfterInsertTriggerHandler if this is the first call in a given context. If it is retry,
	*							then the dispatcher will need to pass null.
	* @param TriggerParameters The trigger parameters passed by the framework.
	* @param TriggerParameters.TriggerEvent The trigger event.
	*/
   	protected void execute(ITriggerHandler handlerInstance, TriggerParameters tp, TriggerParameters.TriggerEvent tEvent) {
    	if(handlerInstance != null) {
    		if(tEvent == TriggerParameters.TriggerEvent.beforeInsert)
    			beforeInsertHandler = handlerInstance;
    		if(tEvent == TriggerParameters.TriggerEvent.beforeUpdate)
    			beforeUpdateHandler = handlerInstance;
    		if(tEvent == TriggerParameters.TriggerEvent.beforeDelete)
    			beforeDeleteHandler = handlerInstance;
    		if(tEvent == TriggerParameters.TriggerEvent.afterInsert)
    			afterInsertHandler = handlerInstance;
    		if(tEvent == TriggerParameters.TriggerEvent.afterUpdate)
    			afterUpdateHandler = handlerInstance;
    		if(tEvent == TriggerParameters.TriggerEvent.afterDelete)
    			afterDeleteHandler = handlerInstance;
    		if(tEvent == TriggerParameters.TriggerEvent.afterUnDelete)
    			afterUndeleteHandler = handlerInstance;
    		handlerInstance.mainEntry(tp);
    		handlerInstance.updateObjects();
    	}
    	else {
    		if(tEvent == TriggerParameters.TriggerEvent.beforeInsert)
    			beforeInsertHandler.inProgressEntry(tp);
    		if(tEvent == TriggerParameters.TriggerEvent.beforeUpdate)
    			beforeUpdateHandler.inProgressEntry(tp);
    		if(tEvent == TriggerParameters.TriggerEvent.beforeDelete)
    			beforeDeleteHandler.inProgressEntry(tp);
    		if(tEvent == TriggerParameters.TriggerEvent.afterInsert)
    			afterInsertHandler.inProgressEntry(tp);
    		if(tEvent == TriggerParameters.TriggerEvent.afterUpdate)
    			afterUpdateHandler.inProgressEntry(tp);
    		if(tEvent == TriggerParameters.TriggerEvent.afterDelete)
    			afterDeleteHandler.inProgressEntry(tp);
    		if(tEvent == TriggerParameters.TriggerEvent.afterUnDelete)
    			afterUndeleteHandler.inProgressEntry(tp);
    	}
    }
    
    /** Build a new TriggerParameters using the provided sub-scope (works for before insert where Ids are null). */
    protected TriggerParameters filteredByRecords(TriggerParameters tp, List<SObject> subScope) {
        Boolean usesOld = tp.isDelete; // delete phases use old*
        List<SObject> newListF, oldListF;
        Map<Id,SObject> newMapF, oldMapF;

        if (usesOld) {
            // DELETE phases: scope is oldList
            oldListF = subScope;
            newListF = null;
        } else {
            // INSERT/UPDATE phases: scope is newList
            newListF = subScope;
            // For UPDATE, also filter oldList to matching records (by Ids which exist on update)
            oldListF = (tp.isUpdate && tp.oldList != null)
                     ? filterOldForUpdateByIds(tp.oldList, subScope)
                     : null;
        }

        // Maps only where Ids exist & original maps provided by the platform
        newMapF = (tp.newMap != null && newListF != null) ? mapFromList(newListF) : null;
        oldMapF = (tp.oldMap != null && oldListF != null) ? mapFromList(oldListF) : null;

        return new TriggerParameters(
            oldListF, newListF, oldMapF, newMapF,
            tp.isBefore, tp.isAfter, tp.isDelete,
            tp.isInsert, tp.isUpdate, tp.isUnDelete, tp.isExecuting
        );
    }
    
    /** For UPDATE, build the oldList subset by Id match. (Ids exist on update.) */
    protected List<SObject> filterOldForUpdateByIds(List<SObject> oldSide, List<SObject> newSubScope) {
        Set<Id> ids = new Set<Id>();
        for (SObject o : newSubScope) if (o.Id != null) ids.add(o.Id);
        if (ids.isEmpty()) return null;

        List<SObject> out = new List<SObject>();
        for (SObject s : oldSide) {
            Id sid = (Id) s.get('Id');
            if (sid != null && ids.contains(sid)) out.add(s);
        }
        return out.isEmpty() ? null : out;
    }
    
    protected Map<Id,SObject> mapFromList(List<SObject> lst) {
        Map<Id,SObject> m = new Map<Id,SObject>();
        for (SObject s : lst) {
            Id sid = (Id) s.get('Id');
            if (sid != null) m.put(sid, s);
        }
        return m.isEmpty() ? null : m;
    }
    
    /** Populate rtDevById for the current scope only once per transaction. */
    protected void ensureRtCache(List<SObject> scope, String sObjectApiName) {
        if (rtDevById != null) return;
        
        rtDevById = new Map<Id, String>();
        Map<String, Schema.RecordTypeInfo> recordTypeInfoByDevName = Schema.getGlobalDescribe().get(sObjectApiName).getDescribe().getRecordTypeInfosByDeveloperName();
        for(String devName : recordTypeInfoByDevName.keySet()){
            rtDevById.put(recordTypeInfoByDevName.get(devName).getRecordTypeId(), devName);
        }
        
                
           
    }
}