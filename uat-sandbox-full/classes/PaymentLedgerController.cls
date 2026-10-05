public class PaymentLedgerController {

    public LedgerStatement ledgerStatement { get; set; }
    public Date   startDate { get; set; }
    public Date   endDate   { get; set; }
    public String ledgerFileName { get; set; }
    public Id     bookingId { get; set; }

    public PaymentLedgerController() {
        bookingId = ApexPages.currentPage().getParameters().get('id');
        String startStr = ApexPages.currentPage().getParameters().get('startDate');
        String endStr   = ApexPages.currentPage().getParameters().get('endDate');

        startDate = (startStr != null) ? Date.valueOf(startStr) : Date.today().addMonths(-1);
        endDate   = (endStr   != null) ? Date.valueOf(endStr)   : Date.today();

        ledgerFileName = 'Payment_Ledger_' +
            DateTime.newInstance(startDate, Time.newInstance(0,0,0,0)).format('dd_MMM_yyyy') +
            '_to_' +
            DateTime.newInstance(endDate,   Time.newInstance(0,0,0,0)).format('dd_MMM_yyyy') + '.doc';

        ledgerStatement = (bookingId != null)
            ? generateLedgerStatement(bookingId, startDate, endDate)
            : new LedgerStatement();
    }

    public static LedgerStatement generateLedgerStatement(Id bookingId, Date startDate, Date endDate) {
        LedgerStatement result = new LedgerStatement();
        result.content = new Map<String, String>();
        result.entry   = new List<LedgerEntry>();

        // ---- Booking + Unit (header) ----
        Booking__c booking = [
            SELECT Id, Unit_Id__c, Account_Id__c, Co_Applicant_1__c,
                   Account_Id__r.Name, Co_Applicant_1__r.Name, Co_Applicant_2__r.Name, Co_Applicant_3__r.Name, Co_Applicant_4__r.Name, Co_Applicant_5__r.Name,
                   Account_Id__r.PersonMailingStreet, Account_Id__r.PersonMailingCity,
                   Account_Id__r.PersonMailingState,  Account_Id__r.PersonMailingPostalCode,
                   Account_Id__r.PersonMailingCountry, Account_Id__r.Phone, Account_Id__r.GST_No__c
            FROM Booking__c WHERE Id = :bookingId LIMIT 1
        ];
        Unit__c unit = [
            SELECT Name, BHK_Configuration__c, Carpet_Area__c, Built_Up_Area_SBA__c,
                   Tower__r.Name, Property__r.Name, Property__r.GSTIN__c
            FROM Unit__c WHERE Id = :booking.Unit_Id__c LIMIT 1
        ];

        // Header content
        result.content.put('Project Name', unit.Property__r != null ? unit.Property__r.Name : '');
        result.content.put('Sub Project' , unit.Tower__r    != null ? unit.Tower__r.Name    : '');
        result.content.put('Customer Name', booking.Account_Id__r != null ? booking.Account_Id__r.Name : '');
        List<String> coApps = new List<String>();
        if (booking.Co_Applicant_1__r != null) coApps.add(booking.Co_Applicant_1__r.Name);
        if (booking.Co_Applicant_2__r != null) coApps.add(booking.Co_Applicant_2__r.Name);
        if (booking.Co_Applicant_3__r != null) coApps.add(booking.Co_Applicant_3__r.Name);
        if (booking.Co_Applicant_4__r != null) coApps.add(booking.Co_Applicant_4__r.Name);
        if (booking.Co_Applicant_5__r != null) coApps.add(booking.Co_Applicant_5__r.Name);
        result.content.put('Co-Applicant/s', String.join(coApps, ', '));
        result.content.put('Unit No.', unit.Name);
        result.content.put('SBA', (unit.Built_Up_Area_SBA__c == null) ? '' : String.valueOf(unit.Built_Up_Area_SBA__c) + ' SqFt');
        result.content.put('Carpet Area', (unit.Carpet_Area__c == null) ? '' : String.valueOf(unit.Carpet_Area__c) + ' SqFt');
        result.content.put('Customer GSTIN', booking.Account_Id__r != null && String.isNotBlank(booking.Account_Id__r.GST_No__c) ? booking.Account_Id__r.GST_No__c : '—');
        result.content.put('Company GSTIN', unit.Property__r != null ? String.valueOf(unit.Property__r.GSTIN__c) : '—');
        String addr =
            safe(booking.Account_Id__r.PersonMailingStreet, true) +
            safe(booking.Account_Id__r.PersonMailingCity, true)   +
            safe(booking.Account_Id__r.PersonMailingState, true)  +
            safe(booking.Account_Id__r.PersonMailingCountry, true)+
            (booking.Account_Id__r.PersonMailingPostalCode != null ? 'PIN: ' + booking.Account_Id__r.PersonMailingPostalCode : '');
        result.content.put('Mailing Address', addr);
        result.content.put('Phone', formatPhone(booking.Account_Id__r != null ? booking.Account_Id__r.Phone : null));
        result.content.put('For the Period',
            DateTime.newInstance(startDate, Time.newInstance(0,0,0,0)).format('dd MMM yyyy') +
            ' to ' +
            DateTime.newInstance(endDate,   Time.newInstance(0,0,0,0)).format('dd MMM yyyy')
        );

        // ---- Demands in window ----
        List<Demand__c> demands = [
            SELECT Id, CreatedDate, Name, Due_Date__c, Invoice_Value__c,
                   Booking_Payment_Schedule_Id__r.Milestone_Code__c
            FROM Demand__c
            WHERE Booking_Id__c = :bookingId
              AND Due_Date__c >= :startDate
              AND Due_Date__c <= :endDate
            ORDER BY Due_Date__c ASC, Id ASC
        ];
        Set<Id> demandIds = new Map<Id, Demand__c>(demands).keySet();

        // ---- Receipts in window (APPROVED only) ----
        Map<Id, List<Payment_Receipt__c>> rByDemand = new Map<Id, List<Payment_Receipt__c>>();
        if (!demandIds.isEmpty()) {
            for (Payment_Receipt__c r : [
                SELECT Id, Name, Approval_Status__c,
                       Amount_Paid__c, Principal_Applied__c, Interest_Applied__c, Tax_on_Interest__c,
                       Date_Of_Payment__c, Mode_Of_Payment__c, Customer_Bank_Name__c,
                       ChequeNumber__c, Transaction_Reference__c, Challan_Number__c, Certificate_Number__c,
                       Demand__c,CreatedDate
                FROM Payment_Receipt__c
                WHERE Demand__c IN :demandIds
                  AND Date_Of_Payment__c >= :startDate
                  AND Date_Of_Payment__c <= :endDate
                  AND Approval_Status__c = 'Approved'
                  AND Receipt_Status__c = 'Posted'
                ORDER BY Date_Of_Payment__c ASC, Id ASC
            ]) {
                if (!rByDemand.containsKey(r.Demand__c)) rByDemand.put(r.Demand__c, new List<Payment_Receipt__c>());
                rByDemand.get(r.Demand__c).add(r);
            }
        }

        // ---- Build ledger rows ----
        Integer sl = 1;
        List<LedgerEntry> rows = new List<LedgerEntry>();

        for (Demand__c d : demands) {
            Decimal debitAmt = nz(d.Invoice_Value__c);
            String dDesc = (d.Booking_Payment_Schedule_Id__r != null && String.isNotBlank(d.Booking_Payment_Schedule_Id__r.Milestone_Code__c))
                ? d.Booking_Payment_Schedule_Id__r.Milestone_Code__c : d.Name;

            // Demand debit
            rows.add(new LedgerEntry(sl++, d.CreatedDate.date(), d.Due_Date__c, dDesc, debitAmt, 0, 0));

            // Receipts: interest debit, tax debit, receipt credit
            List<Payment_Receipt__c> rs = rByDemand.get(d.Id);
            if (rs != null) {
                for (Payment_Receipt__c r : rs) {
                    if (nz(r.Interest_Applied__c) > 0) {
                        rows.add(new LedgerEntry(sl++, r.Date_Of_Payment__c, null, 'Interest Debited', nz(r.Interest_Applied__c), 0, 0));
                    }
                    if (nz(r.Tax_on_Interest__c) > 0) {
                        rows.add(new LedgerEntry(sl++, r.Date_Of_Payment__c, null, 'Tax on Interest', nz(r.Tax_on_Interest__c), 0, 0));
                    }
                    String ref = buildInstrumentRef(r);
                    String descr = 'Receipt: ' + r.Name +
                                  ' (Mode: ' + r.Mode_Of_Payment__c +
                                  (String.isNotBlank(r.Customer_Bank_Name__c) ? ', Bank: ' + r.Customer_Bank_Name__c : '') +
                                  (String.isNotBlank(ref) ? ', Ref: ' + ref : '') + ', Date Of Payment : ' +r.Date_Of_Payment__c.format() + ' )';
                    rows.add(new LedgerEntry(sl++, r.CreatedDate.date(), null, descr, 0, nz(r.Amount_Paid__c), 0));
                }
            }
        }

        // ---- Running balance & raw totals (only ledger rows) ----
        Decimal run = 0, deb = 0, cred = 0;
        for (LedgerEntry e : rows) {
            run  += nz(e.debit);
            run  -= nz(e.credit);
            e.balance = run;
            deb  += nz(e.debit);
            cred += nz(e.credit);
        }
        result.entry = rows;
        result.totalDebits  = deb;
        result.totalCredits = cred;
        result.totalBalance = run;
        result.closingDate  = endDate;

        // ---- Booking-level Interest Outstanding as on closing date ----
        List<Booking_Payment_Schedule__c> bps = [
            SELECT AccruedInterestToDateLedger__c, PreviewInterestToday__c,
                   TotalInterestReceived__c, Interest_Waived__c
            FROM Booking_Payment_Schedule__c
            WHERE Booking__c = :bookingId
        ];
        Decimal ti = 0, tr = 0, tw = 0;
        for (Booking_Payment_Schedule__c s : bps) {
            ti += nz(s.AccruedInterestToDateLedger__c) + nz(s.PreviewInterestToday__c);
            tr += nz(s.TotalInterestReceived__c);
            tw += nz(s.Interest_Waived__c);
        }
        result.totalInterest = (ti - tr - tw);
        if (result.totalInterest < 0) result.totalInterest = 0;

        // ---- Derived totals that INCLUDE interest outstanding (for the "Closing Balance" row) ----
        result.totalDebitsInclInterest  = result.totalDebits  + result.totalInterest;
        result.totalBalanceInclInterest = result.totalBalance + result.totalInterest;

        return result;
    }

    // ---------- Helpers ----------
    private static Decimal nz(Decimal d) { return (d == null) ? 0 : d; }
    private static String safe(String s, Boolean addComma) { return String.isBlank(s) ? '' : (addComma ? (s + ', ') : s); }
    private static String formatPhone(String p) {
        if (String.isBlank(p)) return '—';
        String digits = p.replaceAll('[^0-9]', '');
        if (digits.length() >= 10) digits = digits.right(10);
        return '+91 ' + digits.substring(0,5) + ' ' + digits.substring(5);
    }
    public static String buildInstrumentRef(Payment_Receipt__c r) {
        if (r == null) return '';
        if (r.Mode_Of_Payment__c == 'Cheque') return r.ChequeNumber__c == null ? '' : r.ChequeNumber__c;
        if (r.Mode_Of_Payment__c == 'RTGS' || r.Mode_Of_Payment__c == 'Net Banking' || r.Mode_Of_Payment__c == 'Bank Disbursement')
            return String.valueOf(r.Transaction_Reference__c);
        if (r.Mode_Of_Payment__c == 'TDS') return String.valueOf(r.Challan_Number__c);
        return '';
    }

    // ---------- Flattened DTOs ----------
    public class LedgerStatement {
        public Map<String,String> content { get; set; }
        public List<LedgerEntry>  entry   { get; set; }

        // Raw totals from ledger rows only
        public Decimal totalDebits       { get; set; }
        public Decimal totalCredits      { get; set; }
        public Decimal totalBalance      { get; set; }

        // Booking-wide interest outstanding (not part of entry rows)
        public Decimal totalInterest     { get; set; }

        // NEW: derived totals that INCLUDE interest outstanding
        public Decimal totalDebitsInclInterest  { get; set; }
        public Decimal totalBalanceInclInterest { get; set; }

        public Date   closingDate        { get; set; }

        public LedgerStatement() {
            content = new Map<String,String>();
            entry   = new List<LedgerEntry>();
        }
    }

    public class LedgerEntry {
        public Integer sortOrder { get; set; }
        public Date    entryDate { get; set; }
        public Date    demandDate{ get; set; }
        public String  particulars { get; set; }
        public Decimal debit    { get; set; }
        public Decimal credit   { get; set; }
        public Decimal balance  { get; set; }
        public LedgerEntry(Integer so, Date ed, Date dd, String p, Decimal d, Decimal c, Decimal b) {
            sortOrder=so; entryDate=ed; demandDate=dd; particulars=p; debit=d; credit=c; balance=b;
        }
    }
}