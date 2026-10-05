@IsTest
public class ResidentialTestDataFactory {
    public static Integer accountCounter = 1;
    public static Integer leadCounter = 1;
    public static Integer projectCounter = 1;
    public static Integer towerCounter = 1;
    public static Integer floorCounter = 1;
    public static Integer unitCounter = 1;
    
    public static Id RT_ID_OPPORTUNITY_RESIDENTIAL;
    public static Id RT_ID_LEAD_RESIDENTIAL;
    public static Id RT_ID_SITE_VISIT_RESIDENTIAL;
    public static Id RT_ID_ACCOUNT_CHANNEL_PARTNER_RESIDENTIAL;
    
    static {
        Map<String, Schema.RecordTypeInfo> recordTypeInfoByDevName = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName();
        RT_ID_OPPORTUNITY_RESIDENTIAL = recordTypeInfoByDevName.get('Residential_Sales_Opportunity').getRecordTypeId();

        recordTypeInfoByDevName = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName();
        RT_ID_LEAD_RESIDENTIAL = recordTypeInfoByDevName.get('Standard_Lead_Residential').getRecordTypeId();

        recordTypeInfoByDevName = Schema.SObjectType.Site_Visit__c.getRecordTypeInfosByDeveloperName();
        RT_ID_SITE_VISIT_RESIDENTIAL = recordTypeInfoByDevName.get('Residential_Sales_Site_Visit').getRecordTypeId();

        recordTypeInfoByDevName = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        RT_ID_ACCOUNT_CHANNEL_PARTNER_RESIDENTIAL = recordTypeInfoByDevName.get('Channel_Partner_Residential').getRecordTypeId();
    }
    
    // Accounts (Person Account)
    public static Account preparePersonAccount() {
        Id personRtId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('PersonAccount')
            .getRecordTypeId();
        String uniqueSuffix = String.valueOf(accountCounter++);
        return new Account(
            FirstName = 'Test',
            LastName = 'Person' + uniqueSuffix,
            SAP_External_Id__c = 'A' + uniqueSuffix.leftPad(4, '0'),
            RecordTypeId = personRtId
        );
    }

    public static Account createAccount() {
        Account acc = preparePersonAccount();
        insert acc;
        return acc;
    }
    
    public static Account prepareCPAccount() {
       	//String uniqueSuffix = String.valueOf(Crypto.getRandomInteger());
        String uniqueSuffix = String.valueOf(accountCounter++);
        return new Account(
            FirstName = 'Test',
            LastName = 'Person' + uniqueSuffix,
            SAP_External_Id__c = 'A' + uniqueSuffix.leftPad(4, '0'),
            RecordTypeId = RT_ID_ACCOUNT_CHANNEL_PARTNER_RESIDENTIAL
        );
    }
    
    // Leads
    public static Lead prepareLead() {
        String uniqueSuffix = String.valueOf(leadCounter++);
        return new Lead(
            FirstName = 'Test',
            LastName = 'Lead' + uniqueSuffix,
            Company = 'Test Company',
            Status = 'Open - Not Contacted',
            RecordTypeId = RT_ID_LEAD_RESIDENTIAL
        );
    }

    public static Lead createLead() {
        Lead l = prepareLead();
        insert l;
        return l;
    }
    
    public static Site_Visit__c createSiteVisit(Id leadId, Id projectId) {
        Site_Visit__c sv = new Site_Visit__c(
            Lead__c = leadId,
            Visit_DateTime__c = System.now(),
            Project__c = projectId,
            Status__c = 'Completed',
            RecordTypeId = RT_ID_SITE_VISIT_RESIDENTIAL
        );
        insert sv;
        return sv;
    }
    
    // Inventory: Project
    public static Property__c prepareProperty() {
        String uniqueSuffix = String.valueOf(projectCounter++);
        return new Property__c(
            Name = 'Test Project ' + uniqueSuffix,
            SAP_External_Id__c = 'P' + uniqueSuffix.leftPad(3, '0')
        );
    }

