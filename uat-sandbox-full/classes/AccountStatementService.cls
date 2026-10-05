public with sharing class AccountStatementService {

    public LedgerStatement ledgerStatement { get; set; }
    public StatementData soaStatement { get; set; }
    public Id bookingId { get; set; }

    public Date startDate { get; set; }
    public Date endDate { get; set; }
    public String soaFileName { get; set; }
	public String ledgerFileName { get; set; }

    public AccountStatementService() {
        bookingId = ApexPages.currentPage().getParameters().get('id');

        String startStr = ApexPages.currentPage().getParameters().get('startDate');
		String endStr   = ApexPages.currentPage().getParameters().get('endDate');

        // Default date range if not provided
        startDate = startStr != null ? Date.valueOf(startStr) : Date.today().addMonths(-1);
        endDate = endStr != null ? Date.valueOf(endStr) : Date.today();
        
        soaFileName = 'StatementOfAccount_' + startStr + '_to_' + endStr + '.doc';
    	ledgerFileName = 'Payment_Ledger_' + startStr + '_to_' + endStr + '.doc';

        if (bookingId != null) {
            ledgerStatement = generateLedgerStatement(bookingId, startDate, endDate);
            soaStatement = generateSOAStatement(bookingId, startDate, endDate);
        } else {
            ledgerStatement = new LedgerStatement();
            soaStatement = new StatementData();
        }
    }

    // -------------------------------
    // Ledger Statement Generation (Demand-wise)
    // -------------------------------
    public static LedgerStatement generateLedgerStatement(Id bookingId, Date startDate, Date endDate) {
        LedgerStatement result = new LedgerStatement();
        result.content = new Map<String, String>();
    
        // -------------------------------
        // Fetch Booking and Unit Info (same as before)
        // -------------------------------
        Booking__c booking = [
            SELECT Unit_Id__c, Account_Id__c, Co_Applicant_1__c,
                   Account_Id__r.Name, Co_Applicant_1__r.Name, Co_Applicant_2__r.Name, Co_Applicant_3__r.Name, Co_Applicant_4__r.Name, Co_Applicant_5__r.Name,
                   Account_Id__r.PersonMailingStreet, Account_Id__r.PersonMailingCity,
                   Account_Id__r.PersonMailingState, Account_Id__r.PersonMailingPostalCode,
                   Account_Id__r.PersonMailingCountry, Account_Id__r.Phone, Account_Id__r.GST_No__c
            FROM Booking__c
            WHERE Id = :bookingId
            LIMIT 1
        ];
    
        Unit__c unit = [
            SELECT Name, BHK_Configuration__c, Carpet_Area__c, Built_Up_Area_SBA__c, Tower__r.Name, Property__r.Name, Property__r.GSTIN__c
            FROM Unit__c
            WHERE Id = :booking.Unit_Id__c
            LIMIT 1
        ];
    
        // Header Info
        result.content.put('Project Name', unit.Property__r?.Name);
        result.content.put('Sub Project', unit.Tower__r?.Name);
        result.content.put('Customer Name', booking.Account_Id__r?.Name);
        
        // co applicant build
        List<String> coApplicants = new List<String>();
        if (booking.Co_Applicant_1__r != null) coApplicants.add(booking.Co_Applicant_1__r.Name);
        if (booking.Co_Applicant_2__r != null) coApplicants.add(booking.Co_Applicant_2__r.Name);
        if (booking.Co_Applicant_3__r != null) coApplicants.add(booking.Co_Applicant_3__r.Name);
        if (booking.Co_Applicant_4__r != null) coApplicants.add(booking.Co_Applicant_4__r.Name);
        if (booking.Co_Applicant_5__r != null) coApplicants.add(booking.Co_Applicant_5__r.Name);
        result.content.put('Co-Applicant/s', String.join(coApplicants, ', '));
        
        result.content.put('Unit No.', unit.Name);
        result.content.put('SBA', unit.Built_Up_Area_SBA__c != null ? String.valueOf(unit.Built_Up_Area_SBA__c) + ' SqFt' : '');
        result.content.put('Carpet Area', unit.Carpet_Area__c != null ? String.valueOf(unit.Carpet_Area__c) + ' SqFt' : '');
        result.content.put('Customer GSTIN', booking.Account_Id__r?.GST_No__c != null ? booking.Account_Id__r.GST_No__c : 'No GSTIN Found');
        result.content.put('Company GSTIN', unit.Property__r != null ? unit.Property__r.GSTIN__c : '');
        result.content.put('Mailing Address',
            (booking.Account_Id__r.PersonMailingStreet != null ? booking.Account_Id__r.PersonMailingStreet + ', ' : '') +
            (booking.Account_Id__r.PersonMailingCity != null ? booking.Account_Id__r.PersonMailingCity + ', ' : '') +
            (booking.Account_Id__r.PersonMailingState != null ? booking.Account_Id__r.PersonMailingState + ', ' : '') +
            (booking.Account_Id__r.PersonMailingCountry != null ? booking.Account_Id__r.PersonMailingCountry + ', ' : '') +
            (booking.Account_Id__r.PersonMailingPostalCode != null ? 'PIN: ' + booking.Account_Id__r.PersonMailingPostalCode : '')
        );
        result.content.put('Phone', formatPhone(booking.Account_Id__r?.Phone));
        
        result.content.put( 'For the Period', DateTime.newInstance(startDate, Time.newInstance(0,0,0,0)).format('dd MMM yyyy') + ' to ' + DateTime.newInstance(endDate, Time.newInstance(0,0,0,0)).format('dd MMM yyyy'));
    
        // -------------------------------
        // Fetch Demands within window
        // -------------------------------
        List<Demand__c> demands = [
            SELECT Id, Name, Due_Date__c, Invoice_Value__c, Booking_Payment_Schedule_Id__r.Milestone_Code__c, CreatedDate
            FROM Demand__c
            WHERE Booking_Id__c = :bookingId
              AND Due_Date__c >= :startDate
              AND Due_Date__c <= :endDate
            ORDER BY Due_Date__c ASC
        ];
        Set<Id> demandIds = new Map<Id, Demand__c>(demands).keySet();
    
        // -------------------------------
        // Fetch Receipts within window
        // -------------------------------
        Map<Id, List<Payment_Receipt__c>> demandToReceipts = new Map<Id, List<Payment_Receipt__c>>();
        if (!demandIds.isEmpty()) {
            for (Payment_Receipt__c r : [
                SELECT Id,
                       Name,
                       Amount_Paid__c,
                       Date_Of_Payment__c,
                       Mode_Of_Payment__c,
                       Customer_Bank_Name__c,
                       Demand__c,
                       ChequeNumber__c,
                       Transaction_Reference__c,
                       Challan_Number__c,
                       Certificate_Number__c,
                       Type__c
                FROM Payment_Receipt__c
                WHERE Demand__c IN :demandIds
                  AND Date_Of_Payment__c >= :startDate
                  AND Date_Of_Payment__c <= :endDate
                ORDER BY Date_Of_Payment__c ASC
            ]) {
                if (!demandToReceipts.containsKey(r.Demand__c)) demandToReceipts.put(r.Demand__c, new List<Payment_Receipt__c>());
                demandToReceipts.get(r.Demand__c).add(r);
            }
        }
        
        System.debug(' Demand Size =====>  ' + demands.size());
        Integer totalReceipts = 0;
        for (Id did : demandToReceipts.keySet()) {
            totalReceipts += demandToReceipts.get(did).size();
        }
        System.debug('Total Receipts =====> ' + totalReceipts);
    
        // -------------------------------
        // Build Ledger Entries demand-by-demand
        // -------------------------------
        List<LedgerStatement.Entry> allEntries = new List<LedgerStatement.Entry>();
        Integer sl = 1;
    
        for (Demand__c d : demands) {
            // Add demand row
            Decimal debitAmt = d.Invoice_Value__c != null ? d.Invoice_Value__c : 0;
            allEntries.add(new LedgerStatement.Entry(
                sl++,
                d.Due_Date__c,
                d.CreatedDate.date(),
                d.Booking_Payment_Schedule_Id__r?.Milestone_Code__c != null ? d.Booking_Payment_Schedule_Id__r.Milestone_Code__c : d.Name,
                debitAmt,
                0,
                0
            ));
    
            // Add its receipts
            for (Payment_Receipt__c r : demandToReceipts.get(d.Id)) {
                Decimal creditAmt = r.Amount_Paid__c != null ? r.Amount_Paid__c : 0;
                
                // Pick reference
                String reference = '';
                if (r.Mode_Of_Payment__c == 'Cheque') {
                    reference = r.ChequeNumber__c != null ? String.valueOf(r.ChequeNumber__c) : '';
                } else if (r.Mode_Of_Payment__c == 'RTGS' || 
                           r.Mode_Of_Payment__c == 'Net Banking' || 
                           r.Mode_Of_Payment__c == 'Bank Disbursement') {
                               reference = r.Transaction_Reference__c != null ? r.Transaction_Reference__c : '';
                           } else if (r.Mode_Of_Payment__c == 'TDS') {
                               List<String> parts = new List<String>();
                               if (String.isNotBlank(r.Challan_Number__c)) parts.add(r.Challan_Number__c);
                               if (String.isNotBlank(r.Certificate_Number__c)) parts.add(r.Certificate_Number__c);
                               reference = String.join(parts, ' / ');
                           }
                
                String description = 'Receipt: ' + r.Name + 
                    ' (Mode: ' + r.Mode_Of_Payment__c + 
                    ', Bank: ' + r.Customer_Bank_Name__c + 
                    (String.isNotBlank(reference) ? ', Ref: ' + reference : '') + ')';
                
                if (r.Type__c == 'Installment') {
                    allEntries.add(new LedgerStatement.Entry(
                        sl++,
                        r.Date_Of_Payment__c,
                        null,
                        description,
                        0,
                        creditAmt,
                        0
                    ));
                } else if (r.Type__c == 'Interest') {
                    Decimal tax = creditAmt * 0.18;
                    Decimal netInterest = creditAmt - tax;
                    
                    allEntries.add(new LedgerStatement.Entry(
                        sl++, r.Date_Of_Payment__c, null, 'Interest Debited', netInterest, 0, 0
                    ));
                    allEntries.add(new LedgerStatement.Entry(
                        sl++, r.Date_Of_Payment__c, null, description, 0, creditAmt, 0
                    ));
                    allEntries.add(new LedgerStatement.Entry(
                        sl++, r.Date_Of_Payment__c, null, 'Tax On Interest, ' + r.Name, tax, 0, 0
                    ));
                }
            }
        }
    
        // -------------------------------
        // Running balance & totals
        // -------------------------------
        Decimal runningBalance = 0;
        Decimal totalDebits = 0;
        Decimal totalCredits = 0;
    
        for (LedgerStatement.Entry e : allEntries) {
            runningBalance += e.debit != null ? e.debit : 0;
            runningBalance -= e.credit != null ? e.credit : 0;
            e.balance = runningBalance;
    
            totalDebits += e.debit != null ? e.debit : 0;
            totalCredits += e.credit != null ? e.credit : 0;
        }
    
        result.entry = allEntries;
        result.totalDebits = totalDebits;
        result.totalCredits = totalCredits;
        result.totalBalance = runningBalance;
        result.closingDate = endDate;
        
        System.debug('Generated Ledger Statement: ' + JSON.serializePretty(result));
        return result;
    }

    // -------------------------------
    // Statement of Account Generation (fixed summary totals & demand/future BPS handling)
    // -------------------------------
    public static StatementData generateSOAStatement(Id bookingId, Date startDate, Date endDate) {
        StatementData result = new StatementData();
        
        // -------------------------------
        // Header Info
        // -------------------------------
        Booking__c booking = [
            SELECT Unit_Id__c, Account_Id__c, Account_Id__r.Name, 
                   Co_Applicant_1__r.Name, Co_Applicant_2__r.Name, 
                   Co_Applicant_3__r.Name, Co_Applicant_4__r.Name, 
                   Co_Applicant_5__r.Name,
                   Opportunity_Id__r.Total_Amount__c
            FROM Booking__c
            WHERE Id = :bookingId
            LIMIT 1
        ];
        
        Unit__c unit = booking.Unit_Id__c != null ? [
            SELECT Name, BHK_Configuration__c, Carpet_Area__c, Tower__r.Name, Property__r.Name 
            FROM Unit__c 
            WHERE Id = :booking.Unit_Id__c 
            LIMIT 1
        ] : null;
        
        result.content.put('Project', unit?.Property__r?.Name);
        result.content.put('Sub Project', unit?.Tower__r?.Name);
        result.content.put('Type', unit?.BHK_Configuration__c);
        result.content.put('Unit No.', unit?.Name);
        result.content.put('Applicant', booking.Account_Id__r?.Name);
    
        List<String> coApplicants = new List<String>();
        if (booking.Co_Applicant_1__r != null) coApplicants.add(booking.Co_Applicant_1__r.Name);
        if (booking.Co_Applicant_2__r != null) coApplicants.add(booking.Co_Applicant_2__r.Name);
        if (booking.Co_Applicant_3__r != null) coApplicants.add(booking.Co_Applicant_3__r.Name);
        if (booking.Co_Applicant_4__r != null) coApplicants.add(booking.Co_Applicant_4__r.Name);
        if (booking.Co_Applicant_5__r != null) coApplicants.add(booking.Co_Applicant_5__r.Name);
        result.content.put('Co-Applicant/s', String.join(coApplicants, ', '));
        
        result.content.put(
            'Dated', 
            DateTime.newInstance(startDate, Time.newInstance(0,0,0,0)).format('dd MMM yyyy') + 
            ' to ' + 
            DateTime.newInstance(endDate, Time.newInstance(0,0,0,0)).format('dd MMM yyyy')
        );
        
        // -------------------------------
        // Demands (only those within the date window)
        // -------------------------------
        List<Demand__c> demands = [
            SELECT Id, Name, Due_Date__c, Invoice_Value__c, Booking_Payment_Schedule_Id__c,
                   Booking_Payment_Schedule_Id__r.Milestone_Code__c,
                   Total_Amount_Recieved__c
            FROM Demand__c
            WHERE Booking_Id__c = :bookingId
              AND Due_Date__c >= :startDate 
              AND Due_Date__c <= :endDate
            ORDER BY Due_Date__c ASC
        ];
        
        Decimal totalDemandAmount = 0;
        Set<Id> demandIds = new Map<Id, Demand__c>(demands).keySet();
        Map<Id, Id> demandIdToBpsId = new Map<Id, Id>();
        for (Demand__c d : demands) {
            if (d.Booking_Payment_Schedule_Id__c != null) {
                demandIdToBpsId.put(d.Id, d.Booking_Payment_Schedule_Id__c);
            }
        }
        
        // -------------------------------
        // Receipts (grouped by Demand) — still limited to demands within date window
        // -------------------------------
        Map<Id, Decimal> demandToReceiptSum = new Map<Id, Decimal>();
        Decimal totalAmountReceivedWindow = 0;
        
        List<Payment_Receipt__c> receipts = demandIds.isEmpty() ? new List<Payment_Receipt__c>() : [
            SELECT Id, Name, Date_Of_Payment__c, Mode_Of_Payment__c, Amount_Paid__c, 
                   Customer_Bank_Name__c, ChequeNumber__c, Transaction_Reference__c, Challan_Number__c,
                   Demand__c
            FROM Payment_Receipt__c
            WHERE Demand__c IN :demandIds AND Type__c = 'Installment'
            ORDER BY Date_Of_Payment__c ASC
        ];
        
        for (Payment_Receipt__c r : receipts) {
            Decimal received = r.Amount_Paid__c != null ? r.Amount_Paid__c : 0;
            totalAmountReceivedWindow += received;
            
            if (!demandToReceiptSum.containsKey(r.Demand__c)) {
                demandToReceiptSum.put(r.Demand__c, 0);
            }
            demandToReceiptSum.put(r.Demand__c, demandToReceiptSum.get(r.Demand__c) + received);
            
            String instrumentNumber = 
                r.Mode_Of_Payment__c == 'Cheque' ? String.valueOf(r.ChequeNumber__c) :
                (r.Mode_Of_Payment__c == 'RTGS' || r.Mode_Of_Payment__c == 'Net Banking' || r.Mode_Of_Payment__c == 'Bank Disbursement') ? r.Transaction_Reference__c :
                r.Mode_Of_Payment__c == 'TDS' ? r.Challan_Number__c : '';
            
            String dateOfPayment = r.Date_Of_Payment__c != null 
                ? DateTime.newInstance(r.Date_Of_Payment__c, Time.newInstance(0,0,0,0)).format('dd MMM yyyy') 
                : '';
        
            result.receipts.add(new StatementData.ReceiptEntry(
                r.Name, dateOfPayment, r.Mode_Of_Payment__c, r.Customer_Bank_Name__c, 
                dateOfPayment, instrumentNumber, received
            ));
        }
        
        Decimal totalAmountReceivedForDemands = 0;
        for (Demand__c d : demands) {
            Decimal rcv = 0;
            if (d.Total_Amount_Recieved__c != null) {
                rcv = d.Total_Amount_Recieved__c;
            } else if (demandToReceiptSum.containsKey(d.Id)) {
                rcv = demandToReceiptSum.get(d.Id);
            }
            totalAmountReceivedForDemands += rcv;
        }
        
        // -------------------------------
        // All Booking Payment Schedules (irrespective of dates)
        // -------------------------------
        List<Booking_Payment_Schedule__c> allBps = [
            SELECT Id, Name, Milestone_Code__c, Payment_Due_Date__c, Installment_Amount__c, Adjusted_Amount__c, Installment_Number__c
            FROM Booking_Payment_Schedule__c
            WHERE Booking__c = :bookingId
            ORDER BY Installment_Number__c ASC
        ];
        Map<Id, Booking_Payment_Schedule__c> bpsById = new Map<Id, Booking_Payment_Schedule__c>(allBps);
        
        Map<Id, Id> bpsIdToDemandId = new Map<Id, Id>();
        for (Id dId : demandIdToBpsId.keySet()) {
            Id bpsId = demandIdToBpsId.get(dId);
            if (bpsId != null) bpsIdToDemandId.put(bpsId, dId);
        }
        
        // -------------------------------
        // Apply Receipts to Demands (rolling adjustment logic)
        // -------------------------------
        Decimal carryForward = 0;
        Decimal deficitCarry = 0;
        
        Map<Id, Decimal> demandOutstanding = new Map<Id, Decimal>();
        
        for (Integer i = 0; i < demands.size(); i++) {
            Demand__c d = demands[i];
            Decimal originalAmt = d.Invoice_Value__c != null ? d.Invoice_Value__c : 0;
            totalDemandAmount += originalAmt;
        
            Decimal effectiveAmt = originalAmt;
            if (deficitCarry > 0) {
                effectiveAmt += deficitCarry;
                deficitCarry = 0;
            }
        
            Decimal receiptsForThisDemand = 0;
            if (d.Total_Amount_Recieved__c != null) {
                receiptsForThisDemand = d.Total_Amount_Recieved__c;
            } else if (demandToReceiptSum.containsKey(d.Id)) {
                receiptsForThisDemand = demandToReceiptSum.get(d.Id);
            }
            carryForward += receiptsForThisDemand;
        
            Decimal outstanding;
            if (carryForward >= effectiveAmt) {
                outstanding = 0;
                carryForward -= effectiveAmt;
            } else {
                Decimal deficit = effectiveAmt - carryForward;
                if (i < demands.size() - 1) {
                    outstanding = 0;
                    deficitCarry = deficit;
                } else {
                    outstanding = deficit;
                }
                carryForward = 0;
            }
        
            // If last demand and carryForward still > 0 => excess received
            if (i == demands.size() - 1 && carryForward > 0) {
                outstanding = -carryForward;
                carryForward = 0;
            }
            
            demandOutstanding.put(d.Id, outstanding);
        }
    
        // -------------------------------
        // Build Payment Schedules (all BPS). Compute two aggregates:
        // -------------------------------
        Decimal summaryTotalOutstandingAsOfDate = 0;
        Decimal totalScheduledAmount = 0;
        
        for (Booking_Payment_Schedule__c bps : allBps) {
            Decimal originalAmt = bps.Adjusted_Amount__c != null ? bps.Adjusted_Amount__c : (bps.Installment_Amount__c != null ? bps.Installment_Amount__c : 0);
            totalScheduledAmount += originalAmt;
            
            Boolean isCoveredByWindow = false;
            Decimal outstandingForBps;
            
            if (bpsIdToDemandId.containsKey(bps.Id)) {
                Id relatedDemandId = bpsIdToDemandId.get(bps.Id);
                if (demandOutstanding.containsKey(relatedDemandId)) {
                    outstandingForBps = demandOutstanding.get(relatedDemandId);
                } else {
                    outstandingForBps = originalAmt;
                }
                isCoveredByWindow = true;
            } else if (bps.Payment_Due_Date__c != null && bps.Payment_Due_Date__c <= endDate) {
                outstandingForBps = originalAmt;
                isCoveredByWindow = true;
            } else {
                outstandingForBps = originalAmt;
                isCoveredByWindow = false;
            }
            
            String dueDateStr = bps.Payment_Due_Date__c != null 
                ? DateTime.newInstance(bps.Payment_Due_Date__c, Time.newInstance(0,0,0,0)).format('dd MMM yyyy') 
                : '';
            
            String label = bps.Milestone_Code__c != null ? bps.Milestone_Code__c : bps.Name;
            
            result.schedules.add(new StatementData.PaymentScheduleEntry(
                label,
                dueDateStr,
                originalAmt,
                outstandingForBps
            ));
            
            if (isCoveredByWindow) {
                summaryTotalOutstandingAsOfDate += outstandingForBps;
            }
        }
        
        // -------------------------------
        // Summary
        // -------------------------------
        Decimal totalInterest = 0;
        Decimal totalApartmentCost = booking.Opportunity_Id__r.Total_Amount__c;
        
        result.summary.totalDemandAmount = totalScheduledAmount;
        result.summary.totalApartmentCost = totalApartmentCost;
        
        result.summary.totalAmountReceived = totalAmountReceivedForDemands;
        
        result.summary.totalAmountOutstanding = totalScheduledAmount + summaryTotalOutstandingAsOfDate - totalDemandAmount;
        
        result.summary.balancePayable = Math.max(result.summary.totalAmountOutstanding != null ? result.summary.totalAmountOutstanding : 0, 0);
        
        result.summary.totalIncludingExcess = result.summary.totalAmountReceived;
        
        result.summary.balanceIncludingInterest = result.summary.balancePayable + totalInterest;
        
        return result;
    }

    // VF page getters
    public StatementData getSOAStatement() {
        return soaStatement;
    }

    public Map<String, String> getSOAHeader() {
        return soaStatement != null ? soaStatement.content : new Map<String, String>();
    }

    public List<StatementData.PaymentScheduleEntry> getSOASchedules() {
        return soaStatement != null ? soaStatement.schedules : new List<StatementData.PaymentScheduleEntry>();
    }

    public List<StatementData.ReceiptEntry> getSOAReceipts() {
        return soaStatement != null ? soaStatement.receipts : new List<StatementData.ReceiptEntry>();
    }

    public Decimal getTotalDebit() {
        Decimal total = 0;
        if (ledgerStatement?.entry != null) {
            for (LedgerStatement.Entry entry : ledgerStatement.entry) { total += entry.debit != null ? entry.debit : 0; }
        }
        return total;
    }

    public Decimal getTotalCredit() {
        Decimal total = 0;
        if (ledgerStatement?.entry != null) {
            for (LedgerStatement.Entry entry : ledgerStatement.entry) { total += entry.credit != null ? entry.credit : 0; }
        }
        return total;
    }

    public Decimal getClosingBalance() {
        if (ledgerStatement?.entry != null && !ledgerStatement.entry.isEmpty()) { return ledgerStatement.entry[ledgerStatement.entry.size() - 1].balance; }
        return 0;
    }

    public Decimal getTotalInterest() {
        Decimal interest = 0;
        for (StatementData.PaymentScheduleEntry s : soaStatement.schedules) { interest = 0; }
        return interest;
    }

    public class LedgerEntrySorter implements Comparator<LedgerStatement.Entry> {
        public Integer compare(LedgerStatement.Entry a, LedgerStatement.Entry b) { if (a.entryDate == b.entryDate) return 0; return a.entryDate < b.entryDate ? -1 : 1;
        }
    }
    
    // --- Phone Formatter ---
    private static String formatPhone(String phone) {
        if (String.isBlank(phone)) return '-';
        String digits = phone.replaceAll('[^0-9]', '');
        if (digits.length() >= 10) digits = digits.right(10);
        return '+91 ' + digits.substring(0,5) + ' ' + digits.substring(5);
    }
}