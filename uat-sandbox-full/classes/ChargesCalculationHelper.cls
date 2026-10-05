public with sharing class ChargesCalculationHelper {

    public static FinancialsWrapper calculateCharges(Id recordId) {
        FinancialsWrapper financials = new FinancialsWrapper();
        Id opportunityId;

        if (recordId.getSObjectType() == Booking__c.SObjectType) {
            Booking__c booking = [
                SELECT Id, Opportunity_Id__c 
                FROM Booking__c 
                WHERE Id = :recordId LIMIT 1
            ];
            opportunityId = booking != null ? booking.Opportunity_Id__c : null;
        } else if (recordId.getSObjectType() == Opportunity.SObjectType) {
            opportunityId = recordId;
        }

        if (opportunityId == null) {
            throw new AuraHandledException('No valid Opportunity found for the given record ID.');
        }

        Opportunity opp = [
            SELECT Id, Actual_Discount_Percentage__c,TaxOnOtherCharges__c,OtherCharges__c,
                   (SELECT Id, toLabel(Condition_Type__c) labelConditionType, Type__c, Amount__c, Quantity__c, Percentage__c, Condition_Type__c, Amount_By_Type__c
                    FROM Booking_Conditions__r)
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        if (opp == null || opp.Booking_Conditions__r.isEmpty()) {
            // Return an initialized empty wrapper instead of a partially null one
            return financials;
        }

        Decimal baseRate = 0;
        Decimal baseQty = 0;
        Decimal cgstConstPct = 0;
        Decimal sgstConstPct = 0;
        Decimal cgstLandPct = 0;
        Decimal sgstLandPct = 0;
        Decimal cgstOtherPct = 0;
        Decimal sgstOtherPct = 0;

        List<OtherChargeRow> otherCharges = new List<OtherChargeRow>();

        for (Booking_Condition__c bc : opp.Booking_Conditions__r) {
            if (bc.Condition_Type__c == 'Base Price') {
                baseRate = (bc.Amount__c != null) ? bc.Amount__c : 0;
                baseQty = (bc.Quantity__c != null) ? bc.Quantity__c : 0;
            } else if (bc.Condition_Type__c == 'IN: 2/3 CGST Tax') {
                cgstConstPct = (bc.Percentage__c != null) ? bc.Percentage__c : 0;
            } else if (bc.Condition_Type__c == 'IN: 2/3 SGST Tax') {
                sgstConstPct = (bc.Percentage__c != null) ? bc.Percentage__c : 0;
            } else if (bc.Condition_Type__c == 'IN: 1/3 CGST Tax') {
                cgstLandPct = (bc.Percentage__c != null) ? bc.Percentage__c : 0;
            } else if (bc.Condition_Type__c == 'IN: 1/3 SGST Tax') {
                sgstLandPct = (bc.Percentage__c != null) ? bc.Percentage__c : 0;
            } else if (bc.Condition_Type__c == 'IN: O/P CGST Tax') {
                cgstOtherPct = (bc.Percentage__c != null) ? bc.Percentage__c : 0;
            } else if (bc.Condition_Type__c == 'IN: O/P SGST Tax') {
                sgstOtherPct = (bc.Percentage__c != null) ? bc.Percentage__c : 0;
            } else if (bc.Condition_Type__c == 'Brokerage Fix Amt' || bc.Condition_Type__c == 'Base Price Discount' || bc.Condition_Type__c == '1/3 Agreement Value' || bc.Condition_Type__c == '2/3 Agreement Value') {
                continue;
            } else {
                // Treat as Other Charges
                OtherChargeRow oc = new OtherChargeRow();
                oc.name = (String) bc.get('labelConditionType');
                oc.amount = 0;
                // based on current logic
                oc.type = 'RateBased';
                oc.rate = bc.Amount__c;
                oc.quantity = bc.Quantity__c;
                oc.amount = bc.Amount__c;
                oc.amountByType = bc.Amount_By_Type__c;
                
                // based on field logic
                /* if (bc.Type__c == 'Rate' && bc.Amount__c != null && bc.Quantity__c != null) {
                    oc.type = 'RateBased';
                    oc.rate = bc.Amount__c;
                    oc.quantity = bc.Quantity__c;
                    oc.amount = bc.Amount__c * bc.Quantity__c;
                } else if (bc.Type__c == 'Fixed Amount' && bc.Amount__c != null) {
                    oc.type = 'Fixed';
                    oc.amount = bc.Amount__c;
                } */
                otherCharges.add(oc);
            }
        }

        Decimal baseCost = baseRate * baseQty;
        
        // Discount
        Decimal discountPct = (opp.Actual_Discount_Percentage__c != null) ? opp.Actual_Discount_Percentage__c : 0;
        Decimal discountAmt = (baseCost * discountPct) / 100;

        // Discounted Base Cost
        Decimal discountedBase = baseCost - discountAmt;
        
        // Land & Construction
        Decimal landCostAmt = discountedBase / 3;
        Decimal constCostAmt = (2 * discountedBase) / 3;

        // Taxes
        Decimal taxOnConst = (constCostAmt * (cgstConstPct + sgstConstPct)) / 100;
        Decimal taxOnLand = (landCostAmt * (cgstLandPct + sgstLandPct)) / 100;

        // Actual Base Cost
        Decimal totalLandConst = landCostAmt + constCostAmt + taxOnLand + taxOnConst;
        
        // Other Charges Summary
        Decimal totalOther = 0;
        /*for (OtherChargeRow oc : otherCharges) {
            totalOther += oc.amount;
        }*/
        totalOther = opp.OtherCharges__c != null ? opp.OtherCharges__c : 0;
        //Decimal cgstOther = totalOther * (cgstOtherPct / 100);
        //Decimal sgstOther = totalOther * (sgstOtherPct / 100);
        Decimal cgstOther = opp.TaxOnOtherCharges__c != null ? (opp.TaxOnOtherCharges__c/2).setScale(0, RoundingMode.HALF_UP) : 0;
        Decimal sgstOther = opp.TaxOnOtherCharges__c != null ? (opp.TaxOnOtherCharges__c/2).setScale(0, RoundingMode.HALF_UP) : 0;
        
        
        Decimal grandOther = totalOther + cgstOther + sgstOther;

        // Populate Wrapper
        financials.landCost.put('calculatedAmount', landCostAmt);
        financials.constructionCost.put('calculatedAmount', constCostAmt);

        financials.discount.put('percentage', discountPct);
        financials.discount.put('amount', discountAmt);
        
        financials.otherCharges = otherCharges;
        financials.otherChargesSummary.put('totalOtherCharges', totalOther);
        financials.otherChargesSummary.put('cgstOnOtherCharges', cgstOther);
        financials.otherChargesSummary.put('sgstOnOtherCharges', sgstOther);
        financials.otherChargesSummary.put('grandTotalOtherCharges', grandOther);
        
        financials.Summary.put('LandCost', landCostAmt);
        financials.Summary.put('ConstructionCost', constCostAmt);
        financials.Summary.put('taxOnLandCost', taxOnLand);
        financials.Summary.put('taxOnConstructionCost', taxOnConst);
        financials.Summary.put('total', totalLandConst);
        
        financials.Summary.put('otherChargesTotal', totalOther);
        financials.Summary.put('cgstOnOtherCharges', cgstOther);
        financials.Summary.put('sgstOnOtherCharges', sgstOther);
        financials.Summary.put('grandTotal', totalLandConst + grandOther);

        return financials;
    }
    
    public class FinancialsWrapper {
        public Map<String, Object> landCost { get; set; }
        public Map<String, Object> constructionCost { get; set; }
        public Map<String, Object> Summary { get; set; }
        public Map<String, Object> discount { get; set; }
        public List<OtherChargeRow> otherCharges { get; set; }
        public Map<String, Object> otherChargesSummary { get; set; }
    
        public FinancialsWrapper() {
            landCost = new Map<String, Object>();
            constructionCost = new Map<String, Object>();
            Summary = new Map<String, Object>();
            discount = new Map<String, Object>();
            otherCharges = new List<OtherChargeRow>();
            otherChargesSummary = new Map<String, Object>();
        }
    }
    
    public class OtherChargeRow {
        public String name { get; set; }
        public String type { get; set; }
        public Decimal rate { get; set; }
        public Decimal quantity { get; set; }
        public Decimal amount { get; set; }
        public Decimal amountByType { get; set; }
    }
    
    public static String formatIndianCurrency(Decimal amount) {
        if (amount == null) { return ''; }
        String formattedAmount = String.valueOf(amount.setScale(2));
        String[] parts = formattedAmount.split('\\.');
        String integerPart = parts[0];
        String decimalPart = parts.size() > 1 ? '.' + parts[1] : '';
    
        // Handle negative numbers
        Boolean isNegative = integerPart.startsWith('-');
        if (isNegative) {
            integerPart = integerPart.substring(1);
        }
        if (integerPart.length() > 3) {
            String lastThreeDigits = integerPart.substring(integerPart.length() - 3);
            String otherDigits = integerPart.substring(0, integerPart.length() - 3);
            String pattern = '(?<=\\d)(?=(\\d{2})+$)';
            integerPart = otherDigits.replaceAll(pattern, ',') + ',' + lastThreeDigits;
        }
        String finalString = (isNegative ? '-' : '') + '₹ ' + integerPart + decimalPart;
        return finalString;
    }
}