/**
 * @description Service class to initiate Post-Handover Resale and Rental opportunities
 * directly from Booking__c, adhering to the enterprise architecture where Booking
 * remains the anchor for property ownership, unit, and customer context.
 */
public without sharing class BookingResaleRentalService {

    public class ResaleInitiationResult {
        @AuraEnabled public Id opportunityId { get; set; }
        @AuraEnabled public String opportunityName { get; set; }
        @AuraEnabled public String recordType { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String message { get; set; }
    }

    /**
     * @description Initiates a Resale Assistance Opportunity from a confirmed Booking.
     */
    @AuraEnabled
    public static ResaleInitiationResult createResaleOpportunityFromBooking(Id bookingId, Decimal expectedPrice, String remarks) {
        if (bookingId == null) {
            throw new AuraHandledException('Booking ID is required.');
        }

        List<Booking__c> bList = [
            SELECT Id, Name, Account_Id__c, Account_Id__r.Name, Account_Id__r.PersonContactId,
                   Unit_Id__c, Unit_Id__r.Name, Project__c, Project__r.Name
            FROM Booking__c
            WHERE Id = :bookingId
            LIMIT 1
        ];

        if (bList.isEmpty()) {
            throw new AuraHandledException('Booking record not found.');
        }

        Booking__c b = bList[0];

        // Fetch Resale Assistance RecordType
        Id resaleRtId;
        List<RecordType> rtList = [
            SELECT Id FROM RecordType 
            WHERE SObjectType = 'Opportunity' AND DeveloperName = 'Resale_Assistance' AND IsActive = true 
            LIMIT 1
        ];
        if (!rtList.isEmpty()) {
            resaleRtId = rtList[0].Id;
        }

        String unitName = (b.Unit_Id__r != null) ? b.Unit_Id__r.Name : 'Unit';
        String customerName = (b.Account_Id__r != null) ? b.Account_Id__r.Name : 'Customer';

        Opportunity opp = new Opportunity();
        opp.Name = 'Resale: ' + unitName + ' - ' + customerName;
        opp.AccountId = b.Account_Id__c;
        if (resaleRtId != null) {
            opp.RecordTypeId = resaleRtId;
        }
        opp.Booking__c = b.Id;
        opp.interested_unit__c = b.Unit_Id__c;
        opp.Amount = (expectedPrice != null && expectedPrice > 0) ? expectedPrice : 0;
        opp.Expected_Resale_Price__c = (expectedPrice != null && expectedPrice > 0) ? expectedPrice : 0;
        opp.Resale_Remarks__c = remarks;
        opp.Source_Channel__c = 'Direct Owner';
        opp.Resale_Approval_Status__c = 'Not Submitted';
        opp.Buyer_KYC_Status__c = 'Pending';
        opp.StageName = 'Resale Initiation';
        opp.CloseDate = Date.today().addDays(60);
        opp.Description = String.isNotBlank(remarks) 
            ? remarks 
            : ('Resale Assistance initiated for ' + unitName + ' from Booking ' + b.Name);
        insert opp;

        // Log initiation Task
        Task t = new Task();
        t.WhatId = opp.Id;
        if (b.Account_Id__r != null && b.Account_Id__r.PersonContactId != null) {
            t.WhoId = b.Account_Id__r.PersonContactId;
        }
        t.Subject = 'Resale Assistance Initiated';
        t.ActivityDate = Date.today();
        t.Status = 'Completed';
        t.Priority = 'Normal';
        t.Description = 'Resale opportunity created from Booking ' + b.Name + ' for Unit ' + unitName + '. Expected Price: ₹' + (opp.Amount != null ? opp.Amount.format() : '0');
        t.OwnerId = UserInfo.getUserId();
        insert t;

        ResaleInitiationResult res = new ResaleInitiationResult();
        res.opportunityId = opp.Id;
        res.opportunityName = opp.Name;
        res.recordType = 'Resale Assistance';
        res.status = 'Success';
        res.message = 'Resale Assistance Opportunity successfully initiated from Booking.';
        return res;
    }

    /**
     * @description Initiates a Rental Management Opportunity from a confirmed Booking.
     */
    @AuraEnabled
    public static ResaleInitiationResult createRentalOpportunityFromBooking(Id bookingId, Decimal expectedRent, Date availableDate, String remarks) {
        if (bookingId == null) {
            throw new AuraHandledException('Booking ID is required.');
        }

        List<Booking__c> bList = [
            SELECT Id, Name, Account_Id__c, Account_Id__r.Name, Account_Id__r.PersonContactId,
                   Unit_Id__c, Unit_Id__r.Name, Project__c, Project__r.Name
            FROM Booking__c
            WHERE Id = :bookingId
            LIMIT 1
        ];

        if (bList.isEmpty()) {
            throw new AuraHandledException('Booking record not found.');
        }

        Booking__c b = bList[0];

        // Fetch Rental RecordType
        Id rentalRtId;
        List<RecordType> rtList = [
            SELECT Id FROM RecordType 
            WHERE SObjectType = 'Opportunity' AND DeveloperName = 'Rental' AND IsActive = true 
            LIMIT 1
        ];
        if (!rtList.isEmpty()) {
            rentalRtId = rtList[0].Id;
        }

        String unitName = (b.Unit_Id__r != null) ? b.Unit_Id__r.Name : 'Unit';
        String customerName = (b.Account_Id__r != null) ? b.Account_Id__r.Name : 'Customer';

        Opportunity opp = new Opportunity();
        opp.Name = 'Rental: ' + unitName + ' - ' + customerName;
        opp.AccountId = b.Account_Id__c;
        if (rentalRtId != null) {
            opp.RecordTypeId = rentalRtId;
        }
        opp.Booking__c = b.Id;
        opp.interested_unit__c = b.Unit_Id__c;
        opp.Amount = (expectedRent != null && expectedRent > 0) ? (expectedRent * 12) : 0; // Annualized rent
        opp.Expected_Rent__c = (expectedRent != null && expectedRent > 0) ? expectedRent : 0;
        opp.Lease_Start_Date__c = (availableDate != null) ? availableDate : Date.today().addDays(30);
        opp.Source_Channel__c = 'Direct Owner';
        opp.Rental_Approval_Status__c = 'Not Submitted';
        opp.Tenant_KYC_Status__c = 'Pending';
        opp.StageName = 'Rental Initiation';
        opp.CloseDate = (availableDate != null) ? availableDate : Date.today().addDays(30);
        opp.Description = String.isNotBlank(remarks) 
            ? remarks 
            : ('Rental Management Assistance initiated for ' + unitName + ' from Booking ' + b.Name);
        insert opp;

        // Log initiation Task
        Task t = new Task();
        t.WhatId = opp.Id;
        if (b.Account_Id__r != null && b.Account_Id__r.PersonContactId != null) {
            t.WhoId = b.Account_Id__r.PersonContactId;
        }
        t.Subject = 'Rental Assistance Initiated';
        t.ActivityDate = Date.today();
        t.Status = 'Completed';
        t.Priority = 'Normal';
        t.Description = 'Rental opportunity created from Booking ' + b.Name + ' for Unit ' + unitName + '. Expected Monthly Rent: ₹' + (expectedRent != null ? expectedRent.format() : '0');
        t.OwnerId = UserInfo.getUserId();
        insert t;

        ResaleInitiationResult res = new ResaleInitiationResult();
        res.opportunityId = opp.Id;
        res.opportunityName = opp.Name;
        res.recordType = 'Rental';
        res.status = 'Success';
        res.message = 'Rental Opportunity successfully initiated from Booking.';
        return res;
    }
}