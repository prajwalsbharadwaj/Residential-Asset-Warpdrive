public with sharing class ProjectInCityService {
    
    public class CityInput {
        @InvocableVariable(label='City Name' required=true)
        public String cityName;
    }

    public class ProjectOutput {
        @InvocableVariable(label='Project Name')
        public String projectName;
        
        @InvocableVariable(label='Project ID')
        public String projectId;
    }

    @InvocableMethod(
        label='Get Projects in Selected City'
        description='Returns a list of Project Names and IDs for a specific city'
    )
    public static List<List<ProjectOutput>> getProjectsByCity(List<CityInput> inputs) {

        List<ProjectOutput> results = new List<ProjectOutput>();
        
        // Get the city name from the input
        String selectedCity = inputs[0].cityName;

        for (Property__c p : [
            SELECT Id, Name
            FROM Property__c
            WHERE Location__City__s = :selectedCity
            AND RecordType.DeveloperName = 'Residential_Project'
            ORDER BY Name
        ]) {

            ProjectOutput out = new ProjectOutput();
            out.projectName = p.Name;
            out.projectId = p.Id;

            results.add(out);
        }

        // Return as List of List for Agentforce compatibility
        return new List<List<ProjectOutput>>{ results };
    }
}