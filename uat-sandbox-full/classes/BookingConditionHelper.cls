public class BookingConditionHelper {

    // ---- Field semantics / labels ----
    private static final String TYPE_RATE       = 'Rate';
    private static final String TYPE_PERCENTAGE = 'Percentage';
    private static final String TYPE_AMOUNT     = 'Fixed Amount';

    private static final String CONDITION_BASE                 = 'Base Price';
    private static final String CONDITION_BASE_DISCOUNT        = 'Base Price Discount';
    private static final String CONDITION_LAND_COST            = '1/3 Agreement Value';
    private static final String CONDITION_CONSTRUCTION_COST    = '2/3 Agreement Value';

    private static final String CONDITION_CGST_OTHER           = 'IN: O/P CGST Tax';
    private static final String CONDITION_SGST_OTHER           = 'IN: O/P SGST Tax';

    // Taxable "other charges" for CGST/SGST base  (Corpus Fund Deposit is NON-taxable)
    private static final Set<String> OTHER_CHARGE_TYPES = new Set<String>{
        'BESCOM & BWSSB',
        'Club House Membershi',
        'Legal charge/Expense'
    };
        
        private static final Set<String> ALL_TAX_TYPES = new Set<String>{
            'IN: 2/3 CGST Tax',
            'IN: 2/3 SGST Tax',
            'IN: O/P CGST Tax',
            'IN: O/P SGST Tax'
        };

    private static final Set<String> TAX_TYPES = new Set<String>{
        CONDITION_CGST_OTHER, CONDITION_SGST_OTHER
    };

    // Context rows needed to compute core + tax base
    private static final Set<String> CONTEXT_TYPES = new Set<String>{
        CONDITION_BASE, CONDITION_BASE_DISCOUNT
    };
    static { CONTEXT_TYPES.addAll(OTHER_CHARGE_TYPES); }

    private static Boolean isRecalcRunning = false;

    // ---------------- BEFORE: compute Amount_By_Type__c on rows being DML'ed ----------------
    public void calculateLineAmounts(List<Booking_Condition__c> rows){
        if (rows == null || rows.isEmpty()) return;

        // Context (from Txn or DB), includes Amount_By_Type__c for other charges
        Map<Id, Map<String, Booking_Condition__c>> ctx = contextPerOppFromTxnOrDb(rows);

        // Core numbers per Opp
        Map<Id, Core> coreByOpp = buildCorePerOpp(ctx);

        // Keep amounts we compute in this pass for reuse in tax base
        Map<Id, Map<String, Decimal>> computed = new Map<Id, Map<String, Decimal>>();

        // ---- Pass 1: all non-tax rows
        for (Booking_Condition__c r : rows) {
            if (r == null) continue;
            Core core = coreByOpp.get(r.Opportunity__c);
            if (core == null) core = new Core();

            Decimal amt;
            if (CONDITION_BASE_DISCOUNT.equals(r.Condition_Type__c)) {
                // UI requirement: show discounted base total on this row
                amt = core.discountedBaseTotal;
            } else if (CONDITION_LAND_COST.equals(r.Condition_Type__c)) {
                amt = (core.discountedBaseTotal / 3).setScale(2, RoundingMode.HALF_UP);
            } else if (CONDITION_CONSTRUCTION_COST.equals(r.Condition_Type__c)) {
                amt = ((core.discountedBaseTotal * 2) / 3).setScale(2, RoundingMode.HALF_UP);
            } else if (TYPE_PERCENTAGE.equals(String.valueOf(r.Type__c)) && !TAX_TYPES.contains(r.Condition_Type__c)) {
                Decimal pct = (r.Percentage__c == null) ? 0 : r.Percentage__c;
                amt = (core.discountedBaseTotal * (pct/100)).setScale(2, RoundingMode.HALF_UP);
            } else if (TYPE_RATE.equals(String.valueOf(r.Type__c))) {
                amt = (nz(r.Amount__c) * core.baseQty).setScale(2, RoundingMode.HALF_UP);
            } else {
                amt = nz(r.Amount__c).setScale(2, RoundingMode.HALF_UP);
            }

            r.Amount_By_Type__c = amt;

            if (!computed.containsKey(r.Opportunity__c)) computed.put(r.Opportunity__c, new Map<String, Decimal>());
            computed.get(r.Opportunity__c).put(r.Condition_Type__c, amt);
        }

        // ---- Pass 2: CGST/SGST on sum of taxable OTHER CHARGES (use Amount_By_Type__c)
        for (Booking_Condition__c r : rows) {
            if (!TAX_TYPES.contains(r.Condition_Type__c)) continue;

            Decimal otherSum = 0;

            // Prefer amounts just computed in this DML; else use DB Amount_By_Type__c
            Map<String, Booking_Condition__c> byType = ctx.get(r.Opportunity__c);
            Map<String, Decimal> justNow = computed.get(r.Opportunity__c);

            for (String oc : OTHER_CHARGE_TYPES) {
                Decimal add = 0;
                if (justNow != null && justNow.containsKey(oc)) {
                    add = nz(justNow.get(oc));
                } else if (byType != null && byType.containsKey(oc)) {
                    add = nz(byType.get(oc).Amount_By_Type__c);
                }
                otherSum += add;
            }

            Decimal pct = (r.Percentage__c == null) ? 0 : r.Percentage__c;
            r.Amount_By_Type__c = (otherSum * (pct/100)).setScale(2, RoundingMode.HALF_UP);
        }
    }

    // ---------------- AFTER: recalc siblings when base/discount/other/tax changes ----------------
    public static void recalcSiblingsIfBaseChanged(List<Booking_Condition__c> newList,
                                                   Map<Id, SObject> oldMap){
        if (isRecalcRunning) return;

        Set<String> watch = new Set<String>();
        watch.add(CONDITION_BASE);
        watch.add(CONDITION_BASE_DISCOUNT);
        watch.addAll(OTHER_CHARGE_TYPES);
        watch.addAll(TAX_TYPES);

        Set<Id> opps = new Set<Id>();
        for (Booking_Condition__c r : newList) {
            if (r == null || r.Opportunity__c == null) continue;
            if (!watch.contains(r.Condition_Type__c)) continue;

            if (oldMap == null || oldMap.get(r.Id) == null) { opps.add(r.Opportunity__c); continue; }
            Booking_Condition__c o = (Booking_Condition__c)oldMap.get(r.Id);
            Boolean changed =
                (o.Amount__c != r.Amount__c) ||
                (o.Quantity__c != r.Quantity__c) ||
                (o.Percentage__c != r.Percentage__c) ||
                (String.valueOf(o.Type__c) != String.valueOf(r.Type__c)) ||
                (o.Condition_Type__c != r.Condition_Type__c);
            if (changed) opps.add(r.Opportunity__c);
        }
        if (opps.isEmpty()) return;

        try {
            isRecalcRunning = true;

            Map<Id, Map<String, Booking_Condition__c>> ctx = contextPerOppFromDb(opps);
            Map<Id, Core> coreByOpp = buildCorePerOpp(ctx);

            List<Booking_Condition__c> siblings = [
                SELECT Id, Opportunity__c, Type__c, Amount__c, Quantity__c, Percentage__c,
                       Condition_Type__c, Amount_By_Type__c
                  FROM Booking_Condition__c
                 WHERE Opportunity__c IN :opps
            ];

            // Sum taxable OTHER CHARGES using persisted Amount_By_Type__c
            Map<Id, Decimal> otherSumByOpp = new Map<Id, Decimal>();
            for (Booking_Condition__c r : siblings) {
                if (!OTHER_CHARGE_TYPES.contains(r.Condition_Type__c)) continue;
                Decimal add = nz(r.Amount_By_Type__c);
                otherSumByOpp.put(
                    r.Opportunity__c,
                    (otherSumByOpp.containsKey(r.Opportunity__c) ? otherSumByOpp.get(r.Opportunity__c) : 0) + add
                );
            }

            List<Booking_Condition__c> updates = new List<Booking_Condition__c>();
            for (Booking_Condition__c r : siblings) {
                Core core = coreByOpp.get(r.Opportunity__c);
                if (core == null) core = new Core();

                Decimal newAmt;
                if (CONDITION_BASE_DISCOUNT.equals(r.Condition_Type__c)) {
                    newAmt = core.discountedBaseTotal;
                } else if (TAX_TYPES.contains(r.Condition_Type__c)) {
                    Decimal baseForTax = nz(otherSumByOpp.get(r.Opportunity__c));
                    Decimal pct = (r.Percentage__c == null) ? 0 : r.Percentage__c;
                    newAmt = (baseForTax * (pct/100)).setScale(2, RoundingMode.HALF_UP);
                } else {
                    newAmt = amountForRowUsingCore(r, core, false);
                }

                if (r.Amount_By_Type__c != newAmt) {
                    r.Amount_By_Type__c = newAmt;
                    updates.add(r);
                }
            }
            if (!updates.isEmpty()) update updates;

        } finally {
            isRecalcRunning = false;
        }
    }

    // ---------------- helpers ----------------

    private class Core {
        Decimal baseQty              = 1;     // chargeable area
        Decimal baseTotal            = 0;     // Base row total (usually rate×area)
        Decimal discountEffect       = 0;     // how much discount reduces base
        Decimal discountedBaseTotal  = 0;     // baseTotal − discountEffect (>=0)
    }

    private static Map<Id, Core> buildCorePerOpp(Map<Id, Map<String, Booking_Condition__c>> ctx){
        Map<Id, Core> res = new Map<Id, Core>();
        for (Id oppId : ctx.keySet()) {
            Map<String, Booking_Condition__c> byType = ctx.get(oppId);
            if (byType == null) continue;

            Booking_Condition__c baseRow = byType.get(CONDITION_BASE);
            Booking_Condition__c discRow = byType.get(CONDITION_BASE_DISCOUNT);

            Core c = new Core();
            c.baseQty   = (baseRow == null || baseRow.Quantity__c == null) ? 1 : baseRow.Quantity__c;
            c.baseTotal = amountForBase(baseRow, c.baseQty);

            Decimal eff = discountValue(discRow, c.baseTotal, c.baseQty);
            if (eff < 0) eff = 0;
            if (eff > c.baseTotal) eff = c.baseTotal;
            c.discountEffect      = eff;
            c.discountedBaseTotal = (c.baseTotal - eff).setScale(2, RoundingMode.HALF_UP);

            res.put(oppId, c);
        }
        return res;
    }

    private static Decimal amountForBase(Booking_Condition__c baseRow, Decimal baseQty){
        if (baseRow == null) return 0;
        String t = String.valueOf(baseRow.Type__c);
        if (TYPE_RATE.equals(t))       return (nz(baseRow.Amount__c) * nz(baseQty)).setScale(2, RoundingMode.HALF_UP);
        if (TYPE_PERCENTAGE.equals(t)) return (nz(baseRow.Percentage__c) / 100 * nz(baseQty)).setScale(2, RoundingMode.HALF_UP);
        return nz(baseRow.Amount__c).setScale(2, RoundingMode.HALF_UP);
    }

    // Discount effect (amount to subtract from base)
    private static Decimal discountValue(Booking_Condition__c disc, Decimal baseTotal, Decimal baseQty){
        if (disc == null) return 0;
        String t = String.valueOf(disc.Type__c);

        if (TYPE_PERCENTAGE.equals(t)) {
            Decimal pct = nz(disc.Percentage__c);
            return (baseTotal * (pct/100)).setScale(2, RoundingMode.HALF_UP);
        }
        Decimal perUnit = nz(disc.Amount__c);
        if (perUnit == 0) return 0;
        return (perUnit * nz(baseQty)).setScale(2, RoundingMode.HALF_UP);
    }

    // Generic amount for any non-tax row using the core
    private static Decimal amountForRowUsingCore(Booking_Condition__c r, Core core, Boolean isTax){
        if (r == null) return 0;
        String t = String.valueOf(r.Type__c);

        if (CONDITION_LAND_COST.equals(r.Condition_Type__c))
            return (core.discountedBaseTotal / 3).setScale(2, RoundingMode.HALF_UP);
        if (CONDITION_CONSTRUCTION_COST.equals(r.Condition_Type__c))
            return ((core.discountedBaseTotal * 2) / 3).setScale(2, RoundingMode.HALF_UP);

        if (TYPE_RATE.equals(t))
            return (nz(r.Amount__c) * core.baseQty).setScale(2, RoundingMode.HALF_UP);

        if (TYPE_PERCENTAGE.equals(t)) {
            if (CONDITION_BASE_DISCOUNT.equals(r.Condition_Type__c))
                return (core.baseTotal * (nz(r.Percentage__c)/100)).setScale(2, RoundingMode.HALF_UP);
            if (TAX_TYPES.contains(r.Condition_Type__c) && isTax)
                return 0;
            return (core.discountedBaseTotal * (nz(r.Percentage__c)/100)).setScale(2, RoundingMode.HALF_UP);
        }

        return nz(r.Amount__c).setScale(2, RoundingMode.HALF_UP);
    }

    private static Decimal nz(Decimal d){ return (d == null) ? 0 : d; }

    // ---------- context readers (now also select Amount_By_Type__c) ----------
    private static Map<Id, Map<String, Booking_Condition__c>> contextPerOppFromTxnOrDb(List<Booking_Condition__c> rows){
        Set<Id> opps = new Set<Id>();
        Map<Id, Map<String, Booking_Condition__c>> fromTxn = new Map<Id, Map<String, Booking_Condition__c>>();

        for (Booking_Condition__c r : rows) {
            if (r == null || r.Opportunity__c == null) continue;
            opps.add(r.Opportunity__c);

            if (CONTEXT_TYPES.contains(r.Condition_Type__c)) {
                if (!fromTxn.containsKey(r.Opportunity__c))
                    fromTxn.put(r.Opportunity__c, new Map<String, Booking_Condition__c>());
                fromTxn.get(r.Opportunity__c).put(r.Condition_Type__c, r);
            }
        }

        Map<Id, Map<String, Booking_Condition__c>> fromDb = new Map<Id, Map<String, Booking_Condition__c>>();
        if (!opps.isEmpty()) {
            for (Booking_Condition__c bc : [
                SELECT Id, Opportunity__c, Condition_Type__c, Type__c,
                       Amount__c, Percentage__c, Quantity__c, Amount_By_Type__c
                  FROM Booking_Condition__c
                 WHERE Opportunity__c IN :opps
                   AND Condition_Type__c IN :CONTEXT_TYPES
            ]) {
                if (!fromDb.containsKey(bc.Opportunity__c))
                    fromDb.put(bc.Opportunity__c, new Map<String, Booking_Condition__c>());
                fromDb.get(bc.Opportunity__c).put(bc.Condition_Type__c, bc);
            }
        }

        Map<Id, Map<String, Booking_Condition__c>> res = fromDb;
        for (Id oppId : fromTxn.keySet()) {
            if (!res.containsKey(oppId))
                res.put(oppId, new Map<String, Booking_Condition__c>());
            res.get(oppId).putAll(fromTxn.get(oppId));
        }
        return res;
    }

    private static Map<Id, Map<String, Booking_Condition__c>> contextPerOppFromDb(Set<Id> oppIds){
        Map<Id, Map<String, Booking_Condition__c>> res = new Map<Id, Map<String, Booking_Condition__c>>();
        if (oppIds == null || oppIds.isEmpty()) return res;

        Set<String> need = new Set<String>(); need.addAll(CONTEXT_TYPES);

        for (Booking_Condition__c bc : [
            SELECT Id, Opportunity__c, Condition_Type__c, Type__c,
                   Amount__c, Percentage__c, Quantity__c, Amount_By_Type__c
              FROM Booking_Condition__c
             WHERE Opportunity__c IN :oppIds
               AND Condition_Type__c IN :need
        ]) {
            if (!res.containsKey(bc.Opportunity__c)) res.put(bc.Opportunity__c, new Map<String, Booking_Condition__c>());
            res.get(bc.Opportunity__c).put(bc.Condition_Type__c, bc);
        }
        return res;
    }

    // ---------- numbering & metadata helpers (unchanged) ----------
    public static void updateTypeInBookCond(List<Booking_Condition__c> newList){
        try {
            List<ConditionTypeCode__mdt> mdts = ConditionTypeCode__mdt.getAll().values();
            for (Booking_Condition__c bc : newList){
                for (ConditionTypeCode__mdt mdt : mdts){
                    if (bc.Condition_Type__c == mdt.MasterLabel && mdt.Type__c != null){
                        bc.Type__c  = mdt.Type__c;
                        bc.Order__c = mdt.Order__c;
                        bc.UOM__c = mdt.UOM__c;
                    }
                }
            }
        } catch (Exception ex) {
            ExceptionLogger.logException(
                new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('Booking Condition Before insert Trigger')
                .withClassName('BookingConditionHelper')
                .withMethodName('updateTypeInBookCond')
                .withDescription('Failed to update Type via metadata')
                .withException(ex)
            );
        }
    }

    public static void assignItemNumbers(List<Booking_Condition__c> newList) {
        try{
            Set<Id> bookingIds = new Set<Id>(), oppIds = new Set<Id>();
            for (Booking_Condition__c bc : newList) {
                if (bc.Booking__c != null) bookingIds.add(bc.Booking__c);
                else if (bc.Opportunity__c != null) oppIds.add(bc.Opportunity__c);
            }
            Map<Id, Integer> maxByParent = new Map<Id, Integer>();
            if (!bookingIds.isEmpty()){
                for (AggregateResult ar : [
                    SELECT Booking__c b, MAX(Item_Number__c) m FROM Booking_Condition__c
                    WHERE Booking__c IN :bookingIds GROUP BY Booking__c
                ]) maxByParent.put((Id)ar.get('b'), ((Decimal)ar.get('m')==null)?0:((Decimal)ar.get('m')).intValue());
            }
            if (!oppIds.isEmpty()){
                for (AggregateResult ar : [
                    SELECT Opportunity__c o, MAX(Item_Number__c) m FROM Booking_Condition__c
                    WHERE Opportunity__c IN :oppIds GROUP BY Opportunity__c
                ]) maxByParent.put((Id)ar.get('o'), ((Decimal)ar.get('m')==null)?0:((Decimal)ar.get('m')).intValue());
            }
            for (Booking_Condition__c bc : newList) {
                Id parent = (bc.Booking__c!=null)?bc.Booking__c:bc.Opportunity__c;
                if (CONDITION_BASE.equals(bc.Condition_Type__c)) {
                    bc.Item_Number__c = 1;
                } else if (bc.Item_Number__c == null) {
                    Integer cur = maxByParent.containsKey(parent)?maxByParent.get(parent):1;
                    cur++; bc.Item_Number__c = cur; maxByParent.put(parent, cur);
                }
            }
        } catch (Exception ex) {
            ExceptionLogger.logException(
                new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('Booking Condition Before insert Trigger')
                .withClassName('BookingConditionHelper')
                .withMethodName('assignItemNumbers')
                .withDescription('Failed to assign Item Number')
                .withException(ex)
            );
        }
    }

    // Recalc survivors when a condition row is deleted
    public static void recalcSiblingsOnDelete(List<Booking_Condition__c> oldList) {
        if (oldList == null || oldList.isEmpty()) return;

        Set<Id> opps = new Set<Id>();
        for (Booking_Condition__c r : oldList) {
            if (r == null || r.Opportunity__c == null) continue;
            if (r.Condition_Type__c == CONDITION_BASE ||
                r.Condition_Type__c == CONDITION_BASE_DISCOUNT ||
                OTHER_CHARGE_TYPES.contains(r.Condition_Type__c) ||
                TAX_TYPES.contains(r.Condition_Type__c)) {
                opps.add(r.Opportunity__c);
            }
        }
        if (opps.isEmpty()) return;

        Map<Id, Map<String, Booking_Condition__c>> ctx = contextPerOppFromDb(opps);
        Map<Id, Core> coreByOpp = buildCorePerOpp(ctx);

        List<Booking_Condition__c> survivors = [
            SELECT Id, Opportunity__c, Condition_Type__c, Type__c,
                   Amount__c, Percentage__c, Quantity__c, Amount_By_Type__c
              FROM Booking_Condition__c
             WHERE Opportunity__c IN :opps
        ];

        // Sum taxable OTHER CHARGES from persisted Amount_By_Type__c
        Map<Id, Decimal> otherSumByOpp = new Map<Id, Decimal>();
        for (Booking_Condition__c bc : survivors) {
            if (!OTHER_CHARGE_TYPES.contains(bc.Condition_Type__c)) continue;
            Decimal add = nz(bc.Amount_By_Type__c);
            otherSumByOpp.put(
                bc.Opportunity__c,
                (otherSumByOpp.containsKey(bc.Opportunity__c) ? otherSumByOpp.get(bc.Opportunity__c) : 0) + add
            );
        }

        List<Booking_Condition__c> updates = new List<Booking_Condition__c>();
        for (Booking_Condition__c bc : survivors) {
            Core core = coreByOpp.get(bc.Opportunity__c);
            if (core == null) core = new Core();

            Decimal newAmt;
            if (CONDITION_BASE_DISCOUNT.equals(bc.Condition_Type__c)) {
                newAmt = core.discountedBaseTotal;
            } else if (TAX_TYPES.contains(bc.Condition_Type__c)) {
                Decimal pct  = (bc.Percentage__c == null) ? 0 : bc.Percentage__c;
                Decimal base = nz(otherSumByOpp.get(bc.Opportunity__c));
                newAmt = (base * (pct/100)).setScale(2, RoundingMode.HALF_UP);
            } else {
                newAmt = amountForRowUsingCore(bc, core, false);
            }

            if (bc.Amount_By_Type__c != newAmt) {
                updates.add(new Booking_Condition__c(Id = bc.Id, Amount_By_Type__c = newAmt));
            }
        }
        if (!updates.isEmpty()) update updates;
    }
}