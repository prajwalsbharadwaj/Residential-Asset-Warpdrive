public class SAPBookingCancellationWrappers {

    public class BookingCancellation {
        public transient String BOOKING_ID;
        public String salesdocument;
        public String sales_org;
        public String distr_chan;
        public String division;
        public List<ItemWrapper> item;

        public BookingCancellation() {
            this.item = new List<ItemWrapper>();
        }
    }

    public class ItemWrapper {
        public String ITM_NUMBER;
        public String REASON_REJ;
    }
}