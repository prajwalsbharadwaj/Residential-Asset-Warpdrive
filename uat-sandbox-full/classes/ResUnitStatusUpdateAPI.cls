@RestResource(urlMapping='/sap/v1/unit-status/*')
global without sharing class ResUnitStatusUpdateAPI {

    // Inner class for deserializing the JSON payload from SAP
    public class UnitStatusPayload {
        public String unitId;       // SAP external ID
        public String statusCode;   // Incoming SAP Status Code (e.g., Z0, Z1) - renamed from 'status'
        public Date statusEffectiveDate;
    }

    //Use dicitionary metadata to store these values
   @HttpPost
    global static void doPost() {
        // Get the dynamic map from the helper class.
        Map<String, String> codeToStatusMap = UnitStatusHelper.getCodeToStatusMap();
        
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        // This map will hold the final response for each incoming unitId
        Map<String, Map<String, Object>> responseMap = new Map<String, Map<String, Object>>();
        List<Unit__c> unitsToUpdate = new List<Unit__c>();
        Set<String> unitIdsFromPayload = new Set<String>();

        try {
            List<UnitStatusPayload> inputList = (List<UnitStatusPayload>) JSON.deserialize(
                req.requestBody.toString(),
                List<UnitStatusPayload>.class
            );

            // --- 1. Validate input and collect valid unitIds ---
            for (UnitStatusPayload p : inputList) {
                Map<String, Object> recordResponse = new Map<String, Object>{'externalId' => p.unitId};

                if (String.isBlank(p.unitId)) {
                    recordResponse.put('status', 'Failure');
                    recordResponse.put('message', 'Missing required field: unitId');
                    // Use a unique key for records with no ID to avoid map collision
                    responseMap.put('INVALID_ID_' + System.now().getTime(), recordResponse);
                    continue;
                }

                // Put the response map with the valid ID. This will be updated later.
                responseMap.put(p.unitId, recordResponse);
                unitIdsFromPayload.add(p.unitId); // Add to set for querying

                // Now checking p.statusCode for blankness
                if (String.isBlank(p.statusCode)) {
                    recordResponse.put('status', 'Failure');
                    recordResponse.put('message', 'Missing required field: statusCode'); // Message updated to reflect field name 'statusCode'
                    continue;
                }

                // Validate the incoming SAP status code against our new dynamic map
                if (!codeToStatusMap.containsKey(p.statusCode)) {
                    recordResponse.put('status', 'Failure');
                    recordResponse.put('message', 'Invalid status code: [' + p.statusCode + ']. Expected one of: ' + String.join(new List<String>(codeToStatusMap.keySet()), ', '));
                    continue; // Skip this record as its status code is invalid
                }
            }

            // --- 2. Query existing Unit__c records ---
            Map<String, Unit__c> existingUnits = new Map<String, Unit__c>();
            if (!unitIdsFromPayload.isEmpty()) {
                for (Unit__c unit : [SELECT Id, SAP_External_Id__c, Status__c FROM Unit__c WHERE SAP_External_Id__c IN :unitIdsFromPayload]) {
                    existingUnits.put(unit.SAP_External_Id__c, unit);
                }
            }

            // --- 3. Prepare records for update or mark as failure if not found ---
            for (UnitStatusPayload p : inputList) {
                // Retrieve the response map for the current unitId
                Map<String, Object> recordResponse = responseMap.get(p.unitId);

                // Skip if this record already has a failure status (e.g., missing unitId/statusCode or invalid SAP status from earlier validation)
                if (recordResponse != null && 'Failure'.equals(recordResponse.get('status'))) {
                    continue;
                }

                if (existingUnits.containsKey(p.unitId)) {
                    Unit__c unitToUpdate = existingUnits.get(p.unitId);
                    // Assign the mapped Salesforce Status__c value using p.statusCode
                    unitToUpdate.Status__c = codeToStatusMap.get(p.statusCode);
                    unitToUpdate.Status_Effective_Date__c = p.statusEffectiveDate ?? Date.today();
                    unitsToUpdate.add(unitToUpdate);
                } else {
                    // Unit not found in Salesforce, mark as failure
                    if (recordResponse != null) {
                        recordResponse.put('status', 'Failure');
                        recordResponse.put('message', 'Unit [' + p.unitId + '] not found.');
                    }
                }
            }

            // --- 4. Perform DML operation (update instead of upsert) ---
            if (!unitsToUpdate.isEmpty()) {
                
                //UnitBeforeUpdateTriggerHandler.unitStatusUpdateInProgress = true;
                // Use Database.update with allOrNone = false to allow for partial success
                Database.SaveResult[] updateResults = Database.update(
                    unitsToUpdate,
                    false
                );
				//UnitBeforeUpdateTriggerHandler.unitStatusUpdateInProgress = false;
                
                // --- 5. Process DML results and build the final response ---
                for (Integer i = 0; i < updateResults.size(); i++) {
                    Database.SaveResult sr = updateResults[i];
                    String externalId = unitsToUpdate[i].SAP_External_Id__c;
                    Map<String, Object> recordResponse = responseMap.get(externalId);

                    if (sr.isSuccess()) {
                        recordResponse.put('status', 'Success');
                        recordResponse.put('message', 'Unit status updated');
                    } else {
                        recordResponse.put('status', 'Failure');
                        // Get the first error message for a concise response
                        recordResponse.put('message', sr.getErrors()[0].getMessage());
                    }
                }
            }

            res.responseBody = Blob.valueOf(JSON.serialize(responseMap.values()));
            res.statusCode = 200;

        } catch (Exception ex) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                'status' => 'Failure',
                'message' => 'An unexpected error occurred: ' + ex.getMessage()
            }));
        }
    }
}