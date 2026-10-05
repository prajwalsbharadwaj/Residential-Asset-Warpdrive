public class SalesOfferController {
    private final ApexPages.StandardController stdController;
    public Id paymentPlanId { get; set; }
    public Id recordId { get; set; }
    public Unit__c unitDetails { get; set; }
    public Quote quoteDetails {get;set;}

    public List<Payment_Schedule__c> paymentPlanDetailList  { get; set; }


    public Decimal baseCost { get; set; }
    public Decimal landCharges {get; set;}
    public Decimal gstAmountOnLandCharges {get; set;}
    public Decimal constructionCharges {get; set;}
    public Decimal gstAmountOnConstCharges {get; set;}
    public decimal landChargesTotal{get;set;}
    public decimal constructionChargesTotal{get;set;}
    public Decimal gstAmount { get; set; }
    public Decimal totalSalePrice { get; set; }
    public Decimal grandTotal { get; set; }
    Public integer countOfPaymentSchedule {get;set;}
    public Decimal bescomBasic { get; set; }
    public Decimal bescomGST { get; set; }
    public Decimal bescomTotal { get; set; }
    public Decimal maintenanceBasic { get; set; }
    public Decimal maintenanceGST { get; set; }
    public Decimal maintenanceTotal { get; set; }
    public Decimal clubBasic { get; set; }
    public Decimal clubGST { get; set; }
    public Decimal clubTotal { get; set; }
    public Decimal legalBasic { get; set; }
    public Decimal legalGST { get; set; }
    public Decimal legalTotal { get; set; }
    public Decimal otherChargesTotalBasic { get; set; }
    public Decimal otherChargesTotalGST { get; set; }
    public Decimal otherChargesTotal { get; set; }
    public Decimal grandTotalWithOtherCharges { get; set; }
    public Decimal gstRate { get; set; }
    
    public Decimal installmentAmountTotal { get; set; }
	public Decimal tableGSTTotal { get; set; }
	public Decimal tableGrandTotalWithGST { get; set; }
    public decimal combinedGST {get;set;}
    public string ReraNumber {get;set;}


    // Required constructor for Visualforce extensions
    public SalesOfferController(ApexPages.StandardController stdController) {
        paymentPlanId = ApexPages.currentPage().getParameters().get('paymentPlanId');
        recordId = ApexPages.currentPage().getParameters().get('recordId');
        this.stdController = stdController;
        initialize(recordId , paymentPlanId ); // run the main logic
    }

    private void initialize(Id recordId ,Id paymentPlanId ) {
        // Get the record) 
        if (recordId == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'No record ID provided. Cannot generate Sales Offer.'));
            return;
        }
        try {
            gstRate = 0.18;
            
            //Fetch Quote.
            quoteDetails = [SELECT Id,Quote_Base_Price__c, BESCOM_BWSSB_Charges__c, Legal_Fees__c, Club_Membership_Fees__c, 
                            Maintenance_Deposit_Corpus_Fund__c, OpportunityId,Opportunity.Interested_Unit__r.Tower__r.Rera_Number__c,
                            Opportunity.Interested_Unit__r.Tower__r.OC_Received__c, Opportunity.Interested_Unit__r.Id,
                            Opportunity.Interested_Unit__r.Tower__c,Opportunity.Chargeable_Area__c
                            FROM Quote WHERE Id =: recordId];
              
            
            unitDetails = [
                SELECT Id, Name, Property__r.Name, Floor__r.Name, Built_Up_Area_SBA__c, Unit_Type__c, 
                       Deck_Balcony__c, Garden_Area__c, Carpet_Area__c,Property__r.Address__c,
                       Private_Lobby__c, Property__r.GSTIN__c, Property__r.CIN__c
                FROM Unit__c
                WHERE Id = :quoteDetails.Opportunity.Interested_Unit__r.Id
                LIMIT 1
            ];
            // Calculate financials
            if (quoteDetails.Quote_Base_Price__c != null) {
                landCharges = (quoteDetails.Quote_Base_Price__c * 1/3) * quoteDetails.opportunity.Chargeable_Area__c;
                gstAmountOnLandCharges = 0;
                landChargesTotal = landCharges;
                constructionCharges = (quoteDetails.Quote_Base_Price__c * 2/3) * quoteDetails.opportunity.Chargeable_Area__c;
                if(quoteDetails.Opportunity.Interested_Unit__r.Tower__r.OC_Received__c == false){
                    gstAmountOnConstCharges = (constructionCharges * 2/3) * 0.12 ;
                    constructionChargesTotal = constructionCharges + gstAmountOnConstCharges;
                } else {            
                    gstAmountOnConstCharges = 0 ;
                    constructionChargesTotal = constructionCharges;
                }
                grandTotal = landChargesTotal + constructionChargesTotal;
            }
            
            // Other Charges
            bescomBasic = quoteDetails.BESCOM_BWSSB_Charges__c != null ? quoteDetails.BESCOM_BWSSB_Charges__c * quoteDetails.opportunity.Chargeable_Area__c : 0;
            bescomGST = bescomBasic * gstRate;
            bescomTotal = bescomBasic + bescomGST;
            
            maintenanceBasic = quoteDetails.Maintenance_Deposit_Corpus_Fund__c != null ? quoteDetails.Maintenance_Deposit_Corpus_Fund__c  * quoteDetails.opportunity.Chargeable_Area__c  : 0;
            maintenanceGST = maintenanceBasic * 0;
            maintenanceTotal = maintenanceBasic + maintenanceGST;
            
            clubBasic = quoteDetails.Club_Membership_Fees__c != null ? quoteDetails.Club_Membership_Fees__c : 0;
            clubGST = clubBasic * gstRate;
            clubTotal = clubBasic + clubGST;
            
            legalBasic = quoteDetails.Legal_Fees__c != null ? quoteDetails.Legal_Fees__c : 0;
            legalGST = legalBasic * gstRate;
            legalTotal = legalBasic + legalGST;
            // Totals for other charges
            otherChargesTotalBasic = bescomBasic + maintenanceBasic + clubBasic + legalBasic;
            otherChargesTotalGST = bescomGST + maintenanceGST + clubGST + legalGST;
            otherChargesTotal = bescomTotal + maintenanceTotal + clubTotal + legalTotal;
            // Grand total (A+B)
            grandTotalWithOtherCharges = grandTotal + otherChargesTotal;

            paymentPlanDetailList = [ SELECT Id, Name, Payment_Percentage__c  FROM Payment_Schedule__c  WHERE Payment_Plan_Id__r.Id = :paymentPlanId  Order by Installment_Number__c asc];
            countOfPaymentSchedule = paymentPlanDetailList?.size();
            installmentAmountTotal = 0;
			tableGSTTotal = 0;
            combinedGST = otherChargesTotalGST + gstAmountOnConstCharges + gstAmountOnLandCharges;

			for (Payment_Schedule__c detail : paymentPlanDetailList) {
    			installmentAmountTotal += (detail.Payment_Percentage__c * grandTotalWithOtherCharges)/100 - combinedGST/countOfPaymentSchedule;
                tableGSTTotal += combinedGST/countOfPaymentSchedule;
			}
            tableGrandTotalWithGST = installmentAmountTotal + tableGSTTotal;
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'An error occurred: ' + e.getMessage()));
            System.debug('SalesOfferController Error: ' + e.getMessage() + ' at line ' + e.getLineNumber());
            ExceptionLogger.logException(
                new ExceptionLogger.ExceptionLogPayload().withComponentName('Generate Sales Offer Pdf on Quote').withClassName('SalesOfferController').withMethodName('initialize').withDescription('Failed to generate pdf on Quote record page').withException(e)
            );
        }
        if (unitDetails == null) unitDetails = new Unit__c();
    }
}