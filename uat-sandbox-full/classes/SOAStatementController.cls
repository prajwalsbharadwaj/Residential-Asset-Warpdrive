public class SOAStatementController {

    @AuraEnabled(cacheable=true)
    public static DateBounds getReceiptDateBounds(Id bookingId) {
        DateBounds result = new DateBounds();
        if (bookingId == null) {
            return result;
        }
        List<AggregateResult> agg = [
            SELECT MIN(Date_Of_Payment__c) minDate,
                   MAX(Date_Of_Payment__c) maxDate
            FROM Payment_Receipt__c
            WHERE Receipt_Status__c = 'Posted'
              AND Demand__r.Booking_Id__c = :bookingId
        ];
        if (!agg.isEmpty()) {
            result.firstDate = (Date)agg[0].get('minDate');
        }
        result.lastDate = Date.today();
        return result;
    }

    public StatementData soaStatement { get; set; }
    public Date   startDate { get; set; }
    public Date   endDate   { get; set; }
    public String soaFileName { get; set; }
    public Id     bookingId { get; set; }

    public SOAStatementController() {
        bookingId = ApexPages.currentPage().getParameters().get('id');
        String startStr = ApexPages.currentPage().getParameters().get('startDate');
        String endStr   = ApexPages.currentPage().getParameters().get('endDate');

        startDate = (startStr != null) ? Date.valueOf(startStr) : Date.today().addMonths(-1);
        endDate   = (endStr   != null) ? Date.valueOf(endStr)   : Date.today();

        soaFileName = 'StatementOfAccount_' +
            DateTime.newInstance(startDate, Time.newInstance(0,0,0,0)).format('dd_MMM_yyyy') +
            '_to_' +
            DateTime.newInstance(endDate,   Time.newInstance(0,0,0,0)).format('dd_MMM_yyyy') + '.doc';

        soaStatement = (bookingId != null)
            ? generateSOAStatement(bookingId, startDate, endDate)
            : new StatementData();
    }

    // ---------- Core ----------
    public static StatementData generateSOAStatement(Id bookingId, Date startDate, Date endDate) {
        StatementData res = new StatementData();

        // Booking & unit
        Booking__c booking = [
            SELECT Id, Unit_Id__c, Account_Id__c, Account_Id__r.Name,
                   Co_Applicant_1__r.Name, Co_Applicant_2__r.Name, Co_Applicant_3__r.Name, Co_Applicant_4__r.Name, Co_Applicant_5__r.Name,
                   Opportunity_Id__r.Total_Amount__c,
                   InterestReceivedFromLedger__c, // NEW FIELD
                   TotalInterestOutstandingFromLedger__c // NEW FIELD
            FROM Booking__c WHERE Id = :bookingId LIMIT 1
        ];
        Unit__c unit = booking.Unit_Id__c != null ? [
            SELECT Name, BHK_Configuration__c, Carpet_Area__c, Tower__r.Name, Property__r.Name
            FROM Unit__c WHERE Id = :booking.Unit_Id__c LIMIT 1
        ] : null;

        // Header
        res.content.put('Project', unit?.Property__r?.Name);
        res.content.put('Sub Project', unit?.Tower__r?.Name);
        res.content.put('Type', unit?.BHK_Configuration__c ?? '');
        res.content.put('Unit No.', unit?.Name);
        res.content.put('Applicant', booking.Account_Id__r?.Name);
        List<String> coApps = new List<String>();
        if (booking.Co_Applicant_1__r != null) coApps.add(booking.Co_Applicant_1__r.Name);
        if (booking.Co_Applicant_2__r != null) coApps.add(booking.Co_Applicant_2__r.Name);
        if (booking.Co_Applicant_3__r != null) coApps.add(booking.Co_Applicant_3__r.Name);
        if (booking.Co_Applicant_4__r != null) coApps.add(booking.Co_Applicant_4__r.Name);
        if (booking.Co_Applicant_5__r != null) coApps.add(booking.Co_Applicant_5__r.Name);
        res.content.put('Co-Applicant/s', String.join(coApps, ', '));
        res.content.put('Dated',
            DateTime.newInstance(startDate, Time.newInstance(0,0,0,0)).format('dd MMM yyyy') + ' to ' +
            DateTime.newInstance(endDate,   Time.newInstance(0,0,0,0)).format('dd MMM yyyy')
        );

        // All schedules for snapshot and totals
        List<Booking_Payment_Schedule__c> bps = [
            SELECT Id, Name, Milestone_Code__c, Installment_Number__c,
                   Payment_Due_Date__c, Installment_Amount__c, Adjusted_Amount__c,
                   Outstanding_Principal__c
            FROM Booking_Payment_Schedule__c
            WHERE Booking__c = :bookingId
            ORDER BY Installment_Number__c ASC, Payment_Due_Date__c ASC, Id ASC
        ];

        BookingInterestService.SnapshotDTO bookingSnapshot = BookingInterestService.snapshotFor(bookingId, endDate);
        Map<Id, BookingInterestService.ScheduleDTO> snapshotBySchedule = new Map<Id, BookingInterestService.ScheduleDTO>();
        if (bookingSnapshot != null && bookingSnapshot.schedules != null) {
            for (BookingInterestService.ScheduleDTO dto : bookingSnapshot.schedules) {
                if (dto != null && dto.scheduleId != null) {
                    snapshotBySchedule.put(dto.scheduleId, dto);
                }
            }
        }

        // Per-schedule lines
        Decimal grandAmt = 0, grandOutstanding = 0, grandInterestOutstanding = 0;
        for (Booking_Payment_Schedule__c s : bps) {
            Decimal amount = nz(s.Installment_Amount__c);
            grandAmt += amount;

            BookingInterestService.ScheduleDTO schedSnapshot = snapshotBySchedule.get(s.Id);
            Decimal prinOutstanding = schedSnapshot == null ? nz(s.Outstanding_Principal__c) : nz(schedSnapshot.outstandingPrincipal);
            if (prinOutstanding < 0) prinOutstanding = 0;

            Decimal interestOutstanding = schedSnapshot == null ? 0 : nz(schedSnapshot.interestOutstanding);
            if (interestOutstanding < 0) interestOutstanding = 0;

            Boolean pastOrToday = (s.Payment_Due_Date__c != null && s.Payment_Due_Date__c <= endDate);
            if (pastOrToday) {
                grandOutstanding        += prinOutstanding;
                grandInterestOutstanding += interestOutstanding;
            }

            res.schedules.add(new SOAPaymentScheduleEntry(
                (String.isNotBlank(s.Milestone_Code__c) ? s.Milestone_Code__c : s.Name),
                (s.Payment_Due_Date__c == null ? '' : DateTime.newInstance(s.Payment_Due_Date__c, Time.newInstance(0,0,0,0)).format('dd MMM yyyy')),
                amount,
                pastOrToday ? prinOutstanding : 0,
                interestOutstanding
            ));
        }

        // Receipts in window (Posted only)
        List<Payment_Receipt__c> rs = [
            SELECT Id, Name, Approval_Status__c, Receipt_Status__c, Date_Of_Payment__c, Amount_Paid__c,Principal_Applied__c,Excess_Payment__c,
                   Mode_Of_Payment__c, Customer_Bank_Name__c, ChequeNumber__c, Transaction_Reference__c, Challan_Number__c,Instrument_Date__c
            FROM Payment_Receipt__c
            WHERE Date_Of_Payment__c >= :startDate
              AND Date_Of_Payment__c <= :endDate
              AND Receipt_Status__c = 'Posted'
              AND Demand__r.Booking_Id__c = :bookingId
            ORDER BY Date_Of_Payment__c ASC, Id ASC
        ];
        //Decimal totalReceived = 0;
        Decimal principalReceived = 0;
        Decimal excessAmountReceived = 0;
        for (Payment_Receipt__c r : rs) {
            //totalReceived += nz(r.Amount_Paid__c);
            principalReceived += nz(r.Principal_Applied__c);
            excessAmountReceived += nz(r.Excess_Payment__c);
            res.receipts.add(new SOAReceiptEntry(
                r.Name,
                (r.Date_Of_Payment__c == null ? '' : DateTime.newInstance(r.Date_Of_Payment__c, Time.newInstance(0,0,0,0)).format('dd MMM yyyy')),
                r.Mode_Of_Payment__c,
                r.Customer_Bank_Name__c,
                //(r.Date_Of_Payment__c == null ? '' : DateTime.newInstance(r.Date_Of_Payment__c, Time.newInstance(0,0,0,0)).format('dd MMM yyyy')),
                (r.Instrument_Date__c == null ? '' : DateTime.newInstance(r.Instrument_Date__c, Time.newInstance(0,0,0,0)).format('dd MMM yyyy')),
                buildInstrumentRef(r),
                nz(r.Amount_Paid__c)
            ));
        }

        // Summary
        // res.summary.totalApartmentCost       = (booking.Opportunity_Id__r != null) ? formatINR(nz(booking.Opportunity_Id__r.Total_Amount__c)) : '0';
        res.summary.totalApartmentCost       = (booking.Opportunity_Id__r != null) ? nz(booking.Opportunity_Id__r.Total_Amount__c) : 0;
        
        // res.summary.totalDemandAmount        = formatINR(grandAmt);
        res.summary.totalDemandAmount        = grandAmt;

        res.summary.totalAmountOutstanding   = grandOutstanding;           // principal
      //res.summary.totalAmountReceived      = totalReceived;
        res.summary.totalPrincipalReceived   = principalReceived;
        res.summary.balancePayable           = (grandOutstanding > 0) ? grandOutstanding : 0;
        res.summary.totalInterestOutstanding = grandInterestOutstanding;   // interest
      //res.summary.totalIncludingExcess     = res.summary.totalAmountReceived;
        res.summary.totalIncludingExcess     = principalReceived + excessAmountReceived;
        res.summary.balanceIncludingInterest = res.summary.balancePayable + res.summary.totalInterestOutstanding;

        // NEW SUMMARY FIELDS
        
        res.summary.totalSaleConsideration     = (booking.Opportunity_Id__r != null) ? nz(booking.Opportunity_Id__r.Total_Amount__c) : 0; // Total Sale Consideration (from Opportunity)
        res.summary.totalInterestReceived      = - nz(booking.InterestReceivedFromLedger__c); // Total Interest Received (from Booking)
        // Note: totalInterestOutstanding is already calculated as grandInterestOutstanding. 
        // We use the field from Booking for Total Interest Outstanding for display, if it's the intended source.
        res.summary.bookingInterestOutstanding = nz(booking.TotalInterestOutstandingFromLedger__c); // Total Interest Outstanding (from Booking)
        
		res.summary.totalDueAsOnDate = res.summary.totalInterestOutstanding + res.summary.totalAmountOutstanding;
        
        // --- Added: Populate all summary formatted strings ---
        res.summary.fTotalApartmentCost = formatINR(res.summary.totalApartmentCost);
        res.summary.fTotalDemandAmount = formatINR(res.summary.totalDemandAmount);
        res.summary.fTotalAmountOutstanding = formatINR(res.summary.totalAmountOutstanding);
        res.summary.fTotalInterestOutstanding = formatINR(res.summary.totalInterestOutstanding);
        res.summary.fTotalPrincipalReceived = formatINR(res.summary.totalPrincipalReceived);
        res.summary.fBalancePayable = formatINR(res.summary.balancePayable);
        res.summary.fTotalIncludingExcess = formatINR(res.summary.totalIncludingExcess);
        res.summary.fBalanceIncludingInterest = formatINR(res.summary.balanceIncludingInterest);
        res.summary.fTotalDueAsOnDate = formatINR(res.summary.totalDueAsOnDate);
        res.summary.fTotalSaleConsideration = formatINR(res.summary.totalSaleConsideration);
        res.summary.fTotalInterestReceived = formatINR(res.summary.totalInterestReceived);
        res.summary.fBookingInterestOutstanding = formatINR(res.summary.bookingInterestOutstanding);
        
        return res;
    }

    // ---------- VF getters ----------
    public StatementData getSOAStatement() { return soaStatement; }
    public Map<String,String> getSOAHeader() { return (soaStatement == null) ? new Map<String,String>() : soaStatement.content; }
    public List<SOAPaymentScheduleEntry> getSOASchedules() { return (soaStatement == null) ? new List<SOAPaymentScheduleEntry>() : soaStatement.schedules; }
    public List<SOAReceiptEntry>        getSOAReceipts()  { return (soaStatement == null) ? new List<SOAReceiptEntry>()        : soaStatement.receipts; }
    // public Decimal getTotalInterest() { return (soaStatement == null) ? 0 : soaStatement.summary.totalInterestOutstanding; }
    public String getTotalInterest() { return (soaStatement == null) ? '0.00' : soaStatement.summary.fTotalInterestOutstanding; }

    
    // NEW VF GETTERS for new fields (optional, but good practice if needed elsewhere)
    public Decimal getTotalSaleConsideration() { return (soaStatement == null) ? 0 : soaStatement.summary.totalSaleConsideration; }
    public Decimal getTotalInterestReceived() { return (soaStatement == null) ? 0 : soaStatement.summary.totalInterestReceived; }
    public Decimal getBookingInterestOutstanding() { return (soaStatement == null) ? 0 : soaStatement.summary.bookingInterestOutstanding; }
    public Decimal getTotalDueAsOnDate() { return (soaStatement == null) ? 0 : soaStatement.summary.totalDueAsOnDate; }

    
    
    // ---------- Helpers ----------
    private static Decimal nz(Decimal d) { return (d == null) ? 0 : d; }  
    private static Decimal nz(Decimal a, Decimal fallback) { return (a == null) ? nz(fallback) : a; }
    private static String buildInstrumentRef(Payment_Receipt__c r) {
        if (r == null) return '';
        if (r.Mode_Of_Payment__c == 'Cheque') {
            return r.ChequeNumber__c == null ? '' : r.ChequeNumber__c;
        }
        if (r.Mode_Of_Payment__c == 'RTGS' || r.Mode_Of_Payment__c == 'Net Banking' || r.Mode_Of_Payment__c == 'Bank Disbursement') {
            return String.valueOf(r.Transaction_Reference__c);
        }
        if (r.Mode_Of_Payment__c == 'TDS') {
            return String.valueOf(r.Challan_Number__c);
        }
        return '';
    }

    // --- Added Helper for Indian Currency Formatting (Lakhs/Crores) ---
    public static String formatINR(Decimal val) {
        if (val == null) return '0.00';
        val = val.setScale(2);
        String s = String.valueOf(val.abs());
        List<String> parts = s.split('\\.');
        String intPart = parts[0];
        String decPart = parts.size() > 1 ? '.' + parts[1] : '.00';
        if (intPart.length() <= 3) return (val < 0 ? '-' : '') + intPart + decPart;
        String lastThree = intPart.substring(intPart.length() - 3);
        String rest = intPart.substring(0, intPart.length() - 3);
        String result = '';
        while (rest.length() > 2) {
            result = ',' + rest.substring(rest.length() - 2) + result;
            rest = rest.substring(0, rest.length() - 2);
        }
        return (val < 0 ? '-' : '') + rest + result + ',' + lastThree + decPart;
    }

    // ---------- DTOs ----------
    public class StatementData {
        public Map<String,String>            content   {get; set;}
        public List<SOAPaymentScheduleEntry> schedules {get; set;}
        public List<SOAReceiptEntry>         receipts  {get; set;}
        public SOASummary                    summary   {get; set;}
        public StatementData(){
            content   = new Map<String,String>();
            schedules = new List<SOAPaymentScheduleEntry>();
            receipts  = new List<SOAReceiptEntry>();
            summary   = new SOASummary();
        }
    }
    public class SOAPaymentScheduleEntry {
        public String  milestone { get; set; }
        public String  dueDate   { get; set; }
        public Decimal amount    { get; set; }
        public Decimal outstanding { get; set; }   // principal (displayed per rule)
        public Decimal interest    { get; set; }   // interest
        public String famount    { get; set; }
        public String foutstanding { get; set; }
        public String finterest    { get; set; }
        public SOAPaymentScheduleEntry(String m, String d, Decimal a, Decimal o, Decimal i) {
            milestone=m; dueDate=d; this.famount=formatINR(a); this.foutstanding=formatINR(o); this.finterest=formatINR(i);
            // Added preservation of original decimals just in case
            this.amount = a; this.outstanding = o; this.interest = i;
        }
    }
// Inside SOAReceiptEntry DTO class:
public class SOAReceiptEntry {
    public String  receiptNumber   { get; set; }
    public String  receiptDate     { get; set; }
    public String  paymentMode     { get; set; }
    public String  bankName        { get; set; }
    public String  instrumentDate  { get; set; }
    public String  instrumentNumber{ get; set; }
    public Decimal amountReceived  { get; set; }
    public String  fAmountReceived { get; set; } // Formatted Indian Currency String

    // public SOAReceiptEntry(String n, String rd, String pm, String bn, String id, String inum, Decimal amt) {
    //    receiptNumber=n; receiptDate=rd; paymentMode=pm; bankName=bn; instrumentDate=id; instrumentNumber=inum; amountReceived=amt;
    // }
    public SOAReceiptEntry(String n, String rd, String pm, String bn, String id, String inum, Decimal amt) {
        receiptNumber=n; receiptDate=rd; paymentMode=pm; bankName=bn; instrumentDate=id; instrumentNumber=inum; amountReceived=amt;
        this.fAmountReceived = formatINR(amt); // Formats as 1,00,00,000.00
    }
}
    public class SOASummary {
        // public String totalApartmentCost         { get; set; }
        // public String totalDemandAmount          { get; set; }
        public Decimal totalApartmentCost         { get; set; }
        public Decimal totalDemandAmount          { get; set; }
        public Decimal totalAmountOutstanding     { get; set; } // principal
        public Decimal totalInterestOutstanding   { get; set; } // interest
        //public Decimal totalAmountReceived        { get; set; }
        public decimal totalPrincipalReceived     {get;set;}
        public Decimal balancePayable             { get; set; } // principal
        public Decimal totalIncludingExcess       { get; set; }
        public Decimal balanceIncludingInterest   { get; set; }
        
         // NEW FIELDS
        public Decimal totalDueAsOnDate		       { get; set; }
        public Decimal totalSaleConsideration      { get; set; } // Total_Amount__c on Opportunity/Booking
        public Decimal totalInterestReceived       { get; set; } // InterestReceivedFromLedger__c on Booking
        public Decimal bookingInterestOutstanding  { get; set; } // TotalInterestOutstandingFromLedger__c on Booking

        // --- Added: Display Strings for VF ---
        public String fTotalApartmentCost          { get; set; }
        public String fTotalDemandAmount           { get; set; }
        public String fTotalAmountOutstanding      { get; set; }
        public String fTotalInterestOutstanding    { get; set; }
        public String fTotalPrincipalReceived      { get; set; }
        public String fBalancePayable              { get; set; }
        public String fTotalIncludingExcess        { get; set; }
        public String fBalanceIncludingInterest    { get; set; }
        public String fTotalDueAsOnDate            { get; set; }
        public String fTotalSaleConsideration      { get; set; }
        public String fTotalInterestReceived       { get; set; }
        public String fBookingInterestOutstanding  { get; set; }
    }

    public class DateBounds {
        @AuraEnabled public Date firstDate { get; set; }
        @AuraEnabled public Date lastDate  { get; set; }
    }
}