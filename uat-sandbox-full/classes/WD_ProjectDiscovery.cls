public with sharing class WD_ProjectDiscovery {

    // Wrapper for Agentforce to show clickable options
    public class DiscoveryOption {
        @InvocableVariable(label='Label' description='Display name for the user')
        public String label;
        @InvocableVariable(label='Value' description='ID or API Name to store')
        public String value;
    }

    public class DiscoveryRequest {
        @InvocableVariable(label='City Name' description='Optional: Pass a city to get its projects')
        public String cityName;
    }

    @InvocableMethod(label='Get Cities or Projects' description='Returns list of cities or projects in Label/Value format')
    public static List<List<DiscoveryOption>> discover(List<DiscoveryRequest> requests) {
        List<DiscoveryOption> options = new List<DiscoveryOption>();
        String selectedCity = (requests != null && !requests.isEmpty()) ? requests[0].cityName : null;

        if (String.isBlank(selectedCity)) {
            // SCENARIO 1: No city provided, return unique list of Cities
            for (AggregateResult ar : [SELECT Location__City__s city FROM Property__c where RecordType.DeveloperName ='Residential_Project' GROUP BY Location__City__s]) {
                String cityName = (String)ar.get('city');
                if (cityName != null) {
                    DiscoveryOption opt = new DiscoveryOption();
                    opt.label = cityName;
                    opt.value = cityName;
                    options.add(opt);
                }
            }
        } else {
            // SCENARIO 2: City provided, return Projects in that City
            for (Property__c p : [SELECT Id, Name FROM Property__c WHERE Location__City__s = :selectedCity]) {
                DiscoveryOption opt = new DiscoveryOption();
                opt.label = p.Name;
                opt.value = p.Id; // Value is ID for Site Visit creation
                options.add(opt);
            }
        }
        return new List<List<DiscoveryOption>>{options};
    }
}