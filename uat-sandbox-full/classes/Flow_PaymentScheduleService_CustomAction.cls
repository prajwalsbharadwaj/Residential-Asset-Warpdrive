public with sharing class Flow_PaymentScheduleService_CustomAction {

        // ----------------------------
        // Invocable input + output
        // ----------------------------
        public class Request {
            @InvocableVariable(label='Opportunity Id' description='Opportunity record Id (used before Booking is created)' required=true)
            public Id opportunityId;
        
            @InvocableVariable(label='Booking Id' description='Booking record Id (used once Booking is created)' required=false)
            public Id bookingId;
        
            @InvocableVariable(label='Payment Plan Changed?' description='True if Payment Plan is updated and schedules need regeneration' required=true)
            public Boolean paymentPlanChanged;
        
            @InvocableVariable(label='Amount Changed?' description='True if pricing or charges are updated and installment amounts must be recalculated' required=true)
            public Boolean amountChanged;
        
            @InvocableVariable(label='Recalculate Due Dates?' description='True if BPS due dates should be recalculated' required=true)
            public Boolean recalcDueDates;
        }

    public class Response {
        @InvocableVariable(label='Status') public String status;
        @InvocableVariable(label='Message') public String message;
        @InvocableVariable(label='Created/Updated Record Ids') public List<Id> createdRecordIds;
    }

    @InvocableMethod(label='Process Booking Payment Schedule')
    public static List<Response> process(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null || requests.isEmpty()) return responses;

        Set<Id> oppIds = new Set<Id>();
        Set<Id> bookingIds = new Set<Id>();
        for (Request r : requests) { 
            if (r.opportunityId != null) oppIds.add(r.opportunityId); 
            if (r.bookingId != null) bookingIds.add(r.bookingId); 
        }
        // Query bookings
        Map<Id, Booking__c> bookingMap = new Map<Id, Booking__c>();
        if (!bookingIds.isEmpty()) {
            for (Booking__c b : [SELECT Id, Booking_Date__c, Opportunity_Id__c FROM Booking__c WHERE Id IN :bookingIds]) {
                bookingMap.put(b.Id, b);
            }
        }
        // Query opportunities
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
        if (!oppIds.isEmpty()) {
            for (Opportunity o : [SELECT Id, BaseCostAfterDiscount__c, TaxOnConstructionCost__c, Tax_on_Land_Cost__c,
                                         Token_Amount__c, OtherCharges__c, TaxOnOtherCharges__c, Payment_Plan__c, CloseDate
                                  FROM Opportunity WHERE Id IN :oppIds]) {
                oppMap.put(o.Id, o);
            }
        }
       // Collect plan schedules
        Set<Id> planIds = new Set<Id>();
        for (Opportunity o : oppMap.values()) if (o.Payment_Plan__c != null) planIds.add(o.Payment_Plan__c);

        Map<Id, List<Payment_Schedule__c>> planSchedulesMap = new Map<Id, List<Payment_Schedule__c>>();
        if (!planIds.isEmpty()) {
            for (Payment_Schedule__c ps : [SELECT Id, Payment_Plan_Id__c, Installment_Number__c, Payment_Percentage__c, Due_In_Days__c, Month_Number__c, Milestone_Code__c
                                           FROM Payment_Schedule__c WHERE Payment_Plan_Id__c IN :planIds ORDER BY Installment_Number__c ASC]) {
                if (!planSchedulesMap.containsKey(ps.Payment_Plan_Id__c)) planSchedulesMap.put(ps.Payment_Plan_Id__c, new List<Payment_Schedule__c>());
                planSchedulesMap.get(ps.Payment_Plan_Id__c).add(ps);
            }
        }
        // Existing BPS
        Map<Id, List<Booking_Payment_Schedule__c>> bpsByOpp = new Map<Id, List<Booking_Payment_Schedule__c>>();
        if (!oppMap.isEmpty()) {
            for (Booking_Payment_Schedule__c bps : [SELECT Id, Opportunity__c, Booking__c, Payment_Schedule_Id__c, Installment_Number__c, Installment_Amount__c, Is_Token_Amount__c, Payment_Due_Date__c
                                                    FROM Booking_Payment_Schedule__c WHERE Opportunity__c IN :oppMap.keySet() ORDER BY Installment_Number__c ASC]) {
                if (!bpsByOpp.containsKey(bps.Opportunity__c)) bpsByOpp.put(bps.Opportunity__c, new List<Booking_Payment_Schedule__c>());
                bpsByOpp.get(bps.Opportunity__c).add(bps);
            }
        }
       // DML buckets
        List<Booking_Payment_Schedule__c> toInsert = new List<Booking_Payment_Schedule__c>();
        List<Booking_Payment_Schedule__c> toUpdate = new List<Booking_Payment_Schedule__c>();
        List<Booking_Payment_Schedule__c> toDelete = new List<Booking_Payment_Schedule__c>();

        for (Request req : requests) {
            Response r = new Response(); 
            try {
                // Resolve Opportunity & Booking
                Opportunity opp = (req.opportunityId != null) ? oppMap.get(req.opportunityId) : null;
                Booking__c bk = (req.bookingId != null) ? bookingMap.get(req.bookingId) : null;
                if (opp == null && bk != null) opp = oppMap.get(bk.Opportunity_Id__c);
                if (opp == null) throw new AuraHandledException('Opportunity not found.');
                // REQUIREMENT: anchorDate is STRICTLY Booking_Date__c.
                Date anchorDate = (bk != null && bk.Booking_Date__c != null) ? bk.Booking_Date__c : null;

                List<Booking_Payment_Schedule__c> currentBps = bpsByOpp.containsKey(opp.Id) ? bpsByOpp.get(opp.Id) : new List<Booking_Payment_Schedule__c>();
                List<Payment_Schedule__c> planSchedules = (opp.Payment_Plan__c != null) ? planSchedulesMap.get(opp.Payment_Plan__c) : new List<Payment_Schedule__c>();
                // --- BRANCH 1: INITIAL CREATION / REGISTRATION ---
                if (req.paymentPlanChanged) {
                    toDelete.addAll(currentBps); 
                    if (!planSchedules.isEmpty()) toInsert.addAll(buildBpsFromPlan(opp, anchorDate, bk != null ? bk.Id : null, planSchedules, req.recalcDueDates));
                }
                // --- BRANCH 2: MONEY AND DATE RECALCULATION (SEGREGATED) ---
                else if ((req.amountChanged || req.recalcDueDates) && !currentBps.isEmpty()) {
                    Map<Id, Payment_Schedule__c> planByIdMap = new Map<Id, Payment_Schedule__c>();
                    for (Payment_Schedule__c ps : planSchedules) planByIdMap.put(ps.Id, ps);

                    // UPDATED CALCULATION: Subtract Token from base so total sum remains correct (Balanced Math)
                    Decimal basePayable = safeDec(opp.BaseCostAfterDiscount__c) + safeDec(opp.TaxOnConstructionCost__c) + safeDec(opp.Tax_on_Land_Cost__c) - safeDec(opp.Token_Amount__c);
                    Decimal finalExtra = safeDec(opp.OtherCharges__c) + safeDec(opp.TaxOnOtherCharges__c);
                    
                    Decimal maxPlanNum = 0;
                    Booking_Payment_Schedule__c extraRecord = null;
                    Date possessionDate = null; 

                    for (Booking_Payment_Schedule__c bps : currentBps) {
                        Integer instNum = (bps.Installment_Number__c != null) ? Integer.valueOf(bps.Installment_Number__c) : null;
                        if (instNum == null || instNum == 0) continue;

                        // Identify the dynamic "Other Charges" record
                        if (bps.Payment_Schedule_Id__c == null && bps.Is_Token_Amount__c == false) {
                            extraRecord = bps;
                            continue; // Skip standard math for this record
                        }
                        if (instNum > maxPlanNum) maxPlanNum = instNum;

                        if (bps.Payment_Schedule_Id__c != null && planByIdMap.containsKey(bps.Payment_Schedule_Id__c)) {
                            Payment_Schedule__c ps = planByIdMap.get(bps.Payment_Schedule_Id__c);
                            // SUB-LOGIC: Handle Amount Changes
                            if(req.amountChanged) {
                                Decimal amt = basePayable * (safeDec(ps.Payment_Percentage__c) / 100);
                                // ADD Token only to Row 1
                                if (instNum == 1 && opp.Token_Amount__c>0) { 
                                    amt += safeDec(opp.Token_Amount__c); 
                                    bps.Is_Token_Amount__c = true; 
                                }
                                bps.Installment_Amount__c = amt.setScale(2);
                            }

                            if (req.recalcDueDates) {
                                if (anchorDate != null) {
                                    if (ps.Due_In_Days__c != null) bps.Payment_Due_Date__c = anchorDate.addDays((Integer) ps.Due_In_Days__c);
                                    else if (ps.Month_Number__c != null) bps.Payment_Due_Date__c = anchorDate.addMonths((Integer) ps.Month_Number__c);
                                } else {
                                    bps.Payment_Due_Date__c = null; // Override Trigger defaults if no Booking exists
                                }
                            }
                            
                            if (ps.Milestone_Code__c == 'On Possession') possessionDate = bps.Payment_Due_Date__c;
                            if (bk != null) bps.Booking__c = bk.Id;
                            toUpdate.add(bps);
                        }
                    }
                   // Handle the dynamic extra record update
                    if (finalExtra > 0) {
                        if (extraRecord != null) {
                            if(req.amountChanged) extraRecord.Installment_Amount__c = finalExtra.setScale(2);
                            extraRecord.Installment_Number__c = maxPlanNum + 1;
                            if(req.recalcDueDates) extraRecord.Payment_Due_Date__c = possessionDate;
                            toUpdate.add(extraRecord);
                        } else {
                            toInsert.add(new Booking_Payment_Schedule__c(
                                Opportunity__c = opp.Id, Booking__c = (bk != null ? bk.Id : null),
                                Installment_Amount__c = finalExtra.setScale(2), Installment_Number__c = maxPlanNum + 1,
                                Is_Token_Amount__c = false, Payment_Due_Date__c = (req.recalcDueDates ? possessionDate : null)
                            ));
                        }
                    } else if (extraRecord != null) { toDelete.add(extraRecord); }
                }
                r.status = 'SUCCESS';
            } catch (Exception ex) {
                r.status = 'FAILED'; r.message = ex.getMessage();
            }
            responses.add(r);
        }

        // Bulk DML
        try { if (!toDelete.isEmpty()) delete toDelete; } catch (DmlException de) { for (Response r : responses) { r.status='FAILED'; r.message='Delete failed: '+de.getMessage(); } return responses; }
        try { if (!toInsert.isEmpty()) insert toInsert; } catch (DmlException de) { for (Response r : responses) { r.status='FAILED'; r.message='Insert failed: '+de.getMessage(); } return responses; }
        try { if (!toUpdate.isEmpty()) update toUpdate; } catch (DmlException de) { for (Response r : responses) { r.status='FAILED'; r.message='Update failed: '+de.getMessage(); } return responses; }

        
        return responses;
    }
 
    // ----------------------------
    // Helper: build BPS from plan
    // ----------------------------
    private static List<Booking_Payment_Schedule__c> buildBpsFromPlan(Opportunity opp, Date anchorDate, Id bookingId, List<Payment_Schedule__c> planSchedules, Boolean shouldCalcDates) {
        List<Booking_Payment_Schedule__c> out = new List<Booking_Payment_Schedule__c>();
        
        // UPDATED CALCULATION: Subtract Token from base so total sum remains correct (Balanced Math)
        Decimal basePayable = safeDec(opp.BaseCostAfterDiscount__c) + safeDec(opp.TaxOnConstructionCost__c) + safeDec(opp.Tax_on_Land_Cost__c) - safeDec(opp.Token_Amount__c);
        Decimal finalExtra = safeDec(opp.OtherCharges__c) + safeDec(opp.TaxOnOtherCharges__c);
        Decimal maxNum = 0;
        Date possessionDate = null;

        for (Payment_Schedule__c ps : planSchedules) {
            Integer instNum = (ps.Installment_Number__c != null) ? Integer.valueOf(ps.Installment_Number__c) : -1;
            if (instNum <= 0) continue; 
            if (instNum > maxNum) maxNum = instNum;

            Decimal amt = basePayable * (safeDec(ps.Payment_Percentage__c) / 100);
            if(instNum == 1) amt += safeDec(opp.Token_Amount__c);
            
            Booking_Payment_Schedule__c bps = new Booking_Payment_Schedule__c();
            bps.Opportunity__c = opp.Id;
            if (bookingId != null) bps.Booking__c = bookingId;
            bps.Payment_Schedule_Id__c = ps.Id;
            bps.Installment_Number__c = instNum;
            bps.Installment_Amount__c = amt.setScale(2);
            if (instNum == 1 && opp.Token_Amount__c > 0) bps.Is_Token_Amount__c = true;
            // REQUIREMENT: Force Null if anchor doesn't exist to override Triggers
            if (shouldCalcDates && anchorDate != null) {
                if (ps.Due_In_Days__c != null) bps.Payment_Due_Date__c = anchorDate.addDays((Integer) ps.Due_In_Days__c);
                else if (ps.Month_Number__c != null) bps.Payment_Due_Date__c = anchorDate.addMonths((Integer) ps.Month_Number__c);
            }
            else {
                bps.Payment_Due_Date__c = null;
            }
            if (ps.Milestone_Code__c == 'On Possession') possessionDate = bps.Payment_Due_Date__c;
            out.add(bps);
        }

        if (finalExtra > 0) {
            out.add(new Booking_Payment_Schedule__c(
                Opportunity__c = opp.Id, Booking__c = bookingId,
                Installment_Number__c = maxNum + 1, Installment_Amount__c = finalExtra.setScale(2), 
                Is_Token_Amount__c = false, Payment_Due_Date__c = (shouldCalcDates ? possessionDate : null)
            ));
        }
        return out;
    }

    private static Decimal safeDec(Decimal d) { return (d == null) ? 0 : d; }

    /*private class SObjectFieldComparator implements System.Comparator<SObject> {
        private String fieldName; public SObjectFieldComparator(String f){fieldName=f;}
        public Integer compare(SObject a,SObject b){
            Decimal da = a.get(fieldName) == null ? 0 : Decimal.valueOf(String.valueOf(a.get(fieldName)));
            Decimal db = b.get(fieldName) == null ? 0 : Decimal.valueOf(String.valueOf(b.get(fieldName)));
            if (da==db) return 0; return (da<db)?-1:1;
        }
    }*/
}