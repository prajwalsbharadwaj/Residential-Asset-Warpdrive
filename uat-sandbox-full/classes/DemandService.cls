/** old DemandService Class Backup.
* @Description Service class to handle business logic for creating Demand__c records.
* This class is decoupled from the REST context and can be reused.
*/
public with sharing class DemandService {
    
/**
* @Description Inner class for deserializing the JSON payload.
*/
    public class DemandPayload {
        public String demandNumber;
        public String otherChargesDemandNumber;
        public String bookingnumber;
        public String customerreference;
        public String soldtopartyid;
        public String unitcode;
        public Decimal orderquantity;
        public Decimal invoicevalue;
        public Decimal taxvalue;
        public String milestonecode;
        public Date milestonedate; // Changed from String to Date
        public String milestonedescription; 
        public decimal totgross;
        public decimal tottax;
    }
    
    /**
* @Description Wrapper class to manage record processing.
*/
    private class DemandWrapper {
        DemandPayload payload;
        String responseKey;
        
        DemandWrapper(DemandPayload p, String key) {
            this.payload = p;
            this.responseKey = key;
        }
    }
    
    private class BookingInfo {
        Id bookingId;
        Id unitId;
        
        BookingInfo(Id bookingId, Id unitId) {
            this.bookingId = bookingId;
            this.unitId = unitId;
        }
    }
    
/**
* @Description Processes a list of demand payloads to create Demand__c records.
* @param inputList List of DemandPayload objects from the request.
* @return Map<String, Map<String, Object>> A map containing the processing result for each demand.
*/
    public static Map<String, Map<String, Object>> createDemands(List<DemandPayload> inputList) {
        Map<String, Map<String, Object>> responseMap = new Map<String, Map<String, Object>>();
        List<DemandWrapper> wrappersToProcess = new List<DemandWrapper>();
        
        // 1. Initial Validation and Data Collection
        Set<String> sapAccountIds = new Set<String>();
        Set<String> sapUnitIds = new Set<String>();
        Set<String> incomingDemandNumbers = new Set<String>();
        Set<String> sapBookingNumbers = new Set<String>();
        List<String> bookingScheduleKeys = new List<String>();
        Set<String> milestoneCodes = new Set<String>();
        Set<String> otherChargesBookingNumbers = new Set<String>();
        
        for (DemandPayload p : inputList) {
            String responseKey = String.isNotBlank(p.demandNumber) ? p.demandNumber : System.UUID.randomUUID().toString();
            Map<String, Object> recordResponse = new Map<String, Object>{'externalId' => p.demandNumber};
                responseMap.put(responseKey, recordResponse);
            
            // Basic mandatory field validation
            Boolean isOtherChargesDemand = String.isNotBlank(p.otherChargesDemandNumber);
            Boolean isOrderQuantityMissingForNonOtherCharges = !isOtherChargesDemand && p.orderQuantity == null;
            Boolean isUnitCodeMissingForNonOtherCharges = !isOtherChargesDemand && String.isBlank(p.unitCode);
            if (String.isBlank(p.demandNumber) || String.isBlank(p.soldToPartyId) || isUnitCodeMissingForNonOtherCharges || isOrderQuantityMissingForNonOtherCharges || p.invoiceValue == null || p.taxValue == null) {
                recordResponse.put('status', 'Failure');
                if (isUnitCodeMissingForNonOtherCharges) {
                    recordResponse.put('message', 'Missing mandatory field unitCode for non-other-charges demand.');
                } else if (isOrderQuantityMissingForNonOtherCharges) {
                    recordResponse.put('message', 'Missing mandatory field orderQuantity for non-other-charges demand.');
                } else {
                    recordResponse.put('message', 'Missing one or more mandatory fields: demandNumber, soldToPartyId, invoiceValue, taxValue.');
                }
                continue;
            }
            
           /* if(SAPCodeTranslationUtil.getMilestoneValueByCodeMap().get(p.milestonecode) == 'On Possession') {
                
                if(String.isBlank(p.otherChargesDemandNumber)){
                    recordResponse.put('status', 'Failure');
                    recordResponse.put('message', 'Other charges demand number can\'t be null for an "On Possession" demand.');
                    continue;
                }
            } else {
                if(String.isNotBlank(p.otherChargesDemandNumber)){
                    recordResponse.put('status', 'Failure');
                    recordResponse.put('message', 'Other charges demand number should be null for other demands except "On Possession".');
                    continue;
                }
            }*/
            
            // collect a composite key for Booking Payment schedule lookup.
            if (String.isNotBlank(p.bookingNumber) && String.isNotBlank(p.milestonecode)) {
                bookingScheduleKeys.add(p.bookingNumber + '::' + p.milestonecode);
            }
            if (String.isNotBlank(p.bookingNumber) && String.isNotBlank(p.otherChargesDemandNumber)) {
                otherChargesBookingNumbers.add(p.bookingNumber);
            }
            
            wrappersToProcess.add(new DemandWrapper(p, responseKey));
            
            if (String.isNotBlank(p.soldToPartyId)) sapAccountIds.add(p.soldToPartyId);
            if (String.isNotBlank(p.customerReference)) sapAccountIds.add(p.customerReference);
            if (String.isNotBlank(p.unitCode)) sapUnitIds.add(p.unitCode);
            if (String.isNotBlank(p.demandNumber)) incomingDemandNumbers.add(p.demandNumber);
            if (String.isNotBlank(p.bookingNumber)) sapBookingNumbers.add(p.bookingNumber);
            if (String.isNotBlank(p.milestonecode)) milestoneCodes.add(SAPCodeTranslationUtil.getMilestoneValueByCodeMap().get(p.milestonecode));
        }
        
        // 2. Database Lookups
        Map<String, Id> accountIdMap = getLookupMap('Account', 'SAP_External_Id__c', sapAccountIds);
        Map<String, Id> unitIdMap = getLookupMap('Unit__c', 'SAP_External_Id__c', sapUnitIds);
        Map<String, Id> existingDemandMap = getLookupMap('Demand__c', 'SAP_External_Id__c', incomingDemandNumbers);
        Map<String, BookingInfo> bookingInfoMap = getBookingInfoMap(sapBookingNumbers);
        Map<String, Id> bookingScheduleMap = getBookingScheduleMap(sapBookingNumbers, milestoneCodes, otherChargesBookingNumbers);
        
        
        // 3. Prepare Records for DML
        List<Demand__c> demandsToInsert = new List<Demand__c>();
        List<String> responseKeysForDml = new List<String>(); // Use a parallel list for tracking
        Set<String> processedDemandNumbers = new Set<String>(); // For checking duplicates within the payload
        
        for (DemandWrapper wrapper : wrappersToProcess) {
            Map<String, Object> recordResponse = responseMap.get(wrapper.responseKey);
            
            if (recordResponse.get('status') == 'Failure') continue;
            
            // Validate lookups and duplicates
            if (String.isNotBlank(wrapper.payload.demandNumber)) {
                if(existingDemandMap.containsKey(wrapper.payload.demandNumber)) {
                    recordResponse.put('status', 'Failure');
                    recordResponse.put('message', 'Demand with Number ' + wrapper.payload.demandNumber + ' already exists.');
                    continue;
                }
                if(processedDemandNumbers.contains(wrapper.payload.demandNumber)) {
                    recordResponse.put('status', 'Failure');
                    recordResponse.put('message', 'Duplicate Demand Number ' + wrapper.payload.demandNumber + ' found in the same request.');
                    continue;
                }
            }
            
            if (!accountIdMap.containsKey(wrapper.payload.soldToPartyId)) {
                recordResponse.put('status', 'Failure');
                recordResponse.put('message', 'Account (Sold To Party) with SAP External ID ' + wrapper.payload.soldToPartyId + ' not found.');
                continue;
            }
            if (String.isNotBlank(wrapper.payload.customerReference) && !accountIdMap.containsKey(wrapper.payload.customerReference)) {
                recordResponse.put('status', 'Failure');
                recordResponse.put('message', 'Account (Customer Reference) with SAP External ID ' + wrapper.payload.customerReference + ' not found.');
                continue;
            }
            Boolean isOtherChargesDemand = String.isNotBlank(wrapper.payload.otherChargesDemandNumber);
            if (!isOtherChargesDemand && !unitIdMap.containsKey(wrapper.payload.unitCode)) {
                recordResponse.put('status', 'Failure');
                recordResponse.put('message', 'Unit with SAP External ID ' + wrapper.payload.unitCode + ' not found.');
                continue;
            }
            BookingInfo bookingInfo = bookingInfoMap.get(wrapper.payload.bookingNumber);
            if (String.isNotBlank(wrapper.payload.bookingNumber) && bookingInfo == null) {
                recordResponse.put('status', 'Failure');
                recordResponse.put('message', 'Booking with SAP External ID ' + wrapper.payload.bookingNumber + ' not found.');
                continue;
            }
            Id unitIdForDemand = isOtherChargesDemand ? (bookingInfo != null ? bookingInfo.unitId : null) : unitIdMap.get(wrapper.payload.unitCode);
            if (isOtherChargesDemand && unitIdForDemand == null) {
                recordResponse.put('status', 'Failure');
                recordResponse.put('message', 'Unit not found on Booking with SAP External ID ' + wrapper.payload.bookingNumber + '.');
                continue;
            }
            
            // Get Booking payment schedule Id
            String schedKey;
            if (String.isNotBlank(wrapper.payload.otherChargesDemandNumber) && String.isBlank(wrapper.payload.milestonecode)) {
                schedKey = wrapper.payload.bookingNumber + '::OTHER_CHARGES';
            } else {
                schedKey = wrapper.payload.bookingNumber + '::' + wrapper.payload.milestonecode;
            }
            Id scheduleId = bookingScheduleMap.get(schedKey);
            
            if (scheduleId == null) {
                recordResponse.put('status', 'Failure');
                if (String.isNotBlank(wrapper.payload.otherChargesDemandNumber) && String.isBlank(wrapper.payload.milestonecode)) {
                    recordResponse.put('message', 'Booking payment schedule with Milestone Code [Other Charges] not found.');
                } else {
                    recordResponse.put('message', 'Milestone code [' + wrapper.payload.milestonecode + '] not found.');
                }
                continue;
            }
            // Build the sObject
            Demand__c newDemand = new Demand__c(
                SoldToPartyId__c = accountIdMap.get(wrapper.payload.soldToPartyId),
                Unit__c = unitIdForDemand,
                Order_Qty__c = wrapper.payload.orderQuantity,
                Invoice_Value__c = wrapper.payload.invoiceValue,
                Tax_Value__c = wrapper.payload.taxValue,
                TotalGross__c = wrapper.payload.totgross,
                TotalTax__c = wrapper.payload.tottax,
                Booking_Id__c = bookingInfo != null ? bookingInfo.bookingId : null,
                Account__c = accountIdMap.get(wrapper.payload.customerReference),
                Milestone_Description__c = String.isNotBlank(wrapper.payload.milestoneDescription) ?
                							wrapper.payload.milestoneDescription : SAPCodeTranslationUtil.getMilestoneValueByCodeMap().get(wrapper.payload.milestoneCode),
                SAP_External_Id__c = wrapper.payload.demandNumber,
                Milestone_Date__c = wrapper.payload.milestoneDate, // Directly assign the Date
                Booking_Payment_Schedule_Id__c = scheduleId
            );
            
            /*if(wrapper.payload.otherChargesDemandNumber != null){
                newDemand.Other_Charges_SAP_External_Id__c = wrapper.payload.otherChargesDemandNumber;
            }*/
            
            // No need for try-catch for date parsing here, as it's expected to be a Date type from deserialization.
            // If the incoming JSON doesn't provide a valid date format for direct deserialization into Date,
            // the JSON deserializer will handle the error or set it to null.
            // You might want to add a check for null milestoneDate if it's mandatory.
            
            demandsToInsert.add(newDemand);
            responseKeysForDml.add(wrapper.responseKey); // Add key to the parallel list
            if(String.isNotBlank(wrapper.payload.demandNumber)) {
                processedDemandNumbers.add(wrapper.payload.demandNumber);
            }
        }
        
        // 4. Perform DML and Process Results
        if (!demandsToInsert.isEmpty()) {
            Database.SaveResult[] insertResults = Database.insert(demandsToInsert, false);
            
            for (Integer i = 0; i < insertResults.size(); i++) {
                Database.SaveResult sr = insertResults[i];
                String responseKey = responseKeysForDml.get(i); // Get key by index
                Map<String, Object> recordResponse = responseMap.get(responseKey);
                
                if (sr.isSuccess()) {
                    recordResponse.put('status', 'Success');
                    recordResponse.put('message', 'Demand created successfully.');
                    recordResponse.put('sfId', sr.getId());
                } else {
                    recordResponse.put('status', 'Failure');
                    recordResponse.put('message', sr.getErrors()[0].getMessage());
                }
            }
        }
        
        return responseMap;
    }
    
/**
* @Description Generic helper to query for a map of external ID to Salesforce ID.
*/
    private static Map<String, Id> getLookupMap(String objectName, String externalIdField, Set<String> externalIds) {
        Map<String, Id> resultMap = new Map<String, Id>();
        if (externalIds == null || externalIds.isEmpty()) {
            return resultMap;
        }
        String query = 'SELECT Id, ' + String.escapeSingleQuotes(externalIdField) +
            ' FROM ' + String.escapeSingleQuotes(objectName) +
            ' WHERE ' + String.escapeSingleQuotes(externalIdField) + ' IN :externalIds';
        try {
            for (SObject record : Database.query(query)) {
                String externalIdValue = (String)record.get(externalIdField);
                if (externalIdValue != null) {
                    resultMap.put(externalIdValue, record.Id);
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in getLookupMap for ' + objectName + ': ' + e.getMessage());
        }
        return resultMap;
    }
    
    private static Map<String, BookingInfo> getBookingInfoMap(Set<String> bookingNumbers) {
        Map<String, BookingInfo> resultMap = new Map<String, BookingInfo>();
        if (bookingNumbers == null || bookingNumbers.isEmpty()) {
            return resultMap;
        }
        
        for (Booking__c booking : [
            SELECT Id, SAP_External_Id__c, Unit_Id__c
            FROM Booking__c
            WHERE SAP_External_Id__c IN :bookingNumbers
        ]) {
            resultMap.put(booking.SAP_External_Id__c, new BookingInfo(booking.Id, booking.Unit_Id__c));
        }
        
        return resultMap;
    }
    
    //Composite map for Booking + Milestone.
    private static Map<String, Id> getBookingScheduleMap(Set<String> bookingNumbers, Set<String> milestoneCodes, Set<String> otherChargesBookingNumbers) {
        Map<String, Id> resultMap = new Map<String, Id>();
        if (bookingNumbers.isEmpty()) return resultMap;
        
        List<Booking_Payment_Schedule__c> schedules = new List<Booking_Payment_Schedule__c>();
        
        if (!milestoneCodes.isEmpty()) {
            schedules.addAll([
                SELECT Id, Milestone_Code__c, Booking__r.SAP_External_Id__c
                FROM Booking_Payment_Schedule__c
                WHERE Booking__r.SAP_External_Id__c IN :bookingNumbers
                AND Milestone_Code__c IN :milestoneCodes
                AND Bill_Block__c = null
            ]);
        }
        
        if (otherChargesBookingNumbers != null && !otherChargesBookingNumbers.isEmpty()) {
            schedules.addAll([
                SELECT Id, Milestone_Code__c, Booking__r.SAP_External_Id__c
                FROM Booking_Payment_Schedule__c
                WHERE Booking__r.SAP_External_Id__c IN :otherChargesBookingNumbers
                AND Milestone_Code__c = 'Other Charges'
                AND Bill_Block__c = null
            ]);
        }
        
        for (Booking_Payment_Schedule__c sched : schedules) {
            String bookingNumber = sched.Booking__r.SAP_External_Id__c;
            String milestoneCode = SAPCodeTranslationUtil.getMilestoneCodeMap().get(sched.Milestone_Code__c);
            if (String.isNotBlank(milestoneCode)) {
                String key = bookingNumber + '::' + milestoneCode;
                resultMap.put(key, sched.Id);
            }
            if (sched.Milestone_Code__c == 'Other Charges') {
                resultMap.put(bookingNumber + '::OTHER_CHARGES', sched.Id);
            }
        }
        system.debug('resultMap composite key vs bpsId-> '+resultMap);
        return resultMap;
    }
}