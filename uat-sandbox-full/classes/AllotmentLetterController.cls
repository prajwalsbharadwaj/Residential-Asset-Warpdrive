public class AllotmentLetterController {
    public Booking__c bookingRecord { get; set; }
    public Decimal parkingCount { get; set; }
    public Id recordId { get; set; }

    
    public Decimal bookingPaymentSchedulesTotal {get; set;}
    public Decimal baseCost { get; set; }
    public Decimal clubBasic { get; set; }
    public Decimal bescomBasic { get; set; }
    public Decimal maintenanceBasic { get; set; }
    public Decimal legalBasic { get; set; }
    public Property__c propertyDetails { get; set; }
	public Decimal cgstAmount {get; set;}
    public Decimal sgstAmount {get; set;}
    public Decimal totalOtherAmount {get; set;}
    public List<Booking_Payment_Schedule__c> bookingPaymentSchedulesList {get; set;}
    //public Booking_Payment_Schedule__c bookingPaymentSchedulesList {get; set;}
    
    
    public AllotmentLetterController() {
        initializeData(ApexPages.currentPage().getParameters().get('id'));
    }

    public AllotmentLetterController(ApexPages.StandardController stdController) {
        initializeData(stdController.getId());
    }

    private void initializeData(Id currentRecordId) {
        recordId = currentRecordId;
        system.debug('Inside initializeData');
        if (recordId != null) {
            try {
                // Fetch Booking Record and related details
                bookingRecord = [
                    SELECT Id, Name, Opportunity_Id__c, Booking_Date__c, Payment_Plan_Id__c, Project__r.Name, Project__r.Address__c,
                           Unit_Id__c, Unit_Id__r.Name, Unit_Id__r.Floor__r.Name, Unit_Id__r.Tower__r.Name, Unit_Id__r.Tower__r.RERA_Number__c,
                    	   Unit_Id__r.Tower__r.BESCOM_BWSSB_Charges__c, Unit_Id__r.Tower__r.Maintenance_Deposit_Corpus_Fund__c, Unit_Id__r.Tower__r.Club_Membership_Fees__c, Unit_Id__r.Tower__r.Legal_Fees__c,
                           Unit_Id__r.Carpet_Area__c, Unit_Id__r.BHK_Configuration__c,
                    	   Unit_Id__r.Garden_Area__c, Unit_Id__r.Terrace_Area__c, Unit_Id__r.Saleable_Area__c, Unit_Id__r.Net_Area_Aggregate__c,
                    	   Unit_Id__r.Total_area_of_villa_unit__c, Unit_Id__r.Deck_Balcony__c,
                           Account_Id__c, Account_Id__r.Name, Account_Id__r.BillingStreet, Account_Id__r.BillingCity,
                           Account_Id__r.BillingState, Account_Id__r.BillingPostalCode, Account_Id__r.Phone,
                           Funding_Method__c, Final_Amount__c, Registration__c, Reservation_Deposit__c,
                           OC_Received__c, Brokerage_Value__c, Approval_Status__c,
                           Status__c, Project__c, Opportunity_Id__r.Base_Cost__c, Opportunity_Id__r.Chargeable_Area__c, Opportunity_Id__r.Total_Amount__c,
                           Co_Applicant_1__r.Name,Co_Applicant_2__r.Name, Co_Applicant_3__r.Name, Co_Applicant_4__r.Name, Co_Applicant_5__r.Name,
                           Opportunity_Id__r.OtherCharges__c,Opportunity_Id__r.TaxOnOtherCharges__c
                    FROM Booking__c
                    WHERE Id = :recordId
                    LIMIT 1
                ];

                // Fetch bookingPaymentSchedules related to the bookingRecord
                bookingPaymentSchedulesList = [
                    SELECT Id, Milestone_Code__c, Installment_Number__c, Installment_Amount__c, Booking__r.Opportunity_Id__r.Total_Amount__c
					FROM Booking_Payment_Schedule__c 
                    WHERE Booking__r.Id  = :recordId
                    Order by Installment_Number__c asc
                ];
                
                // bookingPaymentSchedules Total 
                bookingPaymentSchedulesTotal = 0; 
                for (Booking_Payment_Schedule__c detail : bookingPaymentSchedulesList) {
                    bookingPaymentSchedulesTotal += detail.Installment_Amount__c;
                }
                
                
                
                //bookingPaymentSchedulesTotal = bookingPaymentSchedulesList.Installment_Amount__c ; 
                system.debug('parkingResults--> '+ bookingRecord.Opportunity_Id__c);
                // Fetch Parking Count related to the Opportunity
                List<Opportunity_Parking__c> parkingResults = [
                    SELECT Id, Parking_Count__c
                    FROM Opportunity_Parking__c
                    WHERE Opportunity__c = :bookingRecord.Opportunity_Id__c OR Booking__c =:bookingRecord.Id
                    LIMIT 1
                ];
                system.debug('parkingResults--> '+ parkingResults);
                
                // Fetch Tower details to get Other Charges
               Tower__c towerDetails = [
                    SELECT Id, BESCOM_BWSSB_Charges__c, Maintenance_Deposit_Corpus_Fund__c, Club_Membership_Fees__c, Legal_Fees__c
                    FROM Tower__c
                    WHERE Id = :bookingRecord.Unit_Id__r.Tower__r.Id
                    LIMIT 1
                ];
                
             
                
                
                parkingCount = (!parkingResults.isEmpty() && parkingResults[0].Parking_Count__c != null)
                    ? parkingResults[0].Parking_Count__c : 0;
                
                /* Updating Base_Cost__c from Opportunity
                if (bookingRecord != null && bookingRecord.Opportunity_Id__r.Base_Cost__c != null){
                    baseCost = bookingRecord.Opportunity_Id__r.Base_Cost__c != null ? bookingRecord.Opportunity_Id__r.Base_Cost__c : 0;
                } */
                
				
               
             
                //Other Indicative Charges
                bescomBasic = towerDetails.BESCOM_BWSSB_Charges__c != null ?  towerDetails.BESCOM_BWSSB_Charges__c * bookingRecord.Opportunity_Id__r.Chargeable_Area__c : 0;
                maintenanceBasic = towerDetails.Maintenance_Deposit_Corpus_Fund__c != null ? towerDetails.Maintenance_Deposit_Corpus_Fund__c  * bookingRecord.Opportunity_Id__r.Chargeable_Area__c  : 0;
                
                clubBasic = bookingRecord.Unit_Id__r.Tower__r.Club_Membership_Fees__c != null ? bookingRecord.Unit_Id__r.Tower__r.Club_Membership_Fees__c : 0;
            	legalBasic = bookingRecord.Unit_Id__r.Tower__r.Legal_Fees__c != null ? bookingRecord.Unit_Id__r.Tower__r.Legal_Fees__c : 0;
                
                cgstAmount = (bookingRecord.Opportunity_Id__r.TaxOnOtherCharges__c/2).setScale(0, RoundingMode.HALF_UP);
				sgstAmount = (bookingRecord.Opportunity_Id__r.TaxOnOtherCharges__c/2).setScale(0, RoundingMode.HALF_UP);
                decimal otherCharges = bookingRecord.Opportunity_Id__r.OtherCharges__c != null ? bookingRecord.Opportunity_Id__r.OtherCharges__c : 0;
                decimal taxOnOtherCharges = bookingRecord.Opportunity_Id__r.TaxOnOtherCharges__c != null ? bookingRecord.Opportunity_Id__r.TaxOnOtherCharges__c : 0;
                totalOtherAmount = otherCharges +  taxOnOtherCharges;

            } catch (Exception e) {
                // Log the exception using ExceptionLogger for data initialization failures
                ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                    .withComponentName('AllotmentLetterController')
                    .withClassName('AllotmentLetterController')
                    .withMethodName('initializeData')
                    .withRequestBody('Record ID: ' + (recordId != null ? String.valueOf(recordId) : 'N/A') + '; Error Line: ' + e.getLineNumber())
                    .withDomain('Booking')
                    .withException(e);
                ExceptionLogger.logException(payload);

                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error loading booking data. Please contact support.'));
                // Ensure variables are initialized to avoid null pointers downstream even if data loading fails
                bookingRecord = new Booking__c();
                parkingCount = 0;
            }
        } else {
            // If no recordId is provided, initialize empty and log
            bookingRecord = new Booking__c();
            parkingCount = 0;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'No Booking ID provided for controller.'));
        }
    }

    // Word Document generation and saving logic
    public PageReference generateAndSaveWord() {
        if (recordId == null) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Error: Record ID is missing. Cannot generate and save Word document.'
            ));
            return null; // Added return to halt execution
        }

        try {
            system.debug('generateAndSaveWord');
            // Create a PageReference to the Visualforce page that renders the Allotment Letter
            PageReference allotmentPage = new PageReference('/apex/AllotmentLetterWord');
            allotmentPage.getParameters().put('id', recordId);

            // Get the content of the rendered Visualforce page as a Blob
            // The contentType attribute on the Visualforce page itself (application/msword)
            // dictates the output format when getContent() is called.
            Blob wordBlob = !Test.isRunningTest() ? allotmentPage.getContent() : Blob.valueOf('test');

            // Create ContentVersion
            ContentVersion cv = new ContentVersion();
            String title;

            // Construct a meaningful title for the document
            if (bookingRecord != null &&
                bookingRecord.Unit_Id__c != null &&
                bookingRecord.Unit_Id__r != null &&
                bookingRecord.Unit_Id__r.Name != null &&
                bookingRecord.Account_Id__c != null &&
                bookingRecord.Account_Id__r != null &&
                bookingRecord.Account_Id__r.Name != null
            ) {
                // Example: "Allotment Letter - U-101 : John Doe"
                title = 'Allotment Letter - ' + bookingRecord.Unit_Id__r.Name + ' : ' + bookingRecord.Account_Id__r.Name;
            } else {
                // Fallback title if related records are null
                title = 'Allotment Letter - ' + recordId;
            }

            // Append a timestamp to the title to ensure a new ContentDocument is created
            // each time, rather than just a new version, if that's the desired behavior.
            // If you always want to version the SAME document, remove the timestamp from title.
            // For file generation, often a new document per generation is desired.
            title += ' ' + System.now().format('yyyyMMddHHmmss');

            cv.Title = title;
            cv.PathOnClient = 'Allotment_Letter_' + System.now().format('yyyyMMddHHmmss') + '.doc'; // Ensure unique filename
            cv.VersionData = wordBlob;
            cv.IsMajorVersion = true;

            // Insert ContentVersion (this creates the file in Salesforce Files)
            insert cv;

            // Query the inserted ContentVersion to get its ContentDocumentId
            // This ID links to the actual "file" record
            ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            Id contentDocId = insertedCv.ContentDocumentId;

            // Before creating ContentDocumentLink, check if one already exists
            // This prevents the "duplicate value found" error for ContentDocumentLink
            List<ContentDocumentLink> existingCdl = [
                SELECT Id
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :contentDocId
                AND LinkedEntityId = :recordId
                LIMIT 1
            ];

            if (existingCdl.isEmpty()) {
                // Create ContentDocumentLink to relate the file to the Booking record
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = contentDocId; // The ID of the actual file
                cdl.LinkedEntityId = recordId;         // The Booking record ID
                cdl.ShareType = 'V';                   // Viewer permission
                cdl.Visibility = 'AllUsers';           // Visible to all users who can see the record

                insert cdl; // Insert the link only if it doesn't already exist
            } else {
                // If the link already exists, inform the user (optional) and log
                System.debug('Allotment Letter document (ContentDocumentId: ' + contentDocId + ') is already linked to Booking record: ' + recordId);
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.INFO,
                    'Allotment Letter document already linked to this record. A new version was created.'
                ));
            }


            // ===================================================================
            // START: Added Code to Update Booking Status
            // ===================================================================
            
            // After successfully saving the file, update the booking status.
            // The bookingRecord is already in memory from the controller's constructor.
            if (bookingRecord != null && bookingRecord.Id != null) {
                bookingRecord.Status__c = 'Allotment Letter Generated';
                update bookingRecord; // Perform DML update
            }
            
            // ===================================================================
            // END: Added Code
            // ===================================================================

            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.CONFIRM,
                'Allotment Letter Word document successfully generated and saved to Files!'
            ));

            // Redirect back to the Booking record page
            PageReference recordPage = new PageReference('/' + recordId);
            recordPage.setRedirect(true);
            return recordPage;

        } catch (DmlException e) {
            String errorMessage = e.getDmlMessage(0); // Get the specific DML error message
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Error saving Word document to Salesforce Files: ' + errorMessage
            ));
            // Log DML exceptions with detailed payload
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('AllotmentLetterController').withClassName('AllotmentLetterController').withMethodName('generateAndSaveWord').withRequestBody('Record ID: ' + (recordId != null ? String.valueOf(recordId) : 'N/A') + '; DML Error Message: ' + errorMessage + '; Line: ' + e.getLineNumber()).withDomain('DocumentGeneration').withException(e);
            ExceptionLogger.logException(payload);
            System.debug('DML Error saving Word document: ' + e.getMessage() + ' at line: ' + e.getLineNumber());
            return null;

        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Unexpected error during Word save: ' + e.getMessage() + ' at line ' + e.getLineNumber()
            ));
            // Log general exceptions with detailed payload
            ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('AllotmentLetterController').withClassName('AllotmentLetterController')
                .withMethodName('generateAndSaveWord').withRequestBody('Record ID: ' + (recordId != null ? String.valueOf(recordId) : 'N/A') + '; Error Message: ' + e.getMessage() + '; Line: ' + e.getLineNumber())
                .withDomain('DocumentGeneration').withException(e);
            ExceptionLogger.logException(payload);
            System.debug('Unexpected error: ' + e.getMessage() + ' at line: ' + e.getLineNumber());
            return null;
        }
    }
}