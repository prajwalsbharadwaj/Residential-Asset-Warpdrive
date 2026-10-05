public with sharing class BookingScheduleCardsCtrl {

    // ===== Public entrypoint (works on Booking__c or Booking_Payment_Schedule__c pages) =====
    @AuraEnabled(cacheable=false)
    public static BookingInterestService.SnapshotDTO fetchSnapshot(Id recordId, String objectApiName) {
        Id bookingId = resolveBookingId(recordId, objectApiName);
        if (bookingId == null) {
            return new BookingInterestService.SnapshotDTO();
        }
        return BookingInterestService.calculateAsOf(bookingId);
    }

    private static Id resolveBookingId(Id recordId, String objectApiName) {
        if (recordId == null) {
            return null;
        }
        Id bookingId;
        if (objectApiName == 'Booking__c') {
            bookingId = recordId;
        } else if (objectApiName == 'Booking_Payment_Schedule__c') {
            bookingId = [SELECT Booking__c FROM Booking_Payment_Schedule__c WHERE Id = :recordId LIMIT 1].Booking__c;
        }
        return bookingId;
    }
}