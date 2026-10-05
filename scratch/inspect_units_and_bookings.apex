System.debug('=== INSPECTING BOOKED UNITS VS AVAILABLE UNITS ===');

// 1. Get all units currently assigned to bookings
Set<Id> bookedUnitIds = new Set<Id>();
for (Booking__c b : [SELECT Id, Name, Unit_Id__c, Status__c FROM Booking__c WHERE Unit_Id__c != null]) {
    bookedUnitIds.add(b.Unit_Id__c);
    System.debug('BOOKED UNIT: Booking ' + b.Name + ' (' + b.Status__c + ') has UnitId ' + b.Unit_Id__c);
}

// 2. Find available units across different properties and towers
List<Unit__c> availableUnits = [
    SELECT Id, Name, Tower__c, Tower__r.Name, Property__c, Property__r.Name, Saleable_Area__c, BHK_Configuration__c, Status__c
    FROM Unit__c 
    WHERE Id NOT IN :bookedUnitIds
    ORDER BY Property__r.Name, Tower__r.Name
    LIMIT 20
];
System.debug('FOUND ' + availableUnits.size() + ' AVAILABLE UNITS NOT ASSIGNED TO ANY BOOKING:');
for (Unit__c u : availableUnits) {
    System.debug('AVAIL UNIT: ' + u.Id + ' | ' + u.Name + ' | ' + u.Property__r.Name + ' | ' + u.Tower__r.Name + ' | ' + u.BHK_Configuration__c + ' | Status: ' + u.Status__c);
}

// 3. Inspect existing Handovers and their Bookings
for (Handover__c ho : [SELECT Id, Name, Booking__c, Booking__r.Name, Stage__c, Status__c, Unit__c, Unit__r.Name FROM Handover__c]) {
    System.debug('HANDOVER: ' + ho.Id + ' | ' + ho.Name + ' | Booking: ' + ho.Booking__r.Name + ' | Stage: ' + ho.Stage__c + ' | Status: ' + ho.Status__c + ' | Unit: ' + ho.Unit__r?.Name);
}
