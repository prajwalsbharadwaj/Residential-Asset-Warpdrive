public class BookingConditionService {
    BookingConditionSelector selector = new BookingConditionSelector();
    
    public map<Id,list<Booking_Condition__c>> getBookingConditionsByBookingIds(set<Id> bookingConditionsIds){
        
        list<Booking_Condition__c> bcList = selector.getBookingConditionsByIds(bookingConditionsIds);
        map<Id,list<booking_Condition__c>> bcMap = new map<Id,list<booking_Condition__c>>();
        for(Booking_Condition__c bc:bcList){
            if(!bcMap.containsKey(bc.Booking__c)){
                bcMap.put(bc.Booking__c, new list<Booking_Condition__c>());
            }
            bcMap.get(bc.Booking__c).add(bc);
        }
        
        return bcMap;
    }
}