@RestResource(urlMapping='/sap/v1/residential-unit/*')
global without sharing class ResidentialUnitApi {

    public class ResidentialUnitData {
        public String unitCode;
        public String name;
        public String plantCode;
        public String materialTypeCode;
        public String materialGroupCode;
        public String unitTypeCode;
        public String towerCode;
        public String facingCode;
        public String floorCode;
        public String configurationCode;
        public String statusCode;
        public Date statusEffectiveDate;
        public String controlCode;
        public String profitCenterCode;
        
        public Decimal carpetArea;
        public Decimal balconyArea;
    }

    private static Map<String, String> allowedPlants = new Map<String, String>();
    private static Map<String, String> materialTypeMap = new Map<String, String>();
    private static Map<String, String> materialGroupMap = new Map<String, String>();
    private static Map<String, String> unitTypeMap = new Map<String, String>();
    private static Map<String, String> facingMap = new Map<String, String>();
    private static Map<String, String> configMap = new Map<String, String>();
    private static Map<String, String> towerMap = new Map<String, String>();
    private static Map<String, String> floorMap = new Map<String, String>();

    // Lazy-load/populate maps from External_Code_Dictionary__mdt
    private static void ensureMapsLoaded() {
        if(!allowedPlants.isEmpty()) return; // Avoid re-querying if already loaded in same transaction

        for (External_Code_Dictionary__mdt mdt : [
            SELECT Domain__c, Display_Label__c, Code__c, MasterLabel
            FROM External_Code_Dictionary__mdt
            WHERE Is_Active__c = true
        ]) {
            String domain = mdt.Domain__c;
            String code = mdt.Code__c;
            String label = mdt.Display_Label__c;
    
            switch on domain {
                when 'Plant' { allowedPlants.put(code, label); }
                when 'Material Type' { materialTypeMap.put(code, label); }
                when 'Material Group' { materialGroupMap.put(code, label); }
                when 'Unit Type' { unitTypeMap.put(code, label); }
                when 'Facing' { facingMap.put(code, label); }
                when 'Configuration' { configMap.put(code, label); }
                when 'Tower' { towerMap.put(code, label); }
                when 'Floor' { floorMap.put(code, label); }
            }
        }
    }

    @HttpPost
    global static void doPost() {
        ensureMapsLoaded();
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        List<Map<String, Object>> responseList = new List<Map<String, Object>>();
        String requestBodyString = ''; // Initialize for logging visibility

        try {
            // Capture body immediately for usage in try, catch, and finally
            requestBodyString = req.requestBody != null ? req.requestBody.toString() : '';
            System.debug('request body: ' + requestBodyString);

            List<ResidentialUnitData> inputList = (List<ResidentialUnitData>) JSON.deserialize(requestBodyString, List<ResidentialUnitData>.class);
            Set<String> projectExtIds = new Set<String>();
            Set<String> towerExtIds = new Set<String>();
            Set<String> floorExtIds = new Set<String>();
            Set<String> unitExtIds = new Set<String>();

            for (ResidentialUnitData data : inputList) {
                projectExtIds.add(data.plantCode);
                projectExtIds.add(data.profitCenterCode);
                towerExtIds.add(data.plantCode + '-' + data.towerCode);
                floorExtIds.add(data.plantCode + '-' + data.towerCode + '-' + data.floorCode);
                unitExtIds.add(data.unitCode);
            }

            projectExtIds.remove(null);
            unitExtIds.remove(null);

            Map<String, Property__c> existingProjects = new Map<String, Property__c>();
            for (Property__c p : [SELECT Id, SAP_External_Id__c FROM Property__c WHERE SAP_External_Id__c IN :projectExtIds]) {
                existingProjects.put(p.SAP_External_Id__c, p);
            }

            Map<String, Tower__c> existingTowers = new Map<String, Tower__c>();
            for (Tower__c t : [SELECT Id, SAP_External_Id__c FROM Tower__c WHERE SAP_External_Id__c IN :towerExtIds]) {
                existingTowers.put(t.SAP_External_Id__c, t);
            }

            Map<String, Floor__c> existingFloors = new Map<String, Floor__c>();
            for (Floor__c f : [SELECT Id, SAP_External_Id__c FROM Floor__c WHERE SAP_External_Id__c IN :floorExtIds]) {
                existingFloors.put(f.SAP_External_Id__c, f);
            }

            Map<String, Unit__c> existingUnits = new Map<String, Unit__c>();
            for (Unit__c u : [SELECT Id, SAP_External_Id__c FROM Unit__c WHERE SAP_External_Id__c IN :unitExtIds]) {
                existingUnits.put(u.SAP_External_Id__c, u);
            }

            List<SObject> inventoryRecordsToInsert = new List<SObject>();
            List<Unit__c> unitsToInsert = new List<Unit__c>();
            
            for (ResidentialUnitData data : inputList) {
                Map<String, Object> result = new Map<String, Object>{ 'externalId' => data.unitCode };

                if (existingUnits.containsKey(data.unitCode)) {
                    result.put('status', 'Failure');
                    result.put('message', 'Unit already exists');
                    responseList.add(result);
                    continue;
                }

                List<String> errors = validateResidentialUnit(data);
                if (!errors.isEmpty()) {
                    result.put('status', 'Failure');
                    result.put('message', String.join(errors, '; '));
                    responseList.add(result);
                    continue;
                }

                String projectExtId = data.plantCode;
                String towerExtId = projectExtId + '-' + data.towerCode;
                String floorExtId = projectExtId + '-' + data.towerCode + '-' + data.floorCode;

                if (!existingProjects.containsKey(projectExtId)) {
                    inventoryRecordsToInsert.add(new Property__c(Name = allowedPlants.get(projectExtId), SAP_External_Id__c = projectExtId));
                    existingProjects.put(projectExtId, null);
                }

                if (String.isNotBlank(data.profitCenterCode) && !existingProjects.containsKey(data.profitCenterCode)) {
                    inventoryRecordsToInsert.add(new Property__c(Name = allowedPlants.get(data.profitCenterCode), SAP_External_Id__c = data.profitCenterCode));
                    existingProjects.put(data.profitCenterCode, null);
                }

                if (!existingTowers.containsKey(towerExtId)) {
                    inventoryRecordsToInsert.add(new Tower__c(Name = towerMap.get(data.towerCode), SAP_External_Id__c = towerExtId, Property__r = new Property__c(SAP_External_Id__c = projectExtId)));
                    existingTowers.put(towerExtId, null);
                }

                if (!existingFloors.containsKey(floorExtId)) {
                    inventoryRecordsToInsert.add(new Floor__c(Name = floorMap.get(data.floorCode), SAP_External_Id__c = floorExtId, Tower__r = new Tower__c(SAP_External_Id__c = towerExtId), Property__r = new Property__c(SAP_External_Id__c = projectExtId)));
                    existingFloors.put(floorExtId, null);
                }

                unitsToInsert.add(new Unit__c(
                    SAP_External_Id__c = data.unitCode,
                    Name = data.name,
                    Property__r = new Property__c(SAP_External_Id__c = projectExtId),
                    Tower__r = new Tower__c(SAP_External_Id__c = towerExtId),
                    Floor__r = new Floor__c(SAP_External_Id__c = floorExtId),
                    Status__c = SAPCodeTranslationUtil.getStatusValueByCodeMap().get(data.statusCode),
                    Status_Effective_Date__c = data.statusEffectiveDate ?? Date.today(),
                    Control_Code__c = data.controlCode,
                    Profit_Center__r = String.isNotBlank(data.profitCenterCode) ? new Property__c(SAP_External_Id__c = data.profitCenterCode) : null,
                    Unit_Type__c = materialTypeMap.get(data.materialTypeCode),
                    Carpet_Area__c = data.carpetArea,
                    Deck_Balcony__c = data.balconyArea
                ));
    
                result.put('status', 'Pending');
                responseList.add(result);
            }

            insert inventoryRecordsToInsert;

            if (!unitsToInsert.isEmpty()) {
                Database.SaveResult[] results = Database.insert(unitsToInsert, false);
                Integer insertedCount = 0;
                for (Integer i = 0; i < responseList.size(); i++) {
                    Map<String, Object> resp = responseList[i];
                    if (resp.get('status') == 'Pending') {
                        if (results[insertedCount].isSuccess()) {
                            resp.put('status', 'Success');
                            resp.put('unitId', results[insertedCount].getId());
                        } else {
                            resp.put('status', 'Failure');
                            resp.put('message', results[insertedCount].getErrors()[0].getMessage());
                        }
                        insertedCount++;
                    }
                }
            }

            res.addHeader('Content-Type', 'application/json');
            res.responseBody = Blob.valueOf(JSON.serialize(responseList));
            
            // Check for failures to log exception
            boolean hasFailures = false;
            for(Map<String, Object> result : responseList){
                if(result.get('status') == 'Failure'){
                    hasFailures = true;
                    break;
                }
            }

            if(hasFailures){
                res.statusCode = 207; // Multi-Status if mixed
                ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                    .withComponentName('ResidentialUnitApi')
                    .withDescription('Error in processing Residential Unit Create')
                    .withClassName('ResidentialUnitApi')
                    .withMethodName('doPost')
                    .withRequestBody(requestBodyString)
                    .withResponseBody(res.responseBody.toString())
                    .withEndpoint(req.requestURI)
                    .withDomain('SAP Inbound')
                	.withErrorType('Integration Error');

            	ExceptionLogger.addException(payload);
            } else {
                res.statusCode = 200;
            }

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(
                new List<Map<String, Object>>{
                    new Map<String, Object>{ 'status' => 'Failure', 'message' => 'Unhandled exception: ' + e.getMessage() }
                }
            ));
            
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('ResidentialUnitApi')
                .withDescription('Unhandled exception: ' + e.getMessage())
                .withClassName('ResidentialUnitApi')
                .withMethodName('doPost')
                .withRequestBody(requestBodyString)
                .withResponseBody(res.responseBody != null ? res.responseBody.toString() : '') 
                .withEndpoint(req.requestURI)
                .withDomain('SAP Inbound')
                .withException(e);

            ExceptionLogger.addException(payload);
        } finally {
            if(!ExceptionLogger.isLogsCreated() && IntegrationToggle.isLogsEnabled('Create Unit', 'SAP', 'Residential', 'Inbound')) {
                ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                    .withComponentName('ResidentialUnitApi')
                    .withDescription('Success log for debugging')
                    .withClassName('ResidentialUnitApi')
                    .withMethodName('doPost')
                    .withRequestBody(requestBodyString)
                    .withResponseBody(res.responseBody != null ? res.responseBody.toString() : '')
                    .withEndpoint(req.requestURI)
                    .withDomain('SAP Inbound')
                    .withErrorType('Success');
                
                ExceptionLogger.addException(payload);
            }   
            ExceptionLogger.insertLogsIfAny();
        }
    }


    @HttpPatch
    global static void doPatch() {
        ensureMapsLoaded();
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        List<Map<String, Object>> responseList = new List<Map<String, Object>>();
        String requestBodyString = ''; 

        try {
            requestBodyString = req.requestBody != null ? req.requestBody.toString() : '';
            
            List<ResidentialUnitData> inputList = (List<ResidentialUnitData>) JSON.deserialize(requestBodyString, List<ResidentialUnitData>.class);
            Set<String> unitExtIds = new Set<String>();
            for (ResidentialUnitData data : inputList) {
                if (String.isNotBlank(data.unitCode)) {
                    unitExtIds.add(data.unitCode);
                }
            }
    
            Map<String, Unit__c> existingUnits = new Map<String, Unit__c>();
            for (Unit__c u : [
                SELECT Id, SAP_External_Id__c, Name, Control_Code__c, Status__c, Status_Effective_Date__c,
                       Property__r.SAP_External_Id__c, Tower__r.SAP_External_Id__c, Floor__r.SAP_External_Id__c,
                       Profit_Center__r.SAP_External_Id__c, BHK_Configuration__c, 
                       Unit_Type__c, Unit_Group__c, Carpet_Area__c, Deck_Balcony__c
                FROM Unit__c WHERE SAP_External_Id__c IN :unitExtIds
            ]) {
                existingUnits.put(u.SAP_External_Id__c, u);
            }
            
            List<Unit__c> unitsToUpdate = new List<Unit__c>();
            Map<String, List<String>> businessRuleErrors = new Map<String, List<String>>();
            
            for (ResidentialUnitData data : inputList) {
                if (String.isBlank(data.unitCode) || !existingUnits.containsKey(data.unitCode)) {
                    continue;
                }
                
                List<String> validationErrors = validatePatchData(data);
                if (!validationErrors.isEmpty()) {
                    businessRuleErrors.put(data.unitCode, validationErrors);
                    continue; 
                }
                
                Unit__c currentUnit = existingUnits.get(data.unitCode);
                Unit__c unitToUpdate = new Unit__c(Id = currentUnit.Id);
                boolean isUpdateNeeded = false;
                
                // --- Field Comparison and Assignment Logic ---
                if (data.name != null) 
                { 
                    if (String.isBlank(data.name)) 
                    { addError(businessRuleErrors, data.unitCode, 'Mandatory field [name] cannot be blank.'); } 
                    else if (currentUnit.Name != data.name) 
                    { unitToUpdate.Name = data.name; isUpdateNeeded = true; } 
                }
                if (data.controlCode != null && currentUnit.Control_Code__c != data.controlCode) 
                    { unitToUpdate.Control_Code__c = data.controlCode; isUpdateNeeded = true; }
                if (data.statusEffectiveDate != null && currentUnit.Status_Effective_Date__c != data.statusEffectiveDate) 
                    { unitToUpdate.Status_Effective_Date__c = data.statusEffectiveDate; isUpdateNeeded = true; }
                if (data.carpetArea != null && currentUnit.Carpet_Area__c != data.carpetArea) 
                    { unitToUpdate.Carpet_Area__c = data.carpetArea; isUpdateNeeded = true; }
                if (data.balconyArea != null && currentUnit.Deck_Balcony__c != data.balconyArea) 
                    { unitToUpdate.Deck_Balcony__c = data.balconyArea; isUpdateNeeded = true; }
                if (data.statusCode != null && currentUnit.Status__c != SAPCodeTranslationUtil.getStatusValueByCodeMap().get(data.statusCode)) 
                    { unitToUpdate.Status__c = SAPCodeTranslationUtil.getStatusValueByCodeMap().get(data.statusCode); isUpdateNeeded = true; }
                if (data.materialTypeCode != null && currentUnit.Unit_Type__c != materialTypeMap.get(data.materialTypeCode)) 
                    { unitToUpdate.Unit_Type__c = materialTypeMap.get(data.materialTypeCode); isUpdateNeeded = true; }
                if (data.materialGroupCode != null && currentUnit.Unit_Group__c != materialGroupMap.get(data.materialGroupCode)) 
                    { unitToUpdate.Unit_Group__c = materialGroupMap.get(data.materialGroupCode); isUpdateNeeded = true; }
                if (data.configurationCode != null && currentUnit.BHK_Configuration__c != configMap.get(data.configurationCode)) 
                    { unitToUpdate.BHK_Configuration__c = configMap.get(data.configurationCode); isUpdateNeeded = true; }
                
                if (data.plantCode != null && currentUnit.Property__r?.SAP_External_Id__c != data.plantCode) 
                    { unitToUpdate.Property__r = new Property__c(SAP_External_Id__c = data.plantCode); isUpdateNeeded = true; }
                if (data.profitCenterCode != null && currentUnit.Profit_Center__r?.SAP_External_Id__c != data.profitCenterCode) 
                    { unitToUpdate.Profit_Center__r = new Property__c(SAP_External_Id__c = data.profitCenterCode); isUpdateNeeded = true; }
                
                 // ** Composite Lookups (Properly Formatted) **
                    if (data.towerCode != null) {
                        String plantCodeForTowerKey = (data.plantCode != null) ? data.plantCode : currentUnit.Property__r?.SAP_External_Id__c;
                        if (plantCodeForTowerKey != null) {
                            String newTowerExtId = plantCodeForTowerKey + '-' + data.towerCode;
                            if (currentUnit.Tower__r?.SAP_External_Id__c != newTowerExtId) {
                                unitToUpdate.Tower__r = new Tower__c(SAP_External_Id__c = newTowerExtId);
                                isUpdateNeeded = true;
                            }
                        }
                    }
    
                    if (data.floorCode != null) {
                        String plantCodeForFloorKey = (data.plantCode != null) ? data.plantCode : currentUnit.Property__r?.SAP_External_Id__c;
                        String towerCodeForFloorKey = (data.towerCode != null) ? data.towerCode : (currentUnit.Tower__r?.SAP_External_Id__c != null ? currentUnit.Tower__r.SAP_External_Id__c.substringAfter('-') : null);
                            if (plantCodeForFloorKey != null && towerCodeForFloorKey != null) {
                                String newFloorExtId = plantCodeForFloorKey + '-' + towerCodeForFloorKey + '-' + data.floorCode;
                                if (currentUnit.Floor__r?.SAP_External_Id__c != newFloorExtId) {
                                    unitToUpdate.Floor__r = new Floor__c(SAP_External_Id__c = newFloorExtId);
                                    isUpdateNeeded = true;
                                }
                            }
                    }
                    
                if (isUpdateNeeded && !businessRuleErrors.containsKey(data.unitCode)) {
                    unitsToUpdate.add(unitToUpdate);
                }
            }
            
            // --- Perform Database Operation ---
            Map<Id, Database.SaveResult> saveResultMap = new Map<Id, Database.SaveResult>();
            if (!unitsToUpdate.isEmpty()) {
                Database.SaveResult[] srList = Database.update(unitsToUpdate, false);
                for (Integer i = 0; i < srList.size(); i++) {
                    Id recordId = unitsToUpdate[i].Id; 
                    Database.SaveResult sr = srList[i];
                    saveResultMap.put(recordId, sr);
                }
            }
            
            // --- Build Final, Honest Response ---
            for (ResidentialUnitData data : inputList) {
                Map<String, Object> result = new Map<String, Object>{ 'externalId' => data.unitCode };
                if (businessRuleErrors.containsKey(data.unitCode)) {
                    result.put('status', 'Failure');
                    result.put('message', String.join(businessRuleErrors.get(data.unitCode), '; '));
                } else if (String.isBlank(data.unitCode) || !existingUnits.containsKey(data.unitCode)) {
                    result.put('status', 'Failure');
                    result.put('message', 'Unit not found with provided unitCode.');
                } else {
                    Id unitId = existingUnits.get(data.unitCode).Id;
                    if (saveResultMap.containsKey(unitId)) {
                        Database.SaveResult sr = saveResultMap.get(unitId);
                        result.put('status', sr.isSuccess() ? 'Success' : 'Failure');
                        result.put('message', sr.isSuccess() ? 'Unit successfully updated.' : 'Database error: ' + sr.getErrors()[0].getMessage());
                    } else {
                        result.put('status', 'Success');
                        result.put('message', 'No fields to update.');
                    }
                }
                responseList.add(result);
            }
            
            res.addHeader('Content-Type', 'application/json');
            res.responseBody = Blob.valueOf(JSON.serialize(responseList));
            
            // Check for failures to log exception
            boolean hasFailures = false;
            for(Map<String, Object> result : responseList){
                if(result.get('status') == 'Failure'){
                    hasFailures = true;
                    break;
                }
            }

            if(hasFailures){
                res.statusCode = 207;
                ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                    .withComponentName('ResidentialUnitApi')
                    .withDescription('Error in processing Residential Unit Update')
                    .withClassName('ResidentialUnitApi')
                    .withMethodName('doPatch')
                    .withRequestBody(requestBodyString)
                    .withResponseBody(res.responseBody.toString())
                    .withEndpoint(req.requestURI)
                    .withDomain('SAP Inbound')
                    .withErrorType('Integration Error');

            	ExceptionLogger.addException(payload);
            } else {
                res.statusCode = 200;
            }
            
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(
                new Map<String, String>{ 'status' => 'Failure', 'message' => 'Unhandled exception: ' + e.getMessage() + ' at line ' + e.getLineNumber() }
            ));
            
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('ResidentialUnitApi')
                .withDescription('Unhandled exception: ' + e.getMessage())
                .withClassName('ResidentialUnitApi')
                .withMethodName('doPatch')
                .withRequestBody(requestBodyString)
                .withResponseBody(res.responseBody != null ? res.responseBody.toString() : '') 
                .withEndpoint(req.requestURI)
                .withDomain('SAP Inbound')
                .withException(e);

            ExceptionLogger.addException(payload);
        } finally {
            if(!ExceptionLogger.isLogsCreated() && IntegrationToggle.isLogsEnabled('Create Unit', 'SAP', 'Residential', 'Inbound')) {
                ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                    .withComponentName('ResidentialUnitApi')
                    .withDescription('Success log for debugging')
                    .withClassName('ResidentialUnitApi')
                    .withMethodName('doPatch')
                    .withRequestBody(requestBodyString)
                    .withResponseBody(res.responseBody != null ? res.responseBody.toString() : '')
                    .withEndpoint(req.requestURI)
                    .withDomain('SAP Inbound')
                    .withErrorType('Success');
                
                ExceptionLogger.addException(payload);
            }   
            ExceptionLogger.insertLogsIfAny();
        }
    }
    
    // ** HELPER METHOD TO ADD ERRORS TO THE MAP **
    private static void addError(Map<String, List<String>> errorMap, String key, String message) {
        if (!errorMap.containsKey(key)) {
            errorMap.put(key, new List<String>());
        }
        errorMap.get(key).add(message);
    }
    
    // ** VALIDATION HELPER METHOD FOR INCORRECT CODES IN A PATCH REQUEST **
    private static List<String> validatePatchData(ResidentialUnitData data) {
        List<String> errors = new List<String>();
        
        if (String.isNotBlank(data.plantCode) && !allowedPlants.containsKey(data.plantCode)) errors.add('Invalid plant code: ' + data.plantCode);
        if (String.isNotBlank(data.profitCenterCode) && !allowedPlants.containsKey(data.profitCenterCode)) errors.add('Invalid profit center code: ' + data.profitCenterCode);
        if (String.isNotBlank(data.materialTypeCode) && !materialTypeMap.containsKey(data.materialTypeCode)) errors.add('Invalid material type code: ' + data.materialTypeCode);
        if (String.isNotBlank(data.materialGroupCode) && !materialGroupMap.containsKey(data.materialGroupCode)) errors.add('Invalid material group code: ' + data.materialGroupCode);
        if (String.isNotBlank(data.towerCode) && !towerMap.containsKey(data.towerCode)) errors.add('Invalid tower code: ' + data.towerCode);
        if (String.isNotBlank(data.floorCode) && !floorMap.containsKey(data.floorCode)) errors.add('Invalid floor code: ' + data.floorCode);
        if (String.isNotBlank(data.statusCode) && !SAPCodeTranslationUtil.getStatusValueByCodeMap().containsKey(data.statusCode)) errors.add('Invalid status code: ' + data.statusCode);
        if (String.isNotBlank(data.configurationCode) && !configMap.containsKey(data.configurationCode)) errors.add('Invalid configuration code: ' + data.configurationCode);
        if (String.isNotBlank(data.facingCode) && !facingMap.containsKey(data.facingCode)) errors.add('Invalid facing code: ' + data.facingCode);
        if (String.isNotBlank(data.unitTypeCode) && !unitTypeMap.containsKey(data.unitTypeCode)) errors.add('Invalid unit type code: ' + data.unitTypeCode);
        
        return errors;
    }
    
    private static List<String> validateResidentialUnit(ResidentialUnitData data) {
        List<String> errors = new List<String>();
        if (String.isBlank(data.unitCode)) errors.add('Missing mandatory field: unitCode');
        if (String.isBlank(data.plantCode)) errors.add('Missing mandatory field: plantCode');
        else if (!allowedPlants.containsKey(data.plantCode)) errors.add('Invalid plant code: ' + data.plantCode);
        
        if (String.isNotBlank(data.profitCenterCode) && !allowedPlants.containsKey(data.profitCenterCode)) errors.add('Invalid profit center code: ' + data.profitCenterCode);
        
        if (String.isBlank(data.materialTypeCode)) errors.add('Missing mandatory field: materialTypeCode');
        else if (!materialTypeMap.containsKey(data.materialTypeCode)) errors.add('Invalid material type code: ' + data.materialTypeCode);
        
        if (String.isBlank(data.materialGroupCode)) errors.add('Missing mandatory field: materialGroupCode');
        else if (!materialGroupMap.containsKey(data.materialGroupCode)) errors.add('Invalid material group code: ' + data.materialGroupCode);
        
        if (String.isBlank(data.towerCode)) errors.add('Missing mandatory field: towerCode');
        else if (!towerMap.containsKey(data.towerCode)) errors.add('Invalid tower code: ' + data.towerCode);
        
        if (String.isBlank(data.floorCode)) errors.add('Missing mandatory field: floorCode');
        else if (!floorMap.containsKey(data.floorCode)) errors.add('Invalid floor code: ' + data.floorCode);
        
        if (String.isBlank(data.statusCode)) errors.add('Missing mandatory field: statusCode');
        else if (!SAPCodeTranslationUtil.getStatusValueByCodeMap().containsKey(data.statusCode)) {
            errors.add('Invalid status code: [' + data.statusCode + ']. Expected one of: ' +
                       String.join(new List<String>(SAPCodeTranslationUtil.getStatusValueByCodeMap().keySet()), ', '));
        }
        
        return errors;
    }
}