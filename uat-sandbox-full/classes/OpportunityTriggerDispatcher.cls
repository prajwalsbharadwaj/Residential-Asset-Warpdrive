public with sharing class OpportunityTriggerDispatcher extends TriggerDispatcherBase {

    // --- Configure Record Type DeveloperNames per project ---
    private static final Set<String> RESIDENTIAL_RT = new Set<String>{
        'Residential_Sales_Opportunity'
    };
    private static final Set<String> COMMERCIAL_RETAIL_RT = new Set<String>{
        'Contractual_Renewal', 'Early_Expiry', 'Expansion', 'Hard_Option', 'New', 'Renegotiation', 
        'Retail_Change_In_Legal_Entity', 'Retail_Early_Expiry', 'Retail_Opportunity', 'Retail_Term_Expiry', 'Retail_Term_Renewal', 'Retail_Renegotiation',
        'Term_Expiry', 'Term_Renewal'
    };


    // ---------------- Trigger Events ----------------
  
    public override void beforeInsert(TriggerParameters tp)  { route(tp, TriggerParameters.TriggerEvent.beforeInsert); }
    public override void afterInsert(TriggerParameters tp)   { route(tp, TriggerParameters.TriggerEvent.afterInsert);  }
    public override void beforeUpdate(TriggerParameters tp)  { route(tp, TriggerParameters.TriggerEvent.beforeUpdate); }
    public override void afterUpdate(TriggerParameters tp)   { route(tp, TriggerParameters.TriggerEvent.afterUpdate);  }
    public override void beforeDelete(TriggerParameters tp)  { route(tp, TriggerParameters.TriggerEvent.beforeDelete); }

    // ---------------- Core Router ----------------
    private void route(TriggerParameters tp, TriggerParameters.TriggerEvent ev) {
        // Determine the active working list for this phase
        List<Opportunity> work = (tp.isDelete)
            ? (List<Opportunity>) tp.oldList
            : (List<Opportunity>) tp.newList;

        if (work == null || work.isEmpty()) return;

        ensureRtCache(work, 'Opportunity');

        // Partition by project
        List<Opportunity> resList = new List<Opportunity>();
        List<Opportunity> comList = new List<Opportunity>();

        for (Opportunity o : work) {
            if (o.RecordTypeId == null) continue;
            String dev = rtDevById.get(o.RecordTypeId);
            if (dev == null) continue;

            if (RESIDENTIAL_RT.contains(dev))      resList.add(o);
            else if (COMMERCIAL_RETAIL_RT.contains(dev))  comList.add(o);
            // else unknown RT → ignore or log
        }

        // Dispatch to appropriate project handlers with FILTERED TriggerParameters
        if (!resList.isEmpty()) {
            TriggerParameters tpr = filteredByRecords(tp, resList);
            
            Type obType = Type.forName('ResOpportunityTriggerDispatcher');
            ITriggerDispatcher dispatcher = (ITriggerDispatcher)obType.newInstance();
            TriggerFactory.execute(tpr, dispatcher);
        }
        if (!comList.isEmpty()) {
            TriggerParameters tpc = filteredByRecords(tp, comList);
            Type obType = Type.forName('ComOpportunityTriggerDispatcher');
            ITriggerDispatcher dispatcher = (ITriggerDispatcher)obType.newInstance();
            TriggerFactory.execute(tpc, dispatcher);
        }
    }

}