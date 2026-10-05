// Step 1: Delete nonsensical quotes (e.g. CPQ $1,457 or 13-Billion / 29-Billion)
List<Quote> badQuotes = [
    SELECT Id, Name, GrandTotal, OpportunityId, Opportunity.Name 
    FROM Quote 
    WHERE GrandTotal > 500000000 
       OR GrandTotal < 10000 
       OR Name LIKE '%Coloumns%' 
       OR Name LIKE '%Partner Inc%'
];
System.debug('Found ' + badQuotes.size() + ' bad quotes to delete.');
if (!badQuotes.isEmpty()) {
    delete badQuotes;
    System.debug('Deleted bad quotes successfully.');
}

// Step 2: Delete nonsensical bookings (e.g. 1.3 Billion token amount)
List<Booking__c> badBookings = [
    SELECT Id, Name, Booking_Reference_ID__c, Token_Amount__c, Opportunity__c
    FROM Booking__c
    WHERE Token_Amount__c > 50000000 OR Opportunity__r.Name LIKE '%Verification Opp%' OR Opportunity__r.Name LIKE '%Prajwal1Sale%'
];
System.debug('Found ' + badBookings.size() + ' bad bookings to delete.');
if (!badBookings.isEmpty()) {
    // Delete related installments & receipts first if any
    Set<Id> bkgIds = new Set<Id>();
    for (Booking__c b : badBookings) bkgIds.add(b.Id);
    delete [SELECT Id FROM Receipt__c WHERE Booking__c IN :bkgIds];
    delete [SELECT Id FROM Installment__c WHERE Booking__c IN :bkgIds];
    delete [SELECT Id FROM Booking_Applicant__c WHERE Booking__c IN :bkgIds];
    delete badBookings;
    System.debug('Deleted bad bookings and related records.');
}

// Step 3: Remove or fix nonsensical opportunities
List<Opportunity> badOpps = [
    SELECT Id, Name, Amount, Tagged_Unit__c 
    FROM Opportunity 
    WHERE Amount > 500000000 OR Name LIKE '%Verification Opp%' OR Name LIKE '%Prajwal1Sale%'
];
System.debug('Found ' + badOpps.size() + ' bad opps to delete.');
if (!badOpps.isEmpty()) {
    // Delete any remaining quotes on them
    delete [SELECT Id FROM Quote WHERE OpportunityId IN :badOpps];
    delete badOpps;
    System.debug('Deleted bad opps successfully.');
}

System.debug('Cleanup of bad records completed successfully.');
