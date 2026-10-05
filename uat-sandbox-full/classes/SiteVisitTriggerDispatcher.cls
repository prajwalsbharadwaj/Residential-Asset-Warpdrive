public class SiteVisitTriggerDispatcher extends TriggerDispatcherBase {

    
    
    
    // --- Configure Record Type DeveloperNames per project ---
    private static final Set<String> RESIDENTIAL_RT = new Set<String>{
        'Residential_Sales_Site_Visit'
    };
    private static final Set<String> COMMERCIAL_RETAIL_RT = new Set<String>{
        'Site_Visit_Commercial'
    };

    // ---------------- Trigger Events ----------------
  
    public override void beforeUpdate(TriggerParameters tp)  { route(tp, TriggerParameters.TriggerEvent.beforeUpdate); }
    public override void afterUpdate(TriggerParameters tp)   { route(tp, TriggerParameters.TriggerEvent.afterUpdate);  }
    public override void afterInsert(TriggerParameters tp)   { route(tp, TriggerParameters.TriggerEvent.afterInsert);  }
    // ---------------- Core Router ----------------
    private void route(TriggerParameters tp, TriggerParameters.TriggerEvent ev) {
        // Determine the active working list for this phase
        List<Site_Visit__c> work = (tp.isDelete) ? (List<Site_Visit__c>) tp.oldList : (List<Site_Visit__c>) tp.newList;

        if (work == null || work.isEmpty()) return;

        ensureRtCache(work, 'Site_Visit__c');

        // Partition by project
        List<Site_Visit__c> resList = new List<Site_Visit__c>();
        List<Site_Visit__c> comList = new List<Site_Visit__c>();

        for (Site_Visit__c o : work) {
            System.debug(o.Id);
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
            
            Type obType = Type.forName('ResSiteVisitTriggerDispatcher');
            ITriggerDispatcher dispatcher = (ITriggerDispatcher)obType.newInstance();
            TriggerFactory.execute(tpr, dispatcher);
        }
        /*if (!comList.isEmpty()) {
            TriggerParameters tpc = filteredByRecords(tp, comList);
            Type obType = Type.forName('ComSiteVisitTriggerDispatcher');
            ITriggerDispatcher dispatcher = (ITriggerDispatcher)obType.newInstance();
            TriggerFactory.execute(tpc, dispatcher);
        }*/
    }
}