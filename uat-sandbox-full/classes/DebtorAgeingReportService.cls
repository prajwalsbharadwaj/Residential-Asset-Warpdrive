public with sharing class DebtorAgeingReportService {

    /**
     * @description Wrapper class for a single row in the Debtor Ageing Report.
     */
    public class DebtorAgeingRow {
        // Customer and Project/Booking Details
        @AuraEnabled public String customerName { get; set; }
        @AuraEnabled public String bookingName { get; set; }
        @AuraEnabled public String projectName { get; set; }
        @AuraEnabled public String towerName { get; set; }
        @AuraEnabled public String unitName { get; set; }
        
        // Demand & Amount Details
        @AuraEnabled public String demandName { get; set; }
        @AuraEnabled public Date demandDate { get; set; }
        @AuraEnabled public Date dueDate { get; set; }
        @AuraEnabled public Decimal demandAmount { get; set; }        // Invoice_Value__c (Inv Amt)
        @AuraEnabled public Decimal receivedAmount { get; set; }      // Sum of Principal Applied (Received Amt)
        @AuraEnabled public Decimal outstandingBalance { get; set; }  // Calculated: Demand Amount - Received Amount
        
        // Ageing Buckets 
        @AuraEnabled public Decimal currentDue { get; set; }
        @AuraEnabled public Decimal days1to30 { get; set; }
        @AuraEnabled public Decimal days31to60 { get; set; }
        @AuraEnabled public Decimal days61to90 { get; set; }
        @AuraEnabled public Decimal days91to180 { get; set; }
        @AuraEnabled public Decimal days181to365 { get; set; }
        @AuraEnabled public Decimal daysOver365 { get; set; }
        @AuraEnabled public Decimal balanceOverDue { get; set; }
    }

    /**
     * @description Fetches the Debtor Ageing Report data by querying Demands and associated Payments.
     * @param selectedProject (Optional) Filter by a specific project name.
     * @return List of DebtorAgeingRow wrappers.
     */
    @AuraEnabled(cacheable=true)
    public static List<DebtorAgeingRow> getDebtorAgeingData(String selectedProject) {
        
        // --- 1. Query Demands ---
        // Get Demands that have an amount > 0 OR a payment received against them.
        String demandQuery = 'SELECT Id, Name, Due_Date__c, Demand_Letter_Sent_Date__c, Invoice_Value__c, ' +
                             'Booking__r.Name, Account__r.Name, Project__r.Name, Tower__r.Name, Unit__r.Name ' +
                             'FROM Demand__c ' +
                             'WHERE Due_Date__c != NULL AND Invoice_Value__c > 0';

        if (String.isNotBlank(selectedProject)) {
            demandQuery += ' AND Project__r.Name = :selectedProject';
        }
        
        // Order by Project, then Account, then Due Date
        demandQuery += ' ORDER BY Project__r.Name ASC, Account__r.Name ASC, Due_Date__c ASC';

        List<Demand__c> demands = Database.query(demandQuery);
        Set<Id> demandIds = (new Map<Id, Demand__c>(demands)).keySet();
        
        if (demandIds.isEmpty()) {
            return new List<DebtorAgeingRow>();
        }
        
        // --- 2. Query Payments & Calculate Total Received Per Demand ---
        Map<Id, Decimal> demandToPrincipalReceived = new Map<Id, Decimal>();
        
        // Query PaymentReceipts for the retrieved Demands
        for (AggregateResult ar : [
            SELECT Demand__c demandId, SUM(Principal_Applied__c) totalPrincipalReceived
            FROM Payment_Receipt__c
            WHERE Demand__c IN :demandIds AND Approval_Status__c = 'Approved' // Only count Approved payments
            GROUP BY Demand__c
        ]) {
            Id demandId = (Id)ar.get('demandId');
            Decimal received = (Decimal)ar.get('totalPrincipalReceived');
            demandToPrincipalReceived.put(demandId, received);
        }

        // --- 3. Process Demands, Calculate Outstanding Balance, and Ageing ---
        List<DebtorAgeingRow> reportRows = new List<DebtorAgeingRow>();
        Date ageingDate = Date.today();

        for (Demand__c demand : demands) {
            
            // Initial received amount is 0 if no payments found
            Decimal receivedAmount = demandToPrincipalReceived.get(demand.Id) != null 
                ? demandToPrincipalReceived.get(demand.Id) : 0;
            
            Decimal demandAmount = demand.Invoice_Value__c != null ? demand.Invoice_Value__c : 0;
            Decimal outstandingBalance = demandAmount - receivedAmount;
            
            // Only report Demands with a non-zero outstanding balance
            if (outstandingBalance <= 0) continue; 
            
            // --- Map Data ---
            DebtorAgeingRow row = new DebtorAgeingRow();
            row.demandName = demand.Name;
            row.dueDate = demand.Due_Date__c; 
            row.demandDate = demand.DemandLetterSentDate__c	;
            row.demandAmount = demandAmount; 
            row.receivedAmount = receivedAmount;
            row.outstandingBalance = outstandingBalance;
            
            // Related Records (using the lookups from the Demand screenshot)
            row.bookingName = demand.Booking_Id__r.Name;
            row.customerName = demand.Account__r.Name;
            row.projectName = demand.Unit__r.Property__r.Name;
            row.towerName = demand.Unit__r.Tower__r.Name;
            row.unitName = demand.Unit__r.Name;
            
            // --- Ageing Logic ---
            Integer daysPastDue = ageingDate.daysBetween(demand.Due_Date__c);
            row.balanceOverDue = 0.0;
            
            // Initialize all buckets to 0.0
            row.currentDue = 0.0; row.days1to30 = 0.0; row.days31to60 = 0.0; 
            row.days61to90 = 0.0; row.days91to180 = 0.0; row.days181to365 = 0.0; 
            row.daysOver365 = 0.0;

            if (daysPastDue <= 0) {
                // Not Due or Due Today/Future
                row.currentDue = outstandingBalance;
            } else {
                // Overdue - Categorize the full outstanding balance
                row.balanceOverDue = outstandingBalance;
                
                if (daysPastDue >= 1 && daysPastDue <= 30) {
                    row.days1to30 = outstandingBalance;
                } else if (daysPastDue >= 31 && daysPastDue <= 60) {
                    row.days31to60 = outstandingBalance;
                } else if (daysPastDue >= 61 && daysPastDue <= 90) {
                    row.days61to90 = outstandingBalance;
                } else if (daysPastDue >= 91 && daysPastDue <= 180) {
                    row.days91to180 = outstandingBalance;
                } else if (daysPastDue >= 181 && daysPastDue <= 365) {
                    row.days181to365 = outstandingBalance;
                } else { // daysPastDue > 365
                    row.daysOver365 = outstandingBalance;
                }
            }

            reportRows.add(row);
        }

        return reportRows;
    }
    
// ----------------------------------------------------------------------
// Filter Options Method
// ----------------------------------------------------------------------
    
    public class FilterOptions {
        @AuraEnabled public List<String> projects { get; set; }
    }

    /**
     * @description Fetches unique Project Names for LWC filter.
     */
    @AuraEnabled(cacheable=true)
    public static FilterOptions getFilterOptions() {
        FilterOptions options = new FilterOptions();
        
        Set<String> projectNames = new Set<String>();
        for (AggregateResult ar : [
            SELECT Unit__r.Property__r.Name projectName
            FROM Demand__c
            WHERE Unit__r.Property__r.Name != null
            GROUP BY Unit__r.Property__r.Name
        ]) {
            projectNames.add((String)ar.get('projectName'));
        }
        
        options.projects = new List<String>(projectNames);
        options.projects.sort();
        
        return options;
    }
}