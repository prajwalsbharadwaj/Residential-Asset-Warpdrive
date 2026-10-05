@RestResource(urlMapping='/website-lead')
global with sharing class ResWebsiteLeadCapture {
    private static final String COMPONENT = 'ResWebsiteLeadCapture Inbound class';
    private static final String CLASS_NAME = 'ResWebsiteLeadCapture';
    private static final String METHOD_NAME = 'createLead';
    private static final String ENDPOINT = '/website-lead';
    private static final String RECORD_TYPE_DEV_NAME = 'Standard_Lead_Residential';
    private static Id residentialLeadRecordTypeId;

    global class WebsiteLeadRequest {
        public String lead_source;
        public String url;
        public String project_name;
        public String first_name;
        public String last_name;
        public String email;
        public String phone;
        public String interested_in_site_visit;
    }

    @HttpPost
    global static void createLead() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        String requestBody;
        try {
            requestBody = req.requestBody == null ? null : req.requestBody.toString();
            if (String.isBlank(requestBody) || requestBody.trim() == '{}' || requestBody.trim() == '[]') {
                respondError(res, 400, 'Request body cannot be empty.', requestBody, 'Invalid request body', null);
                return;
            }

            WebsiteLeadRequest leadInput;
            try {
                leadInput = (WebsiteLeadRequest) JSON.deserialize(requestBody, WebsiteLeadRequest.class);
            } catch (System.JSONException ex) {
                respondError(res, 400, 'Invalid JSON format: ' + ex.getMessage(),
                    requestBody, 'Invalid JSON format', ex
                );
                return;
            }
            List<String> missingFields = validateRequiredFields(leadInput);
            if (!missingFields.isEmpty()) {
                respondError(
                    res,
                    400,
                    'Missing mandatory fields: ' + String.join(missingFields, ', '),
                    requestBody,
                    'Missing mandatory fields',
                    null
                );
                return;
            }

            Id recordTypeId = getResidentialLeadRecordTypeId();
            if (recordTypeId == null) {
                respondError(res, 500, 'Residential lead record type is not configured.', requestBody, 'Missing record type', null);
                return;
            }

            Lead newLead = new Lead();
            newLead.FirstName = leadInput.first_name;
            newLead.LastName = leadInput.last_name;
            newLead.Email = leadInput.email;
            newLead.Phone = leadInput.phone;
            newLead.Website = leadInput.url;
            newLead.Company = 'Individual';
            newLead.Status = 'Enquiry';
            newLead.RecordTypeId = recordTypeId;
            newLead.Projects__c = normalizeProjectName(leadInput.project_name);
            newLead.LeadSource = leadInput.lead_source;

            if (String.isNotBlank(leadInput.interested_in_site_visit)) {
                newLead.Interested_in_Site_Visit__c = leadInput.interested_in_site_visit;
            }

            Database.DMLOptions dml = new Database.DMLOptions();
            dml.DuplicateRuleHeader.allowSave = true;
            dml.assignmentRuleHeader.useDefaultRule = true;
            Database.SaveResult saveResult = Database.insert(newLead, dml);

            if (saveResult.isSuccess()) {
                res.statusCode = 201;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                    'status' => 'success',
                    'message' => 'Lead created successfully.',
                    'leadId' => saveResult.getId()
                }));
                return;
            }

            String errorMessage = '';
            for (Database.Error err : saveResult.getErrors()) {
                errorMessage += err.getMessage() + ' ';
            }

            respondError(
                res, 400, 'Failed to create lead: ' + errorMessage.trim(),
                requestBody, 'Error while inserting lead', null
            );
        } catch (Exception ex) {
            respondError(
                res, 500, 'An unexpected error occurred: ' + ex.getMessage(),
                requestBody, 'Unhandled exception', ex
            );
        }
    }

    private static List<String> validateRequiredFields(WebsiteLeadRequest leadInput) {
        List<String> missingFields = new List<String>();
        if (leadInput == null) {
            missingFields.addAll(new List<String>{ 'last_name', 'email', 'phone', 'project_name', 'lead_source' });
            return missingFields;
        }

        if (String.isBlank(leadInput.last_name)) missingFields.add('last_name');
        if (String.isBlank(leadInput.email)) missingFields.add('email');
        if (String.isBlank(leadInput.phone)) missingFields.add('phone');
        if (String.isBlank(leadInput.project_name)) missingFields.add('project_name');
        if (String.isBlank(leadInput.lead_source)) missingFields.add('lead_source');
        return missingFields;
    }

    private static Id getResidentialLeadRecordTypeId() {
        if (residentialLeadRecordTypeId != null) {
            return residentialLeadRecordTypeId;
        }

        Schema.RecordTypeInfo rtInfo = Schema.SObjectType.Lead
            .getRecordTypeInfosByDeveloperName()
            .get(RECORD_TYPE_DEV_NAME);
        residentialLeadRecordTypeId = rtInfo == null ? null : rtInfo.getRecordTypeId();
        return residentialLeadRecordTypeId;
    }

    private static String normalizeProjectName(String projectName) {
        if (projectName == 'Phoenix Kessaku') {
            return 'Kessaku';
        }
        return projectName;
    }

    private static void respondError(
        RestResponse res,
        Integer statusCode,
        String message,
        String requestBody,
        String description,
        Exception ex
    ) {
        res.statusCode = statusCode;
        res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
            'status' => 'error',
            'message' => message
        }));

        ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
            .withComponentName(COMPONENT)
            .withDescription(description)
            .withClassName(CLASS_NAME)
            .withMethodName(METHOD_NAME)
            .withRequestBody(requestBody)
            .withResponseBody(res.responseBody.toString())
            .withEndpoint(ENDPOINT)
            .withDomain('Website');

        if (ex != null) {
            payload.withException(ex);
        }

        ExceptionLogger.logException(payload);
    }
}