    public static Property__c createProject() {
        Property__c project = prepareProperty();
        insert project;
        return project;
    }
    
    // Inventory: Tower
    public static Tower__c prepareTower(Id projectId) {
        String uniqueSuffix = String.valueOf(towerCounter++);
        return new Tower__c(
            Name = 'Test Tower ' + uniqueSuffix,
            SAP_External_Id__c = 'T' + uniqueSuffix.leftPad(3, '0'),
            ZWBS_Structure__c = 'Z' + uniqueSuffix.leftPad(3, '0'),
            OC_Received__c = true,
            Property__c = projectId,
            Chargeable_Area_Type__c = 'Carpet Area'
        );
    }

    public static Tower__c createTower(Id projectId) {
        Tower__c tower = prepareTower(projectId);
        insert tower;
        return tower;
    }

    // Inventory: Floor
    public static Floor__c prepareFloor(Id projectId, Id towerId) {
        String uniqueSuffix = String.valueOf(floorCounter++);
        return new Floor__c(
            Name = 'Test Floor ' + uniqueSuffix,
            SAP_External_Id__c = 'F' + uniqueSuffix.leftPad(3, '0'),
            Property__c = projectId,
            Tower__c = towerId
        );
    }

    public static Floor__c createFloor(Id projectId, Id towerId) {
        Floor__c floor = prepareFloor(projectId, towerId);
        insert floor;
        return floor;
    }
    
    // Inventory: Unit
    public static Unit__c prepareUnit(Id projectId, Id towerId, Id floorId) {
        Id unitRtId = Schema.SObjectType.Unit__c.getRecordTypeInfosByDeveloperName()
                  .get('Residential_Unit').getRecordTypeId();
        String uniqueSuffix = String.valueOf(unitCounter++);
        return new Unit__c(
            Name = 'Test Unit ' + uniqueSuffix,
            Property__c = projectId,
            Tower__c = towerId,
            Floor__c = floorId,
            SAP_External_Id__c = 'U' + uniqueSuffix.leftPad(3, '0'),
            Status__c = 'Available',
            RecordTypeId = unitRtId,//new add by AP
            Carpet_Area__c = 1500
        );
    }

    public static Unit__c createUnit(Id projectId, Id towerId, Id floorId) {
        Unit__c unit = prepareUnit(projectId, towerId, floorId);
        insert unit;
        System.debug(unit);
        return unit;
    }

    // Backward-compatibility helper (creates a floor implicitly)
    public static Unit__c createUnit(Id projectId, Id towerId) {
        Floor__c floor = createFloor(projectId, towerId);
        return createUnit(projectId, towerId, floor.Id);
    }
    
    public static Payment_Plan__c createPaymentPlan() {
        return createPaymentPlan(true);
    }

    /*public static Payment_Plan__c createPaymentPlan(Boolean isActive) {
        Payment_Plan__c plan = new Payment_Plan__c(Name = 'Standard Plan', Active__c = isActive, Use_in_Quotation__c = true);
        insert plan;
        return plan;
    }*/
    
   public static Payment_Plan__c createPaymentPlan(Boolean isActive) {
    Payment_Plan__c plan = new Payment_Plan__c(
        Name = 'Standard Plan', 
        Active__c = isActive, 
        Use_In_Quotation__c = true,
        Approval_Status__c = 'Approved' // Add this to satisfy common Lookup Filters
    );
    insert plan;
    return plan;
}

    
    public static List<Payment_Schedule__c> createPaymentSchedules(Id paymentPlanId) {
        return createPaymentSchedules(paymentPlanId, true);
    }
    public static List<Payment_Schedule__c> createPaymentSchedules(Id paymentPlanId, Boolean commitRecords) {
        List<Payment_Schedule__c> schedules = new List<Payment_Schedule__c>{
            new Payment_Schedule__c(
                Name = 'Milestone 1',
                Payment_Percentage__c = 10,
                Billing_Rule__c = 'Milestone billing on a percentage basis',
                Milestone_Code__c = 'Initial Token Advance',
                Payment_Plan_Id__c = paymentPlanId,
                Month_Number__c = 0
            ),
            new Payment_Schedule__c(
                Name = 'Milestone 2',
                Payment_Percentage__c = 90,
                Billing_Rule__c = 'Milestone billing on a percentage basis',
                Milestone_Code__c = 'On Installment 1',
                Payment_Plan_Id__c = paymentPlanId,
                Month_Number__c = 1
            )
        };
        if(commitRecords)
            insert schedules;
        return schedules;
    }
    
