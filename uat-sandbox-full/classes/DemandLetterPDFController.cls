public with sharing class DemandLetterPDFController {
    
    public DemandLetterWrapper demandLetter { get; private set; }
    public String OtherContactNumbers { get; set; }
    public Company_Bank_Account__c bankAccountRecord { get; private set; }
    public String errorMessage { get; private set; }
    
    
    
    public DemandLetterPDFController() {
        contentType = null;
        
        Id demandId = ApexPages.currentPage().getParameters().get('id');
        if (demandId != null) {
            demandLetter = buildDemandLetterFromDemand(demandId);
        } else {
            demandLetter = new DemandLetterWrapper();
        }
        
        if(!ApexPages.hasMessages(ApexPages.Severity.Error)){
            contentType = 'application/msword#Demand_Letter_' + demandLetter.header.demandInvoiceNo + '.doc ; charset=UTF-8';
        }
        
    }
    
    public String contentType {get; private set;}
    
    // ------------------------
    // Wrapper Classes
    // ------------------------
    public class DemandLetterWrapper {
        public Header header { get; set; }
        public CustomerDetails customerDetails { get; set; }
        public Milestone milestone { get; set; }
    }
    
    public class Header {
        public String dated { get; set; }
        public String demandInvoiceNo { get; set; }
        public String CIN { get; set; }
        public String RERA { get; set; }
        public String PAN { get; set; }
        public String GST { get; set; }
    }
    
    public class CustomerDetails {
        public String applicantName { get; set; }
        public String project { get; set; }
        public String coApplicantName { get; set; }
        public List<CoApplicantWrapper> coApplicants { get; set; }
        public String subProject { get; set; }
        public String phone { get; set; }
        public String unitNo { get; set; }
        public String mobile { get; set; }
        public Decimal SBA { get; set; }
        public String carpetArea { get; set; }
        public String preferredContactNo { get; set; }
        public String GSTIN { get; set; }
        public String address { get; set; }
    }
    
    public class Milestone {
        public String name { get; set; }
        public String subProject { get; set; }
        public String dueDate { get; set; }
        public Decimal amountDue { get; set; }
        
        public List<MilestoneLineItem> currentLineItems { get; set; }
        public List<MilestoneLineItem> previousLineItems { get; set; }
        
        public Boolean isPreviousDues { get; set; }
        
        // Totals
        public Decimal totalAmountA { get; set; }
        public Decimal totalAmountB { get; set; }
        public Decimal totalBalance { get; set; }
        
        public Decimal totalPrevAmountA { get; set; }
        public Decimal totalPrevAmountB { get; set; }
        public Decimal totalPrevBalance { get; set; }
        
        public Decimal totalNetAmountA { get; set; }
        public Decimal totalNetAmountB { get; set; }
        public Decimal totalNetBalance { get; set; }
    }
    
    public class MilestoneLineItem {
        public Integer serialNo { get; set; }
        public String description { get; set; }
        public String SACNo { get; set; }
        public Decimal amountA { get; set; }
        public Decimal amountB { get; set; }
        
        public MilestoneLineItem(String description, String SACNo, Decimal amountA, Decimal amountB) {
            this.description = description;
            this.SACNo = SACNo;
            this.amountA = amountA;
            this.amountB = amountB;
        }
        
        public Decimal getBalance() {
            return (amountA == null ? 0 : amountA) - (amountB == null ? 0 : amountB);
        }
    }
    
    public class CoApplicantWrapper {
        public String value { get; set; }
        public CoApplicantWrapper(String val) { value = val; }
    }
    
    // Update Demand Letter Sent Date (runs via <apex:page action>)
    public void markDemandLetterSent() {
        Id demandId = ApexPages.currentPage().getParameters().get('id');
        if (demandId != null) {
            Demand__c d = [
                SELECT Id, DemandLetterSentDate__c
                FROM Demand__c
                WHERE Id = :demandId
                LIMIT 1
            ];
            if (d.DemandLetterSentDate__c == null) {
                d.DemandLetterSentDate__c = Date.today();
                try { update d; } catch (Exception e) {
                    System.debug('Error updating Demand Letter Sent Date: ' + e.getMessage());
                }
            }
        }
    }
    
    // ------------------------
    // Build wrapper data
    // ------------------------
    private DemandLetterWrapper buildDemandLetterFromDemand(Id demandId) {
        Demand__c d = [
            SELECT Id, Name, Due_Date__c, Milestone_Description__c,
            Total_Value__c, Invoice_Value__c, Tax_Value__c , OtherChargesInvoiceValue__c, OtherChargesTaxValue__c,  Total_Amount_Recieved__c,SAP_External_Id__c,
            Account__r.Name, Account__r.Phone, Account__r.PersonHomePhone, Account__r.PersonOtherPhone, Account__r.GST_No__c,
            Account__r.Other_Phone_2__c, Account__r.Other_Phone_3__c, Account__r.Other_Phone_4__c, Account__r.BillingAddress,
            Booking_Id__r.Name, Booking_Id__r.Project__r.Name,
            Booking_Id__r.Unit_Id__r.Tower__r.Name,
            Unit__r.Built_Up_Area_SBA__c, Unit__r.Terrace_Area__c, Unit__r.Garden_Area__c, Unit__r.Deck_Balcony__c,
            Unit__r.Name, Account__r.RERA_Number__c, Account__r.PAN_Number__c, Unit__r.Carpet_Area__c,
            Booking_Id__r.Co_Applicant_1__r.Name, Booking_Id__r.Co_Applicant_2__r.Name, Booking_Id__r.Co_Applicant_3__r.Name,
            Booking_Id__r.Co_Applicant_4__r.Name, Booking_Id__r.Co_Applicant_5__r.Name,
            Booking_Payment_Schedule_Id__r.Milestone_Code__c,
            Booking_Id__r.Unit_Id__r.Property__r.CIN__c, Booking_Id__r.Unit_Id__r.Property__r.GSTIN__c,
            Booking_Payment_Schedule_Id__r.Installment_Number__c,
            Booking_Id__r.Opportunity_Id__c,
            Booking_Id__r.Unit_Id__r.Tower__r.RERA_Number__c,
            Booking_Id__r.Unit_Id__r.Property__r.PAN__c,
            Booking_Id__r.Unit_Id__r.Tower__r.Company_Bank_Account__c,
            Booking_Id__r.Unit_Id__r.Tower__r.Chargeable_Area_Type__c,//AP
            Unit__r.Saleable_Area__c//AP
            FROM Demand__c
            WHERE Id = :demandId
            LIMIT 1
        ];
        System.debug('Demand Total_Value__c: ' + d.Total_Value__c);
        System.debug('Demand Invoice_Value__c : ' + d.Invoice_Value__c);
        
        // Get account number from custom label
        //String accountNumber = Label.Demand_Letter_Bank_Account_Number;
        try {
            if(d.Booking_Id__r.Unit_Id__r.Tower__r.Company_Bank_Account__c != null){
                Id bankAccId = d.Booking_Id__r.Unit_Id__r.Tower__r.Company_Bank_Account__c;
                // Query for bank account record matching 'Name'
                List<Company_Bank_Account__c> bankAcc = [
                    SELECT Id, Name, Branch_Address__c, Bank_Name__c, IFSC_Code__c, Company_Name__c, Branch_Address__Street__s, Branch_Address__City__s, Branch_Address__StateCode__s, Branch_Address__PostalCode__s, Branch_Address__CountryCode__s
                    FROM Company_Bank_Account__c
                    WHERE Id =: bankAccId
                ];
                bankAccountRecord = bankAcc[0];
            }else{
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'No bank account record found on the tower.'));
            }
            
        } catch (Exception e) {
            errorMessage = 'Unexpected error: ' + e.getMessage();
        }
        
        DemandLetterWrapper w = new DemandLetterWrapper();
        
        // --- Header ---
        w.header = new Header();
        w.header.dated = Datetime.now().format('MMM dd, yyyy');
        w.header.demandInvoiceNo = d.SAP_External_Id__c;
        
        // property details
        w.header.CIN  = (d.Booking_Id__r != null && d.Booking_Id__r.Unit_Id__r != null && d.Booking_Id__r.Unit_Id__r.Property__r != null)
            ? d.Booking_Id__r.Unit_Id__r.Property__r.CIN__c : '';
        w.header.RERA = (d.Booking_Id__r != null && d.Booking_Id__r.Unit_Id__r != null && d.Booking_Id__r.Unit_Id__r.Tower__r != null)
            ? d.Booking_Id__r.Unit_Id__r.Tower__r.RERA_Number__c : '';
        w.header.PAN  = (d.Booking_Id__r != null && d.Booking_Id__r.Unit_Id__r != null && d.Booking_Id__r.Unit_Id__r.Property__r != null)
            ? d.Booking_Id__r.Unit_Id__r.Property__r.PAN__c : '';
        w.header.GST  = (d.Booking_Id__r != null && d.Booking_Id__r.Unit_Id__r != null && d.Booking_Id__r.Unit_Id__r.Property__r != null)
            ? d.Booking_Id__r.Unit_Id__r.Property__r.GSTIN__c : '';
        
        // --- Customer Details ---
        w.customerDetails = new CustomerDetails();
        w.customerDetails.applicantName = (d.Account__r != null) ? d.Account__r.Name : '';
        
        if (d.Account__r != null && d.Account__r.BillingAddress != null) {
            Address addr = d.Account__r.BillingAddress;
            
            List<String> parts = new List<String>();
            
            if (addr.getStreet() != null)      parts.add(addr.getStreet());
            if (addr.getCity() != null)        parts.add(addr.getCity());
            if (addr.getState() != null)       parts.add(addr.getState());
            if (addr.getPostalCode() != null)  parts.add(addr.getPostalCode());
            if (addr.getCountry() != null)     parts.add(addr.getCountry());
            
            w.customerDetails.address = String.join(parts, ', ');
        } else {
            w.customerDetails.address = '';
        }
        w.customerDetails.project       = (d.Booking_Id__r != null && d.Booking_Id__r.Project__r != null) ? d.Booking_Id__r.Project__r.Name : '';
        w.customerDetails.subProject    = (d.Booking_Id__r != null && d.Booking_Id__r.Unit_Id__r != null && d.Booking_Id__r.Unit_Id__r.Tower__r != null)
            ? d.Booking_Id__r.Unit_Id__r.Tower__r.Name : '';
        
        // Other contacts (comma separated)
        List<String> otherContacts = new List<String>();
        if (d.Account__r != null) {
            if (d.Account__r.Other_Phone_2__c != null) otherContacts.add(d.Account__r.Other_Phone_2__c);
            if (d.Account__r.Other_Phone_3__c != null) otherContacts.add(d.Account__r.Other_Phone_3__c);
            if (d.Account__r.Other_Phone_4__c != null) otherContacts.add(d.Account__r.Other_Phone_4__c);
            if (d.Account__r.PersonOtherPhone != null)  otherContacts.add(d.Account__r.PersonOtherPhone);
        }
        OtherContactNumbers = String.join(otherContacts, ', ');
        
        // Co-applicants
        List<String> coAppNames = new List<String>();
        if (d.Booking_Id__r != null) {
            if (d.Booking_Id__r.Co_Applicant_1__r != null) coAppNames.add(d.Booking_Id__r.Co_Applicant_1__r.Name);
            if (d.Booking_Id__r.Co_Applicant_2__r != null) coAppNames.add(d.Booking_Id__r.Co_Applicant_2__r.Name);
            if (d.Booking_Id__r.Co_Applicant_3__r != null) coAppNames.add(d.Booking_Id__r.Co_Applicant_3__r.Name);
            if (d.Booking_Id__r.Co_Applicant_4__r != null) coAppNames.add(d.Booking_Id__r.Co_Applicant_4__r.Name);
            if (d.Booking_Id__r.Co_Applicant_5__r != null) coAppNames.add(d.Booking_Id__r.Co_Applicant_5__r.Name);
        }
        List<CoApplicantWrapper> coApplicants = new List<CoApplicantWrapper>();
        Integer idx = 1;
        for (String name : coAppNames) {
            if (!String.isBlank(name)) {
                coApplicants.add(new CoApplicantWrapper('<strong>Co-Applicant_' + idx++ + '</strong>: ' + name));
            }
        }
        w.customerDetails.coApplicants = coApplicants;
        
        w.customerDetails.unitNo  = (d.Unit__r != null) ? d.Unit__r.Name : '';
        w.customerDetails.phone   = (d.Account__r != null && d.Account__r.Phone != null) ? d.Account__r.Phone : '';
        w.customerDetails.mobile  = (d.Account__r != null && d.Account__r.PersonHomePhone != null) ? d.Account__r.PersonHomePhone : '';
        w.customerDetails.preferredContactNo = (d.Account__r != null && d.Account__r.PersonOtherPhone != null) ? d.Account__r.PersonOtherPhone : '';
        w.customerDetails.GSTIN   = (d.Account__r != null) ? d.Account__r.GST_No__c : '';
        w.customerDetails.SBA     = (d.Unit__r != null && d.Unit__r.Built_Up_Area_SBA__c != null)
            ? Integer.valueOf(d.Unit__r.Built_Up_Area_SBA__c.setScale(0, RoundingMode.HALF_UP)) : 0;
        
        // Area details line
        /*
List<String> areaParts = new List<String>();
if (d.Unit__r != null) {
Map<String, Decimal> areaMap = new Map<String, Decimal>{
'Carpet Area'  => d.Unit__r.Carpet_Area__c,
'Terrace Area' => d.Unit__r.Terrace_Area__c,
'Garden Area'  => d.Unit__r.Garden_Area__c,
'Deck Area'    => d.Unit__r.Deck_Balcony__c
};
for (String label : areaMap.keySet()) {
Decimal val = areaMap.get(label);
if (val != null) {
areaParts.add('<strong>' + label + '</strong>: ' + Integer.valueOf(val.setScale(0, RoundingMode.HALF_UP)) + ' sq.ft');
}
}
}
w.customerDetails.carpetArea = String.join(areaParts, ' | ');
*/

