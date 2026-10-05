public class BookingConditionSelector {
    
    public list<Booking_Condition__c> getBookingConditionsByIds(set<Id> bookingConditionIds){
        list<Booking_Condition__c> bcList = [
          SELECT Id, Name, Amount__c, UOM__c, Condition_Type__c, Quantity__c,Item_Number__c,Booking__c
          FROM Booking_Condition__c WHERE Id in: bookingConditionIds
        ];
        return bcList;
    }
}