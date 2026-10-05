public class BookingUpdateWrapper {
    //Note:- All commented fields are not getting used as of now could be used in future.
        public transient Id BOOKING_ID;
        public String booking;
        //public String sales_grp;
        public String sales_off;
        //public String sales_dist;
        //public String purch_no_c;
        //public String purch_date;
        //public String price_grp;
        //public String incoterms1;
        //public String incoterms2;
        public String co_applicant1;
        public String co_applicant2;
        public String co_applicant3;
        public String co_applicant4;
        public String co_applicant5;
        public List<ItemWrapper> item;

    public class ItemWrapper {
        public String itm_number;
        public String material;
        public String reason_rej;
        public String plant;
        //public String sales_dist;
        //public String incoterms1;
        //public String incoterms2;
        //public String pmnttrms;
        //public String price_list;
        public String division;
        //public List<PartnerWrapper> partner;
        public List<ConditionWrapper> cond;
        //public List<ScheduleLineWrapper> schedule_lines;
        public List<BillingWrapper> bill;
    }

    /*public class PartnerWrapper {
        public String document;
        public String partn_role;
        public String p_numb_old;
        public String p_numb_new;
    }*/
    
    /*public class ScheduleLineWrapper {
        public String itm_number;
        public String req_date;
        public String req_qty;
        public String dlv_date;
    }*/
    public class ConditionWrapper {
        public String itm_number;
        public String cond_type;
        public String cond_value;
    }

    public class BillingWrapper {
        public String ITEM_NO;
        public String BILLING_DATE;
        //public String DATE_CODE; 
        public String INV_PER;
        public String BILL_VAL;
        public String BILL_BLOCK;
        public String BILL_RULE; 
        public String MILESTONE_CODE;
        public String MILESTONE_DES;
    }
}