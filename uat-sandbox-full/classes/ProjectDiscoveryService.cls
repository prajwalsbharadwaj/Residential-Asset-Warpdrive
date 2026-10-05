public with sharing class ProjectDiscoveryService {
    
    public class ProjectOutput {
        @InvocableVariable public String cityName;
    }

    @InvocableMethod(
        label='Get Available Cities'
        description='Returns unique project cities'
    )
    public static List<List<ProjectOutput>> getProjects(List<String> searchKeywords) {

        List<ProjectOutput> results = new List<ProjectOutput>();

        for (AggregateResult ar : [
            SELECT Location__City__s city
            FROM Property__c
            WHERE RecordType.DeveloperName = 'Residential_Project'
            AND Location__City__s != NULL
            GROUP BY Location__City__s
            ORDER BY Location__City__s
        ]) {

            ProjectOutput out = new ProjectOutput();
            out.cityName = (String) ar.get('city');

            results.add(out);
        }

        return new List<List<ProjectOutput>>{ results };
    }
}