// Delete empty dummy bookings with 0 installments
List<Booking__c> emptyBkgs = [
    SELECT Id, Name 
    FROM Booking__c 
    WHERE Id NOT IN (SELECT Booking__c FROM Installment__c)
];
System.debug('Deleting ' + emptyBkgs.size() + ' empty bookings.');
delete emptyBkgs;

// Assign standard SAP Reference IDs to active bookings missing them
List<Booking__c> activeBkgs = [
    SELECT Id, Name, Booking_Reference_ID__c, SAP_Customer_Code__c 
    FROM Booking__c 
    WHERE Booking_Reference_ID__c = null
];
Integer code = 50210;
for (Booking__c b : activeBkgs) {
    b.Booking_Reference_ID__c = 'BR-' + code;
    b.SAP_Customer_Code__c = 'SAP-CUST-' + (code + 100);
    code += 320;
}
update activeBkgs;
System.debug('Assigned Reference IDs to active bookings.');
