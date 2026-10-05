public with sharing class SAPBookingCancellationResponseProcessor {

    public class SAPBookingCancellationResponse {
        public String UNIT;
        public String REMARK;
    }

    // The method now accepts the list of bookings we tried to cancel.
    public static void processResponse(List<Booking__c> originalBookings, String jsonResponse) {
        if (String.isBlank(jsonResponse)) { return; }

        // Create a Map of the responses received from SAP for quick lookup.
        // The key is the UNIT ID, the value is the REMARK.
        Map<String, String> responseMap = new Map<String, String>();
        try {
            List<SAPBookingCancellationResponse> parsedResponses = (List<SAPBookingCancellationResponse>) JSON.deserialize(jsonResponse, List<SAPBookingCancellationResponse>.class);
            for (SAPBookingCancellationResponse resp : parsedResponses) {
                if (String.isNotBlank(resp.UNIT)) {
                    responseMap.put(resp.UNIT, resp.REMARK);
                }
            }
        } catch (Exception ex) {
            System.debug('CRITICAL FAILURE: JSON could not be parsed. Error: ' + ex.getMessage());
            return;
        }

        List<Booking__c> bookingsToUpdate = new List<Booking__c>();
        
        // Loop through every booking we originally sent to SAP.
        for (Booking__c booking : originalBookings) {
            Booking__c bookingForUpdate = new Booking__c(Id = booking.Id);

            // Check if this booking's ID exists in the response from SAP.
            if (responseMap.containsKey(booking.SAP_External_Id__c)) {
                // SUCCESS PATH: We got a response back for this specific booking.
                bookingForUpdate.SAP_Sync_Status__c = 'Success';
                bookingForUpdate.SAP_Sync_Message__c = responseMap.get(booking.SAP_External_Id__c);
            } else {
                // ERROR PATH: SAP did not return a response for this booking.
                bookingForUpdate.SAP_Sync_Status__c = 'Error';
                bookingForUpdate.SAP_Sync_Message__c = 'Processing failed. No response received from SAP for this record.';
            }
            
            bookingsToUpdate.add(bookingForUpdate);
        }

        if (!bookingsToUpdate.isEmpty()) {
            try {
                update bookingsToUpdate;
            } catch (DmlException ex) {
                System.debug('CRITICAL DML FAILURE. Error: ' + ex.getMessage());
            }
        }
    }
}