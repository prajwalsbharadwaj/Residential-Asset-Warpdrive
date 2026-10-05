public class SalesOutstandingReportController {
    
    public class outputWrapper {
        @AuraEnabled public List<BookingReportDTO> bookings { get; set; }
        @AuraEnabled public Integer totalRecords { get; set; }
        @AuraEnabled public Integer pageNumber { get; set; }
        @AuraEnabled public Integer pageSize { get; set; }
        @AuraEnabled public Integer totalPages { get; set; }
    } 

    public class BookingReportDTO {
        @AuraEnabled public Id bookingId;
        @AuraEnabled public String customerCode;
        @AuraEnabled public String customerName;
        @AuraEnabled public String contactNo;
        @AuraEnabled public String unitNo;
        @AuraEnabled public Date bookingDate;
        @AuraEnabled public Decimal sbaArea;
        @AuraEnabled public String executiveName;
        @AuraEnabled public Decimal baseCost;
        @AuraEnabled public Decimal otherCharges;
        @AuraEnabled public Decimal taxAmountOnBaseCost;
        @AuraEnabled public Decimal taxAmountOnOtherCharges;
        @AuraEnabled public Decimal agreementCost;
        
        
        @AuraEnabled public Decimal totalOutstandingPrincipal;
        @AuraEnabled public Decimal totalInterestOutstanding;
        @AuraEnabled public Decimal totalPrincipalReceived;
        @AuraEnabled public Decimal totalInterestReceived;
        
        
        @AuraEnabled public Decimal totalCost;
        @AuraEnabled public Decimal totalDue;
        @AuraEnabled public Decimal excessReceived;
        @AuraEnabled public Decimal totalReceived;
        @AuraEnabled public Decimal amountReceivedOnTotalCost;
        @AuraEnabled public Decimal outstandingPrinciple;
        @AuraEnabled public Decimal outstandingInterest; 
    }

    @AuraEnabled(cacheable=true)
    public static outputWrapper getDebtorAgeingReport(String projectName, String towerName, Integer pageNumber, Integer pageSize) {
        Integer offsetVal = (pageNumber - 1) * pageSize;
        outputWrapper ow = new outputWrapper();
        List<BookingReportDTO> reportList = new List<BookingReportDTO>();
        Integer totalCount = getBookingCount(projectName,towerName);
        List<Booking__c> bookings = [
            SELECT Id,
            	   Project__r.Name,
            	   Booking__c.Tower__c, 
                   Account_Id__r.Name,
                   Account_Id__r.SAP_External_Id__c,
                   Account_Id__r.Phone,
                   Unit_Id__r.Name,
                   Unit_Id__r.Built_Up_Area_SBA__c,
                   Booking_Date__c,
            	   Allotment_Letter_Date__c,
            	   Agreement_Executed_Date__c,
            	   Agreement_Registered_Date__c,
                   Sale_Deed_Registered_Date__c,
                   Sale_Deed_Executed_Date__c,
                   Payment_Plan_Id__r.Name,
                   Unit_Id__r.Saleable_Area__c,
            	   Status__c,	
            
            
              	   Opportunity_Id__r.BaseCostAfterDiscount__c,
                   Opportunity_Id__r.Owner.Name,
                   Opportunity_Id__r.Base_Cost__c,
                   Opportunity_Id__r.OtherCharges__c,
                   //Opportunity_Id__r.TaxOnBaseCost__c,
                   Opportunity_Id__r.TaxOnOtherCharges__c,
                   //Opportunity_Id__r.AgreementCost__c,
                   Opportunity_Id__r.Total_Amount__c 
                   
            FROM Booking__c
            WHERE Project__r.Name =:projectName AND tower__c =: towerName
        ];
		System.debug('size'+ bookings.size()); 
        for (Booking__c b : bookings) {
            BookingReportDTO dto = new BookingReportDTO();
            dto.bookingId = b.Id;
            dto.customerCode = b.Account_Id__r.SAP_External_Id__c;
            dto.customerName = b.Account_Id__r.Name;
            dto.contactNo = b.Account_Id__r.Phone;
            dto.unitNo = b.Unit_Id__r.Name;
            dto.bookingDate = b.Booking_Date__c;
            dto.sbaArea = b.Unit_Id__r.Built_Up_Area_SBA__c;
            dto.executiveName = b.Opportunity_Id__r.Owner.Name;

            dto.baseCost = b.Opportunity_Id__r.Base_Cost__c;
            dto.otherCharges = b.Opportunity_Id__r.OtherCharges__c;
            dto.taxAmountOnOtherCharges = b.Opportunity_Id__r.TaxOnOtherCharges__c;
            
            BookingInterestService.SnapshotDTO snapshot = BookingInterestService.calculateAsOf(b.Id);

             if (snapshot != null) {
        		dto.totalOutstandingPrincipal = snapshot.totalOutstandingPrincipal;
        		dto.totalInterestOutstanding = snapshot.totalInterestOutstanding;
        		dto.totalPrincipalReceived = snapshot.totalPrincipalReceived;
        		dto.totalInterestReceived = snapshot.totalInterestReceivedAllocated;
                dto.totalDue = snapshot.totalOutstandingPrincipal + snapshot.totalInterestOutstanding;
                dto.totalReceived = snapshot.totalPrincipalReceived + snapshot.totalInterestReceivedAllocated; 
                dto.outstandingPrinciple = snapshot.totalOutstandingPrincipal - snapshot.totalPrincipalReceived; 
                dto.outstandingInterest = snapshot.totalInterestOutstanding - snapshot.totalInterestReceivedAllocated;
    		}
            dto.totalCost = b.Opportunity_Id__r.Base_Cost__c + b.Opportunity_Id__r.OtherCharges__c;
            if (dto.totalCost != null && dto.totalCost != 0 && dto.totalReceived != null) {
                // Correctly perform division and set scale
                dto.amountReceivedOnTotalCost = ((dto.totalReceived / dto.totalCost) * 100).setScale(2);
            } else {
                // Assign 0 if total cost is null, zero, or total received is null
                dto.amountReceivedOnTotalCost = 0; 
            }
            
            reportList.add(dto);
        }
        ow.bookings = reportList;
        ow.totalRecords = totalCount;
        ow.pageNumber = pageNumber;
        ow.pageSize = pageSize;
        ow.totalPages = (Integer)Math.ceil((Decimal)totalCount / pageSize);

        return ow;
    }
    
    // Get total count (for pagination)
    public static Integer getBookingCount(string projectName, string towerName) {
        return [SELECT COUNT() FROM Booking__c WHERE Project__r.Name =:projectName AND Tower__c =: towerName];
    }
    
    @AuraEnabled
    public static Map<String, List<String>> getProjectVsTowerOptions() {
        List<Property__c> projects = [
            SELECT Id, Name, (SELECT Name FROM Towers__r)
            FROM Property__c
            WHERE RecordType.DeveloperName = 'Residential_Project'
        ];

        Map<String, List<String>> projectVsTowerMap = new Map<String, List<String>>();

        for (Property__c p : projects) {
            List<String> towerNames = new List<String>();
            for (Tower__c t : p.Towers__r) {
                towerNames.add(t.Name);
            }
            projectVsTowerMap.put(p.Name, towerNames);
        }
        system.debug('Project & Towers-> '+ json.serialize(projectVsTowerMap));
        return projectVsTowerMap;
    }


}