    public static Opportunity createOpportunity(Id accountId, Id unitId) {
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            CloseDate = Date.today(),
            StageName = 'Unit Shortlisting',
            AccountId = accountId,
            Interested_Unit__c = unitId,
            Discount_Approval_Status__c = 'Approved',
            Chargeable_Area__c = 1500,
            OwnerId = UserInfo.getUserId(),
            RecordTypeId = RT_ID_OPPORTUNITY_RESIDENTIAL
        );
        insert opp;
        return opp;
    }
     public static Quote createQuote(Id oppId,Id accId){
        quote q = new quote();
        q.Name = 'q1';
        q.Quote_Base_Price__c = 12000;
        q.BESCOM_BWSSB_Charges__c = 200;
        q.Maintenance_Deposit_Corpus_Fund__c = 50;
        q.Club_Membership_Fees__c = 7500000;
        q.Legal_Fees__c = 50000;
        q.OpportunityId = oppId;
        insert q;
        return q;
    }
    
    public static Booking__c createBooking(Id accId, Id unitId, Id planId, Id oppId, Id projectId) {
        Booking__c booking = new Booking__c(
            Account_Id__c = accId,
            Payment_Plan_Id__c = planId,
            Sales_Organization__c = 'Palladium Constructions Private Limited',
            Distribution_Channel__c = 'Direct Sale',
            Division__c = 'Residential Sales',
            Document_Type__c = 'Residential Sales',
            SFDC_booking_reference_date__c = Date.today(),
            Unit_Id__c = unitId,
            Opportunity_Id__c = oppId,
            project__c = projectId
        );
        insert booking;
        return booking;
    }

    // Booking prepare-only
    public static Booking__c prepareBooking(Id accId, Id unitId, Id planId, Id oppId, Id projectId) {
        return new Booking__c(
            Account_Id__c = accId,
            Payment_Plan_Id__c = planId,
            Sales_Organization__c = 'Palladium Constructions Private Limited',
            Distribution_Channel__c = 'Direct Sale',
            Division__c = 'Residential Sales',
            Document_Type__c = 'Residential Sales',
            SFDC_booking_reference_date__c = Date.today(),
            Unit_Id__c = unitId,
            Opportunity_Id__c = oppId,
            Project__c = projectId
        );
    }
    
    Public static list<Agent_Brokerage__c> createAgentBrokerage(Id bookingId){
        list<Agent_Brokerage__c> abList = new list<Agent_Brokerage__c>{
            new Agent_Brokerage__c(
                Bokerage_Amount__c = 120000,
                Booking__c = bookingId,
                Bokerage_Type__c = 'Fixed'
            )
        };
        return abList;
    }
   
    public static List<Booking_Payment_Schedule__c> createBookingPaymentSchedules(Id bookingId, List<Payment_Schedule__c> schedules ){
        return createBookingPaymentSchedules(bookingId, null, schedules);
    }

    public static List<Booking_Payment_Schedule__c> createBookingPaymentSchedules(Id bookingId,
                                                                                  Id opportunityId,
                                                                                  List<Payment_Schedule__c> schedules ){
        if (bookingId == null || schedules == null || schedules.isEmpty()) {
            return new List<Booking_Payment_Schedule__c>();
        }

        Id resolvedOppId = opportunityId;
        if (resolvedOppId == null) {
            try {
                Booking__c booking = [
                    SELECT Opportunity_Id__c
                    FROM Booking__c
                    WHERE Id = :bookingId
                    LIMIT 1
                ];
                resolvedOppId = booking.Opportunity_Id__c;
            } catch (Exception ex) {
                // leave null if lookup fails
            }
        }

        Date baseDate = Date.today().addDays(30);
        List<Booking_Payment_Schedule__c> bpsList = new List<Booking_Payment_Schedule__c>();
        Integer installmentNumber = 1;

        for (Payment_Schedule__c sched : schedules) {
            if (sched == null) {
                continue;
            }
            Booking_Payment_Schedule__c bps = new Booking_Payment_Schedule__c(
                Booking__c = bookingId,
                Opportunity__c = resolvedOppId,
                Installment_Number__c = installmentNumber,
                Payment_Due_Date__c = baseDate.addDays(30 * (installmentNumber - 1)),
                Installment_Amount__c = installmentNumber == 1 ? 1000000 : 9000000,
                Payment_Schedule_Id__c = sched.Id,
                Adjusted_Amount__c = null,
                Bill_Block__c = installmentNumber == 1 ? 'Compl Confirm Missng' : 'Check Day Rate'
            );
            bpsList.add(bps);
            installmentNumber++;
        }

        insert bpsList;
        return bpsList;
    }
    
    public static List<Booking_Condition__c> createBookingCondition(Id bookingId, Id oppId) {
    List<Booking_Condition__c> bcList = new List<Booking_Condition__c>{
        new Booking_Condition__c(
            Booking__c = bookingId,
            Opportunity__c = oppId,
            Condition_Type__c = 'Base Price',
            Amount__c = 10000,
            UOM__c = 'FT2'
        ),
        new Booking_Condition__c(
            Booking__c = bookingId,
            Opportunity__c = oppId,
            Condition_Type__c = 'Base Price Discount',
            Amount_By_Type__c = 100,
            Type__c = 'Fixed Amount',
            UOM__c = 'FT2'
        ),
        new Booking_Condition__c(
            Booking__c = bookingId,
            Opportunity__c = oppId,
            Condition_Type__c = 'BESCOM & BWSSB',
            Amount__c = 200,
            Type__c = 'Rate',
            UOM__c = 'FT2'
        ),
        new Booking_Condition__c(
            Booking__c = bookingId,
            Opportunity__c = oppId,
            Condition_Type__c = 'Corpus Fund Depositi',
            Amount__c = 50,
            Type__c = 'Rate',
            UOM__c = 'FT2'
        ),
        new Booking_Condition__c(
            Booking__c = bookingId,
            Opportunity__c = oppId,
            Condition_Type__c = 'Club House Membershi',
            Amount_By_Type__c = 50000,
            Type__c = 'Fixed Amount',
            UOM__c = 'FT2'
        )
    };
    
    insert bcList;
    return bcList;
}

    public static Booking_Condition__c prepareBookingCondition(
        Id bookingId,
        Id opportunityId,
        String conditionType,
        Decimal amount,
        Decimal quantity,
        Decimal percentage,
        String typeValue
    ) {
        return new Booking_Condition__c(
            Booking__c = bookingId,
            Opportunity__c = opportunityId,
            Condition_Type__c = conditionType,
            Amount__c = amount,
            Quantity__c = quantity,
            Percentage__c = percentage,
            Type__c = typeValue
        );
    }

    public static Booking_Condition__c createBookingCondition(
        Id bookingId,
        Id opportunityId,
        String conditionType,
        Decimal amount,
        Decimal quantity,
        Decimal percentage,
        String typeValue
    ) {
        Booking_Condition__c record = prepareBookingCondition(
            bookingId,
            opportunityId,
            conditionType,
            amount,
            quantity,
            percentage,
            typeValue
        );
        insert record;
        return record;
    }

    // Booking condition prepare-only (default set)
    public static List<Booking_Condition__c> prepareBookingConditions(Id bookingId, Id oppId) {
        return new List<Booking_Condition__c>{
            new Booking_Condition__c(
                Booking__c = bookingId,
                Opportunity__c = oppId,
                Condition_Type__c = 'Base Price',
                Amount__c = 10000,
                UOM__c = 'FT2'
            ),
            new Booking_Condition__c(
                Booking__c = bookingId,
                Opportunity__c = oppId,
                Condition_Type__c = 'Club House Membershi',
                Amount_By_Type__c = 50000,
                Type__c = 'Fixed Amount',
                UOM__c = 'FT2'
            )
        };
    }

    // Opportunity Parking helpers
    public static Opportunity_Parking__c prepareOpportunityParking(Id opportunityId, Integer count) {
        return new Opportunity_Parking__c(
            Opportunity__c = opportunityId,
            Parking_Count__c = (count == null ? 1 : count)
        );
    }

    public static Opportunity_Parking__c createOpportunityParking(Id opportunityId, Integer count) {
        Opportunity_Parking__c op = prepareOpportunityParking(opportunityId, count);
        insert op;
        return op;
    }

    // Prepare (not insert) booking payment schedules for bulk insertion
    public static List<Booking_Payment_Schedule__c> prepareBookingPaymentSchedules(Id bookingId, List<Payment_Schedule__c> schedules) {
        List<Booking_Payment_Schedule__c> bpsList = new List<Booking_Payment_Schedule__c>();
        if (schedules == null || schedules.isEmpty()) return bpsList;
        Integer inst = 0;
        for (Payment_Schedule__c ps : schedules) {
            bpsList.add(new Booking_Payment_Schedule__c(
                Booking__c = bookingId,
                Installment_Number__c = inst,
                Payment_Due_Date__c = Date.today().addDays(30 * inst),
                Installment_Amount__c = inst == 1 ? 1000000 : 9000000,
                Payment_Schedule_Id__c = ps.Id,
                Adjusted_Amount__c = null,
                Bill_Block__c = inst == 1 ? 'Compl Confirm Missng' : 'Check Day Rate'
            ));
            inst++;
        }
        return bpsList;
    }

    // Demand helper (prepare)
    public static Demand__c prepareDemand(Id bpsId, Id unitId, Id accountId, String sapExternalId) {
        return new Demand__c(
            Booking_Payment_Schedule_Id__c = bpsId,
            Unit__c = unitId,
            Account__c = accountId,
            SAP_External_Id__c = sapExternalId
        );
    }

    public static Demand__c prepareDemand(Id bpsId, Id unitId, Id accountId, Id bookingId, String sapExternalId) {
        Demand__c demand = prepareDemand(bpsId, unitId, accountId, sapExternalId);
        demand.Booking_Id__c = bookingId;
        return demand;
    }

    // Company Bank Account helpers
    public static Company_Bank_Account__c prepareCompanyBankAccount() {
        return new Company_Bank_Account__c(
            Name = 'ACC001',
            House_Bank_Id__c = 'HB001',
            Bank_Name__c = 'Standard Chartered Bank',
            Company_Name__c = '2050',
            IFSC_Code__c = 'INFD000000A'
        );
    }

    public static Company_Bank_Account__c prepareCompanyBankAccount(String name, String houseBankId, String bankName, String companyCode, String ifsc) {
        Company_Bank_Account__c c = prepareCompanyBankAccount();
        if (name != null) c.Name = name;
        if (houseBankId != null) c.House_Bank_Id__c = houseBankId;
        if (bankName != null) c.Bank_Name__c = bankName;
        if (companyCode != null) c.Company_Name__c = companyCode;
        if (ifsc != null) c.IFSC_Code__c = ifsc;
        return c;
    }

    public static Company_Bank_Account__c createCompanyBankAccount() {
        Company_Bank_Account__c acc = prepareCompanyBankAccount();
        insert acc;
        return acc;
    }

    // Payment Receipt helpers (prepare)
    public static Payment_Receipt__c preparePaymentReceipt(Id bpsId, Id demandId, Id companyBankAccId) {
        return preparePaymentReceipt(bpsId, demandId, companyBankAccId, 5000, 'RTGS', Date.today(), null, 'Standard Chartered Bank');
    }

    public static Payment_Receipt__c preparePaymentReceipt(Id bpsId, Id demandId, Id companyBankAccId, Decimal amount, String modeOfPayment, Date paymentDate, Integer chequeNumber, String customerBankName) {
        Payment_Receipt__c r = new Payment_Receipt__c(
            Booking_Payment_Schedule__c = bpsId,
            Amount_Paid__c = amount,
            Mode_Of_Payment__c = modeOfPayment,
            Date_Of_Payment__c = paymentDate,
            Demand__c = demandId,
            Company_Bank_Account__c = companyBankAccId,
            Customer_Bank_Name__c = customerBankName,
            Principal_Applied__c = amount
        );
        if (chequeNumber != null) r.ChequeNumber__c = string.valueOf(chequeNumber);
        return r;
    }

    public static List<Payment_Receipt__c> createPaymentReceipts(List<Payment_Receipt__c> receipts) {
        if (receipts == null || receipts.isEmpty()) return new List<Payment_Receipt__c>();
        insert receipts;
        return receipts;
    }

    public static Payment_Receipt__c createPaymentReceipt(Payment_Receipt__c receipt) {
        insert receipt;
        return receipt;
    }

    // Token schedule helpers
    public static Booking_Payment_Schedule__c prepareTokenSchedule(Id bookingId) {
        return new Booking_Payment_Schedule__c(
            Booking__c = bookingId,
            Is_Token_Amount__c = TRUE,
            Adjusted_Amount__c = 5000,
            Installment_Amount__c = 0
        );
    }

    public static Booking_Payment_Schedule__c createTokenSchedule(Id bookingId) {
        Booking_Payment_Schedule__c bps = prepareTokenSchedule(bookingId);
        insert bps;
        return bps;
    }

    // Ledger helpers for tests
    public static List<Ledger_Entry__c> createLedgerAccrual(Id bookingId,
                                                            Id scheduleId,
                                                            Date periodStart,
                                                            Date periodEnd,
                                                            Decimal interestAmount,
                                                            Decimal taxAmount) {
        if (bookingId == null || scheduleId == null) {
            return new List<Ledger_Entry__c>();
        }
        Date startDate = periodStart == null ? periodEnd : periodStart;
        Date endDate = periodEnd == null ? periodStart : periodEnd;
        if (startDate == null) {
            Date today = Date.today();
            startDate = today;
            endDate = today;
        }
        List<Ledger_Entry__c> entries = new List<Ledger_Entry__c>();
        if (interestAmount != null && interestAmount != 0) {
            Ledger_Entry__c interestEntry = new Ledger_Entry__c(
                Booking__c = bookingId,
                Schedule__c = scheduleId,
                Entry_Date__c = endDate,
                Period_Start__c = startDate,
                Period_End__c = endDate,
                Type__c = LedgerConst.TYPE_INTEREST_ACCRUAL_BASIC,
                Bucket__c = LedgerConst.BUCKET_BASIC,
                Source__c = LedgerConst.SOURCE_ACCRUAL,
                Status__c = LedgerConst.STATUS_POSTED,
                Interest_Amount__c = interestAmount
            );
            entries.add(interestEntry);
        }
        if (taxAmount != null && taxAmount != 0) {
            Ledger_Entry__c taxEntry = new Ledger_Entry__c(
                Booking__c = bookingId,
                Schedule__c = scheduleId,
                Entry_Date__c = endDate,
                Period_Start__c = startDate,
                Period_End__c = endDate,
                Type__c = LedgerConst.TYPE_INTEREST_TAX_ACCRUAL_BASIC,
                Bucket__c = LedgerConst.BUCKET_BASIC,
                Source__c = LedgerConst.SOURCE_ACCRUAL,
                Status__c = LedgerConst.STATUS_POSTED,
                Tax_Amount__c = taxAmount
            );
            entries.add(taxEntry);
        }
        if (!entries.isEmpty()) {
            insert entries;
        }
        return entries;
    }

}