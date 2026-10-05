public without sharing class ResaleSalesOrderPDFController {

    public String quoteNumber        { get; private set; }
    public String opportunityName    { get; private set; }
    public String buyerName          { get; private set; }
    public String accountName        { get; private set; }
    public String unitName           { get; private set; }
    public String projectName        { get; private set; }
    public String towerName          { get; private set; }
    public String configuration      { get; private set; }
    public String chargeableArea     { get; private set; }
    public String originalBookingValue { get; private set; }
    public String proposedResaleValue  { get; private set; }
    public String resaleCharges        { get; private set; }
    public String brokerageFee         { get; private set; }
    public String discount             { get; private set; }
    public String grandTotal           { get; private set; }
    public String paymentType          { get; private set; }
    public String dueDate              { get; private set; }
    public String remarks              { get; private set; }
    public String orderDate            { get; private set; }

    public ResaleSalesOrderPDFController() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        String quoteId   = params.get('quoteId');
        paymentType      = params.get('paymentType');
        dueDate          = params.get('dueDate');
        remarks          = params.get('remarks');
        orderDate        = Datetime.now().format('dd MMM yyyy');

        if (String.isBlank(quoteId)) return;

        try {
            Quote q = [
                SELECT Id, Name, QuoteNumber, OpportunityId,
                    Proposed_Resale_Value__c, Resale_Charges__c,
                    Resale_Brokerage_Fee__c, Resale_Discount__c,
                    Final_Resale_Value__c, Original_Booking_Value__c,
                    Chargeable_Area__c,
                    Opportunity.Name, Opportunity.Buyer_Name__c,
                    Opportunity.Account.Name,
                    Opportunity.Interested_Unit__r.Name,
                    Opportunity.Interested_Unit__r.BHK_Configuration__c,
                    Opportunity.Interested_Unit__r.Property__r.Name,
                    Opportunity.Interested_Unit__r.Tower__r.Name
                FROM Quote WHERE Id = :quoteId LIMIT 1
            ];
            quoteNumber          = q.Name;
            opportunityName      = q.Opportunity?.Name ?? '';
            buyerName            = q.Opportunity?.Buyer_Name__c ?? '';
            accountName          = q.Opportunity?.Account?.Name ?? '';
            unitName             = q.Opportunity?.Interested_Unit__r?.Name ?? '';
            projectName          = q.Opportunity?.Interested_Unit__r?.Property__r?.Name ?? '';
            towerName            = q.Opportunity?.Interested_Unit__r?.Tower__r?.Name ?? '';
            configuration        = q.Opportunity?.Interested_Unit__r?.BHK_Configuration__c != null
                                   ? String.valueOf(q.Opportunity.Interested_Unit__r.BHK_Configuration__c) : '';
            chargeableArea       = q.Chargeable_Area__c != null ? String.valueOf(q.Chargeable_Area__c.setScale(2)) : '0';
            originalBookingValue = fmt(q.Original_Booking_Value__c);
            proposedResaleValue  = fmt(q.Proposed_Resale_Value__c);
            resaleCharges        = fmt(q.Resale_Charges__c);
            brokerageFee         = fmt(q.Resale_Brokerage_Fee__c);
            discount             = fmt(q.Resale_Discount__c);
            grandTotal           = fmt(q.Final_Resale_Value__c);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'ResaleSalesOrderPDFController error: ' + e.getMessage());
        }
    }

    private static String fmt(Decimal d) {
        return d != null ? d.setScale(2).toPlainString() : '0.00';
    }
}