public class SAPCodeTranslationUtil {

    /**
     * @description Private static final maps to cache the custom metadata.
     * This improves performance by querying the database only once per transaction.
     */
    private static Map<String, String> milestoneCodeMap;
    private static Map<String, String> billRuleMap;
    private static Map<String, String> billBlockMap;
    private static Map<String, String> salesOrgMap;
    private static Map<String, String> distributionChannelMap;
    private static Map<String, String> divisionMap;
    private static Map<String, String> documentTypeMap;
    private static Map<String, String> statusCodeMap;
    private static Map<String, String> duplicateTowerCodeMap;

    /**
     * @description Queries External_Code_Dictionary__mdt and returns a display-label-to-code map for the supplied domain.
     */
    private static Map<String, String> loadLabelToCodeMap(String domain) {
        Map<String, String> results = new Map<String, String>();

        for (External_Code_Dictionary__mdt record : [
            SELECT Code__c, Display_Label__c
            FROM External_Code_Dictionary__mdt
            WHERE Domain__c = :domain
                AND Is_Active__c = true
        ]) {
            if (record.Code__c != null && record.Display_Label__c != null) {
                results.put(record.Display_Label__c, record.Code__c);
            }
        }

        return results;
    }

    /**
     * @description Fetches the map of booking milestones to their corresponding codes.
     * @return A map with the milestone display label as the key and the code as the value.
     */
    public static Map<String, String> getMilestoneCodeMap() {
        if (milestoneCodeMap == null) {
            milestoneCodeMap = loadLabelToCodeMap('Booking Milestone');
        }

        return milestoneCodeMap;
    }
    
    public static Map<String, String> getStatusCodeByLabelMap() {
        if (statusCodeMap == null) {
            statusCodeMap = loadLabelToCodeMap('Unit Status');
        }

        return statusCodeMap;
    }
    
    public static Map<String, String> getStatusValueByCodeMap() {
        Map<String, String> statusValueByCode = new Map<String, String>();
        
        Map<String, String> labelToCode = getStatusCodeByLabelMap();
        for (String label : labelToCode.keySet()) {
            statusValueByCode.put(labelToCode.get(label), label);
        }        
        return statusValueByCode;
    }
    
    /**
     * @description Fetches the map of booking milestones to their corresponding codes.
     * @return A map with the milestone display label as the key and the code as the value.
     */
    public static Map<String, String> getMilestoneValueByCodeMap() {
        
        Map<String, String> milestoneValueByCode = new Map<String, String>();
        
        Map<String, String> labelToCode = getMilestoneCodeMap();
        for (String label : labelToCode.keySet()) {
            milestoneValueByCode.put(labelToCode.get(label), label);
        }        
        return milestoneValueByCode;
    }

    /**
     * @description Fetches the map of billing rules to their corresponding codes.
     * @return A map with the billing rule display label as the key and the code as the value.
     */
    public static Map<String, String> getBillRuleMap() {
        if (billRuleMap == null) {
            billRuleMap = loadLabelToCodeMap('Booking Bill Rule');
        }

        return billRuleMap;
    }
    
    /**
     * @description Fetches the map of billing blocks to their corresponding codes.
     * @return A map with the billing block display label as the key and the code as the value.
     */
    public static Map<String, String> getBillBlockMap() {
        if (billBlockMap == null) {
            billBlockMap = loadLabelToCodeMap('Booking Bill Block');
        }

        return billBlockMap;
    }

    /**
     * @description Fetches the map of sales organizations to their corresponding codes.
     * @return A map with the sales org display label as the key and the code as the value.
     */
    public static Map<String, String> getSalesOrgMap() {
        if (salesOrgMap == null) {
            salesOrgMap = loadLabelToCodeMap('Sales Org');
        }

        return salesOrgMap;
    }

    /**
     * @description Fetches the map of distribution channels to their corresponding codes.
     * @return A map with the distribution channel display label as the key and the code as the value.
     */
    public static Map<String, String> getDistributionChannelMap() {
        if (distributionChannelMap == null) {
            distributionChannelMap = loadLabelToCodeMap('Distribution Channel');
        }

        return distributionChannelMap;
    }

    /**
     * @description Fetches the map of divisions to their corresponding codes.
     * @return A map with the division display label as the key and the code as the value.
     */
    public static Map<String, String> getDivisionMap() {
        if (divisionMap == null) {
            divisionMap = loadLabelToCodeMap('Division');
        }

        return divisionMap;
    }

    /**
     * @description Fetches the map of document types to their corresponding codes.
     * @return A map with the document type display label as the key and the code as the value.
     */
    public static Map<String, String> getDocumentTypeMap() {
        if (documentTypeMap == null) {
            documentTypeMap = loadLabelToCodeMap('Document Type');
        }

        return documentTypeMap;
    }
    
    public static string getTowerExternalId(String externalId){
        if (duplicateTowerCodeMap == null) {
            duplicateTowerCodeMap = loadLabelToCodeMap('Tower Duplicate External Id');
        }

        if (duplicateTowerCodeMap.containsKey(externalId)) {
            return duplicateTowerCodeMap.get(externalId);
        }
        return externalId;
    }
}