//---------------------------------------------------------------------------------------AP

        //w.customerDetails.carpetArea = String.valueOf(d.Unit__r.Carpet_Area__c.setScale(0, RoundingMode.HALF_UP));

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++AP

Decimal finalAreaValue = 0;

w.customerDetails.carpetArea = (finalAreaValue != null)? String.valueOf(finalAreaValue.setScale(0, RoundingMode.HALF_UP)) : '0';//AP

    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++AP
        
        
        // --- Milestone ---
        w.milestone = new Milestone();
        w.milestone.name       = (d.Booking_Payment_Schedule_Id__r != null) ? d.Booking_Payment_Schedule_Id__r.Milestone_Code__c : '';
        w.milestone.subProject = (d.Booking_Id__r != null && d.Booking_Id__r.Unit_Id__r != null && d.Booking_Id__r.Unit_Id__r.Tower__r != null)
            ? d.Booking_Id__r.Unit_Id__r.Tower__r.Name : '';
        w.milestone.dueDate    = (d.Due_Date__c != null)
            ? Datetime.newInstance(d.Due_Date__c, Time.newInstance(0,0,0,0)).format('MMM dd, yyyy') : '';
        w.milestone.amountDue  = (d.Total_Value__c != null) ? d.Total_Value__c : 0;
        
        // --- Line items lists
        w.milestone.currentLineItems   = new List<MilestoneLineItem>();
        w.milestone.previousLineItems  = new List<MilestoneLineItem>();
        
        // All schedules (for max installment)
        List<Booking_Payment_Schedule__c> bpsList = [
            SELECT Id, Installment_Number__c
            FROM Booking_Payment_Schedule__c
            WHERE Booking__c = :d.Booking_Id__c
        ];
        Integer maxInstallment = 0;
        for (Booking_Payment_Schedule__c bps : bpsList) {
            if (bps.Installment_Number__c != null && bps.Installment_Number__c > maxInstallment) {
                maxInstallment = Integer.valueOf(bps.Installment_Number__c);
            }
        }
        Integer currentInstallment = (d.Booking_Payment_Schedule_Id__r != null)
            ? Integer.valueOf(d.Booking_Payment_Schedule_Id__r.Installment_Number__c) : 0;
        
        // --- Previous Dues (Amount Paid must include Advance Applied)
        w.milestone.isPreviousDues = false;
        
        if (currentInstallment > 0) {
            Integer prevInstallmentNum = currentInstallment - 1;
            
            List<Booking_Payment_Schedule__c> prevBpSchedules = [
                SELECT Id,
                Installment_Amount__c,
                Adjusted_Amount__c,
                TotalPrincipalReceived__c,
                Advance_Applied__c
                FROM Booking_Payment_Schedule__c
                WHERE Booking__c = :d.Booking_Id__c
                AND Installment_Number__c = :prevInstallmentNum
                LIMIT 1
            ];
            
            if (!prevBpSchedules.isEmpty()) {
                Booking_Payment_Schedule__c prevBps = prevBpSchedules.get(0);
                // A: invoice for that schedule (prefer Adjusted)
                Decimal prevInvoice = (prevBps.Adjusted_Amount__c != null)
                    ? prevBps.Adjusted_Amount__c
                    : (prevBps.Installment_Amount__c == null ? 0 : prevBps.Installment_Amount__c);
                        
                        // B: paid towards that schedule principal = Principal Received + Advance Applied
                        Decimal prevPaid = nz(prevBps.TotalPrincipalReceived__c) + nz(prevBps.Advance_Applied__c);
                if (prevPaid > prevInvoice) prevPaid = prevInvoice; // cap
                
                Decimal prevBalance = prevInvoice - prevPaid;
                if (prevBalance < 0) prevBalance = 0;
                
                // Split into 2/3 construction and 1/3 land for rows
                Decimal invConst = (prevInvoice * 2) / 3;
                Decimal invLand  =  prevInvoice / 3;
                Decimal paidConst = (prevPaid * 2) / 3;
                Decimal paidLand  =  prevPaid / 3;
                
                w.milestone.previousLineItems.add(
                    new MilestoneLineItem('Basic Construction Cost', '995411', invConst, paidConst)
                );
                w.milestone.previousLineItems.add(
                    new MilestoneLineItem('Land Cost', '995411', invLand, paidLand)
                );
                
                w.milestone.isPreviousDues = (prevBalance > 0);
            }
        }
        
        // --- Current installment line items
        Decimal invoiceValue = (d.Total_Value__c == null) ? 0 : d.Total_Value__c;
        
        if (currentInstallment < maxInstallment) {
            // simple split for intermediate installments
            w.milestone.currentLineItems.add(new MilestoneLineItem('Basic Construction Cost', '995411', (invoiceValue * 2) / 3, 0));
            w.milestone.currentLineItems.add(new MilestoneLineItem('Land Cost', '995411', invoiceValue / 3, 0));
        } else {
            // Final installment: carve out Other Charges (and their CGST/SGST) from invoice
            if (d.Booking_Id__r != null && d.Booking_Id__r.Opportunity_Id__c != null) {
                ChargesCalculationHelper.FinancialsWrapper fin =
                    ChargesCalculationHelper.calculateCharges(d.Booking_Id__r.Opportunity_Id__c);
                
                Decimal totalOther = (fin.otherChargesSummary.containsKey('totalOtherCharges'))
                    ? (Decimal) fin.otherChargesSummary.get('totalOtherCharges') : 0;
                Decimal cgstOther = (fin.otherChargesSummary.containsKey('cgstOnOtherCharges'))
                    ? (Decimal) fin.otherChargesSummary.get('cgstOnOtherCharges') : 0;
                Decimal sgstOther = (fin.otherChargesSummary.containsKey('sgstOnOtherCharges'))
                    ? (Decimal) fin.otherChargesSummary.get('sgstOnOtherCharges') : 0;
                
                Decimal remainingInvoice = invoiceValue - totalOther - cgstOther - sgstOther;
                
                w.milestone.currentLineItems.add(new MilestoneLineItem('Basic Construction Cost', '995411', ((remainingInvoice * 2) / 3), 0));
                w.milestone.currentLineItems.add(new MilestoneLineItem('Land Cost', '995411', (remainingInvoice / 3), 0));
                
                // Other charges
                for (ChargesCalculationHelper.OtherChargeRow oc : fin.otherCharges) {
                    Decimal ocAmount = (oc.amountByType == null) ? 0 : oc.amountByType;
                    w.milestone.currentLineItems.add(
                        new MilestoneLineItem(oc.name, '995411', ocAmount, 0)
                    );
                }
                if (cgstOther > 0) {
                    w.milestone.currentLineItems.add(
                        new MilestoneLineItem('CGST on Other Charges', '995411', cgstOther, 0)
                    );
                }
                if (sgstOther > 0) {
                    w.milestone.currentLineItems.add(
                        new MilestoneLineItem('SGST on Other Charges', '995411', sgstOther, 0)
                    );
                }
            }
        }
        
        // --- Serial numbers & totals ---
        w.milestone.totalAmountA      = 0;
        w.milestone.totalAmountB      = 0;
        w.milestone.totalBalance      = 0;
        w.milestone.totalPrevAmountA  = 0;
        w.milestone.totalPrevAmountB  = 0;
        w.milestone.totalPrevBalance  = 0;
        w.milestone.totalNetAmountA   = 0;
        w.milestone.totalNetAmountB   = 0;
        w.milestone.totalNetBalance   = 0;
        
        Integer counter = 1;
        
        // Current dues
        for (MilestoneLineItem li : w.milestone.currentLineItems) {
            li.serialNo = counter++;
            w.milestone.totalAmountA += (li.amountA == null ? 0 : li.amountA);
            w.milestone.totalAmountB += (li.amountB == null ? 0 : li.amountB);
            w.milestone.totalBalance += li.getBalance();
        }
        
        // Previous dues
        counter = 1;
        for (MilestoneLineItem li : w.milestone.previousLineItems) {
            li.serialNo = counter++;
            w.milestone.totalPrevAmountA += (li.amountA == null ? 0 : li.amountA);
            w.milestone.totalPrevAmountB += (li.amountB == null ? 0 : li.amountB);
            w.milestone.totalPrevBalance += li.getBalance();
        }
        
        // Net = Current + Previous
        w.milestone.totalNetAmountA = w.milestone.totalAmountA + w.milestone.totalPrevAmountA;
        w.milestone.totalNetAmountB = w.milestone.totalAmountB + w.milestone.totalPrevAmountB;
        w.milestone.totalNetBalance = w.milestone.totalBalance + w.milestone.totalPrevBalance;
        
        w.milestone.amountDue = w.milestone.totalNetBalance;
        
        return w;
    }
    
    // ---------- small helper ----------
    private static Decimal nz(Decimal d) { return (d == null) ? 0 : d; }
}