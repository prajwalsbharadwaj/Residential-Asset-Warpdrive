public class BookingPaymentScheduleService {
    
    BookingPaymentScheduleSelector selector = new BookingPaymentScheduleSelector();
    
    public Map<Id, List<Booking_Payment_Schedule__c>> getBookingPaymentSchedulesByBookingIds(Set<Id> bookingIds){
        Map<Id, List<Booking_Payment_Schedule__c>> bpsMap = new Map<Id, List<Booking_Payment_Schedule__c>>();
        
        list<Booking_Payment_Schedule__c> bpsList = selector.getBookingPaymentScheduleByBookingIds(bookingIds);
        
        for(Booking_Payment_Schedule__c bps:bpsList){
            if (!bpsMap.containsKey(bps.Booking__c)) {
                bpsMap.put(bps.Booking__c, new List<Booking_Payment_Schedule__c>());
            }
            bpsMap.get(bps.Booking__c).add(bps);
        }
        return bpsMap;
    }
}