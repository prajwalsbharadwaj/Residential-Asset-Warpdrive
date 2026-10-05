/**
 * Class Name      : SiteVisitController
 * Description     : Handles Site Visit feedback logic for Public Guest Users.
 * Record Types    : Lead (Standard_Lead_Residential), Site Visit (Residential_Sales_Site_Visit)
 */
public without sharing class SiteVisitController {

    public class SiteVisitWrapper {
        @AuraEnabled public String leadId;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String email;
        @AuraEnabled public String mobile;
        @AuraEnabled public String propertyId; 
        @AuraEnabled public String towerId;    
        @AuraEnabled public String unitId;
        @AuraEnabled public String interactionRating;
        @AuraEnabled public String overallExperience;
        @AuraEnabled public String waitingTime;
    }

    @AuraEnabled(cacheable=true)
    public static List<Property__c> getProperties() {
        return [SELECT Id, Name FROM Property__c ORDER BY Name ASC];
    }

    @AuraEnabled(cacheable=true)
    public static List<Tower__c> getTowers(Id propertyId) {
        return [SELECT Id, Name FROM Tower__c WHERE Property__c = :propertyId ORDER BY Name ASC];
    }

    @AuraEnabled(cacheable=true)
    public static List<Unit__c> getUnits(Id towerId) {
        return [SELECT Id, Name FROM Unit__c WHERE Tower__c = :towerId ORDER BY Name ASC];
    }

    @AuraEnabled
    public static Lead findExistingLead(String phone, String email) {
        if(String.isBlank(phone) && String.isBlank(email)) return null;
        
        // Using bind variables for security and performance
        List<Lead> leads = [SELECT Id, FirstName, LastName, Email, MobilePhone 
                            FROM Lead 
                            WHERE (MobilePhone = :phone AND MobilePhone != null) 
                            OR (Email = :email AND Email != null) 
                            LIMIT 1];
                            
        return leads.isEmpty() ? null : leads[0];
    }

    @AuraEnabled
    // CHANGED PARAMETER NAME TO 'info' TO MATCH YOUR LWC JS
    public static String submitData(SiteVisitWrapper info, String customerSig, String agentSig) {
        if (info == null) {
            throw new AuraHandledException('Submission failed: No data received.');
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Id targetLeadId;

            // 1. Lead Logic
            if (String.isNotBlank(info.leadId)) {
                targetLeadId = (Id)info.leadId;
            } else {
                Id leadRTId = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get('Standard_Lead_Residential').getRecordTypeId();
                Lead newLead = new Lead(
                    FirstName = info.firstName,
                    LastName = info.lastName,
                    MobilePhone = info.mobile,
                    Email = info.email,
                    Company = info.firstName + ' ' + info.lastName,
                    RecordTypeId = leadRTId,
                    Status = 'Open - Not Contacted'
                );
                insert newLead;
                targetLeadId = newLead.Id;
            }

            // 2. Site Visit Logic
            Id svRTId = Schema.SObjectType.Site_Visit__c.getRecordTypeInfosByDeveloperName().get('Residential_Sales_Site_Visit').getRecordTypeId();
            
            Site_Visit__c sv = new Site_Visit__c();
            sv.RecordTypeId = svRTId;
            sv.Lead__c = targetLeadId;
            sv.Project__c = info.propertyId;   
            sv.Building__c = info.towerId;     
            sv.Unit__c = info.unitId;
            sv.Visit_DateTime__c = System.now(); 
            sv.Status__c = 'Completed';
            
            sv.How_was_your_interaction_with_our_sales__c = info.interactionRating;
            sv.Your_Overall_Experience__c = info.overallExperience;
            
            if(String.isNotBlank(info.waitingTime)) {
                sv.Waiting_Time_Before_Assistance_minutes__c = Decimal.valueOf(info.waitingTime);
            }
            insert sv;

            // 3. Signature Logic with Safety Checks
            if(String.isNotBlank(customerSig) && customerSig.contains(',')) {
                saveSignature(customerSig, sv.Id, 'Customer_Signature');
            }
            if(String.isNotBlank(agentSig) && agentSig.contains(',')) {
                saveSignature(agentSig, sv.Id, 'Agent_Signature');
            }

            return 'Success';
        } catch (Exception e) {
            Database.rollback(sp);
            // Log the error for the developer and throw a clean message to the LWC
            System.debug('Submit Error: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static void saveSignature(String base64, Id parentId, String name) {
        ContentVersion cv = new ContentVersion();
        // Added check to prevent split errors
        cv.VersionData = EncodingUtil.base64Decode(base64.substringAfter(','));
        cv.Title = name;
        cv.PathOnClient = name + '.png';
        insert cv;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        cdl.LinkedEntityId = parentId;
        cdl.ShareType = 'V';
        insert cdl;
    }
}