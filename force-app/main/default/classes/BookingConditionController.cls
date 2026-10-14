public with sharing class BookingConditionController {
    
    // 1. Fetch picklist values
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getConditionTypePicklistValues() {
        List<Map<String, String>> results = new List<Map<String, String>>();
        Schema.DescribeFieldResult fieldResult = Booking_Condition__c.Condition_Type__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            results.add(new Map<String, String>{
                'value' => entry.getValue(),
                'label' => entry.getLabel()
            });
        }
        return results;
    }

    // 2. Fetch conditions for either Booking or Opportunity
    @AuraEnabled
    public static List<Booking_Condition__c> getConditions(Id parentId, String parentType) {
        if (parentId == null) throw new AuraHandledException('ParentId required.');
        if (String.isBlank(parentType)) throw new AuraHandledException('ParentType required.');
        
        String fieldName = (parentType == 'Booking__c') ? 'Booking__c' : 'Opportunity__c';
        
        String soql = 'SELECT Id, Condition_Type__c, Amount__c, Quantity__c, Type__c, Percentage__c, Amount_By_Type__c ' +
                      'FROM Booking_Condition__c ' +
                      'WHERE ' + fieldName + ' = :parentId ORDER BY Order__c' ;
        return Database.query(soql);
    }

    // 2b. Fetch default types from custom metadata by label
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getConditionTypeDefaults() {
        Map<String, String> defaultsByLabel = new Map<String, String>();
        for (ConditionTypeCode__mdt m : [SELECT MasterLabel, Type__c FROM ConditionTypeCode__mdt]) {
            if (m.MasterLabel != null && m.Type__c != null) {
                defaultsByLabel.put(m.MasterLabel, m.Type__c);
            }
        }
        return defaultsByLabel;
    }

    // 3. Upsert conditions for either Booking or Opportunity
        // 3. Upsert conditions for either Booking or Opportunity
    @AuraEnabled
    public static void upsertConditions(
        Id parentId,
        String parentType,
        Map<String, Decimal> conditionAmounts,
        Map<String, Decimal> conditionQuantities,
        Map<String, String> conditionTypes
    ) {
        if (parentId == null) throw new AuraHandledException('ParentId required.');
        if (String.isBlank(parentType)) throw new AuraHandledException('ParentType required.');
        if (conditionAmounts == null || conditionAmounts.isEmpty()) return;
    
        // Detect Booking Id if Opportunity
        Id bookingId = null;
        Id opportunityId = null;
        if (parentId.getSobjectType() == Opportunity.SObjectType) {
            opportunityId = parentId;

            List<Booking__c> relatedBookings = [
                SELECT Id FROM Booking__c WHERE Opportunity_Id__c = :opportunityId LIMIT 1
            ];
            if (!relatedBookings.isEmpty()) {
                bookingId = relatedBookings[0].Id;
            }
        } else if(parentId.getSobjectType() == Booking__c.SObjectType) {
            bookingId = parentId;
            Booking__c booking = [SELECT Opportunity_Id__c FROM Booking__c WHERE Id = :bookingId];
            opportunityId = booking.Opportunity_Id__c;
        }   
    
        String fieldName = (parentType == 'Booking__c') ? 'Booking__c' : 'Opportunity__c';
    
        // Fetch existing
        String fetchSoql = 'SELECT Id, Condition_Type__c, Item_Number__c, Amount__c, Percentage__c, Quantity__c, Type__c ' +
                           'FROM Booking_Condition__c ' +
                           'WHERE ' + fieldName + ' = :parentId';
        List<Booking_Condition__c> existing = Database.query(fetchSoql);
    
        Map<String, Booking_Condition__c> existingByType = new Map<String, Booking_Condition__c>();
        Integer maxItemNumber = 0;
    
        for (Booking_Condition__c bc : existing) {
            existingByType.put(bc.Condition_Type__c, bc);
            if (bc.Item_Number__c != null && bc.Item_Number__c > maxItemNumber) {
                maxItemNumber = Integer.valueOf(bc.Item_Number__c);
            }
        }
    
        List<Booking_Condition__c> toUpsert = new List<Booking_Condition__c>();
    
        // Pass 1: Base Price first
        for (String condType : conditionAmounts.keySet()) {
            if (condType == 'Base Price') {
                Decimal amt = conditionAmounts.get(condType);
                Decimal qty = (conditionQuantities != null && conditionQuantities.containsKey(condType) && conditionQuantities.get(condType) != null) ? conditionQuantities.get(condType)
                    : 1;
                    
                if (existingByType.containsKey(condType)) {
                    String valType = (conditionTypes != null && conditionTypes.containsKey(condType)) ? conditionTypes.get(condType) : null;
                    Booking_Condition__c upd = existingByType.get(condType);

                    // Skip if no change
                    Boolean changed = false;
                    if (valType == 'Percentage' || (valType == null && upd.Type__c == 'Percentage')) {
                        if (upd.Percentage__c != amt) { upd.Percentage__c = amt; changed = true; }
                        if (upd.Amount__c != null) { upd.Amount__c = null; changed = true; }
                        if (upd.Type__c != 'Percentage') { upd.Type__c = 'Percentage'; changed = true; }
                    } else {
                        if (upd.Amount__c != amt) { upd.Amount__c = amt; changed = true; }
                        if (upd.Percentage__c != null) { upd.Percentage__c = null; changed = true; }
                        if (valType != null && upd.Type__c != valType) { upd.Type__c = valType; changed = true; }
                    }
                    if (upd.Quantity__c != qty) { upd.Quantity__c = qty; changed = true; }
                    upd.Item_Number__c = 1;
                    if (changed) toUpsert.add(upd);
                } else {
                    String valType = (conditionTypes != null && conditionTypes.containsKey(condType)) ? conditionTypes.get(condType) : 'Fixed Amount';
                    String valTypeNorm = (valType != null) ? valType : 'Fixed Amount';
                    Booking_Condition__c ins = new Booking_Condition__c(
                        Condition_Type__c = condType,
                        Quantity__c = qty,
                        Item_Number__c = 1,
                        Type__c = valTypeNorm
                    );
                    if (valTypeNorm == 'Percentage') {
                        ins.Percentage__c = amt;
                    } else {
                        ins.Amount__c = amt;
                    }
                    if (fieldName == 'Booking__c') {
                        ins.Booking__c = bookingId;
                        ins.Opportunity__c = opportunityId;
                    } else {
                        ins.Opportunity__c = opportunityId;
                        if (bookingId != null) ins.Booking__c = bookingId;
                    }
                    toUpsert.add(ins);
                    if (maxItemNumber < 1) {
                        maxItemNumber = 1;
                    }
                }
            }
        }
        
        // Pass 2: Other types
        for (String condType : conditionAmounts.keySet()) {
            if (condType != 'Base Price') {
                Decimal amt = conditionAmounts.get(condType);
                Decimal qty = (conditionQuantities != null && conditionQuantities.containsKey(condType) && conditionQuantities.get(condType) != null) ? conditionQuantities.get(condType)
                    : 1;
                String passedType = (conditionTypes != null && conditionTypes.containsKey(condType)) ? conditionTypes.get(condType) : null;

                if (existingByType.containsKey(condType)) {
                    Booking_Condition__c upd = existingByType.get(condType);

                    // Skip if no change
                    Boolean changed = false;
                    String effectiveType = (passedType != null) ? passedType : upd.Type__c;
                    if (effectiveType == 'Percentage') {
                        if (upd.Percentage__c != amt) { upd.Percentage__c = amt; changed = true; }
                        if (upd.Amount__c != null) { upd.Amount__c = null; changed = true; }
                        if (upd.Type__c != 'Percentage') { upd.Type__c = 'Percentage'; changed = true; }
                    } else {
                        if (upd.Amount__c != amt) { upd.Amount__c = amt; changed = true; }
                        if (upd.Percentage__c != null) { upd.Percentage__c = null; changed = true; }
                        if (passedType != null && upd.Type__c != passedType) { upd.Type__c = passedType; changed = true; }
                    }
                    if (upd.Quantity__c != qty) { upd.Quantity__c = qty; changed = true; }
                    if (changed) toUpsert.add(upd);
                } else {
                    maxItemNumber++;
                    String valType = (passedType != null) ? passedType : 'Fixed Amount';
                    Booking_Condition__c ins = new Booking_Condition__c(
                        Condition_Type__c = condType,
                        Quantity__c = qty,
                        Item_Number__c = maxItemNumber,
                        Type__c = valType
                    );
                    if (valType == 'Percentage') {
                        ins.Percentage__c = amt;
                    } else {
                        ins.Amount__c = amt;
                    }
                    if (fieldName == 'Booking__c') {
                        ins.Booking__c = bookingId;
                        ins.Opportunity__c = opportunityId;
                    } else {
                        ins.Opportunity__c = opportunityId;
                        if (bookingId != null) ins.Booking__c = bookingId;
                    }
                    toUpsert.add(ins);
                }
            }
        }
        
        if (!toUpsert.isEmpty()) {
            upsert toUpsert;
        }
    }


    // 4. Delete
    @AuraEnabled
    public static void deleteConditions(Id parentId, String parentType, List<String> conditionTypesToDelete) {
        if (parentId == null) throw new AuraHandledException('ParentId required.');
        if (String.isBlank(parentType)) throw new AuraHandledException('ParentType required.');
        if (conditionTypesToDelete == null || conditionTypesToDelete.isEmpty()) return;
        
        String fieldName = (parentType == 'Booking__c') ? 'Booking__c' : 'Opportunity__c';
        String soql = 'SELECT Id FROM Booking_Condition__c ' +
                      'WHERE ' + fieldName + ' = :parentId AND Condition_Type__c IN :conditionTypesToDelete';
        List<Booking_Condition__c> toDelete = Database.query(soql);
        if (!toDelete.isEmpty()) {
            delete toDelete;
        }
    }

    // 5. Get Stage
    @AuraEnabled(cacheable=true)
    public static String getParentStage(Id parentId, String parentType) {
        if (parentId == null) throw new AuraHandledException('ParentId required.');
        if (String.isBlank(parentType)) throw new AuraHandledException('ParentType required.');
        
        if (parentType == 'Booking__c') {
            Booking__c b = [SELECT Status__c FROM Booking__c WHERE Id = :parentId LIMIT 1];
            return b.Status__c;
        } else if (parentType == 'Opportunity') {
            Opportunity o = [SELECT StageName FROM Opportunity WHERE Id = :parentId LIMIT 1];
            return o.StageName;
        }
        throw new AuraHandledException('Unsupported parent type: ' + parentType);
    }
    
    //Get chargeable area.
    @AuraEnabled
    public static Decimal getChargeableArea(Id parentId, String parentType) {
        decimal chargeableArea;
        if (parentId == null) throw new AuraHandledException('ParentId required.');
        if (String.isBlank(parentType)) throw new AuraHandledException('ParentType required.');
        
        Opportunity opp;
        if (parentType == 'Opportunity') {
            opp = [SELECT Chargeable_Area__c FROM Opportunity WHERE Id = :parentId LIMIT 1];
            chargeableArea = opp.Chargeable_Area__c;
        } else if (parentType == 'Booking__c') {
            Booking__c b = [SELECT Opportunity_Id__r.Chargeable_Area__c FROM Booking__c WHERE Id = :parentId LIMIT 1];
            chargeableArea = b.Opportunity_Id__r.Chargeable_Area__c;
        }
        
        return chargeableArea;
    }

}