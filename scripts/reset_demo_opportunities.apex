// Rebalance Demo Opportunities across the Active Sales Pipeline
RecordType rt = [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND DeveloperName = 'Residential_Sales' LIMIT 1];
Project__c proj = [SELECT Id, Name FROM Project__c ORDER BY CreatedDate ASC LIMIT 1];
List<Unit__c> units = [SELECT Id, Name, Configuration__c, Status__c, Base_Price__c FROM Unit__c LIMIT 6];

System.debug('Resetting Demo Opportunities with RecordTypeId: ' + rt.Id);

// 1. Stage: Unit Selection (Deal 1)
List<Opportunity> opp1 = [SELECT Id, Name, StageName, RecordTypeId, Project__c, Tagged_Unit__c FROM Opportunity WHERE Name LIKE '%Vikram Malhotra%' LIMIT 1];
if (!opp1.isEmpty()) {
    opp1[0].RecordTypeId = rt.Id;
    opp1[0].Project__c = proj.Id;
    opp1[0].StageName = 'Unit Selection';
    opp1[0].CloseDate = Date.today().addDays(30);
    opp1[0].Amount = 9850000;
    update opp1[0];
    System.debug('Updated Deal 1 to Unit Selection: ' + opp1[0].Id);
}

// 2. Stage: Quotation Shared (Deal 2)
List<Opportunity> opp2 = [SELECT Id, Name, StageName, RecordTypeId, Project__c, Tagged_Unit__c FROM Opportunity WHERE Name LIKE '%Priya Nair%' LIMIT 1];
if (!opp2.isEmpty()) {
    opp2[0].RecordTypeId = rt.Id;
    opp2[0].Project__c = proj.Id;
    opp2[0].StageName = 'Quotation Shared';
    opp2[0].CloseDate = Date.today().addDays(20);
    if (!units.isEmpty()) opp2[0].Tagged_Unit__c = units[0].Id;
    opp2[0].Amount = 10450000;
    update opp2[0];

    // Ensure a Quote exists
    List<Quote> qList = [SELECT Id FROM Quote WHERE OpportunityId = :opp2[0].Id LIMIT 1];
    if (qList.isEmpty()) {
        Quote q = new Quote(OpportunityId = opp2[0].Id, Name = 'Quotation - ' + units[0].Name + ' (' + units[0].Configuration__c + ')', Status = 'Presented', Description = 'Unit: ' + units[0].Name + ' | Config: ' + units[0].Configuration__c + ' | Super Built-Up Area: 1050 Sq.Ft. (Locked) | Base Rate: ₹4650/sq.ft. | Discount: ₹0/sq.ft. | Parking: 1 Bay(s) (₹275000) | PLC: ₹100/sq.ft. | Finish Package: Standard Vitrified Finish | Net Agreement Value: ₹5262500.00 | Grand Total: ₹5875625.00');
        insert q;
    }
    System.debug('Updated Deal 2 to Quotation Shared: ' + opp2[0].Id);
}

// 3. Stage: Negotiation & Review (Deal 3)
List<Opportunity> opp3 = [SELECT Id, Name, StageName, RecordTypeId, Project__c, Tagged_Unit__c FROM Opportunity WHERE Name LIKE '%Mehra Innovations%' LIMIT 1];
if (!opp3.isEmpty()) {
    opp3[0].RecordTypeId = rt.Id;
    opp3[0].Project__c = proj.Id;
    opp3[0].StageName = 'Negotiation & Review';
    opp3[0].CloseDate = Date.today().addDays(15);
    if (units.size() > 1) opp3[0].Tagged_Unit__c = units[1].Id;
    opp3[0].Amount = 11200000;
    update opp3[0];

    List<Quote> qList = [SELECT Id FROM Quote WHERE OpportunityId = :opp3[0].Id LIMIT 1];
    if (qList.isEmpty() && units.size() > 1) {
        Quote q = new Quote(OpportunityId = opp3[0].Id, Name = 'Quotation - ' + units[1].Name + ' (' + units[1].Configuration__c + ')', Status = 'Presented', Description = 'Unit: ' + units[1].Name + ' | Config: ' + units[1].Configuration__c + ' | Super Built-Up Area: 1420 Sq.Ft. (Locked) | Base Rate: ₹4800/sq.ft. | Discount: ₹50/sq.ft. | Parking: 1 Bay(s) (₹275000) | PLC: ₹150/sq.ft. | Finish Package: Standard Vitrified Finish | Net Agreement Value: ₹7172000.00 | Grand Total: ₹7880600.00');
        insert q;
    }
    System.debug('Updated Deal 3 to Negotiation & Review: ' + opp3[0].Id);
}

// 4. Stage: Quotation Agreed (Deal 4) - Ready for SAP sync
List<Opportunity> opp4 = [SELECT Id, Name, StageName, RecordTypeId, Project__c, Tagged_Unit__c FROM Opportunity WHERE Name LIKE '%Prajwal1Sale%' LIMIT 1];
if (!opp4.isEmpty()) {
    opp4[0].RecordTypeId = rt.Id;
    opp4[0].Project__c = proj.Id;
    opp4[0].StageName = 'Quotation Agreed';
    opp4[0].CloseDate = Date.today().addDays(10);
    if (units.size() > 2) opp4[0].Tagged_Unit__c = units[2].Id;
    opp4[0].Amount = 13500000;
    update opp4[0];

    List<Quote> qList = [SELECT Id, Status FROM Quote WHERE OpportunityId = :opp4[0].Id LIMIT 1];
    if (qList.isEmpty() && units.size() > 2) {
        Quote q = new Quote(OpportunityId = opp4[0].Id, Name = 'Quotation - ' + units[2].Name + ' (' + units[2].Configuration__c + ')', Status = 'Accepted', Description = 'Unit: ' + units[2].Name + ' | Config: ' + units[2].Configuration__c + ' | Super Built-Up Area: 1420 Sq.Ft. (Locked) | Base Rate: ₹4850/sq.ft. | Discount: ₹100/sq.ft. | Parking: 2 Bay(s) (₹550000) | PLC: ₹100/sq.ft. | Finish Package: Standard Vitrified Finish | Net Agreement Value: ₹7437000.00 | Grand Total: ₹8158850.00');
        insert q;
    } else if (!qList.isEmpty()) {
        qList[0].Status = 'Accepted';
        update qList[0];
    }
    System.debug('Updated Deal 4 to Quotation Agreed: ' + opp4[0].Id);
}

System.debug('=== DEMO OPPORTUNITIES REBALANCED SUCCESSFULLY ===');
