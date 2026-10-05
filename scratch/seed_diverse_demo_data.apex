System.debug('=== SEEDING DIVERSE DEMO DATA & ELIMINATING NONSENSICAL DUPLICATES ===');

Savepoint sp = Database.setSavepoint();

try {
    Id currentUserId = UserInfo.getUserId();
    
    // -------------------------------------------------------------------------
    // 0. FIX EXISTING DUPLICATES: Clean up HO-0002 on BO-00000014 to be Stage 1 Readiness
    // -------------------------------------------------------------------------
    List<Handover__c> hoList0002 = [SELECT Id, Name, Stage__c, Status__c, Booking__c FROM Handover__c WHERE Name = 'HO-0002' LIMIT 1];
    if (!hoList0002.isEmpty()) {
        Handover__c ho2 = hoList0002[0];
        ho2.Stage__c = 'Readiness';
        ho2.Status__c = 'Possession Ready';
        ho2.Unit_Readiness__c = '100% Complete';
        ho2.Project_Readiness__c = 'Ready for Possession';
        ho2.Possession_Readiness__c = 'All Clearances Obtained';
        ho2.Finance_Status__c = 'Cleared';
        ho2.OC_Clearance__c = 'Obtained';
        ho2.Registration_Status__c = 'Completed';
        ho2.Target_Handover_Date__c = Date.today().addDays(30);
        ho2.Handover_Owner__c = currentUserId;
        update ho2;
        System.debug('Reset HO-0002 on BO-00000014 as Stage 1 Readiness showcase record: ' + ho2.Id);
    }

    // -------------------------------------------------------------------------
    // 1. SEED BROKER FIRMS / CHANNEL PARTNERS (Accounts & Contacts)
    // -------------------------------------------------------------------------
    Id partnerRtId = null;
    for (RecordType rt : [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'SDO_Account_Partner' LIMIT 1]) {
        partnerRtId = rt.Id;
    }
    if (partnerRtId == null) {
        for (RecordType rt : [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND IsPersonType = false LIMIT 1]) {
            partnerRtId = rt.Id;
        }
    }

    // A) Square Yards Realty LLP
    Account broker1 = null;
    List<Account> existingB1 = [SELECT Id FROM Account WHERE Name = 'Square Yards Realty LLP' LIMIT 1];
    if (existingB1.isEmpty()) {
        broker1 = new Account(
            Name = 'Square Yards Realty LLP',
            RecordTypeId = partnerRtId,
            Phone = '+91 80 4920 1100',
            Website = 'https://www.squareyards.com',
            CP_Approval_Status__c = 'Approved',
            RERA_Number__c = 'PRM/KA/RERA/1251/310/AG/170824/000122',
            GST_No__c = '29AABCS1429B1Z4',
            PAN_Number__c = 'AABCS1429B',
            Distribution_Channel__c = 'Channel Partner',
            BillingCity = 'Bengaluru',
            BillingState = 'Karnataka'
        );
        insert broker1;
        insert new Contact(
            FirstName = 'Sanjay',
            LastName = 'Singhania',
            AccountId = broker1.Id,
            Title = 'Managing Partner',
            Phone = '+91 80 4920 1100',
            MobilePhone = '+91 98450 12345',
            Email = 'sanjay.singhania@squareyards.demo'
        );
        System.debug('Created Broker Account: Square Yards Realty LLP (' + broker1.Id + ')');
    } else {
        broker1 = existingB1[0];
    }

    // B) Anarock Property Consultants Pvt Ltd
    Account broker2 = null;
    List<Account> existingB2 = [SELECT Id FROM Account WHERE Name = 'Anarock Property Consultants Pvt Ltd' LIMIT 1];
    if (existingB2.isEmpty()) {
        broker2 = new Account(
            Name = 'Anarock Property Consultants Pvt Ltd',
            RecordTypeId = partnerRtId,
            Phone = '+91 80 6735 4400',
            Website = 'https://www.anarock.com',
            CP_Approval_Status__c = 'Approved',
            RERA_Number__c = 'PRM/KA/RERA/1251/310/AG/180215/000344',
            GST_No__c = '29AAACA2310C1Z8',
            PAN_Number__c = 'AAACA2310C',
            Distribution_Channel__c = 'Channel Partner',
            BillingCity = 'Bengaluru',
            BillingState = 'Karnataka'
        );
        insert broker2;
        insert new Contact(
            FirstName = 'Pooja',
            LastName = 'Sharma',
            AccountId = broker2.Id,
            Title = 'Regional Director - Residential',
            Phone = '+91 80 6735 4400',
            MobilePhone = '+91 99001 23456',
            Email = 'pooja.sharma@anarock.demo'
        );
        System.debug('Created Broker Account: Anarock Property Consultants (' + broker2.Id + ')');
    } else {
        broker2 = existingB2[0];
    }

    // C) PropTiger Advisory Services
    Account broker3 = null;
    List<Account> existingB3 = [SELECT Id FROM Account WHERE Name = 'PropTiger Advisory Services' LIMIT 1];
    if (existingB3.isEmpty()) {
        broker3 = new Account(
            Name = 'PropTiger Advisory Services',
            RecordTypeId = partnerRtId,
            Phone = '+91 80 3051 8800',
            Website = 'https://www.proptiger.com',
            CP_Approval_Status__c = 'Pending Verification',
            RERA_Number__c = 'PRM/KA/RERA/1251/310/AG/210519/000789',
            GST_No__c = '29AABCP9912D1Z2',
            PAN_Number__c = 'AABCP9912D',
            Distribution_Channel__c = 'Channel Partner',
            BillingCity = 'Bengaluru',
            BillingState = 'Karnataka'
        );
        insert broker3;
        insert new Contact(
            FirstName = 'Vikramaditya',
            LastName = 'Rao',
            AccountId = broker3.Id,
            Title = 'Senior Vice President',
            Phone = '+91 80 3051 8800',
            MobilePhone = '+91 97402 34567',
            Email = 'vikram.rao@proptiger.demo'
        );
        System.debug('Created Broker Account: PropTiger Advisory Services (' + broker3.Id + ')');
    } else {
        broker3 = existingB3[0];
    }

    // -------------------------------------------------------------------------
    // 2. SEED 8 NON-CONVERTED LEADS (Distinct Names, Non-Repeating Sources & Automations)
    // -------------------------------------------------------------------------
    Id leadResidentialRtId = null;
    for (RecordType rt : [SELECT Id FROM RecordType WHERE SobjectType = 'Lead' AND DeveloperName = 'Standard_Lead_Residential' LIMIT 1]) {
        leadResidentialRtId = rt.Id;
    }

    Map<String, Lead> leadsToCreate = new Map<String, Lead>{
        'vikram.malhotra@demo.com' => new Lead(
            FirstName = 'Vikram',
            LastName = 'Malhotra',
            Email = 'vikram.malhotra@demo.com',
            MobilePhone = '+91 98860 11001',
            Phone = '+91 98860 11001',
            LeadSource = 'Website',
            Status = 'New',
            Projects__c = 'Nikoo Homes',
            Type_of_Units__c = '3 BHK',
            Budget__c = '1 Cr to 1.5 Cr',
            Preferred_City__c = 'Bengaluru',
            City = 'Bengaluru',
            Company = 'Self-Employed (Consultant)',
            RecordTypeId = leadResidentialRtId,
            Description = 'Inquired via digital landing page about Phase 4 3BHK high-rise corner unit. Ready for round-robin assignment.'
        ),
        'sneha.kulkarni@demo.com' => new Lead(
            FirstName = 'Sneha',
            LastName = 'Kulkarni',
            Email = 'sneha.kulkarni@demo.com',
            MobilePhone = '+91 98860 11002',
            Phone = '+91 98860 11002',
            LeadSource = 'Google',
            Status = 'Working',
            Projects__c = 'Varthur Vista',
            Type_of_Units__c = '2 BHK',
            Budget__c = '75 Lakhs to 1 Cr',
            Preferred_City__c = 'Bengaluru',
            City = 'Bengaluru',
            Company = 'Amazon India',
            RecordTypeId = leadResidentialRtId,
            Description = 'Google search campaign click. Prefers east-facing 2BHK with balcony. Follow-up call logged.'
        ),
        'kavita.krishnan@demo.com' => new Lead(
            FirstName = 'Kavita',
            LastName = 'Krishnan',
            Email = 'kavita.krishnan@demo.com',
            MobilePhone = '+91 98860 11003',
            Phone = '+91 98860 11003',
            LeadSource = 'Partner',
            Status = 'Site Visit',
            Projects__c = 'Nikoo Homes',
            Type_of_Units__c = '2 BHK',
            Budget__c = '1 Cr to 1.5 Cr',
            Preferred_City__c = 'Bengaluru',
            City = 'Bengaluru',
            Company = 'Infosys Technologies',
            RecordTypeId = leadResidentialRtId,
            Description = 'Referred by Square Yards Realty. Confirmed site visit scheduled for this Saturday 11:00 AM.'
        ),
        'ramesh.gupta@demo.com' => new Lead(
            FirstName = 'Ramesh Chandra',
            LastName = 'Gupta',
            Email = 'ramesh.gupta@demo.com',
            MobilePhone = '+91 98860 11004',
            Phone = '+91 98860 11004',
            LeadSource = 'Manual',
            Status = 'Qualified',
            Projects__c = 'Saket Square',
            Type_of_Units__c = '4 BHK',
            Budget__c = '2 Cr and Above',
            Preferred_City__c = 'Bengaluru',
            City = 'Bengaluru',
            Company = 'Gupta Steel Traders',
            RecordTypeId = leadResidentialRtId,
            Description = 'Walk-in buyer to Experience Center. Completed verified site visit with 5-star rating. Budget ₹2.8 Cr.'
        ),
        'ananya.deshmukh@demo.com' => new Lead(
            FirstName = 'Ananya',
            LastName = 'Deshmukh',
            Email = 'ananya.deshmukh@demo.com',
            MobilePhone = '+91 98860 11005',
            Phone = '+91 98860 11005',
            LeadSource = 'Social Media',
            Status = 'Contacted',
            Projects__c = 'Banjara Beam',
            Type_of_Units__c = '4 BHK',
            Budget__c = '1.5 Cr to 2 Cr',
            Preferred_City__c = 'Hyderabad',
            City = 'Hyderabad',
            Company = 'Deloitte USI',
            RecordTypeId = leadResidentialRtId,
            Description = 'Instagram carousel ad inquiry. Requested floor plan and pricing sheet for Tower B top-floor units.'
        ),
        'devendra.patil@demo.com' => new Lead(
            FirstName = 'Devendra',
            LastName = 'Patil',
            Email = 'devendra.patil@demo.com',
            MobilePhone = '+91 98860 11006',
            Phone = '+91 98860 11006',
            LeadSource = 'Marketing Event',
            Status = 'Qualified',
            Projects__c = 'Miyapur Manor',
            Type_of_Units__c = '4.5 BHK',
            Budget__c = '1.5 Cr to 2 Cr',
            Preferred_City__c = 'Hyderabad',
            City = 'Hyderabad',
            Company = 'Microsoft IDC',
            RecordTypeId = leadResidentialRtId,
            Description = 'Met at Manyata Tech Park Corporate Showcase. High intent buyer, corporate tie-up discount applicable.'
        ),
        'rajeev.nambiar@demo.com' => new Lead(
            FirstName = 'Rajeev',
            LastName = 'Nambiar',
            Email = 'rajeev.nambiar@demo.com',
            MobilePhone = '+91 98860 11007',
            Phone = '+91 98860 11007',
            LeadSource = 'Cold Call',
            Status = 'Dropped',
            Projects__c = 'Nikoo Homes',
            Type_of_Units__c = '1 BHK',
            Budget__c = 'Below 50 Lakhs',
            Preferred_City__c = 'Bengaluru',
            City = 'Bengaluru',
            Company = 'Independent Professional',
            Drop_Reason__c = 'Budget Mismatch',
            Archive_For_In_Days__c = 30,
            Archive_Status__c = 'Archived',
            Archive_Populated_Date__c = Date.today(),
            RecordTypeId = leadResidentialRtId,
            Description = 'Unqualified due to budget mismatch (looking for under ₹45L). Placed in 30-day cooling off archival period.'
        ),
        'harish.iyer@demo.com' => new Lead(
            FirstName = 'Harish',
            LastName = 'Iyer',
            Email = 'harish.iyer@demo.com',
            MobilePhone = '+91 98860 11008',
            Phone = '+91 98860 11008',
            LeadSource = 'Referral',
            Status = 'Working',
            Projects__c = 'Yalahanka Yard',
            Type_of_Units__c = '3 BHK',
            Budget__c = '1.5 Cr to 2 Cr',
            Preferred_City__c = 'Bengaluru',
            City = 'Bengaluru',
            Company = 'Goldman Sachs',
            RecordTypeId = leadResidentialRtId,
            Description = 'Warm referral from existing Nikoo Homes Phase 2 resident. Looking for rapid closure.'
        )
    };

    // Filter out any existing leads by email to prevent duplicates
    Set<String> leadEmails = leadsToCreate.keySet();
    Map<String, Lead> existingLeadMap = new Map<String, Lead>();
    for (Lead el : [SELECT Id, Email FROM Lead WHERE Email IN :leadEmails]) {
        existingLeadMap.put(el.Email, el);
    }
    List<Lead> leadsToInsert = new List<Lead>();
    for (String em : leadsToCreate.keySet()) {
        if (!existingLeadMap.containsKey(em)) {
            leadsToInsert.add(leadsToCreate.get(em));
        }
    }
    if (!leadsToInsert.isEmpty()) {
        insert leadsToInsert;
        System.debug('Inserted ' + leadsToInsert.size() + ' distinct, non-converted Leads with non-repeating sources.');
    }

    // -------------------------------------------------------------------------
    // 3. SEED 4 CUSTOMER PERSON ACCOUNTS (Completely distinct from Leads)
    // -------------------------------------------------------------------------
    Id personAccountRtId = null;
    for (RecordType rt : [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Customer_Individual' AND IsPersonType = true LIMIT 1]) {
        personAccountRtId = rt.Id;
    }
    if (personAccountRtId == null) {
        for (RecordType rt : [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND IsPersonType = true LIMIT 1]) {
            personAccountRtId = rt.Id;
        }
    }

    Map<String, Account> customersToCreate = new Map<String, Account>{
        'aditya.singhal@buyer.demo' => new Account(
            FirstName = 'Aditya',
            LastName = 'Singhal',
            PersonEmail = 'aditya.singhal@buyer.demo',
            PersonMobilePhone = '+91 98860 22001',
            Phone = '+91 98860 22001',
            PAN_Number__c = 'BPKPS1234A',
            Aadhar_Number__c = '782345619012',
            RecordTypeId = personAccountRtId,
            BillingStreet = '104, 12th Main, HAL 2nd Stage, Indiranagar',
            BillingCity = 'Bengaluru',
            BillingState = 'Karnataka',
            BillingPostalCode = '560038'
        ),
        'meera.namboodiri@buyer.demo' => new Account(
            FirstName = 'Meera',
            LastName = 'Namboodiri',
            PersonEmail = 'meera.namboodiri@buyer.demo',
            PersonMobilePhone = '+91 98860 22002',
            Phone = '+91 98860 22002',
            PAN_Number__c = 'AYEPN5678B',
            Aadhar_Number__c = '912367892345',
            RecordTypeId = personAccountRtId,
            BillingStreet = 'Villa 42, Prestige Palms, Whitefield Main Road',
            BillingCity = 'Bengaluru',
            BillingState = 'Karnataka',
            BillingPostalCode = '560066'
        ),
        'kunal.oberoi@buyer.demo' => new Account(
            FirstName = 'Kunal',
            LastName = 'Oberoi',
            PersonEmail = 'kunal.oberoi@buyer.demo',
            PersonMobilePhone = '+91 98860 22003',
            Phone = '+91 98860 22003',
            PAN_Number__c = 'CZXPO9012C',
            Aadhar_Number__c = '634589123456',
            RecordTypeId = personAccountRtId,
            BillingStreet = 'Flat 502, Raheja Residency, 3rd Block, Koramangala',
            BillingCity = 'Bengaluru',
            BillingState = 'Karnataka',
            BillingPostalCode = '560034'
        ),
        'shalini.reddy@buyer.demo' => new Account(
            FirstName = 'Dr. Shalini',
            LastName = 'Reddy',
            PersonEmail = 'shalini.reddy@buyer.demo',
            PersonMobilePhone = '+91 98860 22004',
            Phone = '+91 98860 22004',
            PAN_Number__c = 'DGKPR3456D',
            Aadhar_Number__c = '845612344567',
            RecordTypeId = personAccountRtId,
            BillingStreet = 'Plot 18, 4th Cross, 7th Block, Jayanagar',
            BillingCity = 'Bengaluru',
            BillingState = 'Karnataka',
            BillingPostalCode = '560082'
        )
    };

    Set<String> custEmails = customersToCreate.keySet();
    Map<String, Account> existingCustMap = new Map<String, Account>();
    for (Account ea : [SELECT Id, PersonEmail, Name FROM Account WHERE PersonEmail IN :custEmails]) {
        existingCustMap.put(ea.PersonEmail, ea);
    }
    List<Account> custToInsert = new List<Account>();
    for (String em : customersToCreate.keySet()) {
        if (!existingCustMap.containsKey(em)) {
            custToInsert.add(customersToCreate.get(em));
        }
    }
    if (!custToInsert.isEmpty()) {
        insert custToInsert;
        for (Account a : custToInsert) {
            existingCustMap.put(a.PersonEmail, a);
        }
        System.debug('Inserted ' + custToInsert.size() + ' distinct Customer Person Accounts.');
    }

    Account custAditya = existingCustMap.get('aditya.singhal@buyer.demo');
    Account custMeera  = existingCustMap.get('meera.namboodiri@buyer.demo');
    Account custKunal  = existingCustMap.get('kunal.oberoi@buyer.demo');
    Account custShalini= existingCustMap.get('shalini.reddy@buyer.demo');

    // -------------------------------------------------------------------------
    // 4. FIND AVAILABLE UNITS FOR 4 NEW BOOKINGS (Strictly no duplicate units!)
    // -------------------------------------------------------------------------
    Set<Id> currentlyBookedUnits = new Set<Id>();
    for (Booking__c b : [SELECT Unit_Id__c FROM Booking__c WHERE Unit_Id__c != null]) {
        currentlyBookedUnits.add(b.Unit_Id__c);
    }

    // A) Nikoo Homes unit: RR-NEW500
    Unit__c unitNikoo = [SELECT Id, Name, Tower__c, Property__c, Saleable_Area__c FROM Unit__c WHERE Name = 'RR-NEW500' LIMIT 1];
    // B) Varthur Vista unit: VV-T1U205
    Unit__c unitVarthur = [SELECT Id, Name, Tower__c, Property__c, Saleable_Area__c FROM Unit__c WHERE Name = 'VV-T1U205' LIMIT 1];
    // C) Saket Square unit: SS-SK2-700
    Unit__c unitSaket = [SELECT Id, Name, Tower__c, Property__c, Saleable_Area__c FROM Unit__c WHERE Name = 'SS-SK2-700' LIMIT 1];
    // D) Banjara Beam unit: BB-TB200
    Unit__c unitBanjara = [SELECT Id, Name, Tower__c, Property__c, Saleable_Area__c FROM Unit__c WHERE Name = 'BB-TB200' LIMIT 1];

    // Find payment plans if available
    Id ppNikoo = null;
    for (Payment_Plan__c pp : [SELECT Id FROM Payment_Plan__c WHERE Property__c = :unitNikoo.Property__c LIMIT 1]) {
        ppNikoo = pp.Id;
    }
    if (ppNikoo == null) {
        for (Payment_Plan__c pp : [SELECT Id FROM Payment_Plan__c LIMIT 1]) {
            ppNikoo = pp.Id;
        }
    }

    // -------------------------------------------------------------------------
    // 5. CREATE 4 DISTINCT BOOKINGS WITH STRICT 1:1 HANDOVERS ACROSS ALL STAGES
    // -------------------------------------------------------------------------

    // BOOKING A -> STAGE 2: INSPECTION
    Booking__c bookA = null;
    List<Booking__c> exBookA = [SELECT Id, Name, (SELECT Id FROM Handovers__r) FROM Booking__c WHERE Unit_Id__c = :unitNikoo.Id LIMIT 1];
    if (exBookA.isEmpty()) {
        bookA = new Booking__c(
            Account_Id__c = custAditya.Id,
            Customer__c = custAditya.Id,
            Unit_Id__c = unitNikoo.Id,
            Tower__c = unitNikoo.Tower__c,
            Project__c = unitNikoo.Property__c,
            Status__c = 'Confirmed',
            Approval_Status__c = 'Booking Approved',
            Booking_Date__c = Date.today().addDays(-45),
            Token_Amount__c = 300000,
            Final_Amount__c = 14500000,
            Is_Payment_Plan_Linked__c = true,
            Payment_Plan_Id__c = ppNikoo
        );
        insert bookA;
        System.debug('Created Booking A for Aditya Singhal: ' + bookA.Id);
    } else {
        bookA = exBookA[0];
    }

    // Handover for Booking A -> STAGE 2: INSPECTION
    List<Handover__c> hoA_List = [SELECT Id, Stage__c, Status__c FROM Handover__c WHERE Booking__c = :bookA.Id LIMIT 1];
    Handover__c hoA = null;
    if (hoA_List.isEmpty()) {
        hoA = new Handover__c(
            Booking__c = bookA.Id,
            Unit__c = unitNikoo.Id,
            Customer__c = custAditya.Id,
            Stage__c = 'Inspection',
            Status__c = 'Inspection In Progress',
            Target_Handover_Date__c = Date.today().addDays(20),
            Handover_Owner__c = currentUserId,
            Unit_Readiness__c = '100% Complete',
            Project_Readiness__c = 'Ready for Possession',
            OC_Clearance__c = 'Obtained',
            Finance_Status__c = 'Cleared'
        );
        insert hoA;
        System.debug('Created Handover for Booking A (Stage 2: Inspection): ' + hoA.Id);
    } else {
        hoA = hoA_List[0];
        hoA.Stage__c = 'Inspection';
        hoA.Status__c = 'Inspection In Progress';
        update hoA;
    }

    // Seed active Inspection and Checklist items for Handover A
    List<Inspection__c> inspList = [SELECT Id FROM Inspection__c WHERE Handover__c = :hoA.Id LIMIT 1];
    Inspection__c inspA = null;
    if (inspList.isEmpty()) {
        inspA = new Inspection__c(
            Handover__c = hoA.Id,
            Type__c = 'Auditor Inspection',
            Status__c = 'In Progress',
            Inspection_Date__c = Date.today().addDays(-2),
            Auditor__c = currentUserId,
            External_Token__c = 'INSP-TOK-' + String.valueOf(Crypto.getRandomInteger()).substring(1, 7)
        );
        insert inspA;

        // Seed 6 checklist items: 4 Passed, 2 Issues
        List<Inspection_Checklist_Item__c> chkItems = new List<Inspection_Checklist_Item__c>{
            new Inspection_Checklist_Item__c(Inspection__c = inspA.Id, Item_Name__c = 'Electrical Main Distribution Board', Category__c = 'Electrical', Result__c = 'Pass', Sort_Order__c = 1),
            new Inspection_Checklist_Item__c(Inspection__c = inspA.Id, Item_Name__c = 'Living Room Wall Paint Finish', Category__c = 'Civil & Finishes', Result__c = 'Issue Found', Remarks__c = 'Paint peeling near balcony corner', Sort_Order__c = 2),
            new Inspection_Checklist_Item__c(Inspection__c = inspA.Id, Item_Name__c = 'Master Bathroom Sanitary Plumbing', Category__c = 'Plumbing', Result__c = 'Pass', Sort_Order__c = 3),
            new Inspection_Checklist_Item__c(Inspection__c = inspA.Id, Item_Name__c = 'Master Bedroom UPVC Sliding Window', Category__c = 'Doors & Windows', Result__c = 'Issue Found', Remarks__c = 'Slight friction on left sliding track', Sort_Order__c = 4),
            new Inspection_Checklist_Item__c(Inspection__c = inspA.Id, Item_Name__c = 'Kitchen Granite Countertop & Sink', Category__c = 'Kitchen', Result__c = 'Pass', Sort_Order__c = 5),
            new Inspection_Checklist_Item__c(Inspection__c = inspA.Id, Item_Name__c = 'Balcony Safety Railing & Floor Slope', Category__c = 'Balcony', Result__c = 'Pass', Sort_Order__c = 6)
        };
        insert chkItems;

        // Seed 2 logged snags linked to Handover A
        List<Snag__c> snagsA = new List<Snag__c>{
            new Snag__c(
                Handover__c = hoA.Id,
                Inspection__c = inspA.Id,
                Title__c = 'Paint peeling near balcony sliding door',
                Snag_Description__c = 'Moisture blister and peeling paint on the south corner wall adjacent to the balcony sliding door.',
                Category__c = 'Civil & Finishes',
                Severity__c = 'Medium',
                Status__c = 'Open'
            ),
            new Snag__c(
                Handover__c = hoA.Id,
                Inspection__c = inspA.Id,
                Title__c = 'Master Bedroom sliding track friction',
                Snag_Description__c = 'UPVC window sash catching on lower aluminum track, requires roller adjustment and alignment.',
                Category__c = 'Doors & Windows',
                Severity__c = 'Low',
                Status__c = 'Open'
            )
        };
        insert snagsA;
        System.debug('Seeded Inspection with 6 checklist items and 2 snags for Handover A.');
    }

    // BOOKING B -> STAGE 3: RESOLUTION
    Booking__c bookB = null;
    List<Booking__c> exBookB = [SELECT Id, Name, (SELECT Id FROM Handovers__r) FROM Booking__c WHERE Unit_Id__c = :unitVarthur.Id LIMIT 1];
    if (exBookB.isEmpty()) {
        bookB = new Booking__c(
            Account_Id__c = custMeera.Id,
            Customer__c = custMeera.Id,
            Unit_Id__c = unitVarthur.Id,
            Tower__c = unitVarthur.Tower__c,
            Project__c = unitVarthur.Property__c,
            Status__c = 'Confirmed',
            Approval_Status__c = 'Booking Approved',
            Booking_Date__c = Date.today().addDays(-60),
            Token_Amount__c = 300000,
            Final_Amount__c = 11500000,
            Is_Payment_Plan_Linked__c = true,
            Payment_Plan_Id__c = ppNikoo
        );
        insert bookB;
        System.debug('Created Booking B for Meera Namboodiri: ' + bookB.Id);
    } else {
        bookB = exBookB[0];
    }

    // Handover for Booking B -> STAGE 3: RESOLUTION
    List<Handover__c> hoB_List = [SELECT Id, Stage__c, Status__c FROM Handover__c WHERE Booking__c = :bookB.Id LIMIT 1];
    Handover__c hoB = null;
    if (hoB_List.isEmpty()) {
        hoB = new Handover__c(
            Booking__c = bookB.Id,
            Unit__c = unitVarthur.Id,
            Customer__c = custMeera.Id,
            Stage__c = 'Resolution',
            Status__c = 'Snags In Rectification',
            Target_Handover_Date__c = Date.today().addDays(14),
            Handover_Owner__c = currentUserId,
            Unit_Readiness__c = '100% Complete',
            Project_Readiness__c = 'Ready for Possession',
            OC_Clearance__c = 'Obtained',
            Finance_Status__c = 'Cleared'
        );
        insert hoB;
        // Add 1 in-progress rectification snag
        insert new Snag__c(
            Handover__c = hoB.Id,
            Title__c = 'Master Bathroom exhaust fan wiring check',
            Snag_Description__c = 'Exhaust duct cowl secured; external contractor rectifying wiring connection.',
            Category__c = 'Electrical',
            Severity__c = 'Medium',
            Status__c = 'In Progress',
            External_Token__c = 'SNAG-TOK-' + String.valueOf(Crypto.getRandomInteger()).substring(1, 7)
        );
        System.debug('Created Handover for Booking B (Stage 3: Resolution): ' + hoB.Id);
    } else {
        hoB = hoB_List[0];
        hoB.Stage__c = 'Resolution';
        hoB.Status__c = 'Snags In Rectification';
        update hoB;
    }

    // BOOKING C -> STAGE 4: APPOINTMENT
    Booking__c bookC = null;
    List<Booking__c> exBookC = [SELECT Id, Name, (SELECT Id FROM Handovers__r) FROM Booking__c WHERE Unit_Id__c = :unitSaket.Id LIMIT 1];
    if (exBookC.isEmpty()) {
        bookC = new Booking__c(
            Account_Id__c = custKunal.Id,
            Customer__c = custKunal.Id,
            Unit_Id__c = unitSaket.Id,
            Tower__c = unitSaket.Tower__c,
            Project__c = unitSaket.Property__c,
            Status__c = 'Confirmed',
            Approval_Status__c = 'Booking Approved',
            Booking_Date__c = Date.today().addDays(-90),
            Token_Amount__c = 500000,
            Final_Amount__c = 21000000,
            Is_Payment_Plan_Linked__c = true,
            Payment_Plan_Id__c = ppNikoo
        );
        insert bookC;
        System.debug('Created Booking C for Kunal Oberoi: ' + bookC.Id);
    } else {
        bookC = exBookC[0];
    }

    // Handover for Booking C -> STAGE 4: APPOINTMENT
    List<Handover__c> hoC_List = [SELECT Id, Stage__c, Status__c FROM Handover__c WHERE Booking__c = :bookC.Id LIMIT 1];
    Handover__c hoC = null;
    if (hoC_List.isEmpty()) {
        hoC = new Handover__c(
            Booking__c = bookC.Id,
            Unit__c = unitSaket.Id,
            Customer__c = custKunal.Id,
            Stage__c = 'Appointment',
            Status__c = 'Appointment Confirmed',
            Target_Handover_Date__c = Date.today().addDays(5),
            Handover_Owner__c = currentUserId,
            Appointment_Date__c = DateTime.now().addDays(5),
            Customer_Signee__c = 'Kunal Oberoi',
            Invite_Sent__c = true,
            Reminder_Sent__c = true,
            Reminder_Sent_Date__c = Date.today(),
            Unit_Readiness__c = '100% Complete',
            Project_Readiness__c = 'Ready for Possession',
            OC_Clearance__c = 'Obtained',
            Finance_Status__c = 'Cleared'
        );
        insert hoC;
        System.debug('Created Handover for Booking C (Stage 4: Appointment): ' + hoC.Id);
    } else {
        hoC = hoC_List[0];
        hoC.Stage__c = 'Appointment';
        hoC.Status__c = 'Appointment Confirmed';
        update hoC;
    }

    // BOOKING D -> STAGE 5: COMPLETED
    Booking__c bookD = null;
    List<Booking__c> exBookD = [SELECT Id, Name, (SELECT Id FROM Handovers__r) FROM Booking__c WHERE Unit_Id__c = :unitBanjara.Id LIMIT 1];
    if (exBookD.isEmpty()) {
        bookD = new Booking__c(
            Account_Id__c = custShalini.Id,
            Customer__c = custShalini.Id,
            Unit_Id__c = unitBanjara.Id,
            Tower__c = unitBanjara.Tower__c,
            Project__c = unitBanjara.Property__c,
            Status__c = 'Confirmed',
            Approval_Status__c = 'Booking Approved',
            Booking_Date__c = Date.today().addDays(-120),
            Token_Amount__c = 500000,
            Final_Amount__c = 18500000,
            Is_Payment_Plan_Linked__c = true,
            Payment_Plan_Id__c = ppNikoo
        );
        insert bookD;
        System.debug('Created Booking D for Dr. Shalini Reddy: ' + bookD.Id);
    } else {
        bookD = exBookD[0];
    }

    // Handover for Booking D -> STAGE 5: COMPLETED
    List<Handover__c> hoD_List = [SELECT Id, Stage__c, Status__c FROM Handover__c WHERE Booking__c = :bookD.Id LIMIT 1];
    Handover__c hoD = null;
    if (hoD_List.isEmpty()) {
        hoD = new Handover__c(
            Booking__c = bookD.Id,
            Unit__c = unitBanjara.Id,
            Customer__c = custShalini.Id,
            Stage__c = 'Completed',
            Status__c = 'Completed',
            Target_Handover_Date__c = Date.today().addDays(-7),
            Handover_Owner__c = currentUserId,
            Keys_Handed_Over__c = true,
            Keys_Sets_Count__c = 3,
            Meter_Readings_Captured__c = true,
            Electricity_Meter_Reading__c = 4821.5,
            Water_Meter_Reading__c = 182.5,
            Gas_Meter_Reading__c = 94.2,
            Documents_Handed_Over__c = true,
            Handover_Pack_Generated__c = true,
            Open_Items_Accepted__c = true,
            Warranty_Start_Date__c = Date.today().addDays(-7),
            Warranty_End_Date__c = Date.today().addDays(358),
            Feedback_Rating__c = 5,
            Feedback_Remarks__c = 'Exceptional quality of finishes and seamless handover journey. Very satisfied!',
            Final_Remarks__c = 'Possession completed successfully, all documentation and keys delivered to customer.',
            Unit_Readiness__c = '100% Complete',
            Project_Readiness__c = 'Ready for Possession',
            OC_Clearance__c = 'Obtained',
            Finance_Status__c = 'Cleared'
        );
        insert hoD;
        System.debug('Created Handover for Booking D (Stage 5: Completed): ' + hoD.Id);
    } else {
        hoD = hoD_List[0];
        hoD.Stage__c = 'Completed';
        hoD.Status__c = 'Completed';
        update hoD;
    }

    System.debug('=== SUCCESS: ALL DIVERSE DEMO DATA SEEDED WITH ZERO DUPLICATES! ===');

} catch (Exception ex) {
    Database.rollback(sp);
    System.debug('ERROR SEEDING DATA: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
    throw ex;
}
