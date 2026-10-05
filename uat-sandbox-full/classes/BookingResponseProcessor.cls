public class BookingResponseProcessor {

    public class BookingResponse {
        public String SO;
        public String REMARK;
    }

    public static void processBookingCreationResponse(List<BookingWrapper> payloadList, List<BookingResponse> responseList, string responseBody) {
        try {
            
            List<Booking__c> bList = new List<Booking__c>();

            for (Integer index = 0; index < payloadList.size(); index++) {
                BookingResponse res = responseList.get(index);
                // check response success or failure.
                if(string.isNotBlank(res.SO)){
                    Id bookingId = payloadList.get(index).BOOKING_ID;
                    Booking__c booking = new Booking__c(Id = bookingId);
                    booking.SAP_External_Id__c = res.SO;
                    booking.SAP_Sync_Status__c = 'Success';
                    booking.SAP_Sync_Message__c = responseBody;
                    bList.add(booking);
                }else{
                    Id bookingId = payloadList.get(index).BOOKING_ID;
                    Booking__c booking = new Booking__c(Id = bookingId);
                    booking.SAP_Sync_Status__c = 'Error';
                    booking.SAP_Sync_Message__c = responseBody;
                    bList.add(booking);  
                }
            }

            if (!bList.isEmpty()) {
                //update bList;
               BookingAdminService.updateRecords(bList);
            }
        } catch (Exception e) {
            ExceptionLogger.ExceptionLogPayload logPayload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('BookingResponseProcessor')
                .withDescription('Failed to process SAP booking response: ' + e.getMessage())
                .withClassName('BookingResponseProcessor')
                .withMethodName('processBookingCreationResponse')
                .withRequestBody(JSON.Serialize(responseList))
                .withDomain('SAP')
                .withException(e);
            ExceptionLogger.logException(logPayload);
        }
    }
    
    //Booking Update Response Process.
    public static void processBookingUpdateResponse(List<BookingUpdateWrapper> payloadList, List<BookingResponse> responseList, string responseBody) {
        try {
            
            List<Booking__c> bList = new List<Booking__c>();

            for (Integer index = 0; index < payloadList.size(); index++) {
                BookingResponse res = responseList.get(index);
                // check response success or failure.
                if(string.isNotBlank(res.SO)){
                    Id bookingId = payloadList.get(index).BOOKING_ID;
                    Booking__c booking = new Booking__c(Id = bookingId);
                    booking.SAP_External_Id__c = res.SO;
                    booking.SAP_Sync_Status__c = 'Success';
                    booking.SAP_Sync_Message__c = responseBody;
                    bList.add(booking);
                }else{
                    Id bookingId = payloadList.get(index).BOOKING_ID;
                    Booking__c booking = new Booking__c(Id = bookingId);
                    booking.SAP_Sync_Status__c = 'Error';
                    booking.SAP_Sync_Message__c = responseBody;
                    bList.add(booking);  
                }
            }

            if (!bList.isEmpty()) {
                //update bList;
                BookingAdminService.updateRecords(bList);
            }
        } catch (Exception e) {
            ExceptionLogger.ExceptionLogPayload logPayload = new ExceptionLogger.ExceptionLogPayload()
                .withComponentName('BookingResponseProcessor')
                .withDescription('Failed to process SAP booking response: ' + e.getMessage())
                .withClassName('BookingResponseProcessor')
                .withMethodName('processBookingUpdateResponse')
                .withRequestBody(JSON.Serialize(responseList))
                .withDomain('SAP')
                .withException(e);
            ExceptionLogger.logException(logPayload);
        }
    }
}