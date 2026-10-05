public class DebtorAgeingReportController {
    
    public class outputWrapper{
        @AuraEnabled public list<BookingDto> bookings { get; set; }
        @AuraEnabled public Integer totalRecords { get; set; }
        @AuraEnabled public Integer pageNumber { get; set; }
        @AuraEnabled public Integer pageSize { get; set; }
        @AuraEnabled public Integer totalPages { get; set; }
    }
    
    public class BookingDto {
        @AuraEnabled public String CustomerCode { get; set; }
        @AuraEnabled public String CustomerName { get; set; }
        @AuraEnabled public String ContactNo { get; set; }
        @AuraEnabled public String UnitNo { get; set; }
        @AuraEnabled public String SourceOfBooking { get; set; }
        @AuraEnabled public Date BookingDate { get; set; }
        @AuraEnabled public Decimal SBAAreaSqFt { get; set; }
        @AuraEnabled public String ExecutiveNameOPPOwner { get; set; }
        @AuraEnabled public Decimal BaseCostA { get; set; }
        @AuraEnabled public Decimal OtherChargesB1 { get; set; }
        @AuraEnabled public Decimal TaxAmountOnBaseCost { get; set; }
        @AuraEnabled public Decimal TaxAmountOnOtherChargesB2 { get; set; }
        @AuraEnabled public Decimal AgreementCost { get; set; }
        @AuraEnabled public Decimal TotalCostC1 { get; set; }
        @AuraEnabled public Decimal TotalRebateC2 { get; set; }
        @AuraEnabled public Decimal NetCostAfterRebateAndWaiveOffC { get; set; }
        @AuraEnabled public Decimal DueAsOnDayF1PrincipleDue { get; set; }
        @AuraEnabled public Decimal DueAsOnDayF2TaxOnPrincipleDue { get; set; }
        @AuraEnabled public Decimal TotalReceivedAgainstEventDueG1ChargeTypes { get; set; }
        @AuraEnabled public Decimal TotalReceivedAgainstEventDueG2Tax { get; set; }
        @AuraEnabled public Decimal NetDueF1MinusG1 { get; set; }
        @AuraEnabled public Decimal NetDueTaxF2MinusG2 { get; set; }
        @AuraEnabled public Decimal TotalReceivedAgainstFutureEventH1 { get; set; }
        @AuraEnabled public Decimal TotalOutstandingG1G2H1 { get; set; }
        @AuraEnabled public Decimal AmtDue0To30Days { get; set; }
        @AuraEnabled public Decimal AmtDue31To60Days { get; set; }
        @AuraEnabled public Decimal AmtDue61To90Days { get; set; }
        @AuraEnabled public Decimal AmtDue91To180Days { get; set; }
        @AuraEnabled public Decimal AmtDue180To365Days { get; set; }
        @AuraEnabled public Decimal AmtDueMoreThan365Days { get; set; }
        @AuraEnabled public Decimal ActualDueAsOnDate { get; set; }
        @AuraEnabled public String LastActionTaken { get; set; }
    }
    
    
    @AuraEnabled
    public static outputWrapper getBookings(string towerName, Integer pageNumber, Integer pageSize) {
        if (pageNumber == null || pageNumber < 1) pageNumber = 1;
        if (pageSize == null || pageSize < 1) pageSize = 20;
        
        outputWrapper ow = new outputWrapper();
        List<Booking__c> bookingList = ReportSelector.getBooking(towerName, pageNumber, pageSize);
        Integer totalCount = ReportSelector.getBookingCount(towerName);
        
        List<BookingDto> dtoList = new List<BookingDto>();
        decimal taxOnConstruction = 0;
        decimal taxOnLand = 0;
        decimal creditNoteAmt = 0;
        decimal creditNoteTax = 0;
        decimal totalOutstandingPrincipal = 0;
        for (Booking__c b : bookingList) {
            BookingDto dto = new BookingDto();
            dto.CustomerCode = b.Account_Id__r?.Company_Code__c;
            dto.CustomerName = b.Account_Id__r?.Name;
            dto.ContactNo = b.Account_Id__r?.Phone;
            dto.UnitNo = b.Unit_Id__r.Name;
            dto.SourceOfBooking = getPicklistLabel(Account.Sales_Group__c, b.Account_Id__r.Sales_Group__c);
            dto.BookingDate = b.Booking_Date__c;
            dto.SBAAreaSqFt = b.Unit_Id__r.Built_Up_Area_SBA__c;
            dto.ExecutiveNameOPPOwner = b.Opportunity_Id__r.Owner.Name;
            dto.BaseCostA = b.Opportunity_Id__r.BaseCostAfterDiscount__c;
            dto.OtherChargesB1 = b.Opportunity_Id__r.OtherCharges__c;
            //Tax on land and contruction 
            taxOnConstruction = sv(b.Opportunity_Id__r?.TaxOnConstructionCost__c);
            taxOnLand = sv(b.opportunity_Id__r?.Tax_on_Land_Cost__c);
            dto.TaxAmountOnBaseCost = taxOnConstruction + taxOnLand;
            dto.TaxAmountOnOtherChargesB2 = sv(b.Opportunity_Id__r.TaxOnOtherCharges__c);
            dto.AgreementCost = b.opportunity_Id__r?.Total_Amount__c;
            dto.TotalCostC1 = b.opportunity_Id__r?.Total_Amount__c;
            //Total Credit Note Amount
            creditNoteAmt = sv(b.Account_Id__r.TotalCreditNoteAmt__c);
            creditNoteTax = sv(b.Account_Id__r.TotalTaxOnCreditNote__c);
            dto.TotalRebateC2 = creditNoteAmt + creditNoteTax;
            dto.NetCostAfterRebateAndWaiveOffC = sv(dto.TotalCostC1) - sv(dto.TotalRebateC2);
            //Total oustanding principal
            for(Booking_Payment_Schedule__c bps : b.Booking_Payment_Schedules__r){
                totalOutstandingPrincipal += bps.Installment_Amount__c; 
            }
            dto.DueAsOnDayF1PrincipleDue = sv(totalOutstandingPrincipal);
            dto.DueAsOnDayF2TaxOnPrincipleDue = sv(b.Opportunity_Id__r.TaxOnOtherCharges__c);
            dto.TotalReceivedAgainstEventDueG1ChargeTypes = -1 * sv(b.Total_Principal_Received__c);
            //dto.TotalReceivedAgainstEventDueG2Tax = 
            dto.NetDueF1MinusG1 = sv(dto.DueAsOnDayF1PrincipleDue) - sv(dto.TotalReceivedAgainstEventDueG1ChargeTypes);
            dto.NetDueTaxF2MinusG2 = sv(dto.DueAsOnDayF2TaxOnPrincipleDue) - sv(dto.TotalReceivedAgainstEventDueG2Tax);
            //dto.TotalReceivedAgainstFutureEventH1 = 
            dto.TotalOutstandingG1G2H1 = sv(dto.NetCostAfterRebateAndWaiveOffC) - (sv(dto.TotalReceivedAgainstEventDueG1ChargeTypes) + 
                                                                                   sv(dto.TotalReceivedAgainstEventDueG2Tax) + sv(dto.TotalReceivedAgainstFutureEventH1));
            dto.AmtDue0To30Days = amtDueInRange(b.Booking_Payment_Schedules__r, 0, 30, b.Booking_Date__c);
            dto.AmtDue31To60Days = amtDueInRange(b.Booking_Payment_Schedules__r, 31, 60, b.Booking_Date__c);
            dto.AmtDue61To90Days = amtDueInRange(b.Booking_Payment_Schedules__r, 61, 90, b.Booking_Date__c);
            dto.AmtDue91To180Days = amtDueInRange(b.Booking_Payment_Schedules__r, 91, 180, b.Booking_Date__c);
            dto.AmtDue180To365Days = amtDueInRange(b.Booking_Payment_Schedules__r, 181, 365, b.Booking_Date__c);
            dto.AmtDueMoreThan365Days = amtDueMoreThan365Days(b.Booking_Payment_Schedules__r, b.Booking_Date__c);
            dto.ActualDueAsOnDate = actualDueAsOnDate(b.Booking_Payment_Schedules__r);
            //dto.LastActionTaken = 
            dtoList.add(dto);
        }
        
        ow.bookings = dtoList;
        ow.totalRecords = totalCount;
        ow.pageNumber = pageNumber;
        ow.pageSize = pageSize;
        ow.totalPages = (Integer)Math.ceil((Decimal)totalCount / pageSize);
        
        
        system.debug(JSON.Serialize(ow));
        return ow;
    }
    
    private static Decimal sv(Decimal d) {return d == null ? 0 : d;}
    
    //Fetch Tower Options
    @AuraEnabled(cacheable=true)
    public static List<String> getTowerOptions() {
        // Example: fetch from Tower__c object
        list<tower__c> towers = [SELECT Name FROM Tower__c WHERE RecordType.DeveloperName = 'Residential_Tower'];
        list<String> towerNames = new list<string>();
        for(tower__c t:towers){
            if(t.Name != null){
                towerNames.add(t.name);
            }
        }
        return towerNames;
    }
    
    //calculate and return amount due with specific date ranges.
    @testVisible
    private static Decimal amtDueInRange(List<Booking_Payment_Schedule__c> bpsList, Integer fromDays, Integer toDays, Date bookingDate) {
        Decimal amountDue = 0;
        if (bpsList != null && !bpsList.isEmpty() && bookingDate != null) {
            for (Booking_Payment_Schedule__c bps : bpsList) {
                if (bps.Payment_Due_Date__c != null && bps.Outstanding_Principal__c != null) {
                    // Calculate the number of days between booking date and due date
                    Integer daysDiff = bookingDate.daysBetween(bps.Payment_Due_Date__c);
                    
                    // Check if within range
                    if (daysDiff >= fromDays && daysDiff <= toDays) {
                        amountDue += bps.Outstanding_Principal__c;
                    }
                }
            }
        }
        return amountDue;
    }
    
    //Calculate and return those amt which is due for more than 365 days.
    @testVisible
    private static Decimal amtDueMoreThan365Days(List<Booking_Payment_Schedule__c> bpsList, Date bookingDate) {
    Decimal amountDue = 0;

    if (bpsList != null && !bpsList.isEmpty() && bookingDate != null) {
        for (Booking_Payment_Schedule__c bps : bpsList) {
            if (bps.Payment_Due_Date__c != null && bps.Outstanding_Principal__c != null) {
                // Calculate days difference between booking date and due date
                Integer daysDiff = bookingDate.daysBetween(bps.Payment_Due_Date__c);

                // If more than 365 days from booking date
                if (daysDiff > 365) {
                    amountDue += bps.Outstanding_Principal__c;
                }
            }
        }
    }

    return amountDue;
}
    // calculate and return actual Due As On Date.
    @testVisible
    private static Decimal actualDueAsOnDate(list<Booking_Payment_Schedule__c> bpsList){
        Decimal amtDueAsOnDate = 0;
        if(bpsList != null && !bpsList.isEmpty()){
            for(Booking_Payment_Schedule__c bps:bpsList){
                if(bps.Payment_Due_Date__c <= Date.Today() && bps.Outstanding_Principal__c > 0){
                    amtDueAsOnDate += bps.Outstanding_Principal__c;
                }
            }
        }
        return amtDueAsOnDate;
    }
    
    @testVisible
    private static String getPicklistLabel(SObjectField field, String apiValue) {
    if (String.isBlank(apiValue)) return null;
    for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {
        if (entry.getValue() == apiValue) {
            return entry.getLabel();
        }
    }
    return null;
}

    
}