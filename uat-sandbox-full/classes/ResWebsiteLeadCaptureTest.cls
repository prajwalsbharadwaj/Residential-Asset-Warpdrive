@isTest
private class ResWebsiteLeadCaptureTest {
    private static void setJsonRequest(Map<String, Object> body) {
        RestContext.request = new RestRequest();
        RestContext.request.httpMethod = 'POST';
        RestContext.request.requestURI = '/services/apexrest/website-lead';
        RestContext.request.addHeader('Content-Type', 'application/json');
        RestContext.request.requestBody = Blob.valueOf(JSON.serialize(body));
        RestContext.response = new RestResponse();
    }

    @isTest
    static void testCreateLeadFromJson_Kessaku() {
        setJsonRequest(new Map<String, Object>{
            'lead_source' => 'Website Lead (KESSAKU)',
            'url' => 'https://www.kessaku.in/',
            'project_name' => 'Kessaku',
            'first_name' => 'John',
            'last_name' => 'Doe',
            'email' => 'john.doe@example.com',
            'phone' => '9999999999',
            'interested_in_site_visit' => 'Yes'
        });

        Test.startTest();
        ResWebsiteLeadCapture.createLead();
        Test.stopTest();

        System.assertEquals(201, RestContext.response.statusCode);
        Lead createdLead = [
            SELECT FirstName, LastName, Email, Phone, LeadSource, Projects__c, Interested_in_Site_Visit__c, Company, Website, Status
            FROM Lead
            WHERE Email = 'john.doe@example.com'
            LIMIT 1
        ];
        System.assertEquals('John', createdLead.FirstName);
        System.assertEquals('Doe', createdLead.LastName);
        System.assertEquals('Website Lead (KESSAKU)', createdLead.LeadSource);
        System.assertEquals('Kessaku', createdLead.Projects__c);
        System.assertEquals('Yes', createdLead.Interested_in_Site_Visit__c);
        System.assertEquals('Individual', createdLead.Company);
        System.assertEquals('https://www.kessaku.in/', createdLead.Website);
        System.assertEquals('Enquiry', createdLead.Status);
    }

    @isTest
    static void testCreateLeadFromJson_Obw() {
        setJsonRequest(new Map<String, Object>{
            'lead_source' => 'Website Lead (One Bangalore West)',
            'url' => 'https://www.onebangalorewest.in/luxury-apartments-in-rajajinagar-bangalore/',
            'project_name' => 'One Bangalore West',
            'first_name' => 'Jane',
            'last_name' => 'Smith',
            'email' => 'jane.smith@example.com',
            'phone' => '8888888888',
            'interested_in_site_visit' => 'No'
        });

        Test.startTest();
        ResWebsiteLeadCapture.createLead();
        Test.stopTest();

        System.assertEquals(201, RestContext.response.statusCode);
        Lead createdLead = [
            SELECT FirstName, LastName, LeadSource, Projects__c, Interested_in_Site_Visit__c, Website
            FROM Lead
            WHERE Email = 'jane.smith@example.com'
            LIMIT 1
        ];
        System.assertEquals('Website Lead (One Bangalore West)', createdLead.LeadSource);
        System.assertEquals('One Bangalore West', createdLead.Projects__c);
        System.assertEquals('No', createdLead.Interested_in_Site_Visit__c);
        System.assertEquals('https://www.onebangalorewest.in/luxury-apartments-in-rajajinagar-bangalore/', createdLead.Website);
    }

    @isTest
    static void testCreateLead_FirstNameOptional() {
        setJsonRequest(new Map<String, Object>{
            'lead_source' => 'Website Lead (Kessaku)',
            'url' => 'https://www.kessaku.in/',
            'project_name' => 'Kessaku',
            'last_name' => 'Solo',
            'email' => 'solo@example.com',
            'phone' => '7777777777'
        });

        Test.startTest();
        ResWebsiteLeadCapture.createLead();
        Test.stopTest();

        System.assertEquals(201, RestContext.response.statusCode);
        Lead createdLead = [
            SELECT FirstName, LastName
            FROM Lead
            WHERE Email = 'solo@example.com'
            LIMIT 1
        ];
        System.assertEquals(null, createdLead.FirstName);
        System.assertEquals('Solo', createdLead.LastName);
    }

    @isTest
    static void testCreateLead_MissingFields() {
        setJsonRequest(new Map<String, Object>{
            'first_name' => 'OnlyFirstName'
        });

        Test.startTest();
        ResWebsiteLeadCapture.createLead();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('Missing mandatory fields'));
    }
}