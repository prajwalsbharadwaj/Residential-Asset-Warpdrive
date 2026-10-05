public with sharing class FinancePolicyProvider {
    public class Policy {
        public Integer graceDays;
        public Decimal annualRate;
        public Decimal taxRate;

        public Policy(Decimal annualRate, Integer graceDays, Decimal taxRate) {
            this.annualRate = nz(annualRate);
            this.graceDays = graceDays == null ? 0 : Integer.valueOf(graceDays);
            this.taxRate = nz(taxRate);
        }
    }

    private static final String DEFAULT_KEY = 'default';
    private static Map<String, Policy> policiesByLabel;
    private static Policy defaultPolicy;
    private static Policy testOverride;

    public static Policy get() {
        if (testOverride != null) {
            return clonePolicy(testOverride);
        }
        ensureLoaded();
        return clonePolicy(defaultPolicy);
    }

    public static Policy forOpportunity(Opportunity opp) {
        if (testOverride != null) {
            return clonePolicy(testOverride);
        }
        return lookupPolicy(extractPropertyName(opp));
    }

    public static Policy forBooking(Booking__c booking) {
        if (testOverride != null) {
            return clonePolicy(testOverride);
        }
        return lookupPolicy(extractPropertyName(booking));
    }

    public static void setTestPolicy(Policy policy) {
        testOverride = policy == null ? null : clonePolicy(policy);
    }

    public static void clearTestOverride() {
        testOverride = null;
    }

    public static void clearCache() {
        policiesByLabel = null;
        defaultPolicy = null;
    }

    public static Integer graceDays() {
        return get().graceDays;
    }

    public static Decimal annualRatePct() {
        return get().annualRate;
    }

    public static Decimal interestTaxPct() {
        return get().taxRate;
    }

    public static Decimal nz(Decimal value) {
        return value == null ? 0 : value;
    }

    public static Integer daysNonNeg(Date startIncl, Date endIncl) {
        if (startIncl == null || endIncl == null || startIncl > endIncl) {
            return 0;
        }
        return startIncl.daysBetween(endIncl) + 1;
    }

    @TestVisible
    static void reset() {
        clearTestOverride();
        clearCache();
    }

    // -------- Internal helpers --------
    private static void ensureLoaded() {
        if (policiesByLabel != null) {
            return;
        }
        policiesByLabel = new Map<String, Policy>();

        Map<String, Finance_Policy__mdt> allPolicies = Finance_Policy__mdt.getAll();
        for (Finance_Policy__mdt record : allPolicies.values()) {
            String label = deriveLabel(record);
            if (String.isBlank(label)) {
                continue;
            }
            String key = label.toLowerCase();
            Policy policy = fromMetadata(record);
            policiesByLabel.put(key, policy);

            if (DEFAULT_KEY.equals(key) || 'default'.equalsIgnoreCase(record.DeveloperName)) {
                defaultPolicy = policy;
            }
        }

        if (defaultPolicy == null) {
            defaultPolicy = new Policy(0, 0, 0);
            policiesByLabel.put(DEFAULT_KEY, defaultPolicy);
        }
    }

    private static Policy lookupPolicy(String propertyName) {
        ensureLoaded();
        if (String.isBlank(propertyName)) {
            return clonePolicy(defaultPolicy);
        }
        String normalized = propertyName.toLowerCase();
        for (String key : policiesByLabel.keySet()) {
            if (DEFAULT_KEY.equals(key)) {
                continue;
            }
            if (normalized.contains(key)) {
                return clonePolicy(policiesByLabel.get(key));
            }
        }
        return clonePolicy(defaultPolicy);
    }

    private static Policy fromMetadata(Finance_Policy__mdt record) {
        Decimal annual = record.Default_Annual_Interest_Rate__c;
        Integer grace = record.Grace_Period_Days__c == null ? 0 : Integer.valueOf(record.Grace_Period_Days__c);
        Decimal tax = record.GSTVATRateOnInterest__c;
        return new Policy(annual, grace, tax);
    }

    private static String deriveLabel(Finance_Policy__mdt record) {
        if (record == null) {
            return null;
        }
        if (!String.isBlank(record.MasterLabel)) {
            return record.MasterLabel;
        }
        return record.DeveloperName;
    }

    private static String extractPropertyName(Opportunity opp) {
        if (opp == null) {
            return null;
        }
        if (opp.Interested_Unit__r != null && opp.Interested_Unit__r.Property__r != null && !String.isBlank(opp.Interested_Unit__r.Property__r.Name)) {
            return opp.Interested_Unit__r.Property__r.Name;
        }
        return null;
    }

    private static String extractPropertyName(Booking__c booking) {
        if (booking == null) {
            return null;
        }
        if (booking.Unit_Id__r != null && booking.Unit_Id__r.Property__r != null && !String.isBlank(booking.Unit_Id__r.Property__r.Name)) {
            return booking.Unit_Id__r.Property__r.Name;
        }
        return null;
    }

    private static Policy clonePolicy(Policy input) {
        if (input == null) {
            return null;
        }
        return new Policy(input.annualRate, input.graceDays, input.taxRate);
    }
}