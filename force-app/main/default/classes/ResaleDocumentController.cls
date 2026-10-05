/**
 * Controller for Resale document generation.
 * Handles: Payment Receipt, Transfer NOC, Ownership Certificate, New Owner Letter.
 * Called from VF pages triggered by the Generate_Resale_Documents WebLink on Opportunity.
 */
public with sharing class ResaleDocumentController {

    public Opportunity opp        { get; private set; }
    public Account previousOwner  { get; private set; }
    public Account newBuyer       { get; private set; }
    public Unit__c unit           { get; private set; }
    public String  docType        { get; private set; }
    public String  todayFormatted { get; private set; }
    public String  projectName    { get; private set; }
    public String  towerName      { get; private set; }
    public String  unitName       { get; private set; }

    public ResaleDocumentController() {
        Id oppId = ApexPages.currentPage().getParameters().get('id');
        docType  = ApexPages.currentPage().getParameters().get('type');
        todayFormatted = DateTime.now().format('dd MMMM yyyy');
        if (oppId != null) {
            loadData(oppId);
        }
    }

    public ResaleDocumentController(ApexPages.StandardController stdController) {
        docType  = ApexPages.currentPage().getParameters().get('type');
        todayFormatted = DateTime.now().format('dd MMMM yyyy');
        Id oppId = stdController.getId();
        if (oppId != null) {
            loadData(oppId);
        }
    }

    private void loadData(Id oppId) {
        opp = [
            SELECT Id, Name, Buyer_Name__c, Buyer_Phone__c, Buyer_Email__c,
                Previous_Owner__c, Interested_Unit__c, Final_Resale_Value__c,
                Expected_Resale_Price__c, CloseDate, OwnerId, Owner.Name,
                Amount_Received__c, Outstanding_Amount__c, Full_Payment_Received__c,
                Transfer_Deed_Number__c, Ownership_Transfer_Status__c,
                Booking_Form_Submitted_At__c, Buyer_KYC_Status__c,
                AccountId, Account.Name, Account.PersonEmail, Account.PersonMobilePhone,
                Account.PersonMailingStreet, Account.PersonMailingCity, Account.PersonMailingState,
                Account.PAN_Number__c,
                Interested_Unit__r.Name, Interested_Unit__r.BHK_Configuration__c,
                Interested_Unit__r.Saleable_Area__c, Interested_Unit__r.Carpet_Area__c,
                Interested_Unit__r.Floor__r.Name, Interested_Unit__r.Tower__r.Name,
                Interested_Unit__r.Tower__r.RERA_Number__c,
                Interested_Unit__r.Property__r.Name, Interested_Unit__r.Property__r.Address__c
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];

        // Previous owner account
        if (opp.Previous_Owner__c != null) {
            List<Account> prevOwners = [
                SELECT Id, Name, PersonEmail, PersonMobilePhone, PersonMailingStreet, PersonMailingCity,
                    PersonMailingState, PAN_Number__c
                FROM Account WHERE Id = :opp.Previous_Owner__c LIMIT 1
            ];
            if (!prevOwners.isEmpty()) previousOwner = prevOwners[0];
        }

        // New buyer = AccountId on the Opportunity
        if (opp.AccountId != null) {
            List<Account> buyers = [
                SELECT Id, Name, PersonEmail, PersonMobilePhone, PersonMailingStreet, PersonMailingCity,
                    PersonMailingState, PAN_Number__c, Aadhar_Number__c
                FROM Account WHERE Id = :opp.AccountId LIMIT 1
            ];
            if (!buyers.isEmpty()) newBuyer = buyers[0];
        }

        projectName = opp.Interested_Unit__r?.Property__r?.Name;
        towerName   = opp.Interested_Unit__r?.Tower__r?.Name;
        unitName    = opp.Interested_Unit__r?.Name;
    }

    /** PageReference action: generates the document as a Salesforce File and navigates to the record. */
    public PageReference generateAndSave() {
        // The VF pages handle rendering; this action is used when saving a PDF attachment
        return null;
    }

    /** Formatted agreed value */
    public String getAgreedValueFormatted() {
        Decimal val = opp?.Final_Resale_Value__c != null ? opp.Final_Resale_Value__c : opp?.Expected_Resale_Price__c;
        if (val == null) return 'N/A';
        return 'INR ' + val.format();
    }

    /** Formatted amount received */
    public String getAmountReceivedFormatted() {
        Decimal val = opp?.Amount_Received__c;
        if (val == null) return 'N/A';
        return 'INR ' + val.format();
    }

    /** Formatted outstanding amount */
    public String getOutstandingAmountFormatted() {
        Decimal val = opp?.Outstanding_Amount__c;
        if (val == null) return 'N/A';
        return 'INR ' + val.format();
    }

    public String getNewBuyerAddress() {
        if (newBuyer == null) return '';
        List<String> parts = new List<String>();
        if (String.isNotBlank(newBuyer.PersonMailingStreet)) parts.add(newBuyer.PersonMailingStreet);
        if (String.isNotBlank(newBuyer.PersonMailingCity))   parts.add(newBuyer.PersonMailingCity);
        if (String.isNotBlank(newBuyer.PersonMailingState))  parts.add(newBuyer.PersonMailingState);
        return String.join(parts, ', ');
    }

    public String getPreviousOwnerAddress() {
        if (previousOwner == null) return '';
        List<String> parts = new List<String>();
        if (String.isNotBlank(previousOwner.PersonMailingStreet)) parts.add(previousOwner.PersonMailingStreet);
        if (String.isNotBlank(previousOwner.PersonMailingCity))   parts.add(previousOwner.PersonMailingCity);
        if (String.isNotBlank(previousOwner.PersonMailingState))  parts.add(previousOwner.PersonMailingState);
        return String.join(parts, ', ');
    }
}