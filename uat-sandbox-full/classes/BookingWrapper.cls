public class BookingWrapper {
    public transient Id BOOKING_ID;
    public String PARTNER1;
    public String PARTNER2;
    public String PARTNER3;
    public String PARTNER4;
    public String PARTNER5;
    public String PARTNER6;
    public String Payment_Plan;
    public String CUSTOMER_REF;
    public String CUST_REF_DATE;
    public String SALES_ORG;
    public String DOCUMENT_TYPE;
    public String DIVISION;
    public String DIST_CHANNEL;
    public List<ItemWrapper> ITEM;

    public class ItemWrapper implements Comparable{
        public Integer POSNR;
        public String PLANT_CODE;
        public String MATERIAL;
        public String QTY;
        public String COND1;
        public String COND2;
        public String COND3;
        public String COND4;
        public String COND5;
        public String COND6;
        public String COND7;
        public String COND8;
        public String ZWBS_STRUCTURE;
        public String BILL_BLOCK_ITEM;
        public String UOM;
        public String PRICE1;
        public String PRICE2;
        public String PRICE3;
        public String PRICE4;
        public String PRICE5;
        public String PRICE6;
        public String PRICE7;
        public String PRICE8;
        public List<BillWrapper> BILL;
        
        public Integer compareTo(Object  other) {
            Boolean thisIsZpr0 = (this.COND1 == 'ZPR0');
            Boolean otherIsZpr0 = (((ItemWrapper)other).COND1 == 'ZPR0');
            if (thisIsZpr0 == otherIsZpr0) return 0;
            if (thisIsZpr0) return -1; // This comes first
            return 1;                  // Other comes first
        }
    }

    public class BillWrapper {
        public String ITEM_NO;
        public String BILLING_DATE;
        public String DATE_CODE;
        public String INV_PER;
        public String BILL_VAL;
        public String BILL_BLOCK;
        public String BILL_RULE;
        public String MILESTONE_CODE;
        
        
    }
}