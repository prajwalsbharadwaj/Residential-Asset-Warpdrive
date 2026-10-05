@RestResource(urlMapping='/lead')
global class ResPublicLeadCapture {
	public static Id RT_ID_LEAD_RESIDENTIAL;
    
    static {
        Map<String, Schema.RecordTypeInfo> recordTypeInfoByDevName = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName();
        RT_ID_LEAD_RESIDENTIAL = recordTypeInfoByDevName.get('Standard_Lead_Residential').getRecordTypeId();
    }
    
    @HttpPost
    global static void createLead() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        
        String jsonBody;

        try {
            jsonBody = req.requestBody.toString();
            if (String.isBlank(jsonBody) || jsonBody.trim() == '{}' || jsonBody.trim() == '[]') {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                    'status' => 'error',
                    'message' => 'Request body cannot be empty.'
                }));
                ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload().withComponentName('ResPublicLeadCapture Inbound class').withDescription('Invalid request body').withClassName('ResPublicLeadCapture').withMethodName('createLead').withRequestBody(jsonBody).withResponseBody(res.responseBody.toString()).withEndpoint('/lead').withDomain('SAP');
                ExceptionLogger.logException(payload);
                return;
            }

            ExternalLeadWrapper leadInput;
            try {
                leadInput = (ExternalLeadWrapper) JSON.deserialize(jsonBody, ExternalLeadWrapper.class);
            } catch (System.JSONException e) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                    'status' => 'error',
                    'message' => 'Invalid JSON format: ' + e.getMessage()
                }));
                ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload().withComponentName('ResPublicLeadCapture Inbound class').withDescription('HTTP Error: 400').withClassName('ResPublicLeadCapture').withMethodName('createLead').withRequestBody(jsonBody).withResponseBody(res.responseBody.toString()).withEndpoint('/lead').withDomain('SAP');
                ExceptionLogger.logException(payload);
                return;
            }

            List<String> missingFields = new List<String>();
            if (String.isBlank(leadInput.name)) missingFields.add('name');
            if (String.isBlank(leadInput.email)) missingFields.add('email');
            if (String.isBlank(leadInput.phone)) missingFields.add('phone');
            if (String.isBlank(leadInput.project_name)) missingFields.add('project_name');

            if (!missingFields.isEmpty()) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                    'status' => 'error',
                    'message' => 'Missing mandatory fields: ' + String.join(missingFields, ', ')
                }));
                ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload().withComponentName('ResPublicLeadCapture Inbound class').withDescription('Missing mandatory fields').withClassName('ResPublicLeadCapture').withMethodName('createLead').withRequestBody(jsonBody).withResponseBody(res.responseBody.toString()).withEndpoint('/lead').withDomain('SAP');
                ExceptionLogger.logException(payload);
                return;
            }

            String firstName = '';
            String lastName = '';
            if (String.isNotBlank(leadInput.name)) {
                List<String> nameParts = leadInput.name.trim().split(' ', 2);
                if (nameParts.size() > 1) {
                    firstName = nameParts[0];
                    lastName = nameParts[1];
                } else {
                    lastName = nameParts[0];
                }
            }

            if (String.isBlank(lastName)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                    'status' => 'error',
                    'message' => 'Last Name could not be derived from the name field.'
                }));
                return;
            }
            
            if(leadInput.action != 'inquiry_created'){
                res.statusCode = 200;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                    'status' => 'success',
                    'message' => 'Skipping the lead update action ' + leadInput.action
                }));
                return;
            }
            
            Lead newLead = new Lead();
            newLead.FirstName = firstName;
            newLead.LastName = lastName;
            newLead.Email = leadInput.email;
            newLead.Phone = leadInput.phone;
            newLead.Projects__c = leadInput.project_name == 'Phoenix Kessaku' ? 'Kessaku' : leadInput.project_name;
            newLead.Rating = leadInput.rating;
            newLead.City = leadInput.city;
            newLead.RecordTypeId = RT_ID_LEAD_RESIDENTIAL;
            
            newLead.Status = String.isNotBlank(leadInput.lead_status) ? (leadInput.lead_status == 'Fresh' ? 'New' : leadInput.lead_status)  : 'New';
            
            // *** NEW: Map Lead Source and Sub-source ***
            if (String.isNotBlank(leadInput.source)) {
                newLead.LeadSource = leadInput.source;
            }
            
            // Map dependent Lead Sub-source field
            // Assumes a custom field named Lead_Subsource__c
            // Salesforce will validate the dependency automatically on insert
            if (String.isNotBlank(leadInput.sub_source)) {
                newLead.Lead_Subsource__c = leadInput.sub_source; 
            }

            if (leadInput.extra_details != null) {
                newLead.GenderIdentity = leadInput.extra_details.gender;
                newLead.Street = leadInput.extra_details.address;
                newLead.Industry = leadInput.extra_details.industry;
                newLead.Company = String.isNotBlank(leadInput.extra_details.company_name) 
                                ? leadInput.extra_details.company_name : 'Individual';
            } else {
                newLead.Company = 'Individual';
            }
            
            Database.DMLOptions dml = new Database.DMLOptions();
            dml.DuplicateRuleHeader.allowSave = true;
			dml.assignmentRuleHeader.useDefaultRule = true;
            Database.SaveResult sr = Database.insert(newLead, dml);

            if (sr.isSuccess()) {
                res.statusCode = 201;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                    'status' => 'success',
                    'message' => 'Lead created successfully.',
                    'leadId' => sr.getId()
                }));
            } else {
                String errorMessage = '';
                for (Database.Error err : sr.getErrors()) {
                    // This will catch dependency errors, e.g., "bad value for restricted picklist"
                    errorMessage += err.getMessage() + ' ';
                }
                
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                    'status' => 'error',
                    'message' => 'Failed to create lead: ' + errorMessage.trim()
                }));
                
                ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload().withComponentName('ResPublicLeadCapture Inbound class').withDescription('Error while inserting lead').withClassName('ResPublicLeadCapture').withMethodName('createLead').withRequestBody(jsonBody).withResponseBody(res.responseBody.toString()).withEndpoint('/lead').withDomain('SAP');
                ExceptionLogger.logException(payload);
            }

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                'status' => 'error',
                'message' => 'An unexpected error occurred: ' + e.getMessage()
            }));
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload().withComponentName('ResPublicLeadCapture Inbound class').withDescription('HTTP Error: 400').withClassName('ResPublicLeadCapture').withMethodName('createLead').withRequestBody(jsonBody).withResponseBody(res.responseBody.toString()).withEndpoint('/lead').withDomain('SAP');
            ExceptionLogger.logException(payload);
        }
    }
}