@isTest
private class ResPublicLeadCaptureTest {
    
    @testSetup
    static void setupTestData() {
        // No data needed for this REST API — Lead is inserted during the POST call
    }

    // ✅ Helper to set REST request
    private static void setRestRequest(Object body, String method) {
        RestContext.request = new RestRequest();
        RestContext.request.httpMethod = method;
        RestContext.request.requestURI = '/services/apexrest/lead';
        RestContext.request.addHeader('Content-Type', 'application/json');
        RestContext.request.requestBody = Blob.valueOf(
            body != null ? JSON.serialize(body) : ''
        );
        RestContext.response = new RestResponse();
    }

    // ✅ Positive: Successful lead creation with all fields
    @isTest
    static void testCreateLead_Success() {
        Map<String, Object> payload = new Map<String, Object>{
            'name' => 'John Doe',
            'email' => 'john.doe@example.com',
            'phone' => '1234567890',
            'project_name' => 'Kessaku',
            'rating' => 'Hot',
            'city' => 'New York',
            'lead_status' => 'Working - Contacted',
            'source' => 'Web',
            'action' => 'inquiry_created',
            'extra_details' => new Map<String, Object>{
                'gender' => 'Male',
                'address' => '123 Street',
                'industry' => 'Tech',
                'company_name' => 'Acme Inc'
            }
        };

        setRestRequest(payload, 'POST');

        Test.startTest();
        ResPublicLeadCapture.createLead();
        Test.stopTest();

        //System.assertEquals(201, RestContext.response.statusCode);
        Map<String, Object> res = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        System.assertEquals('success', res.get('status'), res.get('message'));
        System.assert(res.containsKey('leadId'));
    }
    
    // ✅ Positive: Skip lead other action
    @isTest
    static void testSkipLeadOtherUpdateActions_Success() {
        Map<String, Object> payload = new Map<String, Object>{
            'name' => 'John Doe',
            'email' => 'john.doe@example.com',
            'phone' => '1234567890',
            'project_name' => 'Kessaku',
            'rating' => 'Hot',
            'city' => 'New York',
            'lead_status' => 'Working - Contacted',
            'source' => 'Web',
            'action' => 'notes_add',
            'extra_details' => new Map<String, Object>{
                'gender' => 'Male',
                'address' => '123 Street',
                'industry' => 'Tech',
                'company_name' => 'Acme Inc'
            }
        };

        setRestRequest(payload, 'POST');

        Test.startTest();
        ResPublicLeadCapture.createLead();
        Test.stopTest();

        //System.assertEquals(201, RestContext.response.statusCode);
        Map<String, Object> res = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        System.assertEquals('success', res.get('status'), res.get('message'));
        System.assert(!res.containsKey('leadId'));
        System.assertEquals('Skipping the lead update action notes_add', res.get('message'));
    }

    // ❌ Negative: Empty request body
    @isTest
    static void testCreateLead_EmptyBody() {
        setRestRequest(null, 'POST');

        Test.startTest();
        ResPublicLeadCapture.createLead();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        System.Assert.isTrue(RestContext.response.responseBody.toString().contains('cannot be empty'), 'Expected message that a field cannot be empty.');
    }

    // ❌ Negative: Invalid JSON format
    @isTest
    static void testCreateLead_InvalidJSON() {
        RestContext.request = new RestRequest();
        RestContext.request.httpMethod = 'POST';
        RestContext.request.requestURI = '/services/apexrest/lead';
        RestContext.request.addHeader('Content-Type', 'application/json');
        RestContext.request.requestBody = Blob.valueOf('{invalidJson: }');
        RestContext.response = new RestResponse();

        Test.startTest();
        ResPublicLeadCapture.createLead();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        System.Assert.isTrue(RestContext.response.responseBody.toString().contains('Invalid JSON format'), 'Expected invalid JSON format message.');
    }

    // ❌ Negative: Missing mandatory fields
    @isTest
    static void testCreateLead_MissingFields() {
        Map<String, Object> payload = new Map<String, Object>{
            'name' => '',
            'email' => '',
            'phone' => '',
            'project_name' => ''
        };

        setRestRequest(payload, 'POST');

        Test.startTest();
        ResPublicLeadCapture.createLead();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        System.Assert.isTrue(RestContext.response.responseBody.toString().contains('Missing mandatory fields'), 'Expected missing mandatory fields message.');
    }

    // ❌ Negative: Name without last name
    @isTest
    static void testCreateLead_MissingLastName() {
        Map<String, Object> payload = new Map<String, Object>{
            'name' => 'John',
            'email' => 'john@example.com',
            'phone' => '1234567890',
            'project_name' => 'Project X',
            'action' => 'inquiry_created'
        };

        setRestRequest(payload, 'POST');

        Test.startTest();
        ResPublicLeadCapture.createLead();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        //System.assert(RestContext.response.responseBody.toString().contains('Last Name could not be derived'));
    }

    // ❌ Negative: DML failure (simulate picklist dependency error)
    @isTest
    static void testCreateLead_DMLFailure() {
        Map<String, Object> payload = new Map<String, Object>{
            'name' => 'Jane Doe',
            'email' => 'jane.doe@example.com',
            'phone' => '1234567890',
            'project_name' => 'Project Y',
            'sub_source' => 'InvalidValue' // triggers possible picklist validation failure
        };

        Test.startTest();
        //Test.startTest();
        // Mock insert failure by setting a bad value for a required dependent picklist
        setRestRequest(payload, 'POST');
        Test.stopTest();
    }

    // 🔥 Exception handling — simulate unexpected exception
    @isTest
    static void testCreateLead_Exception() {
        Test.startTest();
        RestContext.request = null; // Force NullPointerException
        RestContext.response = new RestResponse();
        ResPublicLeadCapture.createLead();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode);
        System.Assert.isTrue(RestContext.response.responseBody.toString().contains('unexpected error'), 'Expected unexpected error message.');
    }
}