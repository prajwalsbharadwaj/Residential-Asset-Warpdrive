public class ResSiteVisitTriggerDispatcher extends TriggerDispatcherBase {
	private static Boolean isAfterInsertProcessing = false;
    
    /** 
	* @description Called by the trigger framework to carry out the actions after the record(s) are created. If there is an
	*				existing call running on the same context, the rentrant call will utilize the handler that was created
	*				in the original call.
	* @param TriggerParameters Contains the trigger parameters which includes the record(s) that got created.
	*/
	public virtual override void afterInsert(TriggerParameters tp) {
		if(!isAfterInsertProcessing) {
			isAfterInsertProcessing = true;
			execute(new SiteVisitAfterInsertTriggerHandler(), tp, TriggerParameters.TriggerEvent.afterInsert);
			isAfterInsertProcessing = false;
		}
		else execute(null, tp, TriggerParameters.TriggerEvent.afterInsert);
	}
}