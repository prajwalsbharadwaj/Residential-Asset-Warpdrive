// End-to-End Verification Script for Residential Sales Flow
Project__c proj = [SELECT Id, Name FROM Project__c LIMIT 1];
Tower__c tow = [SELECT Id, Name FROM Tower__c WHERE Project__c = :proj.Id LIMIT 1];
Unit__c unit = [SELECT Id, Name, Status__c, Super_Built_Up_Area_SqFt__c, Base_Price__c FROM Unit__c WHERE Floor__r.Tower__c = :tow.Id LIMIT 1];
Account acc = [SELECT Id, Name FROM Account LIMIT 1];

System.debug('=== VERIFICATION START ===');
System.debug('Target Project: ' + proj.Name);
System.debug('Target Unit: ' + unit.Name + ' (Status: ' + unit.Status__c + ')');

// 1. Create or get test Opportunity
Opportunity opp = new Opportunity(
    Name = 'Verification Opp - ' + acc.Name,
    AccountId = acc.Id,
    Project__c = proj.Id,
    StageName = 'Unit Selection',
    CloseDate = Date.today().addDays(15)
);
insert opp;
System.debug('1. Opportunity Created in stage: ' + opp.StageName + ' (Id: ' + opp.Id + ')');

// 2. Unit Selection & Quote Generation with strictly locked SBA
UnitSelectionQuoteController.QuoteResultWrapper quoteRes = UnitSelectionQuoteController.saveQuotation(
    opp.Id,
    unit.Id,
    50, // Discount ₹50/sft
    1,  // 1 covered parking slot
    100, // PLC ₹100/sft
    'Standard Vitrified Finish',
    'Special Festival Offer'
);
System.debug('2. Quote Generated: ' + quoteRes.quoteName + ' (Grand Total: ' + quoteRes.grandTotal + ')');

// Check Opportunity Stage
opp = [SELECT Id, StageName, Tagged_Unit__c, Amount FROM Opportunity WHERE Id = :opp.Id];
System.debug('Opportunity updated to Stage: ' + opp.StageName + ' | Tagged Unit: ' + opp.Tagged_Unit__c);
System.assert(opp.StageName == 'Quotation Shared', 'Stage should be Quotation Shared');

// 3. Mark Customer Agreement
UnitSelectionQuoteController.QuoteResultWrapper agreeRes = UnitSelectionQuoteController.agreeQuotation(opp.Id, quoteRes.quoteId);
opp = [SELECT Id, StageName FROM Opportunity WHERE Id = :opp.Id];
System.debug('3. Quote Agreed! Opportunity Stage: ' + opp.StageName);
System.assert(opp.StageName == 'Quotation Agreed', 'Stage should be Quotation Agreed');

// 4. SAP Sales Order Generation & Booking Creation
UnitSelectionQuoteController.SapBookingResultWrapper sapRes = UnitSelectionQuoteController.syncToSapAndCreateBooking(opp.Id);
System.debug('4. SAP Sync & Booking: ' + sapRes.bookingReferenceId + ' | SAP SO: ' + sapRes.sapSalesOrder);
System.assert(sapRes.bookingReferenceId.startsWith('BR-'), 'Must have BR- prefix');

// 5. INVENTORY LOCK VERIFICATION: Unit must be Blocked
Unit__c updatedUnit = [SELECT Id, Name, Status__c FROM Unit__c WHERE Id = :unit.Id];
System.debug('5. Inventory Status: ' + updatedUnit.Name + ' is now ' + updatedUnit.Status__c);
System.assert(updatedUnit.Status__c == 'Blocked', 'Unit must be marked as Blocked');

// 6. Verify Booking Record
Booking__c b = [SELECT Id, Name, Booking_Reference_ID__c, SAP_Customer_Code__c, Total_Booking_Amount__c, Token_Amount__c, Status__c FROM Booking__c WHERE Id = :sapRes.bookingId];
System.debug('6. Booking Record Created: ' + b.Name + ' | Ref ID: ' + b.Booking_Reference_ID__c + ' | Token: ₹' + b.Token_Amount__c);
System.assert(b.Booking_Reference_ID__c == sapRes.bookingReferenceId, 'Booking Ref ID must match');

System.debug('=== VERIFICATION COMPLETE: ALL CHECKS PASSED ===');
