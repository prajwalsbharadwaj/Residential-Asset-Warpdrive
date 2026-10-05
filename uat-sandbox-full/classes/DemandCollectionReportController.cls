public with sharing class DemandCollectionReportController {
    
    // Wrapper class for response
    public class PaymentReceiptResponse {
        @AuraEnabled public List<ReceiptsDto> records { get; set; }
        @AuraEnabled public Integer totalRecords { get; set; }
        @AuraEnabled public Integer pageNumber { get; set; }
        @AuraEnabled public Integer pageSize { get; set; }
        @AuraEnabled public Integer totalPages { get; set; }
    }
    
    public class ReceiptsDto {
    // Basic info
    @AuraEnabled public String Project { get; set; }
    @AuraEnabled public String Subproject { get; set; }
    @AuraEnabled public String CustomerName { get; set; }
    @AuraEnabled public String UnitNo { get; set; }
    @AuraEnabled public String Status { get; set; }
    @AuraEnabled public Decimal BaseRate { get; set; }
    @AuraEnabled public Decimal SBA { get; set; }
    @AuraEnabled public String CustCode { get; set; }
    @AuraEnabled public Object CustomerAddressBilling { get; set; }
    @AuraEnabled public String PAN { get; set; }
    
    // Dates
    @AuraEnabled public Date DemandCreatedDate { get; set; }
    @AuraEnabled public Date ReceiptDate { get; set; }
    
    // Demand & collection
    @AuraEnabled public String PaymentReceiptNumber { get; set; }
    @AuraEnabled public String DemandId { get; set; }
    @AuraEnabled public String IsAutoTaxOrReceiptStatus { get; set; }
    @AuraEnabled public Decimal DemandInvoiceValue { get; set; }
    @AuraEnabled public Decimal ReceiptAmt { get; set; }
    @AuraEnabled public Decimal InterestDue { get; set; }
    @AuraEnabled public Decimal InterestPaidOrTotalInterestReceived { get; set; }
    
    // Previous dues and charges
    @AuraEnabled public Decimal PrevDuePrincipleOnly { get; set; }
    @AuraEnabled public Decimal BasicConstructionCost { get; set; }
    @AuraEnabled public Decimal BESCOMAndBWSSBCharges { get; set; }
    @AuraEnabled public Decimal ClubMembershipFee { get; set; }
    @AuraEnabled public Decimal LandCost { get; set; }
    @AuraEnabled public Decimal LegalFees { get; set; }
    @AuraEnabled public Decimal MaintenanceDeposit { get; set; }
    
    // Taxable amounts
    @AuraEnabled public Decimal OthrChrgCgstTaxableAmt { get; set; }
    @AuraEnabled public Decimal OthrChrgSgstTaxableAmt { get; set; }
    @AuraEnabled public Decimal CGSTOnOtherChrg { get; set; }
    @AuraEnabled public Decimal SGSTOnOtherChrg{ get; set; }
}

    @AuraEnabled(cacheable=true)
    public static PaymentReceiptResponse getPaymentReceipts(Date startDate, Date endDate, Integer pageNumber, Integer pageSize) {

        List<Payment_Receipt__c> records = ReportSelector.getPaymentReceipt(startDate, endDate, pageNumber, pageSize);
        list<ReceiptsDto> receiptDetails = new list<ReceiptsDto>();
        for(Payment_Receipt__c receipt:records){
            ReceiptsDto wrapper = new ReceiptsDto();
            wrapper.Project = receipt?.Demand__r?.Unit__r?.Property__r?.Name;
            wrapper.Subproject = receipt?.Demand__r?.Unit__r?.Tower__r?.Name;
            wrapper.CustomerName = receipt?.Account__r?.Name;
            wrapper.UnitNo = receipt?.Demand__r?.Unit__r?.Name;
            //wrapper.Status = ??
            wrapper.BaseRate = receipt?.Booking_Payment_Schedule__r?.Opportunity__r?.BasePrice__c;
            wrapper.SBA = receipt?.Demand__r?.Unit__r?.Built_Up_Area_SBA__c;
            wrapper.CustCode = receipt?.Account__r?.Company_Code__c;
            wrapper.CustomerAddressBilling = receipt?.Account__r?.BillingAddress;
            wrapper.PAN = receipt?.Account__r?.Pan_Number__c;
            wrapper.DemandCreatedDate = date.valueOf(receipt?.Demand__r.createdDate);
            wrapper.ReceiptDate = receipt.Date_Of_Payment__c;
            wrapper.PaymentReceiptNumber = receipt.Name;
            wrapper.DemandId = receipt?.Demand__r?.SAP_External_Id__c;
            wrapper.IsAutoTaxOrReceiptStatus = receipt.Receipt_Status__c;
            wrapper.DemandInvoiceValue = receipt?.Booking_Payment_Schedule__r?.installment_amount__c;
            wrapper.ReceiptAmt = receipt.Amount_Paid__c;
            wrapper.InterestDue = receipt?.Booking_Payment_Schedule__r?.Booking__r?.Total_Interest_Outstanding__c;
            wrapper.InterestPaidOrTotalInterestReceived = receipt?.Booking_Payment_Schedule__r?.Booking__r?.InterestReceivedFromLedger__c;
            // previous Dues.
            if(receipt.Booking_Payment_Schedule__r.Booking__c != null){
                decimal outstandingPrincipal = ReportSelector.getPrevDues(receipt.Booking_Payment_Schedule__r.Booking__c);
                wrapper.PrevDuePrincipleOnly = outstandingPrincipal;
            }
            wrapper.BasicConstructionCost = receipt?.Booking_Payment_Schedule__r?.Opportunity__r?.Construction_Cost__c;
            wrapper.LandCost = receipt?.Booking_Payment_Schedule__r?.Opportunity__r?.Land_Cost__c;
            wrapper.ClubMembershipFee = receipt?.Demand__r?.Unit__r?.Tower__r?.Club_Membership_Fees__c;
            wrapper.LegalFees = receipt?.Demand__r?.Unit__r?.Tower__r?.Legal_Fees__c;
            
            //Some charges are subjected to chargeable area.
            decimal chargeableArea = receipt?.Booking_Payment_Schedule__r?.Opportunity__r?.Chargeable_Area__c;
            chargeableArea = chargeableArea != null ? chargeableArea : 1;
            
            decimal calculatedMaintenance = receipt?.Demand__r?.Unit__r?.Tower__r?.Maintenance_Deposit_Corpus_Fund__c;
            calculatedMaintenance = calculatedMaintenance != null ? calculatedMaintenance * chargeableArea : 0;
            
            decimal calculatedBescom = receipt?.Demand__r?.Unit__r.Tower__r?.BESCOM_BWSSB_Charges__c;
            calculatedBescom = calculatedBescom != null ? calculatedBescom * chargeableArea : 0;
            
            wrapper.BESCOMAndBWSSBCharges = calculatedBescom;
            wrapper.MaintenanceDeposit = calculatedMaintenance;
            
            //Other charges
            decimal taxableOtherCharges = 0;
            taxableOtherCharges = receipt?.Booking_Payment_Schedule__r?.Opportunity__r?.Taxable_Other_Charges__c;
            wrapper.OthrChrgCgstTaxableAmt = taxableOtherCharges > 0 ? taxableOtherCharges/2 : 0;
            wrapper.OthrChrgSgstTaxableAmt = taxableOtherCharges > 0 ? taxableOtherCharges/2 : 0;
            
            decimal taxOnOtherCharges = 0;
            taxOnOtherCharges = receipt?.Booking_Payment_Schedule__r?.Opportunity__r?.TaxOnOtherCharges__c;
            wrapper.CGSTOnOtherChrg = taxOnOtherCharges > 0 ? taxOnOtherCharges/2 : 0;
            wrapper.SGSTOnOtherChrg = taxOnOtherCharges > 0 ? taxOnOtherCharges/2 : 0;
            
            receiptDetails.add(wrapper);
        }

        Integer totalRecords = [
            SELECT COUNT() 
            FROM Payment_Receipt__c 
            WHERE Date_Of_Payment__c >= :startDate AND Date_Of_Payment__c <= :endDate
        ];

        PaymentReceiptResponse response = new PaymentReceiptResponse();
        response.records = receiptDetails;
        response.totalRecords = totalRecords;
        response.pageNumber = pageNumber;
        response.pageSize = pageSize;
        response.totalPages = (Integer) Math.ceil((Decimal) totalRecords / pageSize);

        return response;
    }
}