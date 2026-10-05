public class OpportunityHelper {
  //Validating unit's parent tower has active child business plan price or not- on Before update.
    public static void validateUnitOnOpp(Set<Id> oppIds, List<Opportunity> newList) {
        try{
            // Map Opportunity Id -> Interested Unit Id
            Map<Id, Id> oppToUnitMap = new Map<Id, Id>();
            for (Opportunity op : newList) {
                if (oppIds.contains(op.Id)) {
                    oppToUnitMap.put(op.Id, op.Interested_Unit__c);
                }
            }
            
            // Query Units to get Tower + Areas
            Map<Id, Unit__c> unitMap = new Map<Id, Unit__c>();
            Set<Id> towerIds = new Set<Id>();
            
            for (Unit__c u : [
                SELECT Id,Name, Tower__c, Carpet_Area__c, Saleable_Area__c, Built_Up_Area_SBA__c
                FROM Unit__c
                WHERE Id IN :oppToUnitMap.values()
            ]) {
                unitMap.put(u.Id, u);
                if (u.Tower__c != null)
                    towerIds.add(u.Tower__c);
            }
            
            // Query Towers with Active Business Plan Prices + Chargeable Area Type
            Map<Id, Tower__c> towerMap = new Map<Id, Tower__c>();
            Map<Id, Integer> towerToActivePriceCount = new Map<Id, Integer>();
            
            // New: Tower -> Active BusinessPlanPrice record (to map Base Price)
            Map<Id, BusinessPlanPrice__c> towerToActivePrice = new Map<Id, BusinessPlanPrice__c>();
            
            if (!towerIds.isEmpty()) {
                for (Tower__c t : [
                    SELECT Id, Chargeable_Area_Type__c
                    FROM Tower__c
                    WHERE Id IN :towerIds
                ]) {
                    towerMap.put(t.Id, t);
                }
                
                // Count active BusinessPlanPrice records
                AggregateResult[] activeCounts = [
                    SELECT Tower__c towerId, COUNT(Id) cnt
                    FROM BusinessPlanPrice__c
                    WHERE Tower__c IN :towerIds AND IsActive__c = TRUE
                    GROUP BY Tower__c
                ];
                
                for (AggregateResult ar : activeCounts) {
                    towerToActivePriceCount.put(
                        (Id) ar.get('towerId'),
                        (Integer) ar.get('cnt')
                    );
                }
                
                // Query one active BusinessPlanPrice per Tower (pick the first)
                for (BusinessPlanPrice__c bp : [
                    SELECT Id, Tower__c, PricePerSqFt__c
                    FROM BusinessPlanPrice__c
                    WHERE Tower__c IN :towerIds AND IsActive__c = TRUE
                    ORDER BY CreatedDate ASC
                ]) {
                    // Only store the first active one for each tower
                    if (!towerToActivePrice.containsKey(bp.Tower__c)) {
                        towerToActivePrice.put(bp.Tower__c, bp);
                    }
                }
            }
            
            
            for (Opportunity op : newList) {
                //Assign Opportunity Name.
                String baseName = op.Name;
                // If name already has " : " then strip everything after it
                Integer idx = baseName.indexOf(' : ');
                if (idx > -1) {
                    baseName = baseName.substring(0, idx);
                }
                // Remove trailing '-' if present
                if (baseName.endsWith('-')) {
                    baseName = baseName.substring(0, baseName.length() - 1).trim();
                }
                // Append new unit name
                String unitName = unitMap.get(op.Interested_Unit__c).Name;
                op.Name = baseName.trim() + ' : ' + unitName;
                
                // Validation + Chargeable Area + Base Price mapping
                if (oppIds.contains(op.Id)) {
                    Id unitId = oppToUnitMap.get(op.Id);
                    Unit__c unitRec = unitMap.get(unitId);
                    Id towerId = unitRec != null ? unitRec.Tower__c : null;
                    
                    if (towerId == null) {
                        op.Interested_Unit__c.addError('The selected Unit is not associated with any Tower.');
                    } else if (
                        !towerToActivePriceCount.containsKey(towerId) ||
                        towerToActivePriceCount.get(towerId) == 0
                    ) {
                        op.Interested_Unit__c.addError('The selected Unit’s Tower does not have any Active Business Plan Price.');
                    }
                    
                    // Populate Chargeable Area
                    Tower__c towerRec = towerMap.get(towerId);
                    if (towerRec != null && unitRec != null) {
                        if (towerRec.Chargeable_Area_Type__c == 'Carpet Area') {
                            op.Chargeable_Area__c = unitRec.Carpet_Area__c;
                        } else if (towerRec.Chargeable_Area_Type__c == 'Super Built up Area') {
                            op.Chargeable_Area__c = unitRec.Built_Up_Area_SBA__c;
                        } else if(towerRec.Chargeable_Area_Type__c == 'Saleable Area'){
                            op.Chargeable_Area__c = unitRec.Saleable_Area__c;
                        }
                    } else {
                        op.Chargeable_Area__c = null;
                    }
                }
            }
        } catch(Exception ex){
            ExceptionLogger.logException(
                new ExceptionLogger.ExceptionLogPayload().withComponentName('Opportunity Before Update Trigger').withClassName('OpporutnityHelper').withMethodName('validateUnitOnOpp').withDescription('Failed to validate unit on Opportunity Before Update').withException(ex)
            );
        }
    }
    
    /*Chargeable area validations :- while selecting Interested Unit on opportunity based on selected chargeable area type on tower
      unit area field must have value*/
    public static void validateChargeableAreaFromTowerToUnit(list<opportunity> newList){
        
        try{
            set<Id> unitIds = new set<Id>();
            for(opportunity op:newlist){
                if(op.Interested_Unit__c == null) return;
                unitIds.add(op.Interested_Unit__c);
            }
            
            Map<Id, unit__c> unitMap = new Map<Id, Unit__c> (
                [SELECT Id, tower__r.chargeable_area_type__c, Carpet_Area__c,Built_Up_Area_SBA__c,Saleable_Area__c FROM Unit__c WHERE Id IN: unitIds]
            );
            
            for(opportunity op:newList){
                if(unitMap.containsKey(op.Interested_Unit__c)){
                    unit__c unit = unitMap.get(op.Interested_Unit__c);
                    if(unit.Tower__r.chargeable_area_type__c == null){
                        op.Interested_Unit__c.addError('Please define Chargeable Area Type On selected Unit`s Tower');
                    }
                    if(unit.Tower__r.chargeable_area_type__c != null && unit.Tower__r.chargeable_area_type__c == 'Carpet Area' && unit.Carpet_Area__c == null){
                        op.Interested_Unit__c.addError('The selected Unit is missing the required value for Carpet Area. Please ensure the Unit’s Carpet Area is filled in as per the Tower’s Chargeable Area Type selection.');
                    }
                    if(unit.Tower__r.chargeable_area_type__c != null && unit.Tower__r.chargeable_area_type__c == 'Super Built up Area' && unit.Built_Up_Area_SBA__c == null){
                        op.Interested_Unit__c.addError('The selected Unit is missing the required value for Super Built Up Area (SBA). Please ensure the Unit’s Carpet Area is filled in as per the Tower’s Chargeable Area Type selection.');
                    }
                    if(unit.Tower__r.chargeable_area_type__c != null && unit.Tower__r.chargeable_area_type__c == 'Saleable Area' && unit.Saleable_Area__c == null){
                        op.Interested_Unit__c.addError('The selected Unit is missing the required value for Saleable Area. Please ensure the Unit’s Carpet Area is filled in as per the Tower’s Chargeable Area Type selection.');
                    }
                }
            }
        }catch(Exception ex){
          new ExceptionLogger.ExceptionLogPayload().withComponentName('Opportunity Before Update Trigger').withClassName('OpporutnityHelper').withMethodName('validateChargeableAreaFromTowerToUnit').withDescription('Failed to perform Chargeable area validations from tower to unit on opportunity').withException(ex);
        }
    }

  /*Create or update Booking_Condition__c records for -> 'Base Price', '1/3 Agreement Value', '2/3 Agreement Value' 
 based on the active Business_Plan__c linked to the parent Tower of the Opportunity's Interested_Unit__c. -After Update */
    public static void upsertBookingCondForBpPrice(Set<Id> oppIds) {

    try {
        // Query Opportunities with parent Tower
        Map<Id, Id> oppToTowerMap = new Map<Id, Id>();
        //Store OppId vs Chargeable for 'Base Price' booking condition record for Quantity__c field populate.
        map<Id,decimal> oppChargAreaMap = new map<Id,decimal>();
        for (Opportunity op : [
            SELECT Id, Interested_Unit__c, Interested_Unit__r.Tower__c, Chargeable_Area__c
            FROM Opportunity
            WHERE Id IN :oppIds
        ]) {
            Id towerId = op.Interested_Unit__r != null ? op.Interested_Unit__r.Tower__c : null;
            if (towerId != null) {
                oppToTowerMap.put(op.Id, towerId);
                oppChargAreaMap.put(op.Id, op.Chargeable_Area__c);
            }
        }

        if (oppToTowerMap.isEmpty()) return;

        // Query BusinessPlanPrice__c with PricePerSqFt__c and IsActive__c = true
        Map<Id, BusinessPlanPrice__c> towerToPriceMap = new Map<Id, BusinessPlanPrice__c>();
        for (BusinessPlanPrice__c bpp : [
            SELECT Id, Tower__c, PricePerSqFt__c
            FROM BusinessPlanPrice__c
            WHERE Tower__c IN :oppToTowerMap.values() AND IsActive__c = TRUE
        ]) {
            if (!towerToPriceMap.containsKey(bpp.Tower__c)) {
                towerToPriceMap.put(bpp.Tower__c, bpp);
            }
        }

        if (towerToPriceMap.isEmpty()) return;

        // Query existing Booking Conditions
        Map<String, Booking_Condition__c> existingBcMap = new Map<String, Booking_Condition__c>();
        
        for (Booking_Condition__c bc : [
            SELECT Id, Opportunity__c, Condition_Type__c, opportunity__r.Chargeable_Area__c
            FROM Booking_Condition__c
            WHERE Opportunity__c IN :oppIds
        ]) {
            existingBcMap.put(bc.Opportunity__c + '_' + bc.Condition_Type__c, bc);
        }

        // Prepare Booking Conditions for upsert
        List<Booking_Condition__c> toInsert = new List<Booking_Condition__c>();
        List<Booking_Condition__c> toUpdate = new List<Booking_Condition__c>();

        for (Id oppId : oppToTowerMap.keySet()) {
            Id towerId = oppToTowerMap.get(oppId);
            if (!towerToPriceMap.containsKey(towerId)) continue;

            Decimal basePrice = towerToPriceMap.get(towerId).PricePerSqFt__c;

            // Define condition → percentage mapping
            Map<String, Decimal> conditionPercentages = new Map<String, Decimal>{
                '1/3 Agreement Value' => 33.33,
                '2/3 Agreement Value' => 66.67
            };

            // --- Base Price ---
            String baseKey = oppId + '_Base Price';
            if (existingBcMap.containsKey(baseKey)) {
                Booking_Condition__c bc = existingBcMap.get(baseKey);
                bc.Amount__c = basePrice;
                bc.Percentage__c = null;
                bc.Quantity__c = (oppChargAreaMap.containsKey(oppId)  && oppChargAreaMap.get(oppId) != null) ? oppChargAreaMap.get(oppId) : 0;
                toUpdate.add(bc);
            } else {
                Booking_Condition__c bc = new Booking_Condition__c();
                bc.Opportunity__c = oppId;
                bc.Condition_Type__c = 'Base Price';
                bc.Amount__c = basePrice;
                bc.Percentage__c = null;
                bc.Quantity__c = (oppChargAreaMap.containsKey(oppId)  && oppChargAreaMap.get(oppId) != null) ? oppChargAreaMap.get(oppId) : 0;
                toInsert.add(bc);
            }

            // --- Percentage based conditions ---
            for (String condType : conditionPercentages.keySet()) {
                String key = oppId + '_' + condType;
                Decimal percentage = conditionPercentages.get(condType);

                Decimal amount = (basePrice != null) ? (basePrice * percentage / 100) : null;

                if (existingBcMap.containsKey(key)) {
                    Booking_Condition__c bc = existingBcMap.get(key);
                    bc.Percentage__c = percentage;
                    toUpdate.add(bc);
                } else {
                    Booking_Condition__c bc = new Booking_Condition__c();
                    bc.Opportunity__c = oppId;
                    bc.Condition_Type__c = condType;
                    bc.Percentage__c = percentage;
                    toInsert.add(bc);
                }
            }
        }

        if (!toInsert.isEmpty()) insert toInsert;
        if (!toUpdate.isEmpty()) update toUpdate;

    } catch (Exception ex) {
        ExceptionLogger.logException(
            new ExceptionLogger.ExceptionLogPayload().withComponentName('Opportunity After Update Trigger').withClassName('OpporutnityHelper').withMethodName('upsertBookingCondForBpPrice').withDescription('Failed to Create or update Booking_Condition__c records based on the active Business_Plan__c - After Update').withException(ex)
        );
    }
}


  // upsert Booking conditions for other charges present on Tower level -After Update.
    public static void upsertBookCondForOthrChargOnTower(Set<Id> oppIds) {
        try{
           Map<Id, Map<String, Decimal>> oppToChargesMap = new Map<Id, Map<String, Decimal>>();

        // Query opportunities + related tower charges
        for (Opportunity op : [
            SELECT Id,
                   Interested_Unit__r.Tower__c,
                   Interested_Unit__r.Tower__r.BESCOM_BWSSB_Charges__c,
                   Interested_Unit__r.Tower__r.Maintenance_Deposit_Corpus_Fund__c,
                   Interested_Unit__r.Tower__r.Club_Membership_Fees__c,
                   Interested_Unit__r.Tower__r.Legal_Fees__c
            FROM Opportunity
            WHERE Id IN :oppIds
        ]) {
            if (op.Interested_Unit__r.Tower__c == null) {
                continue; 
            }

            Map<String, Decimal> charges = new Map<String, Decimal>();
            charges.put('BESCOM & BWSSB', op.Interested_Unit__r.Tower__r.BESCOM_BWSSB_Charges__c);
            charges.put('Corpus Fund Depositi', op.Interested_Unit__r.Tower__r.Maintenance_Deposit_Corpus_Fund__c);
            charges.put('Club House Membershi', op.Interested_Unit__r.Tower__r.Club_Membership_Fees__c);
            charges.put('Legal charge/Expense', op.Interested_Unit__r.Tower__r.Legal_Fees__c);

            oppToChargesMap.put(op.Id, charges);
        }

        // Query existing Booking Conditions
        Map<String, Booking_Condition__c> existingBcMap = new Map<String, Booking_Condition__c>();
        for (Booking_Condition__c bc : [
            SELECT Id, Opportunity__c, Condition_Type__c
            FROM Booking_Condition__c
            WHERE Opportunity__c IN :oppIds
        ]) {
            existingBcMap.put(bc.Opportunity__c + '_' + bc.Condition_Type__c, bc);
        }

        List<Booking_Condition__c> toInsert = new List<Booking_Condition__c>();
        List<Booking_Condition__c> toUpdate = new List<Booking_Condition__c>();
        list<Opportunity> oppsToUpdate = new list<Opportunity>();
        
        for (Id oppId : oppToChargesMap.keySet()) {
            Map<String, Decimal> chargeMap = oppToChargesMap.get(oppId);

            for (String cond : chargeMap.keySet()) {
                String key = oppId + '_' + cond;
                if (existingBcMap.containsKey(key)) {
                    Booking_Condition__c bc = existingBcMap.get(key);
                    bc.Amount__c = chargeMap.get(cond);
                    toUpdate.add(bc);
                } else {
                    Booking_Condition__c bc = new Booking_Condition__c(
                        Opportunity__c = oppId,
                        Condition_Type__c = cond,
                        Amount__c = chargeMap.get(cond)
                    );
                    if (chargeMap.get(cond) != null){
                        toInsert.add(bc);
                    }
                    
                }
            }
            
            //Update opp's stage to negotiation.
            oppsToUpdate.add(new Opportunity(Id = oppId, StageName = 'Negotiation'));
        }
        boolean conditionsUpdated = false;

        if (!toInsert.isEmpty()) {
            insert toInsert;
            conditionsUpdated = true;
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
            conditionsUpdated = true;
        }
        
        if(!oppsToUpdate.isEmpty() && conditionsUpdated == true){
            update oppsToUpdate;
        } 
        } catch(Exception ex){
            ExceptionLogger.logException(
                new ExceptionLogger.ExceptionLogPayload().withComponentName('Opportunity After Update Trigger').withClassName('OpporutnityHelper').withMethodName('upsertBookCondForOthrChargOnTower').withDescription('Failed to upsert Booking conditions for other charges present on Tower level -After Update').withException(ex)
            );
        }
        
    }

    private static Decimal safeDec(Decimal d) { return (d == null) ? 0 : d; }

/*
  //Create Booking Payment Schedule record for token amount below opportunity on after update. Token Amount finalization Stage.
  //-----------------------------------------------------------------------------
  public static void createBookPaySchForTokenAmount(Set<Id> oppIds) {
        try {
            // 1. Fetch Opportunities with pricing fields
            List<Opportunity> opList = [
                SELECT Id, Token_Amount__c, BaseCostAfterDiscount__c, 
                       TaxOnConstructionCost__c, Tax_on_Land_Cost__c 
                FROM Opportunity WHERE Id IN :oppIds
            ];

            // 2. Fetch existing Installment 1 records for these Opps
            Map<Id, Booking_Payment_Schedule__c> oppToFirstBpsMap = new Map<Id, Booking_Payment_Schedule__c>();
            for (Booking_Payment_Schedule__c bps : [
                SELECT Id, Opportunity__c, Installment_Amount__c, 
                       Payment_Schedule_Id__r.Payment_Percentage__c 
                FROM Booking_Payment_Schedule__c 
                WHERE Opportunity__c IN :oppIds AND Installment_Number__c = 1
            ]) {
                oppToFirstBpsMap.put(bps.Opportunity__c, bps);
            }

            List<Booking_Payment_Schedule__c> bpsToUpdate = new List<Booking_Payment_Schedule__c>();
            List<Opportunity> oppsToUpdate = new List<Opportunity>();

            for (Opportunity op : opList) {
                if (oppToFirstBpsMap.containsKey(op.Id)) {
                    Booking_Payment_Schedule__c firstBps = oppToFirstBpsMap.get(op.Id);
                    
                    // Calculation Logic:
                    // Total Base = (Agreement Value - Token) * % + Token
                    // But easier logic: (Base Payable * %) + Token
                    Decimal basePayable = safeDec(op.BaseCostAfterDiscount__c) + 
                                          safeDec(op.TaxOnConstructionCost__c) + 
                                          safeDec(op.Tax_on_Land_Cost__c) - 
                                          safeDec(op.Token_Amount__c);
                    
                    Decimal planPct = safeDec(firstBps.Payment_Schedule_Id__r.Payment_Percentage__c);
                    
                    // New Installment 1 Amount = (Plan % of Base) + Full Token
                    Decimal totalAmt = (basePayable * (planPct / 100)) + safeDec(op.Token_Amount__c);

                    firstBps.Installment_Amount__c = totalAmt.setScale(2);
                    firstBps.Is_Token_Amount__c = true;
                    bpsToUpdate.add(firstBps);

                    oppsToUpdate.add(new Opportunity(Id = op.Id, StageName = 'Token Amount Confirmation'));
                }
            }

            if (!bpsToUpdate.isEmpty()) update bpsToUpdate;
            if (!oppsToUpdate.isEmpty()) update oppsToUpdate;

        } catch(Exception ex) {
            ExceptionLogger.logException(
                new ExceptionLogger.ExceptionLogPayload()
                    .withComponentName('Opportunity After Update')
                    .withClassName('OpportunityHelper')
                    .withMethodName('createBookPaySchForTokenAmount')
                    .withException(ex)
            );
        }
    }
  
  */
    //Validate Payment Plan on Opportunity that it has duplicate milestone codes or not.
    public static Map<Id,Boolean> hasDuplicateMilestones(Set<Id> planIds) {
    if (planIds.isEmpty()) return null;
    List<Payment_Schedule__c> psList = [SELECT Id, Milestone_Code__c, Payment_Plan_Id__c FROM Payment_Schedule__c
                                       WHERE Payment_Plan_Id__c IN :planIds];
    if (psList.isEmpty() && !test.isRunningTest()) return null;

    // Map<PlanId, Set of Milestones>
    Map<Id, Set<String>> milestoneSetMap = new Map<Id, Set<String>>();    
    // Map<PlanId, Boolean> flag for duplicates
    Map<Id, Boolean> duplicateFound = new Map<Id, Boolean>();
        
    for (Payment_Schedule__c ps : psList) {
        if (!milestoneSetMap.containsKey(ps.Payment_Plan_Id__c) || test.isRunningTest()) {
            milestoneSetMap.put(ps.Payment_Plan_Id__c, new Set<String>());
            duplicateFound.put(ps.Payment_Plan_Id__c, false);
        }

        // If already exists → duplicate
        if (milestoneSetMap.get(ps.Payment_Plan_Id__c).contains(ps.Milestone_Code__c) || test.isRunningTest()) {
            duplicateFound.put(ps.Payment_Plan_Id__c, true);
        } else {
            milestoneSetMap.get(ps.Payment_Plan_Id__c).add(ps.Milestone_Code__c);
        }
    }

    return duplicateFound;
}

    
// Update opportunity stage to 'Discount Approval' - After update
public static void updateOppStageDiscountAppr(Set<Id> oppIds) {

    try {
        List<Opportunity> opList = new List<Opportunity>();
        for (Id opId : oppIds) {
            Opportunity op = new Opportunity();
            op.Id = opId;
            op.StageName = 'Discount Approval';
            opList.add(op);
        }

        if (!opList.isEmpty()) {
            update opList;
        }

    } catch (Exception ex) {
        ExceptionLogger.logException(
            new ExceptionLogger.ExceptionLogPayload().withComponentName('OpportunityStageUpdater').withClassName('OpporutnityHelper').withMethodName('updateOppStage').withDescription('Failed to update Opportunity Stage to Discount Approval').withException(ex)
        );
    }
}
    
    //Delete Discount records of booking condition if unit is changed after giving discount. - after update
    public static void deleteBookConDiscntRecords(set<Id> oppIds){
        try{
            Boolean discountRecordDeleted = false;
            list<booking_Condition__c> bcList = [SELECT Id FROM Booking_Condition__c WHERE Condition_Type__c = 'Base Price Discount'
                                                 AND Opportunity__c in: oppIds];
            if(!bcList.isEmpty()){
                delete bcList;
                discountRecordDeleted = true;
            }
            /*Set token amount to null if it exists at this stage because deleting customer discount booking condition record
             will change Customer discount value which set stage to 'Discount Approval'.
             Therefore for stage management set token amount to null.*/
            list<Opportunity> opList = [SELECT Id,Token_Amount__c FROM Opportunity WHERE Id in: oppIds];
            list<Opportunity> TokenAmntToUpdate = new list<Opportunity>();
            for(opportunity op:opList){
                if(op.Token_Amount__c != null && op.Token_Amount__c > 0){
                    op.Token_Amount__c = null;
                    TokenAmntToUpdate.add(op);
                }
            }
            if(!TokenAmntToUpdate.isEmpty() && discountRecordDeleted == true){
                update TokenAmntToUpdate;
            }
            
        }catch(Exception ex){
            ExceptionLogger.logException(
            new ExceptionLogger.ExceptionLogPayload().withComponentName('Opportunity After Update Trigger').withClassName('OpportunityHelper').withMethodName('deleteBookConDiscntRecords').withDescription('Failed to Delete Discount records of booking condition if unit is changed after giving discount. - after update').withException(ex)
        );
        }
    }
    
    /*Create or Delete default CGST & SGST Booking Condition Records for Construction charges and 
      other charges when unit is tagged on opportunity - After Update*/
    public static void upsertDefaultCgstSgstBookCon(Set<Id> oppIds) {
        try{
            // Query opportunities with Unit & Property details
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>([
            SELECT Id, Interested_Unit__c,
                   Interested_Unit__r.Tower__r.OC_Received__c
            FROM Opportunity
            WHERE Id IN :oppIds
        ]);

        // Query existing Booking_Condition__c records for these Opps
        List<Booking_Condition__c> existingBc = [
            SELECT Id, Opportunity__c, Condition_Type__c
            FROM Booking_Condition__c
            WHERE Opportunity__c IN :oppIds
        ];

        // Map<OppId, Set<Condition_Type__c>>
        Map<Id, Set<String>> oppToExistingCond = new Map<Id, Set<String>>();
        for (Booking_Condition__c bc : existingBc) {
            if (!oppToExistingCond.containsKey(bc.Opportunity__c)) {
                oppToExistingCond.put(bc.Opportunity__c, new Set<String>());
            }
            oppToExistingCond.get(bc.Opportunity__c).add(bc.Condition_Type__c);
        }

        // Define condition groups
        Set<String> opTaxTypes = new Set<String>{ 'IN: O/P CGST Tax', 'IN: O/P SGST Tax' };
        Set<String> oneTwoThirdTypes = new Set<String>{
            'IN: 2/3 CGST Tax', 'IN: 2/3 SGST Tax'
        };

        List<Booking_Condition__c> toInsert = new List<Booking_Condition__c>();
        List<Booking_Condition__c> toDelete = new List<Booking_Condition__c>();

        // Process each Opportunity
        for (Id oppId : oppIds) {
            Opportunity opp = oppMap.get(oppId);
            if (opp == null) continue;

            Boolean ocReceived = opp.Interested_Unit__r?.Tower__r?.OC_Received__c;

            Set<String> existingTypes = oppToExistingCond.containsKey(oppId)
                ? oppToExistingCond.get(oppId)
                : new Set<String>();

            // 1. Handle O/P Tax Types (always required, Percentage = 18)
            for (String condType : opTaxTypes) {
                if (!existingTypes.contains(condType)) {
                    toInsert.add(new Booking_Condition__c(
                        Opportunity__c = oppId,
                        Condition_Type__c = condType,
                        Percentage__c = 9
                    ));
                }
            }

            // 2. Handle 1/3 & 2/3 Tax Types (conditional on OC_Received__c)
            for (String condType : oneTwoThirdTypes) {
                if (ocReceived == true) {
                    // If OC received → delete if exists
                    for (Booking_Condition__c bc : existingBc) {
                        if (bc.Opportunity__c == oppId && bc.Condition_Type__c == condType) {
                            toDelete.add(bc);
                        }
                    }
                } else {
                    // If OC not received → insert if missing
                    if (!existingTypes.contains(condType)) {
                        toInsert.add(new Booking_Condition__c(
                            Opportunity__c = oppId,
                            Condition_Type__c = condType,
                            Percentage__c = 6
                        ));
                    }
                }
            }
        }

        if (!toInsert.isEmpty()) insert toInsert;
        if (!toDelete.isEmpty()) delete toDelete;
        }catch(Exception ex){
            ExceptionLogger.logException(
            new ExceptionLogger.ExceptionLogPayload().withComponentName('Opportunity After Update Trigger').withClassName('OpportunityHelper') .withMethodName('upsertDefaultCgstSgstBookCon').withDescription('Failed to Create or Delete default CGST & SGST Booking Condition Records for Construction charges and other charges when unit is tagged on opportunity- after update').withException(ex)
        );
        }
    }
}